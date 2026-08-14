# V3 Dual-Controller Calculator — Two-Wire Link

Program the controllers as follows:

| Controller | HEX file |
|---|---|
| Controller 1: keypad, ALU, and error detection | `Big Program V3 Process Controller 2-Wire.hex` |
| Controller 2: LCD and display formatting | `Big Program V3 Display Controller 2-Wire.hex` |

Only two UART communication signals connect the controllers, matching the
schematic's crossed `TX` and `RX` nets:

- Process `P3.1/TXD` to display `P3.0/RXD`: message byte
- Display `P3.1/TXD` to process `P3.0/RXD`: `06H` ACK byte

The current display-controller LCD wiring is:

- LCD `D0-D7` on `P1.0-P1.7`
- LCD `RS`, `RW`, and `EN` on `P2.0`, `P2.1`, and `P2.2`
- LCD `VEE` through a contrast potentiometer, or to ground for a Proteus test

Read `V3 two-wire REQ-ACK guide.md` for the complete wiring and timing details.
Each HEX has a matching `.asm` source and `.lst` assembly listing.

## Current display behavior

- Mode 3 is named `ADVANCE` and appears as `3:ADV` in the menu.
- A non-exact division is shown as a mixed fraction. For example, `13 / 4`
  displays `3⌟1⌟4`, meaning quotient 3, remainder 1, divisor 4.
- An exact division continues to display only its integer quotient.
- If a decimal input exceeds 65535, the digit that caused the overflow remains
  visible on expression line 1 before `ERROR:INPUT SIZE` appears on line 2.
- In logical mode, a full `8-bit operator 8-bit =` expression is retained even
  though it is 18 characters long. Press `4` for its leftmost 16-character
  window and `6` for its rightmost 16-character window. Line 2 is not moved.
- Logical-mode digit keys `2-9` are silently ignored. Only `0` and `1` are
  accepted as operand digits; `ERROR:USE 0/1` is no longer displayed.
- Pressing another binary operator before operand 2 begins replaces the old
  operator. For example, `1+-` displays `1-` instead of `ANS-`.
- NOT remains a postfix unary operation when executed with `#`. Before `#`, it
  participates in operator replacement: `11`, `NOT`, `OR` displays `11 OR`
  without creating an intermediate `ANS`.
