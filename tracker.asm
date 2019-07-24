.cpu "65816"
.include "macros_inc.asm"
.include "bank_00_inc.asm"
.include "super_io_def.asm"
.include "vicky_def.asm"
.include "interrupt_def.asm"

MOUSE_BUTTONS_REG= $180F00 ; bit 2=middle, bit 1=right, bit 0=left
INSTR_REC_LEN    = INSTRUMENT_BAGPIPE1 - INSTRUMENT_ACCORDN

* = MOUSE_BUTTONS_REG
                .byte 0
TEMP_STORAGE    .byte 0,0
LOW_NIBBLE      .byte 0
HIGH_NIBBLE     .byte 0
HEX_MAP         .text '0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F'
STATE_MACHINE   .byte 0  ; High Nibble is the Mode (inst, order, pattern), Low nibble is state: 0 is record mode, 1 is play mode
TICK            .byte 0  ; this is used to count the number of 1/60 intervals
BPM             .byte 60 ; how fast should the lines change - 
PATTERN_NUM     .byte 1
LINE_NUM_DEC    .byte 1
ORDER_EDITOR_SCR = 128 * 7 + 53
PTRN_EDITOR_SCR  = 128 * 27 + 4

* = HRESET
                CLC
                XCE   ; go into native mode
                SEI   ; ignore interrupts
                JML TRACKER

* = HIRQ       ; IRQ handler.
RHIRQ           setaxl
                PHB
                PHD
                PHA
                PHX
                PHY
                ;
                ; todo: look up IRQ triggered and do stuff
                ;
                JSL IRQ_HANDLER

                PLY
                PLX
                PLA
                PLD
                PLB
                RTI

; Interrupt Vectors
* = VECTORS_BEGIN
JUMP_READY      JML TRACKER    ; Kernel READY routine. Rewrite this address to jump to a custom kernel.
RVECTOR_COP     .addr HCOP     ; FFE4
RVECTOR_BRK     .addr HBRK     ; FFE6
RVECTOR_ABORT   .addr HABORT   ; FFE8
RVECTOR_NMI     .addr HNMI     ; FFEA
                .word $0000    ; FFEC
RVECTOR_IRQ     .addr HIRQ     ; FFEE

RRETURN         JML TRACKER

RVECTOR_ECOP    .addr HCOP     ; FFF4
RVECTOR_EBRK    .addr HBRK     ; FFF6
RVECTOR_EABORT  .addr HABORT   ; FFF8
RVECTOR_ENMI    .addr HNMI     ; FFFA
RVECTOR_ERESET  .addr HRESET   ; FFFC
RVECTOR_EIRQ    .addr HIRQ     ; FFFE

* = $160000
.include "OPL2_Rad_Player.asm"

* = $181000


.include "OPL2_library.asm"
.include "keyboard_def.asm"
.include "display.asm"
.include "Interrupt_Handler.asm" ; Interrupt Handler Routines
.include "midi.asm"
.include "display_func.asm"

; Draw the screen
; Top portion is the instruments editor (left) and order list (right)
; Bottom part is the pattern editor
; we'll need to figure out how to do stereo, left- and right-only.

TRACKER
                JSL OPL2_INIT_PLAYER
                ; Setup the Interrupt Controller
                ; For Now all Interrupt are Falling Edge Detection (IRQ)
                LDA #$FF
                STA @lINT_EDGE_REG0
                STA @lINT_EDGE_REG1
                STA @lINT_EDGE_REG2
                
                ; Mask all Interrupt @ This Point
                LDA #$FF
                STA @lINT_MASK_REG0
                STA @lINT_MASK_REG1
                STA @lINT_MASK_REG2
                
                JSR DRAW_DISPLAY
                
                ; we allow keyboard inputs 
                JSR INIT_KEYBOARD
                JSR INIT_MOUSEPOINTER
                JSR INIT_CURSOR
                JSR RESET_STATE_MACHINE
                
                ; store the high-byte in memory
                LDA #`INSTRUMENT_ACCORDN
                STA INSTR_ADDR+2
                
                ; pick ELPIANO2 as the default instrument
                LDA #$42
                STA @lINSTR_NUMBER
                
                LDX #0 ; setup channel 1
                JSR LOAD_INSTRUMENT
                
                LDX #1 ; setup channel 2
                JSR LOAD_INSTRUMENT
                
                LDX #2 ; setup channel 3
                JSR LOAD_INSTRUMENT
                
                JSL IOPL2_TONE_TEST

                JSR ENABLE_IRQS
                JSR INIT_TIMER0  
                ; JSR INIT_OPL2_TMRS
                CLI
                
                ; we allow input of data via MIDI
                JSR INIT_MIDI
          
ALWAYS          NOP
                NOP
                
                BRA ALWAYS
;
; IINITCURSOR
; Author: Stefany
; Init the Cursor Registers
; Verify that the Math Block Works
; Inputs:
; None
; Affects:
;  Vicky's Internal Cursor's Registers
INIT_CURSOR     PHA
                LDA #$E9      ;The Cursor Character will be a Fully Filled Block
                STA VKY_TXT_CURSOR_CHAR_REG
                LDA #$0       ;Set Cursor Disabled
                STA VKY_TXT_CURSOR_CTRL_REG ;
                
                setaxl        ; Set Acc back to 16bits before setting the Cursor Position
                LDA #$0000;
                STA VKY_TXT_CURSOR_X_REG_L; // Set the X to Position 1
                LDA #$0000;
                STA VKY_TXT_CURSOR_Y_REG_L; // Set the Y to Position 1 (Below)
                
                setas
                PLA
                RTS
                
ENABLE_IRQS
                ; Clear Any Pending Interrupt
                LDA @lINT_PENDING_REG0
                AND #FNX0_INT07_MOUSE | FNX0_INT02_TMR0 ;AND #FNX0_INT00_SOF
                STA @lINT_PENDING_REG0  ; Writing it back will clear the Active Bit
                
                LDA @lINT_PENDING_REG1
                AND #FNX1_INT00_KBD | FNX1_INT05_MPU401
                STA @lINT_PENDING_REG1  ; Writing it back will clear the Active Bit
                
                ;LDA @lINT_PENDING_REG2
                ;AND #FNX2_INT01_OPL2L | FNX2_INT00_OPL2R
                ;STA @lINT_PENDING_REG2  ; Writing it back will clear the Active Bit
                
                ; Enable Mouse
                LDA #~(FNX0_INT07_MOUSE | FNX0_INT02_TMR0)  ;LDA #~(FNX0_INT00_SOF | FNX0_INT00_SOF )
                STA @lINT_MASK_REG0
                
                ; Enable Keyboard
                LDA #~(FNX1_INT00_KBD | FNX1_INT05_MPU401)
                STA @lINT_MASK_REG1
                
                ; Enable OPL2 Interrupts
                ;LDA #~(FNX2_INT01_OPL2L | FNX2_INT00_OPL2R)
                ;STA @lINT_MASK_REG2
                RTS
                
; *******************************************************************************
; * Reset everything to their initial state
; *******************************************************************************
RESET_STATE_MACHINE
                .as
                LDA #1
                STA STATE_MACHINE
                
                STZ LINE_NUM_HEX
                
                LDA #1
                STA LINE_NUM_DEC
                STA PATTERN_NUM
                
                JSR DISPLAY_BPM
                JSR DISPLAY_PATTERN
                
                RTS
                
; ***********************************************************************
; * Timers are not yet implemented in C256 Foenix.
; ***********************************************************************
INIT_TIMER0     
                .as
                PHB
                
                LDA #0
                PHA
                PLB ; set databank to 0
                
                LDA #3
                STA M0_OPERAND_A
                STZ M0_OPERAND_A + 1
                STZ M0_OPERAND_B + 1
                SEC
                LDA BPM
                SBC #4
                STA M0_OPERAND_B
                
                setal
                LDA M0_RESULT 
                TAX
                
                setas
                LDA #0
                STA TIMER0_CHARGE_L
                STA TIMER0_CHARGE_M
                STA TIMER0_CHARGE_H
                
                LDA @lSPM_004,X
                STA TIMER0_CMP_L
                LDY #8
                JSR WRITE_HEX
                
                LDA @lSPM_004+1,X
                STA TIMER0_CMP_M
                LDY #6
                JSR WRITE_HEX
                
                LDA @lSPM_004+2,X
                STA TIMER0_CMP_H
                LDY #4
                JSR WRITE_HEX
                
                LDA #TMR0_CMP_RECLR
                STA TIMER0_CMP_REG
                
                LDA #(TMR0_EN | TMR0_UPDWN | TMR0_SCLR)
                STA TIMER0_CTRL_REG
                
                PLB
                RTS
                
; ***********************************************************************
; * OPL2 Timers
; * Timer1 increments every 80us.   When register overflows an IRQ is generate.
; * Timer2 increments every 320us.  When register overflows an IRQ is generate.
; ***********************************************************************
INIT_OPL2_TMRS
                .as
                LDA #$80 ; Reset OPL2 Interrupts
                STA OPL2_L_IRQ ; byte 4 of OPL2
                
                ; wait 80 us
                JSR WAIT_80
                
                LDA #$10
                STA OPL2_L_TIMER1 ; byte 2 of OPL2
                STA OPL2_L_TIMER2 ; byte 2 of OPL2

                LDA #$3 ; enable timers 1 and 2
                STA OPL2_L_IRQ ; byte 4 of OPL2
                
                RTS

WAIT_80         
                .as
                LDX #560
   WAIT_LP
                DEX
                BNE WAIT_LP
                RTS
                
; X contains the channel
LOAD_INSTRUMENT
                .as
                LDA @lINSTR_NUMBER

                ; calculate the memory offset to the instrument bank
                STA @lM0_OPERAND_A
                LDA #0
                STA @lM0_OPERAND_A + 1
                STA @lM0_OPERAND_B + 1
                LDA #INSTR_REC_LEN
                STA @lM0_OPERAND_B
                setal
                LDA @lM0_RESULT
                
                CLC
                ADC #<>INSTRUMENT_ACCORDN
                STA INSTR_ADDR
                
                setas
                ; Y still contains the instrument number
                LDA @lINSTR_NUMBER
                LDY #5 * 128 + 19
                JSR WRITE_HEX

                LDA [INSTR_ADDR]
                BNE DRUM_SET
                
                ; $20 Amp Mod, Vibrator, EG Type, Key Scaling, F Mult
                INC INSTR_ADDR
                BNE LD_INST_1
                INC INSTR_ADDR+1
    LD_INST_1         
                JSR LOAD_AM_VIB_MULT
                
                ; $40 Key Scaling Lvl, Operator Lvl
                INC INSTR_ADDR
                BNE LD_INST_2
                INC INSTR_ADDR+1
    LD_INST_2 
                JSR LOAD_KEY_OP_LVL
                
                ; $60 Attack Rate, Decay Rate
                INC INSTR_ADDR
                BNE LD_INST_3
                INC INSTR_ADDR+1
    LD_INST_3 
                JSR LOAD_ATT_DEC_RATE
                
                ; $80 Sustain Level, Release Rate
                INC INSTR_ADDR
                BNE LD_INST_4
                INC INSTR_ADDR+1
    LD_INST_4
                JSR LOAD_SUSTAIN_RELEASE_RATE
                
                ; $C0 Feedback, Connection Type
                INC INSTR_ADDR
                BNE LD_INST_5
                INC INSTR_ADDR+1
    LD_INST_5
                JSR LOAD_FEEDBACK_ALGO
                
                ; $E0 Waveform Selection
                INC INSTR_ADDR
                BNE LD_INST_6
                INC INSTR_ADDR+1
    LD_INST_6
                JSR LOAD_WAVE
                
                setal
                LDA INSTR_ADDR
                ADC #6
                STA INSTR_ADDR
                setas
                ;display instrument name
                LDY #5 * 128 + 24
                JSR WRITE_INSTRUMENT_NAME
                
DRUM_SET
                RTS

; 
LOAD_AM_VIB_MULT
                LDA [INSTR_ADDR]
                PHA
                PHA
                PHA
                PHA
                STA @lOPL2_S_AM_VID_EG_KSR_MULT,X
                AND #TREMOLO
                LDY #7 * 128 + 13
                JSR WRITE_OFF_ON
                
                PLA
                AND #VIBRATO
                LDY #8 * 128 + 13
                JSR WRITE_OFF_ON
                
                PLA
                AND #SUSTAINING
                LDY #9 * 128 + 13
                JSR WRITE_OFF_ON
                
                PLA
                AND #KSR
                LDY #10 * 128 + 13
                JSR WRITE_OFF_ON
                
                PLA
                AND #MULTIPLIER
                LDY #11 * 128 + 14
                JSR WRITE_HEX
                
                LDY #6
                LDA [INSTR_ADDR], Y
                PHA
                PHA
                PHA
                PHA
                STA @lOPL2_S_AM_VID_EG_KSR_MULT + 3,X
                AND #TREMOLO
                LDY #7 * 128 + 39
                JSR WRITE_OFF_ON
                
                PLA
                AND #VIBRATO
                LDY #8 * 128 + 39
                JSR WRITE_OFF_ON
                
                PLA
                AND #SUSTAINING
                LDY #9 * 128 + 39
                JSR WRITE_OFF_ON
                
                PLA
                AND #KSR
                LDY #10 * 128 + 39
                JSR WRITE_OFF_ON
                
                PLA
                AND #MULTIPLIER
                LDY #11 * 128 + 40
                JSR WRITE_HEX
                
                RTS
                
LOAD_KEY_OP_LVL
                ; Operator 1
                LDA [INSTR_ADDR]
                PHA
                STA @lOPL2_S_KSL_TL,X
                AND #KEY_SCALE
                ROL A
                ROL A
                ROL A
                LDY #12 * 128 + 14
                JSR WRITE_HEX
                
                PLA 
                AND #OP_LEVEL
                LDY #13 * 128 + 14
                JSR WRITE_HEX
                
                ; Operator 2
                LDY #6
                LDA [INSTR_ADDR],Y
                PHA
                STA @lOPL2_S_KSL_TL + 3,X
                AND #KEY_SCALE
                ROL A
                ROL A
                ROL A
                LDY #12 * 128 + 40
                JSR WRITE_HEX
                
                PLA 
                AND #OP_LEVEL
                LDY #13 * 128 + 40
                JSR WRITE_HEX
                
                RTS

LOAD_ATT_DEC_RATE
                LDA [INSTR_ADDR]
                PHA
                STA @lOPL2_S_AR_DR,X
                AND #ATTACK_RT
                LSR A
                LSR A
                LSR A
                LSR A
                LDY #14 * 128 + 14
                JSR WRITE_HEX
                
                PLA
                AND #DECAY_RT
                LDY #15 * 128 + 14
                JSR WRITE_HEX
                
                LDY #6
                LDA [INSTR_ADDR],Y
                PHA
                STA @lOPL2_S_AR_DR + 3,X
                AND #ATTACK_RT
                LSR A
                LSR A
                LSR A
                LSR A
                LDY #14 * 128 + 40
                JSR WRITE_HEX
                
                PLA
                AND #DECAY_RT
                LDY #15 * 128 + 40
                JSR WRITE_HEX
                RTS
                
LOAD_SUSTAIN_RELEASE_RATE
                LDA [INSTR_ADDR]
                PHA
                STA @lOPL2_S_SL_RR,X
                AND #ATTACK_RT
                LSR A
                LSR A
                LSR A
                LSR A
                LDY #16 * 128 + 14
                JSR WRITE_HEX
                
                PLA
                AND #DECAY_RT
                LDY #17 * 128 + 14
                JSR WRITE_HEX
                
                LDY #6
                LDA [INSTR_ADDR],Y
                PHA
                STA @lOPL2_S_SL_RR + 3,X
                AND #ATTACK_RT
                LSR A
                LSR A
                LSR A
                LSR A
                LDY #16 * 128 + 40
                JSR WRITE_HEX
                
                PLA
                AND #DECAY_RT
                LDY #17 * 128 + 40
                JSR WRITE_HEX
                RTS
                
LOAD_FEEDBACK_ALGO
                LDA [INSTR_ADDR]
                PHA
                STA @lOPL2_S_FEEDBACK,X
                AND #FEEDBACK
                LSR A
                LDY #20 * 128 + 40
                JSR WRITE_HEX
                
                PLA
                AND #ALGORITHM
                LDY #21 * 128 + 40
                JSR WRITE_HEX
                
                RTS

LOAD_WAVE
                LDA [INSTR_ADDR]
                STA @lOPL2_S_WAVE_SELECT,X
                AND #$7
                LDY #18 * 128 + 14
                JSR WRITE_HEX
                
                LDY #5
                LDA [INSTR_ADDR],Y
                STA @lOPL2_S_WAVE_SELECT+3,X
                AND #$7
                LDY #18 * 128 + 40
                JSR WRITE_HEX
                RTS

INIT_KEYBOARD
                PHD
                PHA
                PHX
                PHP
                
                CLC
                setas
                LDA #$00
                STA KEYBOARD_SC_FLG     ; Clear the Keyboard Flag
                
                JSR Poll_Inbuf
                
                LDA #$AA      ;Send self test command
                STA KBD_CMD_BUF
                ;; Sent Self-Test Code and Waiting for Return value, it ought to be 0x55.
                JSR Poll_Outbuf ;

                LDA KBD_OUT_BUF   ;Check self test result
                CMP #$55
                BEQ passAAtest

                BRL initkb_loop_out

passAAtest      
;; Test AB
                LDA #$AB      ;Send test Interface command
                STA KBD_CMD_BUF

                JSR Poll_Outbuf ;

                LDA KBD_OUT_BUF   ;Display Interface test results
                CMP #$00      ;Should be 00
                BEQ passABtest

                BRL initkb_loop_out

passABtest      

                ;LDA #$A8        ; Enable Second PS2 Port
                ;STA KBD_DATA_BUF
                ;JSR Poll_Outbuf ;

;; Program the Keyboard & Enable Interrupt with Cmd 0x60
                LDA #$60            ; Send Command 0x60 so to Enable Interrupt
                STA KBD_CMD_BUF
                JSR Poll_Inbuf ;
                LDA #%01101001      ; Enable Interrupt
                ;LDA #%01001011      ; Enable Interrupt for Mouse and Keyboard
                STA KBD_DATA_BUF
                JSR Poll_Inbuf ;
                
; Reset Keyboard
                LDA #$FF      ; Send Keyboard Reset command
                STA KBD_DATA_BUF
                ; Must wait here;
                LDX #$FFFF
DLY_LOOP1       DEX
                NOP
                NOP
                NOP
                NOP
                NOP
                NOP
                NOP
                NOP
                CPX #$0000
                BNE DLY_LOOP1
                JSR Poll_Outbuf ;

                LDA KBD_OUT_BUF   ; Read Output Buffer

DO_CMD_F4_AGAIN
                JSR Poll_Inbuf ;
                LDA #$F4      ; Enable the Keyboard
                STA KBD_DATA_BUF
                JSR Poll_Outbuf ;

                LDA KBD_OUT_BUF   ; Clear the Output buffer
                CMP #$FA
                BNE DO_CMD_F4_AGAIN
                
                ; Till We Reach this point, the Keyboard is setup Properly
                JSR INIT_MOUSE

                ; Unmask the Keyboard interrupt
                ; Clear Any Pending Interrupt
                LDA @lINT_PENDING_REG0  ; Read the Pending Register &
                AND #FNX0_INT07_MOUSE
                STA @lINT_PENDING_REG0  ; Writing it back will clear the Active Bit

                LDA @lINT_PENDING_REG1  ; Read the Pending Register &
                AND #FNX1_INT00_KBD
                STA @lINT_PENDING_REG1  ; Writing it back will clear the Active Bit

initkb_loop_out 
InitSuccess     
                PLP
                PLX
                PLA
                PLD
                RTS
          
;INIT_MOUSEPOINTER
INIT_MOUSEPOINTER
                setaxl
                LDX #<>MOUSE_POINTER_PTR
                LDA #$100
                LDY #$0500
                MVN #`MOUSE_POINTER_PTR,#$AF
                
                setas
                LDA #$01
                STA @lMOUSE_PTR_CTRL_REG_L  ; Enable Mouse, Mouse Pointer Graphic Bank 0
                RTS
                
Poll_Inbuf      .as
                LDA STATUS_PORT   ; Load Status Byte
                AND #<INPT_BUF_FULL ; Test bit $02 (if 0, Empty)
                CMP #<INPT_BUF_FULL
                BEQ Poll_Inbuf
                RTS

Poll_Outbuf     .as
                LDA STATUS_PORT
                AND #OUT_BUF_FULL ; Test bit $01 (if 1, Full)
                CMP #OUT_BUF_FULL
                BNE Poll_Outbuf
                RTS

INIT_MOUSE      .as

                JSR Poll_Inbuf
                LDA #$A8          ; Enable the second PS2 Channel
                STA KBD_CMD_BUF

;                LDX #$4000
;DLY_MOUSE_LOOP  DEX
                ;CPX #$0000
                ;BNE DLY_MOUSE_LOOP
DO_CMD_A9_AGAIN
                JSR Poll_Inbuf
                LDA #$A9          ; Tests second PS2 Channel
                STA KBD_CMD_BUF
                JSR Poll_Outbuf ;
                LDA KBD_OUT_BUF   ; Clear the Output buffer
                CMP #$00
                BNE DO_CMD_A9_AGAIN
                ; IF we pass this point, the Channel is OKAY, Let's move on

                JSR Poll_Inbuf
                LDA #$20
                STA KBD_CMD_BUF
                JSR Poll_Outbuf ;

                LDA KBD_OUT_BUF
                ORA #$02
                PHA
                JSR Poll_Inbuf
                LDA #$60
                STA KBD_CMD_BUF
                JSR Poll_Inbuf ;
                PLA
                STA KBD_DATA_BUF

                LDA #$F6        ;Tell the mouse to use default settings
                JSR MOUSE_WRITE
                JSR MOUSE_READ

                ; Set the Mouse Resolution 1 Clicks for 1mm - For a 640 x 480, it needs to be the slowest
                LDA #$E8
                JSR MOUSE_WRITE
                JSR MOUSE_READ
                
                LDA #$00
                JSR MOUSE_WRITE
                JSR MOUSE_READ

                ; Set the Refresh Rate to 60
;                LDA #$F2
;                JSR MOUSE_WRITE
;                JSR MOUSE_READ
;                LDA #60
;                JSR MOUSE_WRITE
;                JSR MOUSE_READ


                LDA #$F4        ; Enable the Mouse
                JSR MOUSE_WRITE
                JSR MOUSE_READ
                
                ; Let's Clear all the Variables Necessary to Computer the Absolute Position of the Mouse
                LDA #$00
                STA MOUSE_PTR
                RTS

MOUSE_WRITE     .as
                PHA
                JSR Poll_Inbuf
                LDA #$D4
                STA KBD_CMD_BUF
                JSR Poll_Inbuf
                PLA
                STA KBD_DATA_BUF
                RTS

MOUSE_READ      .as
                JSR Poll_Outbuf ;
                LDA KBD_INPT_BUF
                RTS

              
                
; Find the matching note for the key pressed
; A = Scan code
PLAY_TRACKER_NOTE
                PHA
                PHX
                setxs
                TAX
                BMI NONOTE ; key release should not play a note

                LDA @lSCAN_TO_NOTE, X  
                
                setxl
                LDY #128 + 70
                JSR WRITE_HEX
                STA @lOPL2_NOTE
                
                BMI NONOTE  ; if the lookup table returns $80, then don't play the note
                
                AND #$70
                LSR
                LSR
                LSR
                LSR
                STA @lOPL2_OCTAVE
                LDA @lOPL2_NOTE
                AND #$0F
                STA @lOPL2_NOTE
                LDA #0
                STA @lOPL2_CHANNEL
                JSR OPL2_GET_REG_OFFSET
                JSL OPL2_PLAYNOTE
                setas
                
NONOTE          
                setxl
                PLX
                PLA
                RTS




                
                ;      00,  01,  02,  03,  04,  05,  06,  07,  08,  09,  0A,  0B,  0C,  0D,  0E,  0F
SCAN_TO_NOTE    .text $80, $80, $80, $31, $33, $80, $36, $38, $3A, $80, $80, $80, $80, $80, $80, $80
                .text $30, $32, $34, $35, $37, $39, $3B, $40, $80, $80, $80, $80, $80, $80, $80, $21
                .text $23, $80, $26, $28, $2A, $80, $80, $80, $80, $80, $80, $80, $20, $22, $24, $25
                .text $27, $29, $2B, $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $80
                .text $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $80
                .text $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $80, $80
                
MIDI_COMMAND_TABLE
                 .word <>NOTE_OFF, <>NOTE_ON
                 .word <>POLY_PRESSURE, <>CONTROL_CHANGE
                 .word <>PROGRAM_CHANGE, <>CHANNEL_PRESSURE  ; these two command expect 1 datat byte only - no running status
                 .word <>PITCH_BEND, <>SYSTEM_COMMAND
                 .word <>INVALID_COMMAND
                 
* = $190000 ; pattern memory - reserving memory is kind of inefficient, but it's easier right now
PATTERN_BYTES = 1793
LINE_BYTES    =   28
PATTERNS .for pattern=1, pattern <= 36, pattern += 1 ; 64548 bytes total
    ; one pattern is 64 lines, each line is 9 channels - 1793 bytes per pattern
    .byte pattern
    .for line = 1, line <= 64, line += 1  ; 28 bytes per line
        .byte line     ; line number
        .rept 9
            ; we could compress the notes/octave to reduce
            .byte 0, 0, 0 ; note, octave, instrument, effect
        .next
    .next
.next

ORDERS    .fill 120, 0
* = $1A0000
.include "bpm.asm"
