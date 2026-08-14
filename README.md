# 8051 Calculator V3 — Project 06

Project 06 is a dual-controller AT89C52 calculator derived from Project 04. One
controller handles the keypad, calculator state, ALU operations, and error
detection. The second controller controls the 16×2 LCD and presentation logic.

The controllers communicate through the built-in 8051 UART. Each message byte
sent by the process controller is acknowledged by the display controller with
`06H`; no parallel event bus is required.

## Main features

- Arithmetic, 8-bit Logical, and Advance operating modes.
- Continuously right-scrolling mode title on LCD line 2.
- Logical-mode title changed to `8bit LOGIC`.
- Equation entry remains on LCD line 1 while the title scrolls.
- Cursor is hidden during each line-2 redraw and restored to line 1 afterward.
- Consecutive binary operators replace one another: `1+-` displays `1-`.
- Logical digits `2–9` are silently ignored; only `0` and `1` enter operands.
- Keys `4` and `6` manually select logical-expression windows when an equation
  exceeds the LCD's 16-character width.
- Non-exact division uses a mixed-fraction display such as `3⌟1⌟4`.
- Input-size, arithmetic-overflow, divide-by-zero, and 8-bit-length errors.

## Firmware files

Program the matching firmware into each controller:

| Controller | Source | Firmware |
|---|---|---|
| Process/keypad controller | [Process ASM](<Big Program V3 Process Controller 2-Wire.asm>) | [Process HEX](<Big Program V3 Process Controller 2-Wire.hex>) |
| Display/LCD controller | [Display ASM](<Big Program V3 Display Controller 2-Wire.asm>) | [Display HEX](<Big Program V3 Display Controller 2-Wire.hex>) |

The `.lst` files are the corresponding ASEM-51 assembly listings.

## Hardware connections

Both AT89C52 controllers require an 11.0592 MHz oscillator, a valid reset
circuit, `EA` tied high, and a common ground.

### Process controller

| Hardware | AT89C52 connection |
|---|---|
| 4×4 keypad | `P1.0–P1.7` |
| UART transmit to display | `P3.1/TXD` |
| UART ACK receive from display | `P3.0/RXD` |

### Display controller

| Hardware | AT89C52 connection |
|---|---|
| LCD `D0–D7` | `P1.0–P1.7` |
| LCD `RS` | `P2.0` |
| LCD `RW` | `P2.1` |
| LCD `EN` | `P2.2` |
| UART receive from process | `P3.0/RXD` |
| UART ACK transmit to process | `P3.1/TXD` |

Cross-connect the serial pins:

```text
Process P3.1/TXD  ->  Display P3.0/RXD
Display P3.1/TXD  ->  Process P3.0/RXD
Process GND       ---  Display GND
```

Connect the LCD contrast pin `VEE` to the wiper of a 10 kΩ potentiometer between
`+5 V` and ground. For a quick Proteus test, `VEE` can be connected directly to
ground.

## UART configuration

Both controllers use:

- UART mode 1
- 9600 baud
- Timer 1 mode 2
- `TH1 = TL1 = FDH`
- `SMOD = 0`
- 11.0592 MHz oscillator

Using a different oscillator without recalculating `TH1` can prevent ACK from
being received and stop keypad events from reaching the display.

## Controls

### Mode menu

| Key | Mode |
|---|---|
| `1` | Arithmetic |
| `2` | 8-bit Logical |
| `3` | Advance |

### Common controls

| Key | Action |
|---|---|
| `*` | Clear the current expression |
| `#` | Execute the current expression |
| `*`, then `#` | Return to the mode menu |

### Mode operators

| Mode | `A` | `B` | `C` | `D` |
|---|---|---|---|---|
| Arithmetic | Add | Subtract | Multiply | Divide |
| Logical | AND | OR | XOR | NOT |
| Advance | Square | — | — | — |

The physical operator symbols printed on a keypad may differ from the logical
`A–D` key codes. Follow the keypad wiring used by the process-controller source.

## LCD behavior

- Line 1 displays the equation and operator symbols.
- Line 2 scrolls the selected mode title to the right during entry.
- A result or error replaces the scrolling title.
- Clear restarts the active mode's marquee.
- The display uses software-generated 16-character frames instead of the
  HD44780 display-shift command, so line 1 never shifts with line 2.

In Logical mode, an expression can contain up to 18 characters: eight bits, one
operator, eight bits, and the equals symbol. When it exceeds 16 characters,
key `4` selects the left window and key `6` selects the right window.

## Project 04 compared with Project 06

| Feature | Project 04 | Project 06 |
|---|---|---|
| Mode title | Static | Continuously scrolls right |
| Logical title | `LOGIC: 0/1 ONLY` | `8bit LOGIC` |
| Invalid Logical digits | Shows `ERROR:USE 0/1` | Digits `2–9` are ignored |
| Consecutive operators | `1+-` displays `ANS-` | `1+-` displays `1-` |
| Cursor during line-2 redraw | Not applicable | Hidden, then restored to line 1 |
| Logical keys `4` and `6` | Manual expression windows | Unchanged |
| Division and fractions | Mixed-fraction support | Unchanged |
| UART protocol and wiring | Two-wire UART with ACK | Unchanged |
| LCD port assignment | Data on P1; control on P2 | Unchanged |
| ALU operations | Project 04 implementation | Unchanged |

Project 04 remains unchanged.

## Build verification

Both Project 06 sources assemble with ASEM-51 V1.3 with zero errors. The
generated Intel HEX files contain valid checksums and fit within the AT89C52's
8 KB program-memory capacity.

For protocol details and troubleshooting, see
[V3 two-wire REQ-ACK guide](<V3 two-wire REQ-ACK guide.md>).
