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
