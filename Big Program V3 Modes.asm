; 8051 CALCULATOR - THREE-MODE VERSION 3
; LCD data: P3.0-P3.7 | RS=P2.0 | RW=P2.1 | EN=P2.2
;
; MODE MENU: 1=Arithmetic, 2=Logical, 3=Additional
;   Mode 1: A=+, B=-, C=*, D=/
;   Mode 2: A=AND, B=OR, C=XOR, D=NOT; input accepts 0/1 only
;   Mode 3: A=Square
;   #=Equals, *=Clear, * then #=Return to mode menu
;
; DISPLAY
;   Line 1: entered expression
;   Line 2: temporary READY, right-aligned signed result, or error message
;
; VALUES
;   R2:R3 = operand 1/result (high:low)
;   R4:R5 = operand 2        (high:low)
;   R6    = operator code
;   R7    = input state: 0=operand 1, 1=operand 2
;   20H.0 = error flag
;   20H.1 = star-clear pending flag
;   20H.2 = negative-result flag (R2:R3 stores the magnitude)
;   20H.3 = result-is-being-displayed flag
; ----- Scratch RAM ------------------------------------------------------------
DIGIT_TMP   EQU 30H             ; DIGIT TEMPORARY: most recently entered digit
TMP_H       EQU 31H             ; TEMPORARY HIGH BYTE: high byte of working value
TMP_L       EQU 32H             ; TEMPORARY LOW BYTE: low byte of working value
QUO_H       EQU 33H             ; QUOTIENT HIGH BYTE: high byte of division quotient
QUO_L       EQU 34H             ; QUOTIENT LOW BYTE: low byte of division quotient
REM_H       EQU 35H             ; REMAINDER HIGH BYTE: high byte of division remainder
REM_L       EQU 36H             ; REMAINDER LOW BYTE: low byte of division remainder
MC0         EQU 37H             ; MULTIPLICAND BYTE 0: least-significant product byte
MC1         EQU 38H             ; MULTIPLICAND BYTE 1
MC2         EQU 39H             ; MULTIPLICAND BYTE 2
MC3         EQU 3AH             ; MULTIPLICAND BYTE 3: most-significant product byte
PROD0       EQU 3BH             ; PRODUCT BYTE 0: least-significant result byte
PROD1       EQU 3CH             ; PRODUCT BYTE 1
PROD2       EQU 3DH             ; PRODUCT BYTE 2: nonzero means 16-bit overflow
PROD3       EQU 3EH             ; PRODUCT BYTE 3: most-significant result byte
MUL0        EQU 3FH             ; MULTIPLIER LOW BYTE: low byte of second factor
MUL1        EQU 40H             ; MULTIPLIER HIGH BYTE: high byte of second factor
ERROR_CODE  EQU 41H             ; ERROR CODE: selects the LCD error message
DIV_OVER    EQU 42H             ; DIVISION OVERFLOW BIT: temporary 17th remainder bit
DIGIT_COUNT EQU 43H             ; DIGIT COUNT: decimal characters awaiting display
LCD_LINE1   EQU 080H            ; LCD LINE 1 COMMAND: first DDRAM address of row 1
LCD_LINE2   EQU 0C0H            ; LCD LINE 2 COMMAND: first DDRAM address of row 2
LCD_WIDTH   EQU 10H             ; LCD WIDTH: sixteen visible characters per row
MODE        EQU 44H             ; ACTIVE MODE: 0=menu, 1=arithmetic, 2=logical, 3=additional
OP1_BITS    EQU 45H             ; OPERAND 1 BIT COUNT: number of binary digits entered
OP2_BITS    EQU 46H             ; OPERAND 2 BIT COUNT: number of binary digits entered
; Error codes
; 01H = overflow, 03H = divide by zero
; 04H = input greater than 65535
; 07H = non-binary logical input, 08H = more than 8 binary bits

    ORG 0000H
    LJMP MAIN

; INITIALISATION AND MAIN CONTROLLER
MAIN: ; Initialize stack, ports, LCD and calculator state
    MOV SP, #5FH                 ; Stack uses 60H upward, away from variables
    MOV P1, #0FFH
    MOV P3, #00H                 ; Known LCD data-bus state during power-up
    CLR P2.0                     ; RS=0
    CLR P2.1                     ; RW=0
    CLR P2.2                     ; EN=0 before the first LCD transaction
    LCALL LCD_POWER_DELAY        ; Physical LCD requires a power-on settling time
    LCALL LCD_INIT
    LCALL SHOW_STARTUP

CALC_LOOP: ; Continuously scan and dispatch keypad input
    LCALL KEYPAD_SCAN
    CJNE A, #0FFH, PROCESS_KEY
    LJMP CALC_LOOP

PROCESS_KEY: ; Debounce and classify one key press
    PUSH ACC
    LCALL WAIT_KEY_RELEASE
    POP ACC
    MOV DIGIT_TMP, A

    MOV A, MODE
    JNZ ACTIVE_MODE_KEY
    MOV A, DIGIT_TMP
    LCALL SELECT_MODE
    LJMP CALC_LOOP

ACTIVE_MODE_KEY:
    ; A # immediately following * opens the mode menu.
    JNB 20H.1, CHECK_CLEAR_KEY
    CLR 20H.1
    MOV A, DIGIT_TMP
    CJNE A, #0FH, CHECK_CLEAR_KEY
    LCALL SHOW_MODE_MENU
    LJMP CALC_LOOP

CHECK_CLEAR_KEY:
    MOV A, DIGIT_TMP
    CJNE A, #0EH, CHECK_DIGIT
    LCALL CLEAR_CURRENT
    SETB 20H.1                    ; Keep one-key window for * then #
    LJMP CALC_LOOP

CHECK_DIGIT:
    CJNE A, #0AH, $ + 3
    JNC CHECK_OPERATOR

    CJNE R7, #02H, DIGIT_NOT_LOCKED
    LJMP CALC_LOOP                ; Ignore digits after unary NOT or square
DIGIT_NOT_LOCKED:
    JNB 20H.3, DIGIT_ENTRY_READY
    LCALL START_NEW_ENTRY
DIGIT_ENTRY_READY:
    MOV A, MODE
    CJNE A, #02H, STORE_DECIMAL_DIGIT
    MOV A, DIGIT_TMP
    CJNE A, #02H, $ + 3
    JNC INVALID_BINARY_DIGIT
    LCALL ACCUMULATE_BINARY
    SJMP CHECK_DIGIT_RESULT

STORE_DECIMAL_DIGIT:
    MOV A, DIGIT_TMP
    LCALL ACCUMULATE_DIGIT
CHECK_DIGIT_RESULT:
    JB 20H.0, DIGIT_ERROR
    MOV A, DIGIT_TMP
    ADD A, #30H
    LCALL LCD_DATA
    LJMP CALC_LOOP

INVALID_BINARY_DIGIT:
    MOV ERROR_CODE, #07H
    LCALL SET_ERROR
DIGIT_ERROR:            LCALL DISPLAY_ERROR
    LJMP CALC_LOOP

; OPERATOR SELECTION
CHECK_OPERATOR: ; Decode the selected mode's A-D functions and #
    MOV A, DIGIT_TMP
    CJNE A, #0FH, CHECK_MODE_OPERATOR
    JNB 20H.3, HASH_EXECUTE
    LJMP CALC_LOOP

CHECK_MODE_OPERATOR:
    CJNE A, #0EH, $ + 3
    JNC UNKNOWN_KEY

    MOV A, MODE
    CJNE A, #03H, PREPARE_MODE_OPERATOR
    MOV A, DIGIT_TMP
    CJNE A, #0AH, UNKNOWN_KEY     ; Additional mode currently accepts A only

PREPARE_MODE_OPERATOR:
    LCALL PREPARE_OPERATOR_ENTRY
    JNB 20H.0, DECODE_MODE_OPERATOR
    LJMP CALC_LOOP

DECODE_MODE_OPERATOR:
    MOV A, MODE
    CJNE A, #01H, CHECK_LOGIC_MODE

    ; Arithmetic mode: A-D maps directly to operator codes 1-4.
    MOV A, DIGIT_TMP
    CLR C
    SUBB A, #09H
    MOV R6, A
    MOV A, DIGIT_TMP
    CLR C
    SUBB A, #0AH
    MOV DPTR, #NORMAL_SYMBOLS
    MOVC A, @A+DPTR
    LCALL LCD_DATA
    LJMP NEXT_OPERAND

CHECK_LOGIC_MODE:
    CJNE A, #02H, DO_SQUARE

    ; Logical mode: A-C are binary operators; D is unary NOT.
    MOV A, DIGIT_TMP
    CJNE A, #0DH, LOGIC_BINARY_OPERATOR
    MOV R6, #08H
    MOV A, #'~'
    LCALL LCD_DATA
    LJMP UNARY_PENDING

DO_SQUARE: ; Select square and wait for equals
    MOV R6, #09H
    MOV A, #'^'
    LCALL LCD_DATA
    MOV A, #'2'
    LCALL LCD_DATA
    LJMP UNARY_PENDING

LOGIC_BINARY_OPERATOR:  CLR C
    SUBB A, #05H                 ; A-C maps to operator codes 5-7
    MOV R6, A
    MOV A, DIGIT_TMP
    CLR C
    SUBB A, #0AH
    MOV DPTR, #LOGIC_SYMBOLS
    MOVC A, @A+DPTR
    LCALL LCD_DATA
    LJMP NEXT_OPERAND

HASH_EXECUTE: ; Execute the selected operation on #
    MOV A, #'='
    LCALL LCD_DATA
    JB 20H.0, EQUALS_SHOW
    MOV ERROR_CODE, #00H
    LCALL EXECUTE_MATH
EQUALS_SHOW:            LCALL DISPLAY_RESULT
    LJMP CALC_LOOP
UNKNOWN_KEY:            LJMP CALC_LOOP
NEXT_OPERAND:           MOV R7, #01H
    LJMP CALC_LOOP
UNARY_PENDING:          MOV R7, #02H
    LJMP CALC_LOOP
; MODE, CLEAR AND ANS STATE
RESET_STATE: ; Clear operands, operator, flags and error code
    MOV R2, #00H
    MOV R3, #00H
    MOV R4, #00H
    MOV R5, #00H
    MOV R6, #00H
    MOV R7, #00H
    MOV ERROR_CODE, #00H
    MOV OP1_BITS, #00H
    MOV OP2_BITS, #00H
    CLR 20H.0
    CLR 20H.1
    CLR 20H.2
    CLR 20H.3
    RET

SHOW_STARTUP: ; Show READY once, then open the mode menu
    MOV MODE, #00H
    LCALL RESET_STATE
    MOV A, #01H
    LCALL LCD_CMD
    MOV A, #0C5H
    LCALL LCD_CMD
    MOV DPTR, #STR_READY
    LCALL LCD_PUTS
    LCALL READY_DELAY
    LJMP SHOW_MODE_MENU

SHOW_MODE_MENU: ; Display the three selectable calculator modes
    MOV MODE, #00H
    LCALL RESET_STATE
    MOV A, #01H
    LCALL LCD_CMD
    MOV DPTR, #STR_SELECT_MODES
    LCALL LCD_PUTS
    MOV A, #LCD_LINE2
    LCALL LCD_CMD
    MOV DPTR, #STR_MODE_MENU
    LCALL LCD_PUTS
    RET

SELECT_MODE: ; Accept menu keys 1, 2 or 3
    CJNE A, #01H, SELECT_MODE_2
    MOV MODE, #01H
    SJMP MODE_SELECTED
SELECT_MODE_2:           CJNE A, #02H, SELECT_MODE_3
    MOV MODE, #02H
    SJMP MODE_SELECTED
SELECT_MODE_3:           CJNE A, #03H, SELECT_MODE_DONE
    MOV MODE, #03H
MODE_SELECTED:           LCALL RESET_STATE
    LJMP SHOW_MODE_STATUS
SELECT_MODE_DONE:        RET

SHOW_MODE_STATUS: ; Clear the expression and identify the active mode
    MOV A, #01H
    LCALL LCD_CMD
    MOV A, #LCD_LINE2
    LCALL LCD_CMD
    MOV A, MODE
    CJNE A, #01H, STATUS_LOGICAL
    MOV DPTR, #STR_ARITHMETIC
    SJMP PRINT_MODE_STATUS
STATUS_LOGICAL:         CJNE A, #02H, STATUS_ADDITIONAL
    MOV DPTR, #STR_LOGICAL
    SJMP PRINT_MODE_STATUS
STATUS_ADDITIONAL:      MOV DPTR, #STR_ADDITIONAL
PRINT_MODE_STATUS:      LCALL LCD_PUTS
    MOV A, #LCD_LINE1
    LJMP LCD_CMD

CLEAR_CURRENT: ; Clear the current expression without changing mode
    LCALL RESET_STATE
    LJMP SHOW_MODE_STATUS

START_NEW_ENTRY: ; Start a fresh calculation after a displayed result
    LJMP CLEAR_CURRENT

PREPARE_ANS_EXPRESSION: ; Preserve the result and begin an ANS expression
    ; An operator entered after a result starts a chained calculation.
    ; Preserve R2:R3 and the sign, clear operand 2, and show "ANS" on line 1.
    JNB 20H.3, PREPARE_ANS_DONE
    MOV R4, #00H
    MOV R5, #00H
    MOV R6, #00H
    MOV R7, #00H
    MOV ERROR_CODE, #00H
    MOV OP2_BITS, #00H
    CLR 20H.0
    CLR 20H.3
    MOV A, #01H
    LCALL LCD_CMD
    MOV DPTR, #STR_ANS
    LCALL LCD_PUTS
PREPARE_ANS_DONE:       RET

PREPARE_OPERATOR_ENTRY: ; Evaluate a pending operation before chaining
    ; If a result is already visible, start a calculation using that ANS.
    JB 20H.0, PREPARE_OPERATOR_DONE
    JB 20H.3, PREPARE_OPERATOR_USE_ANS
    ; If operand 2 is active, evaluate the pending operation before accepting
    ; another operator. This makes 11+11+11 evaluate as (11+11)+11 = 33.
    CJNE R7, #01H, PREPARE_OPERATOR_DONE
    LCALL EXECUTE_MATH
    JB 20H.0, PREPARE_OPERATOR_ERROR
    SETB 20H.3
PREPARE_OPERATOR_USE_ANS:LCALL PREPARE_ANS_EXPRESSION
    RET
PREPARE_OPERATOR_ERROR: LCALL DISPLAY_ERROR
PREPARE_OPERATOR_DONE:  RET
; LCD DRIVER AND TWO-LINE TEXT OUTPUT
LCD_INIT: ; Wake and configure the two-line LCD
    ; Standard physical-controller wake-up sequence. Force 8-bit mode three
    ; times before selecting the final 8-bit, two-line configuration.
    MOV A, #030H
    LCALL LCD_CMD
    LCALL LCD_DELAY              ; First wake-up command needs the longest gap
    MOV A, #030H
    LCALL LCD_CMD
    MOV A, #030H
    LCALL LCD_CMD
    MOV A, #038H                 ; 8-bit interface, 2 lines, 5x8 font
    LCALL LCD_CMD
    MOV A, #00CH                 ; Display on, cursor and blink off
    LCALL LCD_CMD
    MOV A, #006H                 ; Increment cursor, no automatic shift
    LCALL LCD_CMD
    MOV A, #001H
    LCALL LCD_CMD
    RET

LCD_CMD: ; Write one instruction byte to the LCD
    CLR P2.0                     ; RS=0: command
    SJMP LCD_WRITE

LCD_DATA: ; Write one character byte to the LCD
    SETB P2.0                    ; RS=1: character data
LCD_WRITE: ; Send A using the selected LCD register
    MOV P3, A
    CLR P2.1
    SETB P2.2
    LCALL SHORT_DELAY
    CLR P2.2
    LCALL LCD_DELAY
    RET

LCD_PUTS: ; Print a zero-terminated code-memory string
    ; Print a zero-terminated code-memory string addressed by DPTR.
    CLR A
    MOVC A, @A+DPTR
    JZ LCD_PUTS_DONE
    LCALL LCD_DATA
    INC DPTR
    SJMP LCD_PUTS
LCD_PUTS_DONE:          RET

LCD_CLEAR_LINE2: ; Erase all sixteen characters on line 2
    MOV A, #LCD_LINE2
    LCALL LCD_CMD
    MOV R0, #LCD_WIDTH
LCD_CLEAR_L2_LOOP:      MOV A, #' '
    LCALL LCD_DATA
    DJNZ R0, LCD_CLEAR_L2_LOOP
    MOV A, #LCD_LINE2
    LCALL LCD_CMD
    RET

; LCD TIMING DELAYS
LCD_POWER_DELAY: ; Wait for the LCD power supply to settle
    ; Approximately 40 ms at 11.0592/12 MHz. This delay occurs only at reset,
    ; before the first LCD function-set command.
    PUSH 00H
    PUSH 01H
    MOV R0, #80
LCD_POWER_D_OUTER:      MOV R1, #255
    DJNZ R1, $
    DJNZ R0, LCD_POWER_D_OUTER
    POP 01H
    POP 00H
    RET

SHORT_DELAY: ; Generate the LCD enable pulse width
    NOP
    NOP
    RET

LCD_DELAY: ; Wait for an LCD command to complete
    PUSH 00H                     ; Preserve register-bank-0 R0 and R1
    PUSH 01H
    MOV R0, #4
LCD_D_LOOP1:            MOV R1, #255
    DJNZ R1, $
    DJNZ R0, LCD_D_LOOP1
    POP 01H
    POP 00H
    RET
; Delay for showing "Ready" on screen
READY_DELAY: ; Keep READY visible for about one second
    ; Roughly one second on a classic 12-clock 11.0592/12 MHz 8051.
    PUSH 00H
    PUSH 01H
    PUSH 02H
    MOV R2, #8
READY_D_OUTER:          MOV R0, #255
READY_D_MIDDLE:         MOV R1, #255
    DJNZ R1, $
    DJNZ R0, READY_D_MIDDLE
    DJNZ R2, READY_D_OUTER
    POP 02H
    POP 01H
    POP 00H
    RET
; KEYPAD SCANNING AND DEBOUNCE (Group 1)
KEYPAD_SCAN: ; Scan the 4x4 keypad and return a key code
    MOV P1, #0F0H                ; Rows low, columns released high
    MOV A, P1
    ANL A, #0F0H
    CJNE A, #0F0H, KEY_FOUND
    MOV A, #0FFH
    RET
KEY_FOUND:              LCALL DEBOUNCE_DELAY
    MOV P1, #0F0H
    MOV A, P1
    ANL A, #0F0H
    CJNE A, #0F0H, SCAN_ROW_0
    MOV A, #0FFH
    RET
SCAN_ROW_0:             MOV P1, #0FEH
    MOV A, P1
    JNB ACC.4, GOT_KEY_1
    JNB ACC.5, GOT_KEY_2
    JNB ACC.6, GOT_KEY_3
    JNB ACC.7, GOT_KEY_A
SCAN_ROW_1:             MOV P1, #0FDH
    MOV A, P1
    JNB ACC.4, GOT_KEY_4
    JNB ACC.5, GOT_KEY_5
    JNB ACC.6, GOT_KEY_6
    JNB ACC.7, GOT_KEY_B
SCAN_ROW_2:             MOV P1, #0FBH
    MOV A, P1
    JNB ACC.4, GOT_KEY_7
    JNB ACC.5, GOT_KEY_8
    JNB ACC.6, GOT_KEY_9
    JNB ACC.7, GOT_KEY_C
SCAN_ROW_3:             MOV P1, #0F7H
    MOV A, P1
    JNB ACC.4, GOT_KEY_STAR
    JNB ACC.5, GOT_KEY_0
    JNB ACC.6, GOT_KEY_HASH
    JNB ACC.7, GOT_KEY_D
    MOV A, #0FFH
    RET
GOT_KEY_0:     MOV A, #00H
               RET
GOT_KEY_1:     MOV A, #01H
               RET
GOT_KEY_2:     MOV A, #02H
               RET
GOT_KEY_3:     MOV A, #03H
               RET
GOT_KEY_4:     MOV A, #04H
               RET
GOT_KEY_5:     MOV A, #05H
               RET
GOT_KEY_6:     MOV A, #06H
               RET
GOT_KEY_7:     MOV A, #07H
               RET
GOT_KEY_8:     MOV A, #08H
               RET
GOT_KEY_9:     MOV A, #09H
               RET
GOT_KEY_A:     MOV A, #0AH
               RET
GOT_KEY_B:     MOV A, #0BH
               RET
GOT_KEY_C:     MOV A, #0CH
               RET
GOT_KEY_D:     MOV A, #0DH
               RET
GOT_KEY_STAR:  MOV A, #0EH
               RET
GOT_KEY_HASH:  MOV A, #0FH
               RET

WAIT_KEY_RELEASE: ; Block until the pressed key is released
    MOV P1, #0F0H
    MOV A, P1
    ANL A, #0F0H
    CJNE A, #0F0H, WAIT_KEY_RELEASE
    LCALL DEBOUNCE_DELAY
    RET

DEBOUNCE_DELAY: ; Reject mechanical keypad bounce
    ; Approximately milliseconds on a classic 12-clock 8051; tune for crystal.
    MOV R0, #20
DEBOUNCE_OUTER:         MOV R1, #255
    DJNZ R1, $
    DJNZ R0, DEBOUNCE_OUTER
    RET

; BINARY INPUT: VALUE = VALUE * 2 + BIT, MAXIMUM 8 BITS
ACCUMULATE_BINARY: ; Append one binary digit to the active 8-bit operand
    MOV DIGIT_TMP, A
    CJNE R7, #00H, BINARY_OP2
    MOV A, OP1_BITS
    CJNE A, #08H, $ + 3
    JNC BINARY_TOO_LONG
    MOV A, R3
    RL A
    ORL A, DIGIT_TMP
    MOV R3, A
    MOV R2, #00H
    INC OP1_BITS
    RET
BINARY_OP2:             MOV A, OP2_BITS
    CJNE A, #08H, $ + 3
    JNC BINARY_TOO_LONG
    MOV A, R5
    RL A
    ORL A, DIGIT_TMP
    MOV R5, A
    MOV R4, #00H
    INC OP2_BITS
    RET
BINARY_TOO_LONG:        MOV ERROR_CODE, #08H
    LJMP SET_ERROR

; DECIMAL INPUT: VALUE = VALUE * 10 + DIGIT, WITH 16-BIT RANGE CHECK
ACCUMULATE_DIGIT: ; Append one decimal digit to the active operand
    MOV DIGIT_TMP, A
    CJNE R7, #00H, ACC_OP2
    MOV TMP_H, R2
    MOV TMP_L, R3
    LCALL MUL10_TMP_CHECK
    JC INPUT_TOO_LARGE
    MOV A, TMP_L
    ADD A, DIGIT_TMP
    MOV TMP_L, A
    MOV A, TMP_H
    ADDC A, #00H
    JC INPUT_TOO_LARGE
    MOV TMP_H, A
    MOV R2, TMP_H
    MOV R3, TMP_L
    RET
ACC_OP2:                MOV TMP_H, R4
    MOV TMP_L, R5
    LCALL MUL10_TMP_CHECK
    JC INPUT_TOO_LARGE
    MOV A, TMP_L
    ADD A, DIGIT_TMP
    MOV TMP_L, A
    MOV A, TMP_H
    ADDC A, #00H
    JC INPUT_TOO_LARGE
    MOV TMP_H, A
    MOV R4, TMP_H
    MOV R5, TMP_L
    RET
; check if exceed 16bits
MUL10_TMP_CHECK: ; Multiply input by ten with 16-bit range checking
    ; Multiply TMP_H:TMP_L by 10. Return C=1 if it exceeds 16 bits.
    MOV A, TMP_L
    MOV B, #10
    MUL AB
    MOV TMP_L, A
    MOV REM_L, B
    MOV A, TMP_H
    MOV B, #10
    MUL AB
    MOV TMP_H, A
    MOV A, B
    JNZ MUL10_OVERFLOW
    MOV A, TMP_H
    ADD A, REM_L
    MOV TMP_H, A
    JC MUL10_OVERFLOW
    CLR C
    RET
MUL10_OVERFLOW:         SETB C
    RET
INPUT_TOO_LARGE:        MOV ERROR_CODE, #04H
    LJMP SET_ERROR

; ALU DISPATCHER
EXECUTE_MATH: ; Dispatch the operator code to the ALU routine
    MOV A, R6
    JZ NO_OPERATOR_SELECTED
    CJNE A, #0AH, $ + 3
    JNC NO_OPERATOR_SELECTED
    DEC A
    MOV B, #03H                  ; Each LJMP table entry occupies 3 bytes
    MUL AB
    MOV DPTR, #ALU_JUMP_TABLE
    JMP @A+DPTR                  ; ALU routine RET returns to dispatcher caller
NO_OPERATOR_SELECTED:   RET      ; Equals alone returns operand 1 unchanged

ALU_JUMP_TABLE:
    LJMP MATH_ADD
    LJMP MATH_SUB
    LJMP MATH_MUL
    LJMP MATH_DIV
    LJMP LOGIC_AND
    LJMP LOGIC_OR
    LJMP LOGIC_XOR
    LJMP LOGIC_NOT
    LJMP MATH_SQUARE

; 16-BIT ARITHMETIC
MATH_ADD: ; Add signed-magnitude ANS and a 16-bit operand
    ; Normal case: positive operand 1 + positive operand 2.
    ; Chained negative ANS case: (-magnitude) + operand 2.
    JB 20H.2, ADD_TO_NEGATIVE_ANS
    MOV A, R3
    ADD A, R5
    MOV R3, A
    MOV A, R2
    ADDC A, R4
    MOV R2, A
    JNC ADD_OK
    LJMP ARITH_OVERFLOW
ADD_OK:                 RET
ADD_TO_NEGATIVE_ANS:
    ; Compare operand 2 with the stored negative magnitude.
    MOV A, R4
    CLR C
    SUBB A, R2
    JC ADD_NEG_MAG_LARGER
    JNZ ADD_POS_MAG_LARGER
    MOV A, R5
    CLR C
    SUBB A, R3
    JC ADD_NEG_MAG_LARGER
ADD_POS_MAG_LARGER:
    ; operand2 >= magnitude: result is positive operand2-magnitude.
    CLR C
    MOV A, R5
    SUBB A, R3
    MOV R3, A
    MOV A, R4
    SUBB A, R2
    MOV R2, A
    CLR 20H.2
    RET
ADD_NEG_MAG_LARGER:
    ; magnitude > operand2: result remains negative magnitude-operand2.
    CLR C
    MOV A, R3
    SUBB A, R5
    MOV R3, A
    MOV A, R2
    SUBB A, R4
    MOV R2, A
    RET

MATH_SUB: ; Subtract with signed-magnitude result support
    ; A negative chained ANS gives (-magnitude)-operand2. Add magnitudes,
    ; retaining the negative sign and detecting magnitude overflow.
    JB 20H.2, SUB_FROM_NEGATIVE_ANS
    ; Compare positive operand 1 with operand 2 before subtracting.
    MOV A, R2
    CLR C
    SUBB A, R4
    JC SUB_RESULT_NEGATIVE
    JNZ SUB_RESULT_POSITIVE
    MOV A, R3
    CLR C
    SUBB A, R5
    JC SUB_RESULT_NEGATIVE
SUB_RESULT_POSITIVE:    CLR C
    MOV A, R3
    SUBB A, R5
    MOV R3, A
    MOV A, R2
    SUBB A, R4
    MOV R2, A
    CLR 20H.2
    RET
SUB_RESULT_NEGATIVE:
    ; Store the magnitude operand2-operand1 and mark it as negative.
    CLR C
    MOV A, R5
    SUBB A, R3
    MOV R3, A
    MOV A, R4
    SUBB A, R2
    MOV R2, A
    SETB 20H.2
    RET
SUB_FROM_NEGATIVE_ANS:  MOV A, R3
    ADD A, R5
    MOV R3, A
    MOV A, R2
    ADDC A, R4
    MOV R2, A
    JNC SUB_NEG_OK
    LJMP ARITH_OVERFLOW
SUB_NEG_OK:             RET

MATH_MUL: ; Multiply 16x16 and detect result overflow
    ; Shift-and-add 16x16 multiplication. A 32-bit scratch product permits
    ; reliable overflow detection; a valid result must have PROD3:PROD2 = 0.
    MOV MC0, R3
    MOV MC1, R2
    MOV MC2, #00H
    MOV MC3, #00H
    MOV MUL0, R5
    MOV MUL1, R4
    MOV PROD0, #00H
    MOV PROD1, #00H
    MOV PROD2, #00H
    MOV PROD3, #00H
    MOV R0, #16
MUL16_LOOP:             MOV A, MUL0
    ANL A, #01H
    JZ MUL16_NO_ADD
    CLR C
    MOV A, PROD0
    ADD A, MC0
    MOV PROD0, A
    MOV A, PROD1
    ADDC A, MC1
    MOV PROD1, A
    MOV A, PROD2
    ADDC A, MC2
    MOV PROD2, A
    MOV A, PROD3
    ADDC A, MC3
    MOV PROD3, A
MUL16_NO_ADD:           CLR C
    MOV A, MC0
    RLC A
    MOV MC0, A
    MOV A, MC1
    RLC A
    MOV MC1, A
    MOV A, MC2
    RLC A
    MOV MC2, A
    MOV A, MC3
    RLC A
    MOV MC3, A
    CLR C
    MOV A, MUL1
    RRC A
    MOV MUL1, A
    MOV A, MUL0
    RRC A
    MOV MUL0, A
    DJNZ R0, MUL16_LOOP
    MOV A, PROD2
    ORL A, PROD3
    JZ MUL16_VALID
    LJMP ARITH_OVERFLOW
MUL16_VALID:            MOV R2, PROD1
    MOV R3, PROD0
    MOV A, R2
    ORL A, R3
    JNZ MUL16_KEEP_SIGN
    CLR 20H.2                    ; Never display negative zero
MUL16_KEEP_SIGN:        RET

MATH_DIV: ; Divide unsigned 16-bit magnitudes
    ; Unsigned 16-bit restoring division. Quotient replaces operand 1;
    ; remainder is intentionally discarded.
    MOV A, R4
    ORL A, R5
    JNZ DIVISOR_VALID
    LJMP DIVIDE_BY_ZERO
DIVISOR_VALID:
    MOV TMP_H, R2                ; Shifting dividend
    MOV TMP_L, R3
    MOV QUO_H, #00H
    MOV QUO_L, #00H
    MOV REM_H, #00H
    MOV REM_L, #00H
    MOV R0, #16
DIV16_LOOP:
    ; Take the next dividend bit from the MSB side.
    CLR C
    MOV A, TMP_L
    RLC A
    MOV TMP_L, A
    MOV A, TMP_H
    RLC A
    MOV TMP_H, A
    ; remainder = remainder*2 + next dividend bit.
    MOV A, REM_L
    RLC A
    MOV REM_L, A
    MOV A, REM_H
    RLC A
    MOV REM_H, A
    MOV DIV_OVER, #00H
    JNC DIV16_NO_REM_OVER
    MOV DIV_OVER, #01H
DIV16_NO_REM_OVER:
    ; Make space for the next quotient bit.
    CLR C
    MOV A, QUO_L
    RLC A
    MOV QUO_L, A
    MOV A, QUO_H
    RLC A
    MOV QUO_H, A
    ; A 17th remainder bit means remainder is certainly >= divisor.
    MOV A, DIV_OVER
    JNZ DIV16_SUBTRACT
    ; Unsigned compare remainder with divisor.
    MOV A, REM_H
    CLR C
    SUBB A, R4
    JC DIV16_LESS
    JNZ DIV16_SUBTRACT
    MOV A, REM_L
    CLR C
    SUBB A, R5
    JC DIV16_LESS
DIV16_SUBTRACT:         CLR C
    MOV A, REM_L
    SUBB A, R5
    MOV REM_L, A
    MOV A, REM_H
    SUBB A, R4
    MOV REM_H, A
    ORL QUO_L, #01H
DIV16_LESS:             DJNZ R0, DIV16_LOOP
    MOV R2, QUO_H
    MOV R3, QUO_L
    MOV A, R2
    ORL A, R3
    JNZ DIV16_KEEP_SIGN
    CLR 20H.2                    ; Never display negative zero
DIV16_KEEP_SIGN:        RET

MATH_SQUARE: ; Square operand 1 through checked multiplication
    MOV A, R2
    MOV R4, A
    MOV A, R3
    MOV R5, A
    CLR 20H.2                    ; A square is always non-negative
    LCALL MATH_MUL              ; Same 16-bit overflow checking as multiply
    RET

; REQUIRED 8-BIT LOGICAL OPERATIONS
LOGIC_AND: ; Perform the required 8-bit AND
    MOV A, R3
    ANL A, R5
    MOV R3, A
    MOV R2, #00H
    RET

LOGIC_OR: ; Perform the required 8-bit OR
    MOV A, R3
    ORL A, R5
    MOV R3, A
    MOV R2, #00H
    RET

LOGIC_XOR: ; Perform the required 8-bit XOR
    MOV A, R3
    XRL A, R5
    MOV R3, A
    MOV R2, #00H
    RET

LOGIC_NOT: ; Invert all eight bits of operand 1
    MOV A, R3
    CPL A
    MOV R3, A
    MOV R2, #00H
    RET

; ERROR DETECTION
ARITH_OVERFLOW:         MOV ERROR_CODE, #01H
    LJMP SET_ERROR
DIVIDE_BY_ZERO:         MOV ERROR_CODE, #03H
    LJMP SET_ERROR

SET_ERROR: ; Set the shared arithmetic error flag
    SETB 20H.0
    RET
; RESULT AND ERROR DISPLAY
DISPLAY_RESULT: ; Send a valid result to LCD line 2
    JB 20H.0, DISPLAY_ERROR
    MOV A, MODE
    CJNE A, #02H, DISPLAY_DECIMAL_RESULT
    LCALL LCD_PRINT_BIN8_RIGHT
    SJMP RESULT_DISPLAYED
DISPLAY_DECIMAL_RESULT: LCALL LCD_PRINT_U16_RIGHT
RESULT_DISPLAYED:
    SETB 20H.3                    ; Enable new-entry and ANS behavior
    RET

DISPLAY_ERROR: ; Select and print the active error message
    LCALL LCD_CLEAR_LINE2
    MOV A, ERROR_CODE
    CJNE A, #01H, ERR_CHK_ZERO
    MOV DPTR, #STR_ERR_OVERFLOW
    SJMP ERROR_PRINT
ERR_CHK_ZERO:           CJNE A, #03H, ERR_CHK_INPUT
    MOV DPTR, #STR_ERR_DIV_ZERO
    SJMP ERROR_PRINT
ERR_CHK_INPUT:          CJNE A, #04H, ERR_CHK_OPERATOR
    MOV DPTR, #STR_ERR_INPUT
    SJMP ERROR_PRINT
ERR_CHK_OPERATOR:       CJNE A, #07H, ERR_CHK_BIT_COUNT
    MOV DPTR, #STR_ERR_BINARY
    SJMP ERROR_PRINT
ERR_CHK_BIT_COUNT:      CJNE A, #08H, ERR_UNKNOWN
    MOV DPTR, #STR_ERR_8_BITS
    SJMP ERROR_PRINT
ERR_UNKNOWN:            MOV DPTR, #STR_ERROR
ERROR_PRINT:            LCALL LCD_PUTS
    RET

LCD_PRINT_BIN8_RIGHT: ; Print R3 as eight right-aligned binary digits
    MOV A, #LCD_LINE2
    LCALL LCD_CMD
    MOV R0, #08H
BIN8_PADDING:           MOV A, #' '
    LCALL LCD_DATA
    DJNZ R0, BIN8_PADDING
    MOV DIGIT_TMP, R3
    MOV R0, #08H
BIN8_PRINT_LOOP:        MOV A, DIGIT_TMP
    ANL A, #080H
    JZ BIN8_PRINT_ZERO
    MOV A, #'1'
    SJMP BIN8_WRITE
BIN8_PRINT_ZERO:        MOV A, #'0'
BIN8_WRITE:             LCALL LCD_DATA
    MOV A, DIGIT_TMP
    RL A
    MOV DIGIT_TMP, A
    DJNZ R0, BIN8_PRINT_LOOP
    RET

LCD_PRINT_U16_RIGHT: ; Convert and right-align a signed 16-bit result
    ; Convert the sign+magnitude result to decimal and right-align it on line 2.
    ; Digits are stacked as ASCII, then popped in most-significant-first order.
    MOV TMP_H, R2
    MOV TMP_L, R3
    MOV A, TMP_H
    ORL A, TMP_L
    JNZ U16_CONVERT
    ; Start from C0H and write 15 spaces followed by zero. Beginning at the
    ; line base is more reliable on physical LCD controller variants.
    MOV A, #LCD_LINE2
    LCALL LCD_CMD
    MOV R0, #0FH
U16_ZERO_PAD:           MOV A, #' '
    LCALL LCD_DATA
    DJNZ R0, U16_ZERO_PAD
    MOV A, #'0'
    LCALL LCD_DATA
    RET
U16_CONVERT:            MOV R0, #00H
U16_DIVIDE_LOOP:        LCALL DIV_TMP_BY_10
    ADD A, #30H
    PUSH ACC
    INC R0
    MOV A, TMP_H
    ORL A, TMP_L
    JNZ U16_DIVIDE_LOOP
    ; Padding = 16 - digit count - optional minus sign. Always position the
    ; cursor at C0H, then write the padding and value sequentially.
    MOV DIGIT_COUNT, R0
    MOV A, R0
    JNB 20H.2, U16_ALIGN_COUNT_READY
    INC A
U16_ALIGN_COUNT_READY:  MOV B, A
    MOV A, #LCD_WIDTH
    CLR C
    SUBB A, B
    MOV R1, A                     ; Number of leading spaces
    MOV A, #LCD_LINE2
    LCALL LCD_CMD
    MOV A, R1
    JZ U16_PADDING_DONE
U16_PADDING_LOOP:       MOV A, #' '
    LCALL LCD_DATA
    DJNZ R1, U16_PADDING_LOOP
U16_PADDING_DONE:
    JNB 20H.2, U16_PRINT_PREPARE
    MOV A, #'-'
    LCALL LCD_DATA
U16_PRINT_PREPARE:      MOV R0, DIGIT_COUNT
U16_PRINT_LOOP:         POP ACC
    LCALL LCD_DATA
    DJNZ R0, U16_PRINT_LOOP
    RET

DIV_TMP_BY_10: ; Divide a temporary 16-bit value by ten
    ; Divide TMP_H:TMP_L by 10 using 16 restoring-division steps.
    ; Quotient returns in TMP_H:TMP_L; remainder (0..9) returns in A.
    MOV QUO_H, #00H
    MOV QUO_L, #00H
    MOV REM_L, #00H
    MOV R1, #16
DIV10_LOOP:             CLR C
    MOV A, TMP_L
    RLC A
    MOV TMP_L, A
    MOV A, TMP_H
    RLC A
    MOV TMP_H, A
    MOV A, REM_L
    RLC A
    MOV REM_L, A
    CLR C
    MOV A, QUO_L
    RLC A
    MOV QUO_L, A
    MOV A, QUO_H
    RLC A
    MOV QUO_H, A
    MOV A, REM_L
    CLR C
    SUBB A, #10
    JC DIV10_LESS
    MOV REM_L, A
    ORL QUO_L, #01H
DIV10_LESS:             DJNZ R1, DIV10_LOOP
    MOV TMP_H, QUO_H
    MOV TMP_L, QUO_L
    MOV A, REM_L
    RET

; ZERO-TERMINATED LCD STRINGS (ALL FIT WITHIN A 16-CHARACTER LCD LINE)
NORMAL_SYMBOLS: DB '+', '-', '*', '/'
LOGIC_SYMBOLS:  DB '&', '|', 'X'
STR_READY:          DB 'READY', 00H
STR_ANS:            DB 'ANS', 00H
STR_SELECT_MODES:   DB 'SELECT 3 MODES', 00H
STR_MODE_MENU:      DB '1:AR 2:LOG 3:ADD', 00H
STR_ARITHMETIC:     DB 'ARITHMETIC', 00H
STR_LOGICAL:        DB 'LOGIC: 0/1 ONLY', 00H
STR_ADDITIONAL:     DB 'ADDITIONAL', 00H
STR_ERR_OVERFLOW:   DB 'ERROR:OVERFLOW', 00H
STR_ERR_DIV_ZERO:   DB 'ERROR:DIV ZERO', 00H
STR_ERR_INPUT:      DB 'ERROR:INPUT SIZE', 00H
STR_ERR_BINARY:     DB 'ERROR:USE 0/1', 00H
STR_ERR_8_BITS:     DB 'ERROR:MAX 8 BIT', 00H
STR_ERROR:          DB 'ERROR', 00H

    END
