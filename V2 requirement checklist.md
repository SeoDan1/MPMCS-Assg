# 8051 Calculator V2 — Requirement Checklist

## Version 1 port compatibility

V2 keeps every Version 1 hardware connection unchanged. No new port or pin is required.

| Device signal | Version 1 | Version 2 |
|---|---|---|
| LCD 8-bit data bus | `P3.0`–`P3.7` | `P3.0`–`P3.7` |
| Keypad rows | `P1.0`–`P1.3` | `P1.0`–`P1.3` |
| Keypad columns | `P1.4`–`P1.7` | `P1.4`–`P1.7` |
| LCD `RS` | `P2.0` | `P2.0` |
| LCD `RW` | `P2.1` | `P2.1` |
| LCD `EN` | `P2.2` | `P2.2` |

Port 0 and `P2.3`–`P2.7` remain unused by the calculator program.

## Key controls

| Key sequence | Function |
|---|---|
| `0`–`9` | Enter an unsigned decimal value from 0 to 65535 |
| `A` | Add |
| `B` | Subtract |
| `C` | Multiply |
| `D` | Divide |
| `#` | Calculate / equals |
| `*` | Toggle next-page mode |
| `*`, then `A` | 8-bit AND |
| `*`, then `B` | 8-bit OR |
| `*`, then `C` | 8-bit XOR |
| `*`, then `D`, then `#` | Select square and press equals to calculate |
| `*`, then `#` | Clear calculator and LCD |
| `*`, then `4` | Manually scroll display left |
| `*`, then `6` | Manually scroll display right |

`*` toggles next-page mode. After a next-page function is selected, the mode is cleared automatically.

## Display and ANS behaviour

- `READY` appears briefly after reset or clear, then disappears automatically.
- The expression is entered on line 1.
- A result is shown directly at the right edge of line 2 without a `RESULT:` label.
- Entering a digit after a result clears both display lines and starts a new calculation.
- Entering an operator after a result preserves it as operand 1, clears the display, and starts line 1 with `ANS`. For example, after obtaining `5`, pressing `A`, `2`, `*` displays `ANS+2` and calculates `7`.
- Entering another operator while operand 2 is active evaluates the pending calculation first. Therefore `11+11+11` is processed as `(11+11)+11` and produces `33`.
- Pressing equals without selecting an operator displays the entered value itself as the answer.
- Negative results are stored as a sign plus a 16-bit magnitude and are right-aligned with a minus sign.

## Numeric limits

- Maximum value that can be entered for either operand: `65535` (`FFFFH`).
- Minimum entered value: `0`.
- Displayable signed result range: `-65535` through `65535`, stored as a sign plus a 16-bit magnitude.
- Every intermediate chained result must also remain within that magnitude range.
- Entering `65536` or more produces `ERROR:INPUT SIZE`.
- Addition, multiplication, square, or negative-ANS chaining beyond a magnitude of 65535 produces `ERROR:OVERFLOW`.

## Requirement mapping

| Requirement | V2 implementation |
|---|---|
| Arithmetic `+`, `-`, `*`, `/` | `MATH_ADD`, `MATH_SUB`, `MATH_MUL`, and `MATH_DIV` |
| Results up to 16 bits | Results use `R2:R3` plus a sign flag; `LCD_PRINT_U16_RIGHT` displays magnitudes from 0 to 65535, including negative subtraction results |
| 8-bit AND, XOR, OR | `LOGIC_AND`, `LOGIC_XOR`, and `LOGIC_OR` operate on `R3` and `R5` |
| Arithmetic error detection | Detects addition/multiplication/square overflow, signed-magnitude overflow while chaining a negative ANS, division by zero, and oversized input |
| Square function | `MATH_SQUARE` uses the checked 16×16 multiplication routine |
| Correct two-line text/symbol display | Line 1 shows the expression or `ANS` expression; line 2 briefly shows `READY`, then shows a right-aligned result or an error string |
| Correct display of input data | Digits are converted to ASCII and echoed to line 1 after successful range checking |
| Manual scrolling | HD44780 commands `18H` and `1CH`, controlled by `*`+`4` and `*`+`6` |
| Display error message | `DISPLAY_ERROR` prints a specific message on line 2 |

## Error messages

| Condition | LCD line 2 |
|---|---|
| Addition, multiplication, or square exceeds 65535 | `ERROR:OVERFLOW` |
| Divisor is zero | `ERROR:DIV ZERO` |
| Entered operand exceeds 65535 | `ERROR:INPUT SIZE` |
| An 8-bit logical operation is requested using a negative `ANS` | `ERROR:NEG LOGIC` |

All messages contain at most 16 characters.

## Suggested verification cases

| Input sequence | Expected line-2 output |
|---|---|
| `65535 A 0 #` | Right-aligned `65535` |
| `65535 A 1 #` | `ERROR:OVERFLOW` |
| `300 C 200 #` | Right-aligned `60000` |
| `256 C 256 #` | `ERROR:OVERFLOW` |
| `65535 D 255 #` | Right-aligned `257` |
| `10 D 0 #` | `ERROR:DIV ZERO` |
| `2 B 3 #` | Right-aligned `-1` |
| `123 #` | Right-aligned `123` |
| `11 A 11 A 11 #` | Right-aligned `33` |
| `255 * D #` | Right-aligned `65025` |
| `256 * D #` | `ERROR:OVERFLOW` |
| `255 * A 170 #` | Right-aligned `170` |
| Enter `65536` | `ERROR:INPUT SIZE` |

Division is unsigned integer division; the quotient is displayed and the remainder is discarded.

## Build verification

`Big Program V2.asm` was assembled with ASEM-51 V1.3. The assembler reported `no errors` and generated `Big Program V2.hex` and `Big Program V2.lst`.

The arithmetic algorithms were also checked programmatically:

- 200,000 random 16-bit multiplication and division cases: no mismatches.
- Decimal conversion for every value from 0 through 65535: no mismatches.
- Input accumulation for all 655,360 combinations of a 16-bit value and one decimal digit: no mismatches.
- 500,000 random signed `ANS` addition/subtraction chaining cases: no mismatches.
