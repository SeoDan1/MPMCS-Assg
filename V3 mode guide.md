# 8051 Calculator V3 — Three-Mode Guide

## Startup

The LCD shows `READY` briefly, then:

```text
SELECT 3 MODES
1:AR 2:LOG 3:ADD
```

Press `1`, `2`, or `3` to enter a mode.

## Blinking input cursor

The LCD hardware cursor blinks at the next character position whenever operand
input is required. It is hidden on the startup/menu pages and while displaying
results or errors. It is also hidden after selecting unary NOT or square because
those operations wait for `#` rather than another operand.

## Common keys

| Key | Function |
|---|---|
| `#` | Equals / execute the selected operation |
| `*` | Clear the current expression and stay in the current mode |
| `*`, then `#` | Return to the mode-selection menu |

`*`, then `#` is a sequential key combination. After `*` clears the current expression, the immediately following `#` opens the mode menu. Any other next key starts a new expression in the same mode.

## Mode 1 — Arithmetic

Inputs are unsigned decimal values from 0 to 65535. Signed negative results are supported.

| Key | Operation |
|---|---|
| `A` | Addition |
| `B` | Subtraction |
| `C` | Multiplication |
| `D` | Division |

Example: `12 A 3 #` displays `15`.

## Mode 2 — Logical

Only keys `0` and `1` are accepted as input digits. Each operand may contain at most eight bits. Results are always displayed as exactly eight binary digits.

| Key | Operation |
|---|---|
| `A` | AND |
| `B` | OR |
| `C` | XOR |
| `D` | NOT operand 1 |

Examples:

- `1010 A 1100 #` displays `00001000`.
- `1010 B 1100 #` displays `00001110`.
- `1010 C 1100 #` displays `00000110`.
- `1010 D #` displays `11110101`.

Digits `2`–`9` display `ERROR:USE 0/1`. A ninth binary digit displays `ERROR:MAX 8 BIT`.

## Mode 3 — Additional

Currently only key `A` is assigned:

| Key | Operation |
|---|---|
| `A` | Square operand 1; press `#` to calculate |

Example: `12 A #` displays `144`.

## Hardware ports

| Connection | Port |
|---|---|
| LCD data `D0–D7` | `P3.0–P3.7` |
| Keypad | `P1.0–P1.7` |
| LCD `RS` | `P2.0` |
| LCD `RW` | `P2.1` |
| LCD `EN` | `P2.2` |

## Build verification

`Big Program V3 Modes.asm` assembles with ASEM-51 V1.3 with no errors. The generated firmware is `Big Program V3 Modes.hex`.
