`timescale 1ns / 1ps

// Testbench de punta a punta para uart_top.v. A diferencia de todos los
// testbenches anteriores, aca el DUT es una caja negra de verdad: solo se
// manejan los pines externos (clk, reset, rx, tx), sin acceso a señales
// internas ni al tick del baud rate generator. Por eso el timing es
// puramente por tiempo real (#delay), como lo haria un dispositivo serie
// externo de verdad.
//
// Protocolo (ver rtl/alu_ctrl.v): host manda 3 bytes [op][A][B], la FPGA
// responde con 2 bytes [result][flags], flags={5'b0,zero,carry,overflow}.
//
// Usa un DVSR chico (5) via parametro para simular rapido; en la placa se
// usaria el default (651, para 9600 baudios a 100MHz).
//   iverilog -o sim.out ../rtl/*.v uart_top_tb.v && vvp sim.out

module uart_top_tb;

    localparam integer DVSR       = 5;
    localparam integer WIDTH      = 8;
    localparam integer DBIT       = 8;
    localparam integer SB_TICK    = 16;
    localparam integer CLK_PERIOD = 10;                    // ns
    localparam integer BIT_NS     = 16 * DVSR * CLK_PERIOD; // duracion real de 1 bit

    localparam [5:0]
        OP_ADD = 6'b100000,
        OP_SUB = 6'b100010,
        OP_AND = 6'b100100,
        OP_OR  = 6'b100101,
        OP_XOR = 6'b100110,
        OP_SRA = 6'b000011,
        OP_SRL = 6'b000010,
        OP_NOR = 6'b100111;

    reg  clk, reset;
    reg  rx;
    wire tx;

    integer errors = 0;
    integer checks = 0;

    uart_top #(
        .DVSR    (DVSR),
        .WIDTH   (WIDTH),
        .DBIT    (DBIT),
        .SB_TICK (SB_TICK)
    ) dut (
        .clk   (clk),
        .reset (reset),
        .rx    (rx),
        .tx    (tx)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    // Manda un byte por rx sosteniendo cada bit BIT_NS, como un host real.
    task automatic send_byte(input [DBIT-1:0] data);
        integer i;
        begin
            rx = 1'b0; // start
            #(BIT_NS);
            for (i = 0; i < DBIT; i = i + 1) begin
                rx = data[i];
                #(BIT_NS);
            end
            rx = 1'b1; // stop
            #(BIT_NS);
        end
    endtask

    // Espera a que tx este en 0 (espera de NIVEL, no de flanco). Importante:
    // no podemos esperar un FLANCO de bajada, porque el controlador puede
    // empezar a responder mientras el testbench todavia esta terminando de
    // sostener el bit de Stop del ultimo byte pedido (send_byte sostiene
    // cada bit el tiempo completo, pero el receptor ya sabe el valor desde
    // la mitad del bit) - para cuando el testbench mira, el flanco real ya
    // paso y nunca se lo detecta como flanco. Chequeando el NIVEL en vez del
    // flanco, funciona sin importar si llegamos un poco antes o despues.
    task automatic wait_tx_low;
        begin
            while (tx !== 1'b0)
                @(negedge clk);
        end
    endtask

    task automatic check_roundtrip(
        input [5:0] op, input [7:0] a, input [7:0] b,
        input [7:0] exp_result, input exp_zero, input exp_carry, input exp_overflow
    );
        reg [7:0] exp_flags;
        reg [7:0] got_result, got_flags;
        reg start_ok_1, stop_ok_1, start_ok_2, stop_ok_2;
        integer local_errors;
        integer i;
        begin
            local_errors = 0;
            checks = checks + 1;
            exp_flags = {5'b0, exp_zero, exp_carry, exp_overflow};

            send_byte({2'b00, op});
            send_byte(a);
            send_byte(b);

            // Primer byte de respuesta: result. Captura los 8 bits en un
            // registro y compara el byte entero al final (mas facil de
            // diagnosticar que comparar bit a bit).
            wait_tx_low;
            #(BIT_NS/4);
            start_ok_1 = (tx === 1'b0);
            for (i = 0; i < DBIT; i = i + 1) begin
                #(BIT_NS);
                got_result[i] = tx;
            end
            #(BIT_NS);
            stop_ok_1 = (tx === 1'b1);

            // Segundo byte de respuesta: flags
            wait_tx_low;
            #(BIT_NS/4);
            start_ok_2 = (tx === 1'b0);
            for (i = 0; i < DBIT; i = i + 1) begin
                #(BIT_NS);
                got_flags[i] = tx;
            end
            #(BIT_NS);
            stop_ok_2 = (tx === 1'b1);

            if (!start_ok_1) begin
                local_errors = local_errors + 1;
                $display("FAIL op=%b: bit de Start (result) no esta en 0", op);
            end
            if (!stop_ok_1) begin
                local_errors = local_errors + 1;
                $display("FAIL op=%b: bit de Stop (result) no esta en 1", op);
            end
            if (got_result !== exp_result) begin
                local_errors = local_errors + 1;
                $display("FAIL op=%b a=%h b=%h: result=%h esperado=%h", op, a, b, got_result, exp_result);
            end
            if (!start_ok_2) begin
                local_errors = local_errors + 1;
                $display("FAIL op=%b: bit de Start (flags) no esta en 0", op);
            end
            if (!stop_ok_2) begin
                local_errors = local_errors + 1;
                $display("FAIL op=%b: bit de Stop (flags) no esta en 1", op);
            end
            if (got_flags !== exp_flags) begin
                local_errors = local_errors + 1;
                $display("FAIL op=%b: flags=%b esperado=%b", op, got_flags, exp_flags);
            end

            if (local_errors == 0)
                $display("OK   op=%b a=%h b=%h -> result=%h flags(z,c,v)=%b%b%b  (ida y vuelta completa por UART)",
                          op, a, b, exp_result, exp_zero, exp_carry, exp_overflow);
            else
                errors = errors + 1;

            #(BIT_NS); // respiro antes del siguiente pedido
        end
    endtask

    initial begin
        clk   = 1'b0;
        reset = 1'b1;
        rx    = 1'b1;
        repeat (4) @(negedge clk);
        reset = 1'b0;
        #(BIT_NS);

        check_roundtrip(OP_ADD, 8'd10, 8'd20, 8'd30,  1'b0, 1'b0, 1'b0);
        check_roundtrip(OP_ADD, 8'hFF, 8'h01, 8'h00,  1'b1, 1'b1, 1'b0);
        check_roundtrip(OP_SUB, 8'd5,  8'd10, 8'hFB,  1'b0, 1'b1, 1'b0);
        check_roundtrip(OP_AND, 8'hAA, 8'h55, 8'h00,  1'b1, 1'b0, 1'b0);
        check_roundtrip(OP_SRL, 8'h81, 8'd1,  8'h40,  1'b0, 1'b0, 1'b0);

        if (errors == 0)
            $display("TEST PASSED: %0d checks, 0 errors", checks);
        else
            $display("TEST FAILED: %0d checks, %0d errors", checks, errors);

        $finish;
    end

endmodule
