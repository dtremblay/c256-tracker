MIDI_DATA_REG    = $AF1330 ; read/write MIDI data
MIDI_STATUS_REG  = $AF1331 ; read - status, write control
MIDI_ADDRESS_HI  = $AF1160
MIDI_ADDRESS_LO  = $AF1161

INIT_MIDI
                PHA
                setas
                .xl
                STZ MIDI_COUNTER
                STZ TIMING_CNTR
                
                LDA #5    ; (C256 - MIDI IN) Bit[0] = 1, Bit[2] = 1 (Page 132 Manual)
                STA @lGP25_REG
                ; LDA #0
                ; STA @lGP26_REG ; disable MIDI out
                
                LDA #$3F
                STA @lMIDI_STATUS_REG
                
                LDY #10 * 128 + 54
MORE_DATA       LDA @lMIDI_DATA_REG
                JSR WRITE_HEX
                INY
                INY
                
                LDA @lMIDI_STATUS_REG
                AND #$80
                CMP #$80
                BNE MORE_DATA
                
INIT_MIDI_DONE
                PLA
                RTS
; xl and as
; A contains the MIDI DATA
RECEIVE_MIDI_DATA
                .as
                setxl
                PHA
                
                BPL RECEIVED_DATA_MSG
                
                PHA
                AND #$F ; channel - store it somewhere when you care
                STA MIDI_CHANNEL
                
                PLA
                AND #$70
                LSR 
                LSR 
                LSR 
                
                STA MIDI_CTRL
                CMP #$E
                BNE RECEIVE_MIDI_DATA_DONE
                
                JSR SYSTEM_COMMAND
                BRA RECEIVE_MIDI_DATA_DONE 
                
RECEIVED_DATA_MSG
                PHA
                setxs
                LDA MIDI_CTRL
                TAX
                PLA
                JSR (MIDI_COMMAND_TABLE,X)
                setxl
                
RECEIVE_MIDI_DATA_DONE
                PLA
                RTS
                
; /// A contains the last byte received from MIDI
NOTE_OFF
NOTE_ON         ; we need two data bytes: the note and the velocity
                .as
                .xs
                LDX MIDI_COUNTER
                STA MIDI_DATA1,X
                
                TXA
                INC A
                STA MIDI_COUNTER
                CMP #2
                BNE MORE_NOTE_DATA_NEEDED
                
                STZ MIDI_COUNTER  ; reset the counter
                LDA #0
                STA OPL2_CHANNEL
                
                
                setxl
                LDA MIDI_CTRL
                LDY #12*128 + 54
                JSR WRITE_HEX
                
                ; NOTE VALUE
                LDA MIDI_DATA1
                STA @lD0_OPERAND_B
                LDY #12*128 + 56
                JSR WRITE_HEX
                
                LDA #0
                STA @lD0_OPERAND_A + 1
                STA @lD0_OPERAND_B + 1
                LDA #12
                STA @lD0_OPERAND_A
                
                SEC
                LDA @lD0_RESULT
                SBC #2
                STA OPL2_OCTAVE
                LDY #12*128 + 60
                JSR WRITE_HEX
                
                LDA @lD0_REMAINDER
                STA OPL2_NOTE
                LDY #12*128 + 62
                JSR WRITE_HEX
                
                ; VELOCITY VALUE
                LDA MIDI_DATA2
                LDY #12*128 + 64
                JSR WRITE_HEX
                
                ; /// if velocity is zero, turn note off
                CMP #0
                BNE PLAY_NOTE_ON  ; otherwise, turn note on
                STA OPL2_PARAMETER0
                LDA #$FF
                LDY #12*128 + 70
                JSR WRITE_HEX
                
                JSR OPL2_SET_KEYON
                
                BRA MORE_NOTE_DATA_NEEDED
                
PLAY_NOTE_ON
                LDA #1
                STA OPL2_PARAMETER0
                
                setal
                JSR OPL2_GET_REG_OFFSET
                JSL OPL2_PLAYNOTE
                setas
                
MORE_NOTE_DATA_NEEDED
                setxs
                RTS


POLY_PRESSURE
CONTROL_CHANGE
PITCH_BEND
                .xs
                LDX MIDI_COUNTER
                STA MIDI_DATA1,X
                
                TXA
                INC A
                STA MIDI_COUNTER
                CMP #2
                BNE MORE_CTRL_DATA_NEEDED
                
                setxl
                LDA MIDI_CTRL
                LDY #14*128 + 54
                JSR WRITE_HEX
                
                LDA MIDI_DATA1
                LDY #14*128+56
                JSR WRITE_HEX
                
                LDA MIDI_DATA2
                LDY #14*128+58
                JSR WRITE_HEX
                
                STZ MIDI_COUNTER
                
                ;JSR CTRL_TRACKER_NOTE
                
MORE_CTRL_DATA_NEEDED
                RTS
                
PROGRAM_CHANGE
CHANNEL_PRESSURE
                .as
                PHA
                setxl
                LDA MIDI_CTRL
                LDY #15*128 + 54
                JSR WRITE_HEX
                
                PLA
                LDY #15*128 + 56
                JSR WRITE_HEX
                
                LDA #16
                STA MIDI_CTRL
                RTS
                
SYSTEM_COMMAND
                .as
                setxl
                LDA @lTIMING_CNTR
                INC A
                CMP #3
                BNE DISPLAY_COUNTER
                LDA #0
                
DISPLAY_COUNTER
                LDY #16*128 + 54
                JSR WRITE_HEX
                STA @lTIMING_CNTR
                RTS
                
INVALID_COMMAND .as
                ; 
                RTS