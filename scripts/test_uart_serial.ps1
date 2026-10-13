<#
.SYNOPSIS
    Prueba uart_top en la Basys3 mandando una operacion [opcode][A][B] por el
    puerto serie y mostrando la respuesta [result][flags].

.DESCRIPTION
    No necesita ningun programa de terminal externo: abre el puerto COM
    directo desde PowerShell (9600 baudios, 8N1, sin control de flujo, que
    es lo que espera el diseno), manda los 3 bytes del pedido, y lee los 2
    bytes de respuesta.

    flags = {5'b0, zero, carry, overflow} (bit2=zero, bit1=carry, bit0=overflow)

.EXAMPLE
    .\test_uart_serial.ps1 -Op ADD -A 10 -B 20
    # ADD: 10 + 20 = 30

.EXAMPLE
    .\test_uart_serial.ps1 -Op SUB -A 5 -B 10
    # SUB: 5 - 10 = 0xFB (251), con borrow
#>
param(
    [string]$Port = "COM3",
    [string]$Op = "ADD",   # ADD SUB AND OR XOR NOR SRL SRA (o un valor hex como 0x20)
    [byte]$A  = 10,
    [byte]$B  = 20
)

$opCodes = @{
    "ADD" = 0x20; "SUB" = 0x22; "AND" = 0x24; "OR" = 0x25
    "XOR" = 0x26; "NOR" = 0x27; "SRL" = 0x02; "SRA" = 0x03
}
if ($opCodes.ContainsKey($Op.ToUpper())) {
    $opByte = [byte]$opCodes[$Op.ToUpper()]
    $opName = $Op.ToUpper()
} else {
    $opByte = [byte]$Op
    $opName = "op=0x{0:X2}" -f $opByte
}

$sp = New-Object System.IO.Ports.SerialPort $Port, 9600, ([System.IO.Ports.Parity]::None), 8, ([System.IO.Ports.StopBits]::One)
$sp.Handshake = [System.IO.Ports.Handshake]::None
$sp.ReadTimeout = 3000
$sp.WriteTimeout = 2000

try {
    $sp.Open()
    # Pausa corta: algunos puentes USB-UART meten un glitch en la linea TX
    # justo al abrir el puerto, que el receptor de la FPGA puede llegar a
    # interpretar como un bit de Start falso y correr el alineamiento del
    # siguiente byte. Mejor dejar asentar la linea antes de mandar nada.
    Start-Sleep -Milliseconds 200
    $sp.DiscardInBuffer()
    Write-Host "Puerto $Port abierto (9600 8N1)." -ForegroundColor DarkGray

    Write-Host ("Mandando: {0}  A=0x{1:X2} ({1})  B=0x{2:X2} ({2})" -f $opName, $A, $B)
    $sp.Write([byte[]]@($opByte), 0, 1)
    $sp.Write([byte[]]@($A), 0, 1)
    $sp.Write([byte[]]@($B), 0, 1)

    $result = $sp.ReadByte()
    $flags  = $sp.ReadByte()

    $zero     = ($flags -band 0x04) -ne 0
    $carry    = ($flags -band 0x02) -ne 0
    $overflow = ($flags -band 0x01) -ne 0

    Write-Host ""
    Write-Host ("result = 0x{0:X2}  ({0})" -f $result) -ForegroundColor Green
    Write-Host ("flags  = 0x{0:X2}  (zero={1} carry={2} overflow={3})" -f $flags, $zero, $carry, $overflow) -ForegroundColor Green
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    if ($sp.IsOpen) { $sp.Close() }
}
