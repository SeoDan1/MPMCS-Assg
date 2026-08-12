Universal Asynchronous Receiver-Transmitter (UART) Overview
UART (Universal Asynchronous Receiver-Transmitter) is a hardware peripheral responsible for serial communication between electronic devices. Rather than being a strict bus protocol like I²C or SPI, UART is a physical hardware circuit inside microcontrollers and chips that converts data between parallel data (used inside the CPU) and serial data (sent bit-by-bit over a wire).

**Physical Wiring**
UART uses a point-to-point connection requiring only 3 wires:
TX (Transmit): Sends data out.
RX (Receive): Receives incoming data.
GND (Ground): Provides a shared voltage reference between both devices.

Key Rule: Connections are crossed — Device A's TX pin connects directly to Device B's RX pin, and vice-versa.

<img width="513" height="236" alt="image" src="https://github.com/user-attachments/assets/5421b4d8-17cc-4cfd-aeb8-463ac7f5b7e9" />

**Why "Asynchronous"?**
Synchronous protocols (like SPI or I²C) include a dedicated Clock wire (CLK) to tell the receiver exactly when to sample bits.
UART is asynchronous — it has no clock wire. Instead, both devices must agree on two rules before communicating:
Baud Rate: The transmission speed measured in bits per second (e.g., 9600, 115200).
Frame Format: The exact structure of the data packet (data length, error checking, stop bits).

**Anatomy of a UART Packet Frame**
Since there is no clock signal to separate bits, UART packages data into individual frames:
Idle Line (Logic HIGH): When no data is being sent, the signal wire rests at logic high (1).
Start Bit (Logic LOW): The transmitter pulls the line down to logic low (0) for 1 bit period to signal the start of transmission.
Data Bits (5 to 9 bits): The actual payload (usually 8 bits / 1 byte), sent Least Significant Bit (LSB) first.
Parity Bit (Optional): Used for basic hardware error checking (Even or Odd parity).
Stop Bit(s) (1 or 2 bits): The line returns to logic high (1) to signify packet completion.

<img width="888" height="440" alt="image" src="https://github.com/user-attachments/assets/a752006c-0bc6-4c28-8e79-7a0b1bfb0fe1" />

**Pros and Cons**
Pros: Simple hardware setup (only 2 signal wires), no clock wire required, supported by nearly all microcontrollers.
Cons: Limited to 2 devices per line, slower than SPI/I²C, and sensitive to baud rate timing mismatches (clock drift >3% causes corrupted data).

