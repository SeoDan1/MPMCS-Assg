; ==============================================================================
; MCU 2: LCD DISPLAY DRIVER (SLAVE)
; LCD Data: P1.0-P1.7 | RS=P2.0 | RW=P2.1 | EN=P2.2
; Comm: UART (P3.0, P3.1) @ 9600 baud (11.0592 MHz crystal)
; ==============================================================================

    ORG 0000H
    LJMP MAIN

MAIN:
    MOV SP, #5FH                 ; Stack uses 60H upward
    
    ; Setup Pins
    MOV P1, #00H                 ; Clear LCD Data Port
    CLR P2.0                     ; RS = 0
    CLR P2.1                     ; RW = 0
    CLR P2.2                     ; EN = 0

    ; Init UART: Mode 1, 8-bit, 9600 baud @ 11.0592 MHz
    MOV TMOD, #20H               ; Timer 1, Mode 2 (8-bit auto-reload)
    MOV TH1, #0FDH               ; 9600 baud
    MOV SCON, #50H               ; Mode 1, Receive Enable
    SETB TR1                     ; Start Timer 1
    
    ; Init the physical LCD
    LCALL LCD_POWER_DELAY
    LCALL LCD_INIT
    
    ; Send Startup 'Ready' signal (0xBB) back to MCU 1
    MOV SBUF, #0BBH
    JNB TI, $
    CLR TI

UART_LISTENER:
    ; 1. Wait for Command Type (0x00 = CMD, 0x01 = DATA)
    JNB RI, $
    MOV R2, SBUF
    CLR RI
    
    ; 2. Wait for Payload Byte
    JNB RI, $
    MOV A, SBUF
    CLR RI
    
    ; 3. Execute
    CJNE R2, #00H, EXECUTE_DATA
    LCALL LCD_CMD_PHYSICAL
    SJMP SEND_ACK
    
EXECUTE_DATA:
    LCALL LCD_DATA_PHYSICAL
    
SEND_ACK:
    ; 4. Acknowledge execution so MCU 1 can send the next byte
    MOV SBUF, #0AAH
    JNB TI, $
    CLR TI
    
    LJMP UART_LISTENER           ; Loop forever

; ------------------------------------------------------------------------------
; PHYSICAL LCD TIMING & CONTROL ROUTINES
; ------------------------------------------------------------------------------

LCD_INIT: 
    MOV A, #030H
    LCALL LCD_CMD_PHYSICAL
    LCALL LCD_DELAY
    MOV A, #030H
    LCALL LCD_CMD_PHYSICAL
    MOV A, #030H
    LCALL LCD_CMD_PHYSICAL
    MOV A, #038H                 ; 8-bit interface, 2 lines, 5x8 font
    LCALL LCD_CMD_PHYSICAL
    MOV A, #00CH                 ; Display on, cursor and blink off
    LCALL LCD_CMD_PHYSICAL
    MOV A, #006H                 ; Increment cursor, no automatic shift
    LCALL LCD_CMD_PHYSICAL
    MOV A, #001H                 ; Clear display
    LCALL LCD_CMD_PHYSICAL
    RET

LCD_CMD_PHYSICAL:
    CLR P2.0                     ; RS=0: command
    SJMP LCD_WRITE

LCD_DATA_PHYSICAL: 
    SETB P2.0                    ; RS=1: character data
    
LCD_WRITE:
    MOV P1, A                    ; Put payload onto P1 (Data bus)
    CLR P2.1                     ; RW=0: write
    SETB P2.2                    ; EN=1
    LCALL SHORT_DELAY            ; Hold EN
    CLR P2.2                     ; EN=0
    LCALL LCD_DELAY              ; Execution time wait
    RET

LCD_POWER_DELAY: 
    PUSH 00H
    PUSH 01H
    MOV R0, #80
LCD_POWER_D_OUTER:      
    MOV R1, #255
    DJNZ R1, $
    DJNZ R0, LCD_POWER_D_OUTER
    POP 01H
    POP 00H
    RET

SHORT_DELAY: 
    NOP
    NOP
    RET

LCD_DELAY: 
    PUSH 00H
    PUSH 01H
    MOV R0, #4
LCD_D_LOOP1:            
    MOV R1, #255
    DJNZ R1, $
    DJNZ R0, LCD_D_LOOP1
    POP 01H
    POP 00H
    RET

    END