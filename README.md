# TP1 — ALU

ALU de ancho parametrizable en Verilog, con una demo para la Basys3
(`alu_top`) que carga operandos y opcode por switches/botones y muestra el
resultado en LEDs. Target: Digilent Basys3 (`xc7a35tcpg236-1`).

Este TP es la base del TP2 (UART): ver [Contrato para TPs futuros](#contrato-para-tps-futuros)
más abajo antes de integrarlo en otro diseño.

## Uso

Cloná el repo y abrí `TP_1_ALU.xpr` directo en Vivado 2024.2 (Windows o
Linux) — el proyecto usa rutas relativas (`$PPRDIR/rtl/...`), así que
funciona igual en cualquier máquina, no hace falta reconfigurar nada.

## Estructura

```
TP_1_ALU/
  TP_1_ALU.xpr   proyecto Vivado (trackeado en git)
  docs/          enunciado del TP
  rtl/           alu.v (nucleo), alu_top.v (wrapper de demo para Basys3)
  tb/            testbenches (ver "Simulacion")
  constraints/   basys3.xdc
  scripts/       build_and_sim.tcl (regenera el .xpr si hace falta, ver mas abajo)
```

Lo que NO está en git (se regenera solo al abrir/compilar el proyecto):
`TP_1_ALU.cache/`, `TP_1_ALU.hw/`, `TP_1_ALU.ip_user_files/`,
`TP_1_ALU.sim/`, `.Xil/`, `*.jou`, `*.log`.

## `alu.v` — interfaz

```verilog
module alu #(
    parameter WIDTH = 32
) (
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    input  wire [5:0]       op,
    output reg  [WIDTH-1:0] result,
    output wire              zero,
    output reg               carry_out,
    output reg               overflow
);
```

Puramente combinacional. `WIDTH` es parametrizable (la demo `alu_top` la
instancia con `WIDTH=8`; los testbenches del núcleo usan `WIDTH=32`).

Opcodes (`op[5:0]`, estilo MIPS funct):

| Mnemonico | Valor       | Operacion                          |
|-----------|-------------|-------------------------------------|
| `OP_ADD`  | `6'b100000` | `result = a + b`                    |
| `OP_SUB`  | `6'b100010` | `result = a - b`                    |
| `OP_AND`  | `6'b100100` | `result = a & b`                    |
| `OP_OR`   | `6'b100101` | `result = a \| b`                   |
| `OP_XOR`  | `6'b100110` | `result = a ^ b`                    |
| `OP_SRA`  | `6'b000011` | `result = a >>> b[log2(WIDTH)-1:0]` (aritmetico, extiende signo) |
| `OP_SRL`  | `6'b000010` | `result = a >> b[log2(WIDTH)-1:0]`  (logico, rellena con 0) |
| `OP_NOR`  | `6'b100111` | `result = ~(a \| b)`                |
| otro      | —           | `result = 0`                        |

Flags:
- `zero`: `result == 0`.
- `carry_out`: solo tiene sentido para `ADD`/`SUB`. Para `ADD` es el carry
  aritmetico normal. Para `SUB` es el bit alto de la resta sin signo
  `{1'b0,a} - {1'b0,b}` (o sea, se activa cuando `a < b` sin signo — un
  "borrow", no el carry invertido estilo x86). Para el resto de las
  operaciones queda en 0.
- `overflow`: overflow aritmetico con signo en `ADD`/`SUB` (0 en el resto).
- El shift amount para `SRL`/`SRA` sale de los bits bajos de `b`
  (`b[$clog2(WIDTH)-1:0]`), no hay rango invalido posible.

## `alu_top.v` — wrapper de demo (Basys3)

Registra A, B y Op por separado; cada boton confirma que el valor actual de
los switches se cargue en su registro. No tiene reset ni debounce (ver
"Limitaciones conocidas").

```
sw_data[7:0] --+--(btn_load_a)--> reg_a[7:0]  --\
               \--(btn_load_b)--> reg_b[7:0]  ---> alu (WIDTH=8) --> led_result[7:0] + flags
sw_op[5:0] ------(btn_load_op)--> reg_op[5:0] --/
```

### Mapeo de pines (`constraints/basys3.xdc`)

| Señal           | Pines Basys3     |
|-----------------|------------------|
| `clk`           | `W5` (100 MHz)   |
| `sw_data[7:0]`  | SW0–SW7          |
| `sw_op[5:0]`    | SW8–SW13         |
| `btn_load_a`    | BTNU             |
| `btn_load_b`    | BTNL             |
| `btn_load_op`   | BTNR             |
| `led_result[7:0]` | LED0–LED7      |
| `led_zero`      | LED8             |
| `led_carry`     | LED9             |
| `led_overflow`  | LED10            |

## Simulación

Un solo simulation set de Vivado (`sim_1`, top `alu_tb_simple`), archivo
único y autocontenido (`tb/alu_tb_simple.v`, sin includes ni tasks
compartidas): aplica una docena de casos fijos sobre `alu.v` (carry/borrow
y overflow en ADD/SUB, patrones de bits en AND/OR/XOR/NOR, SRL vs SRA) y
compara contra valores esperados escritos a mano en cada `check(...)`.

Para correrla: abrí el `.xpr`, **Run Simulation → Run Behavioral
Simulation**. También se puede correr suelta con iverilog desde `tb/`:

```bash
iverilog -o sim.out ../rtl/alu.v alu_tb_simple.v && vvp sim.out
```

### Regenerar el `.xpr` (batch, sin GUI)

Normalmente no hace falta — alcanza con abrir `TP_1_ALU.xpr` ya
commiteado. `scripts/build_and_sim.tcl` sirve si el proyecto se corrompe o
para validar en batch que todo sigue compilando y simulando bien (es
literalmente cómo se generó el `.xpr` que está en el repo):

```bash
source /ruta/a/Vivado/2024.2/settings64.sh   # settings64.bat en Windows
cd tps/TP_1_ALU
vivado -mode batch -source scripts/build_and_sim.tcl -tclargs "$(pwd)"
```

## Síntesis / implementación

Corridas verificadas sobre este diseño: síntesis y bitstream completos sin
critical warnings, timing cumplido a 100MHz (`All user specified timing
constraints are met`), utilización mínima (69 LUTs de 20800).

## Limitaciones conocidas

- `btn_load_a/b/op` no tienen debounce ni sincronizador de entrada. Un
  toque de botón real puede rebotar y disparar varias cargas seguidas del
  mismo valor (inofensivo, es idempotente), o quedar metaestable un ciclo
  aislado. Para esta demo no genera fallas funcionales, pero es lo primero
  a sospechar si algo se comporta raro al tocar los botones en la placa.
- No hay reset: al energizar la placa, `reg_a`/`reg_b`/`reg_op` arrancan en
  un valor no inicializado hasta la primera carga por botón.

## Contrato para TPs futuros

El TP2 (UART) va a partir de este proyecto. Lo reutilizable en principio:

- **`alu.v`** tal cual, como núcleo combinacional parametrizable en
  `WIDTH` — se puede instanciar con otro ancho o conectar a otro
  datapath sin tocarlo.
- La estructura de carpetas (`docs/`, `rtl/`, `tb/`, `constraints/`,
  `scripts/`) y la convención de commitear el `.xpr` (rutas relativas,
  `$PPRDIR/...`) pero ignorar el cache/build que genera Vivado
  (`.gitignore` en `tps/`).

Lo que **no** es reusable sin cambios: `alu_top.v` es un wrapper de demo
pensado solo para probar la ALU sola en la Basys3 (switches como entrada
directa) — el UART va a necesitar su propio wrapper/datapath, no éste.
