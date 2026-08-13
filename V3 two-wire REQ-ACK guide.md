# 8051 Calculator V3 — REQ/ACK-Only Connection

This variant removes the eight-wire event data bus. It uses the built-in 8051
UART and the two crossed wires shown in the Proteus schematic:

| Process controller | Display controller | Purpose |
|---|---|---|
| `P3.1/TXD` output | `P3.0/RXD` input | Message byte |
| `P3.0/RXD` input | `P3.1/TXD` output | `06H` ACK byte |
| `GND` | `GND` | Common reference |

Firmware files:

- `Big Program V3 Process Controller 2-Wire.asm`
- `Big Program V3 Display Controller 2-Wire.asm`

`P2` on the process controller and `P1` on the display controller are no longer
connected to each other.

## How one byte is transferred

The process controller transmits a standard 8051 UART frame:

1. One low start bit.
2. Eight data bits, least-significant bit first.
3. One high stop bit.
4. The display controller sends byte `06H` back through its own TX pin.
5. The process controller accepts the next keypad action after receiving ACK.

The data is serialized on TX/RX, so no separate parallel event bus is required.
The command, digit, result, and error values remain necessary because
the display controller still needs to know what to show; they now travel one bit
at a time through the hardware UART.

## Startup behavior

The display controller initializes the LCD and shows `READY` and the mode menu
locally. It does not need a startup message from the process controller. The
process controller starts scanning the keypad immediately.

## Remaining hardware

### Process controller

| Hardware | Port |
|---|---|
| 4×4 keypad | `P1.0–P1.7` |
| UART `TXD` to display `RXD` | `P3.1` |
| UART `RXD` from display `TXD` | `P3.0` |

### Display controller

| Hardware | Port |
|---|---|
| LCD `D0–D7` | `P1.0–P1.7` |
| UART `RXD` from process `TXD` | `P3.0` |
| UART `TXD` to process `RXD` | `P3.1` |
| LCD `RS` | `P2.0` |
| LCD `RW` | `P2.1` |
| LCD `EN` | `P2.2` |

## Clock requirement

Both programs configure Timer 1 for 9600 baud with an 11.0592 MHz oscillator:
`TH1 = TL1 = FDH`, UART mode 1, and `SMOD = 0`. Set both AT89C52 clock-frequency
properties in Proteus to 11.0592 MHz.

If another oscillator frequency is used, recalculate `TH1` in both firmware
files. A mismatch can cause the process controller to wait indefinitely for ACK.

## LCD checks for the supplied schematic

- Connect LCD `VSS` to ground and `VDD` to `+5 V`.
- Do not leave LCD `VEE` floating. Connect it to the wiper of a 10 kΩ contrast
  potentiometer between `+5 V` and ground. For a quick Proteus test, connect
  `VEE` directly to ground.
- LCD data `D0-D7` connects to display-controller `P1.0-P1.7`.
- LCD `RS`, `RW`, and `EN` connect to `P2.0`, `P2.1`, and `P2.2`.
- Tie both AT89C52 `EA` pins high and provide a valid reset pulse.
- Both controllers and the LCD must share ground.
