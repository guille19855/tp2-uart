`timescale 1ns / 1ps

// Testbench autocontenido para uart_rx.v (sin includes ni tasks
// compartidas). No usa baud_rate_gen: genera `s_tick` con un divisor
// simple para simular rapido, ya que a uart_rx solo le importa la
// cantidad de ticks entre eventos, no la frecuencia real.
//   iverilog -o sim.out ../rtl/uart_rx.v uart_rx_tb.v && vvp sim.out

module uart_rx_tb;

    localparam integer DBIT     = 8;
    localparam integer SB_TICK  = 16;
    localparam integer CLK_PERIOD = 10;  // ns
    localparam integer TICK_DIV   = 4;   // s_tick cada TICK_DIV ciclos de clk

    reg clk, reset;
    reg rx;
    wire rx_done;
    wire [DBIT-1:0] d_out;

    integer errors = 0;
    integer checks = 0;

    // Generador de s_tick local al testbench (no es baud_rate_gen: solo
    // necesitamos 16 ticks por bit, no una frecuencia real de baudios).
    // Declarado ANTES de instanciar el DUT para que la conexion de puerto
    // no cree un wire implicito separado del reg de abajo.
    reg [$clog2(TICK_DIV)-1:0] tick_cnt = 0;
    reg s_tick_r = 1'b0;

    uart_rx #(
        .DBIT    (DBIT),
        .SB_TICK (SB_TICK)
    ) dut (
        .clk     (clk),
        .reset   (reset),
        .rx      (rx),
        .s_tick  (s_tick_r),
        .rx_done (rx_done),
        .d_out   (d_out)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    always @(posedge clk) begin
        if (tick_cnt == TICK_DIV-1) begin
            tick_cnt  <= 0;
            s_tick_r  <= 1'b1;
        end else begin
            tick_cnt  <= tick_cnt + 1'b1;
            s_tick_r  <= 1'b0;
        end
    end

    task automatic wait_ticks(input integer n);
        integer j;
        begin
            for (j = 0; j < n; j = j + 1)
                @(posedge s_tick_r);
        end
    endtask

    // Maneja start bit, 8 bits de datos (LSB primero) y stop bit, todos
    // mantenidos estables durante los 16 ticks de su bit correspondiente.
    task automatic send_byte(input [DBIT-1:0] data);
        integer i;
        begin
            rx = 1'b0;               // start bit
            wait_ticks(16);
            for (i = 0; i < DBIT; i = i + 1) begin
                rx = data[i];
                wait_ticks(16);
            end
            rx = 1'b1;                // stop bit
            wait_ticks(SB_TICK);
        end
    endtask

    // Envia un byte y verifica que rx_done pulse con el dato esperado.
    // rx_done es una salida combinacional (Mealy): se activa durante UN
    // solo ciclo de clk, justo cuando termina el bit de Stop. En vez de
    // mirarla una sola vez (hay una carrera con el ultimo tick de
    // send_byte), la vigilamos en cada flanco de clk mientras se envia
    // el frame completo, asi no se puede perder el pulso.
    task automatic check_byte(input [DBIT-1:0] data);
        integer wait_cycles;
        reg got_done;
        reg [DBIT-1:0] got_data;
        begin
            got_done = 1'b0;
            got_data = {DBIT{1'b0}};

            fork : send_and_watch
                begin
                    send_byte(data);
                end
                begin
                    wait_cycles = 0;
                    while (wait_cycles < (2 + DBIT + 2) * 16 * TICK_DIV) begin
                        @(posedge clk);
                        if (rx_done) begin
                            got_done = 1'b1;
                            got_data = d_out;
                        end
                        wait_cycles = wait_cycles + 1;
                    end
                end
            join

            checks = checks + 1;
            if (!got_done) begin
                errors = errors + 1;
                $display("FAIL data=%h: rx_done nunca se activo", data);
            end else if (got_data !== data) begin
                errors = errors + 1;
                $display("FAIL data=%h: d_out=%h", data, got_data);
            end else begin
                $display("OK   data=%h recibido correctamente", data);
            end

            // Deja un respiro en idle (rx=1) antes del siguiente frame
            rx = 1'b1;
            wait_ticks(8);
        end
    endtask

    initial begin
        clk   = 1'b0;
        reset = 1'b1;
        rx    = 1'b1; // linea en reposo = 1
        repeat (4) @(negedge clk);
        reset = 1'b0;
        wait_ticks(4);

        check_byte(8'h00);
        check_byte(8'hFF);
        check_byte(8'hA5);
        check_byte(8'h55);
        check_byte(8'h01);
        check_byte(8'h80);

        // Reset a mitad de una recepcion: debe volver a IDLE y no marcar
        // rx_done espurio para el frame interrumpido. Importante: hay que
        // matar send_byte(8'hC3) en el momento del reset (con `disable`),
        // si no sigue solo moviendo `rx` con los bits restantes del frame
        // interrumpido y esos bits "fantasma" contaminan la prueba siguiente.
        fork : reset_mid_frame
            send_byte(8'hC3);
            begin
                wait_ticks(20); // interrumpe a mitad del byte de datos
                reset = 1'b1;
                @(posedge clk);
                reset = 1'b0;
                disable reset_mid_frame;
            end
        join

        checks = checks + 1;
        if (rx_done) begin
            errors = errors + 1;
            $display("FAIL: rx_done activo justo despues del reset a mitad de frame");
        end else begin
            $display("OK   sin rx_done espurio tras reset a mitad de frame");
        end

        rx = 1'b1;
        wait_ticks(8);

        // Verifica que el receptor vuelve a funcionar normalmente
        check_byte(8'h3C);

        if (errors == 0)
            $display("TEST PASSED: %0d checks, 0 errors", checks);
        else
            $display("TEST FAILED: %0d checks, %0d errors", checks, errors);

        $finish;
    end

endmodule
