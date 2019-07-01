;////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////
; Interrupt Handler
;////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////

check_irq_bit  .macro
                LDA \1
                AND #\2
                CMP #\2
                BNE END_CHECK
                STA \1
                JSR \3
                
END_CHECK
                .endm
                
IRQ_HANDLER
; First Block of 8 Interrupts
                setdp 0
                
                setas
                LDA #0
                PHA
                PLB
                
                LDA INT_PENDING_REG0
                BEQ CHECK_PENDING_REG1
; Start of Frame
                check_irq_bit INT_PENDING_REG0, FNX0_INT00_SOF, SOF_INTERRUPT
; Timer 0
                check_irq_bit INT_PENDING_REG0, FNX0_INT02_TMR0, TIMER0_INTERRUPT
; FDC Interrupt
                check_irq_bit INT_PENDING_REG0, FNX0_INT06_FDC, FDC_INTERRUPT
; Mouse IRQ
                check_irq_bit INT_PENDING_REG0, FNX0_INT07_MOUSE, MOUSE_INTERRUPT

; Second Block of 8 Interrupts
CHECK_PENDING_REG1
                setas
                LDA INT_PENDING_REG1
                BEQ CHECK_PENDING_REG2   ; BEQ EXIT_IRQ_HANDLE
; Keyboard Interrupt
                check_irq_bit INT_PENDING_REG1, FNX1_INT00_KBD, KEYBOARD_INTERRUPT
; COM2 Interrupt
                check_irq_bit INT_PENDING_REG1, FNX1_INT03_COM2, COM2_INTERRUPT
; COM1 Interrupt
                check_irq_bit INT_PENDING_REG1, FNX1_INT04_COM1, COM1_INTERRUPT
; MPU401 - MIDI Interrupt
                check_irq_bit INT_PENDING_REG1, FNX1_INT05_MPU401, MPU401_INTERRUPT
; LPT Interrupt
                check_irq_bit INT_PENDING_REG1, FNX1_INT06_LPT, LPT1_INTERRUPT

; Third Block of 8 Interrupts
CHECK_PENDING_REG2
                setas
                LDA INT_PENDING_REG2
                BEQ EXIT_IRQ_HANDLE
                
; OPL2 Right Interrupt
                check_irq_bit INT_PENDING_REG2, FNX2_INT00_OPL2R, OPL2R_INTERRUPT
; OPL2 Left Interrupt
                check_irq_bit INT_PENDING_REG2, FNX2_INT01_OPL2L, OPL2L_INTERRUPT
                
EXIT_IRQ_HANDLE
                ; Exit Interrupt Handler
                setaxl
                RTL

KEYBOARD_INTERRUPT
                .as
                ldx #$0000

IRQ_HANDLER_FETCH
                LDA KBD_INPT_BUF        ; Get Scan Code from KeyBoard
                STA KEYBOARD_SC_TMP     ; Save Code Immediately

                setxl
                LDY #70
                JSR WRITE_HEX  ; print the HEX key code at column 70 on the top line
                
                JSR PLAY_TRACKER_NOTE
                
                CMP #$1A
                BNE NOT_LEFT_BRACKET
                DEC INSTR_NUMBER
                JSR LOAD_INSTRUMENT  ; X is already set to 0
                
NOT_LEFT_BRACKET
                CMP #$1B
                BNE NOT_RIGHT_BRACKET
                INC INSTR_NUMBER
                JSR LOAD_INSTRUMENT  ; X is already set to 0
                
NOT_RIGHT_BRACKET

                ; Check for Shift Press or Unpressed
                CMP #$2A                ; Left Shift Pressed
                BNE NOT_KB_SET_SHIFT
                BRL KB_SET_SHIFT
NOT_KB_SET_SHIFT
                CMP #$AA                ; Left Shift Unpressed
                BNE NOT_KB_CLR_SHIFT
                BRL KB_CLR_SHIFT
NOT_KB_CLR_SHIFT
                ; Check for CTRL Press or Unpressed
                CMP #$1D                ; Left CTRL pressed
                BNE NOT_KB_SET_CTRL
                BRL KB_SET_CTRL
NOT_KB_SET_CTRL
                CMP #$9D                ; Left CTRL Unpressed
                BNE NOT_KB_CLR_CTRL
                BRL KB_CLR_CTRL

NOT_KB_CLR_CTRL
                CMP #$38                ; Left ALT Pressed
                BNE NOT_KB_SET_ALT
                BRL KB_SET_ALT
NOT_KB_SET_ALT
                CMP #$B8                ; Left ALT Unpressed
                BNE KB_UNPRESSED
                BRL KB_CLR_ALT


KB_UNPRESSED    AND #$80                ; See if the Scan Code is press or Depressed
                CMP #$80                ; Depress Status - We will not do anything at this point
                BNE KB_NORM_SC
                
                ; send note off signal
                LDA #$00
                STA OPL2_PARAMETER0 ; Set Keyon False
                JSR OPL2_SET_KEYON
                
                BRL KB_CHECK_B_DONE

KB_NORM_SC      

                LDA KEYBOARD_SC_TMP
                setxs
                TAX
                LDA KEYBOARD_SC_FLG     ; Check to See if the SHIFT Key is being Pushed
                AND #$10
                CMP #$10
                BEQ SHIFT_KEY_ON

                LDA KEYBOARD_SC_FLG     ; Check to See if the CTRL Key is being Pushed
                AND #$20
                CMP #$20
                BEQ CTRL_KEY_ON

                LDA KEYBOARD_SC_FLG     ; Check to See if the ALT Key is being Pushed
                AND #$40
                CMP #$40
                BEQ ALT_KEY_ON
                ; Pick and Choose the Right Bank of Character depending if the Shift/Ctrl/Alt or none are chosen
                LDA @lScanCode_Press_Set1, x
                BRL KB_WR_2_SCREEN
SHIFT_KEY_ON    LDA @lScanCode_Shift_Set1, x
                BRL KB_WR_2_SCREEN
CTRL_KEY_ON     LDA @lScanCode_Ctrl_Set1, x
                BRL KB_WR_2_SCREEN
ALT_KEY_ON      LDA @lScanCode_Alt_Set1, x

                ; Write Character to Screen (Later in the buffer)
KB_WR_2_SCREEN
                setxl
                LDY #74
                JSR WRITE_HEX
                
                JMP KB_CHECK_B_DONE

KB_SET_SHIFT    LDA KEYBOARD_SC_FLG
                ORA #$10
                STA KEYBOARD_SC_FLG
                JMP KB_CHECK_B_DONE

KB_CLR_SHIFT    LDA KEYBOARD_SC_FLG
                AND #$EF
                STA KEYBOARD_SC_FLG
                JMP KB_CHECK_B_DONE

KB_SET_CTRL     LDA KEYBOARD_SC_FLG
                ORA #$20
                STA KEYBOARD_SC_FLG
                JMP KB_CHECK_B_DONE

KB_CLR_CTRL     LDA KEYBOARD_SC_FLG
                AND #$DF
                STA KEYBOARD_SC_FLG
                JMP KB_CHECK_B_DONE

KB_SET_ALT      LDA KEYBOARD_SC_FLG
                ORA #$40
                STA KEYBOARD_SC_FLG
                JMP KB_CHECK_B_DONE

KB_CLR_ALT      LDA KEYBOARD_SC_FLG
                AND #$BF
                STA KEYBOARD_SC_FLG

KB_CHECK_B_DONE .as
                LDA STATUS_PORT
                AND #OUT_BUF_FULL ; Test bit $01 (if 1, Full)
                CMP #OUT_BUF_FULL ; if Still Byte in the Buffer, fetch it out
                BNE KB_DONE
                JMP IRQ_HANDLER_FETCH

KB_DONE
                RTS
;
; ///////////////////////////////////////////////////////////////////
; ///
; /// Start of Frame Interrupt
; /// 60Hz, 16ms Cyclical Interrupt
; ///
; ///////////////////////////////////////////////////////////////////
SOF_INTERRUPT
                .as
                LDA @lTICK
                INC A
                CMP @lBPM
                BNE TICK_DONE
                
                ; we now have to increment the line count
                CLC
                SED
                LDA @lLINE_NUM
                ADC #1
                CMP #$65  ; this is the maximum number of lines
                BNE INCR_DONE
                LDA #1
INCR_DONE
                CLD
                STA @lLINE_NUM
                JSR DISPLAY_LINE
                LDA #0  ; reset the tick to 0
TICK_DONE
                STA @lTICK
                RTS
                
; ///////////////////////////////////////////////////////////////////
; ///
; /// MPU-401 (MIDI)
; /// Desc: Interrupt for Data Rx/Tx
; /// We get a single interrupt per byte
; /// MIDI command have a command byte then one or two data bytes
; ///
; ///////////////////////////////////////////////////////////////////
MPU401_INTERRUPT  .as
                PHA
                setxl
                
MORE_MIDI_DATA  LDA @lMIDI_STATUS_REG ; if bit D7 is low, there is more data to read
                STA MIDI_REG
                AND #$80
                CMP #$80
                BEQ MIDI_DONE
                
                LDA @lMIDI_DATA_REG
                JSR RECEIVE_MIDI_DATA
                
                LDA MIDI_REG
                CMP #$80
                BNE MORE_MIDI_DATA
MIDI_DONE
                PLA
                RTS
                
TIMER0_INTERRUPT
                .as
;; PUT YOUR CODE HERE
                 RTS
;
; ///////////////////////////////////////////////////////////////////
; ///
; /// Mouse Interrupt
; /// Desc: Basically Assigning the 3Bytes Packet to Vicky's Registers
; ///       Vicky does the rest
; ///////////////////////////////////////////////////////////////////
MOUSE_INTERRUPT
                .as
                LDA KBD_INPT_BUF
                PHA
                LDX #$0000
                setxs
                LDX MOUSE_PTR
                BNE MOUSE_BYTE_GT1
                
                ; copy the buttons to another address
                AND #%0111
                STA MOUSE_BUTTONS_REG
                
    MOUSE_BYTE_GT1
                PLA
                STA @lMOUSE_PTR_BYTE0, X
                INX
                CPX #$03
                BNE EXIT_FOR_NEXT_VALUE
                
                ; Create Absolute Count from Relative Input
                LDA @lMOUSE_PTR_X_POS_L
                STA MOUSE_POS_X_LO
                LDA @lMOUSE_PTR_X_POS_H
                STA MOUSE_POS_X_HI

                LDA @lMOUSE_PTR_Y_POS_L
                STA MOUSE_POS_Y_LO
                LDA @lMOUSE_PTR_Y_POS_H
                STA MOUSE_POS_Y_HI
                
                
                ; print the character on the upper-right of the screen
                ; this is temporary
                CLC
                LDA MOUSE_BUTTONS_REG
                setxl
                LDY #60
                JSR WRITE_HEX
                setxs
                
                JSR MOUSE_BUTTON_HANDLER
                
                LDX #$00
EXIT_FOR_NEXT_VALUE
                STX MOUSE_PTR

                setxl
                RTS
                
MOUSE_BUTTON_HANDLER
                setas
                
                LDA @lMOUSE_BUTTONS_REG
                BEQ MOUSE_CLICK_DONE
                
                ; set the cursor position ( X/8 and Y/8 ) and enable blinking
                setal
                CLC
                LDA @lMOUSE_PTR_X_POS_L
                LSR
                LSR
                LSR
                LSR
                STA CURSORX
                STA @lVKY_TXT_CURSOR_X_REG_L
                
                CLC
                LDA @lMOUSE_PTR_Y_POS_L
                LSR
                LSR
                LSR
                STA CURSORY
                STA @lVKY_TXT_CURSOR_Y_REG_L
                
                setas
                LDA #$03      ;Set Cursor Enabled And Flash Rate @1Hz
                STA @lVKY_TXT_CURSOR_CTRL_REG
                
MOUSE_CLICK_DONE
                RTS
;
; ///////////////////////////////////////////////////////////////////
; ///
; /// Floppy Controller
; /// Desc: Interrupt for Data Rx/Tx or Process Commencement or Termination
; ///
; ///////////////////////////////////////////////////////////////////
FDC_INTERRUPT   .as

;; PUT YOUR CODE HERE
                RTS
;
;
; ///////////////////////////////////////////////////////////////////
; ///
; /// Serial Port COM2
; /// Desc: Interrupt for Data Rx/Tx or Process Commencement or Termination
; ///
; ///////////////////////////////////////////////////////////////////
COM2_INTERRUPT  .as

;; PUT YOUR CODE HERE
                RTS
;
; ///////////////////////////////////////////////////////////////////
; ///
; /// Serial Port COM1
; /// Desc: Interrupt for Data Rx/Tx or Process Commencement or Termination
; ///
; ///////////////////////////////////////////////////////////////////
COM1_INTERRUPT  .as

;; PUT YOUR CODE HERE
                RTS
;
;
; ///////////////////////////////////////////////////////////////////
; ///
; /// Parallel Port LPT1
; /// Desc: Interrupt for Data Rx/Tx or Process Commencement or Termination
; ///
; ///////////////////////////////////////////////////////////////////
LPT1_INTERRUPT  .as

;; PUT YOUR CODE HERE
                RTS

OPL2R_INTERRUPT .as
                RTS

OPL2L_INTERRUPT .as
                RTS

NMI_HANDLER
                RTL
                
