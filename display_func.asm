; ****************************************************
; * Initialize display
; * 80 columns by 60 rows
DRAW_DISPLAY
                ; set the display size - 128 x 64
                LDA #128
                STA COLS_PER_LINE
                LDA #64
                STA LINES_MAX

                ; set the visible display size - 80 x 60
                LDA #80
                STA COLS_VISIBLE
                LDA #60
                STA LINES_VISIBLE
                LDA #0
                STA BORDER_X_SIZE
                STA BORDER_Y_SIZE

                ; set the border to purple
                setas
                LDA #$20
                STA BORDER_COLOR_B
                STA BORDER_COLOR_R
                LDA #0
                STA BORDER_COLOR_G

                ; enable the border
                LDA #Border_Ctrl_Enable
                STA BORDER_CTRL_REG

                ; enable text display
                LDA #Mstr_Ctrl_Text_Mode_En
                STA MASTER_CTRL_REG_L

                setal
                LDA #<>CS_TEXT_MEM_PTR      ; store the initial screen buffer location
                STA SCREENBEGIN
                STA CURSORPOS
                setas
                LDA #`CS_TEXT_MEM_PTR
                STA SCREENBEGIN+2
                STA CURSORPOS+2

                ; copy screen data from TRACKER_SCREEN to CS_TEXT_MEM_PTR
                setaxl
                LDA #128*28-1
                LDX #<>TRACKER_SCREEN
                LDY #<>CS_TEXT_MEM_PTR
                MVN #`TRACKER_SCREEN,#$AF

                LDA #256 * 8
                LDX #<>FNXFONT
                LDY #<>FONT_MEMORY_BANK0
                MVN #`FNXFONT,#$AF

                ; set the fg LUT to Purple (2)
                LDA #$60FF
                STA FG_CHAR_LUT_PTR + 8;
                STA BG_CHAR_LUT_PTR + 8;
                LDA #$0080
                STA FG_CHAR_LUT_PTR + 10;
                STA BG_CHAR_LUT_PTR + 10;
                
                ; set the fg LUT to Green (3)
                LDA #$8020
                STA FG_CHAR_LUT_PTR + 12;
                STA BG_CHAR_LUT_PTR + 12;
                LDA #$0010
                STA FG_CHAR_LUT_PTR + 14;
                STA BG_CHAR_LUT_PTR + 14;
                
                ; set the fg LUT to Gray (4)
                LDA #$CCCC
                STA FG_CHAR_LUT_PTR + 16;
                STA BG_CHAR_LUT_PTR + 16;
                LDA #$00CC
                STA FG_CHAR_LUT_PTR + 18;
                STA BG_CHAR_LUT_PTR + 18;
                
                ; set the fg LUT to Yellow (5)
                LDA #$DD22
                STA FG_CHAR_LUT_PTR + 20;
                STA BG_CHAR_LUT_PTR + 20;
                LDA #$00DD
                STA FG_CHAR_LUT_PTR + 22;
                STA BG_CHAR_LUT_PTR + 22;

                ; set the character bg and fg color
                LDX #128*64
                setas
                LDA #$20
SETTEXTCOLOR
                STA CS_COLOR_MEM_PTR-1,X
                DEX
                BNE SETTEXTCOLOR
                
                LDY #38 * 128
                JSR REVERSE_LUT
                
                JSR HIGHLIGHT_MODE
                
                JSR DISPLAY_ACTIVE_CHANNELS

                RTS
                

; ****************************************************
; * Write a Hex Value to the position specified by Y
; * Y contains the screen position
; * A contains the value to display
WRITE_HEX
                .as
                .xl
        PHA
            PHX
                PHY
                STA @lTEMP_STORAGE
                AND #$F0
                lsr A
                lsr A
                lsr A
                lsr A
                setxs
                TAX
                LDA HEX_MAP,X
                STA @lLOW_NIBBLE
                
                LDA @lTEMP_STORAGE
                AND #$0F
                TAX
                LDA HEX_MAP,X
                STA @lHIGH_NIBBLE
                
                setaxl
                PLY
                LDA @lLOW_NIBBLE
                STA [SCREENBEGIN], Y
                ; change the foreground color of the text
                LDA #$3030
                TYX
                STA @lCS_COLOR_MEM_PTR, X
                setas
            PLX
        PLA
                RTS
                
; ****************************************************
; * Write On or Off to the position specified by Y
; * Y contains the screen position
; * A if 0, then Off, otherwise On
WRITE_OFF_ON
                .as
                PHX
                CMP #0
                BEQ DISPLAY_OFF
                LDA #'O'
                STA [SCREENBEGIN], Y
                LDA #$30
                TYX
                STA @lCS_COLOR_MEM_PTR, X
                INY
                
                LDA #'n'
                STA [SCREENBEGIN], Y
                LDA #$30
                TYX
                STA @lCS_COLOR_MEM_PTR, X
                
                INY
                LDA #$20
                STA [SCREENBEGIN], Y
                LDA #$30
                TYX
                STA @lCS_COLOR_MEM_PTR, X
                BRA ON_OFF_DONE
                
DISPLAY_OFF
                LDA #'O'
                STA [SCREENBEGIN], Y
                LDA #$30
                TYX
                STA @lCS_COLOR_MEM_PTR, X
                INY
                
                LDA #'f'
                STA [SCREENBEGIN], Y
                LDA #$30
                TYX
                STA @lCS_COLOR_MEM_PTR, X
                
                INY
                LDA #'f'
                STA [SCREENBEGIN], Y
                LDA #$30
                TYX
                STA @lCS_COLOR_MEM_PTR, X
ON_OFF_DONE
                PLX
                RTS

; ****************************************************
; * Display instrument name at position specified by Y.
; * Y Register contains the screen position to write.
; * INSTR_ADDR points to the address of the instrument name string.
WRITE_INSTRUMENT_NAME
                .as
                LDA #10
                STA @lTEMP_STORAGE
      WRITE_CHAR
                LDA [INSTR_ADDR]
                STA [SCREENBEGIN], Y
                INC INSTR_ADDR
                BNE WRITE_CONTINUE
                INC INSTR_ADDR + 1
                
      WRITE_CONTINUE
                LDA #$30
                TYX
                STA @lCS_COLOR_MEM_PTR, X
                INY
                
                LDA @lTEMP_STORAGE
                DEC A
                STA @lTEMP_STORAGE
                BNE WRITE_CHAR
                
                RTS
                
                
; ****************************************************
; * Display the pattern screen
; * 
; * LINE_NUM_DEC contains the decimal line number.
; * LINE_NUM_HEX contains the hex line number.
; * TAB_COUNTER contains the line number being drawn from 1 to 64.
; * We are defaulting to 32 lines of pattern to display.
; * If line number is < 10, display blanks
; * A simple header is displayed above line 1.
; * lines are grouped by 4, every fourth line is a tick line.
DISPLAY_PATTERN
                .as
                PHB
                PHD
                
                LDA #`PATTERNS
                STA PTRN_ADDR + 2
                
                LDA PATTERN_NUM ; this is a BCD value so it won't work once values are above 9
                ; display the pattern number
                LDY #23*128 + 19
                JSR WRITE_HEX
                
                ; find the starting address of the pattern and write it to the PTRN_ADDR
                DEC A  ; use 0 based offsets
                STA @lUNSIGNED_MULT_A
                STZ UNSIGNED_MULT_A + 1
            setal
                LDA #PATTERN_BYTES  ; this is the pattern size
                STA @lUNSIGNED_MULT_B
                LDA @lUNSIGNED_MULT_RESULT
                INC A ; skip the pattern # byte
                STA PTRN_ADDR
            setas 
                ; Draw the line number in the heading
                LDA LINE_NUM_DEC
                ; display the line number at the 'Line:' field
                LDY #23*128 + 7
                JSR WRITE_HEX
                
                ; Draw the pattern grid
                LDA #32
                STA REM_LINES
                
                LDY #<>CS_TEXT_MEM_PTR + 128 * 28 ; top of the pattern display
                LDA LINE_NUM_HEX
                CMP #10
                BCS DRAW_DATA ; if line# is greater than 10, skip blank lines and topline
                
DRAW_BLANK_LINES
                SEC
                LDA #9
                SBC LINE_NUM_HEX
                
                BEQ DRAW_TOP_LINE
                STA TAB_COUNTER
BLANKS_LOOP
            setal
                LDA #127
                LDX #<>blank_line
                MVN #`blank_line,#$AF
            setas
                DEC REM_LINES
                DEC TAB_COUNTER
                BNE BLANKS_LOOP
                
DRAW_TOP_LINE
            setal
                LDA #127
                LDX #<>top_line
                MVN #`top_line,#$AF
            setas
                DEC REM_LINES
                LDA #1
                BRA MOD_TOP_LINE
DRAW_DATA
                SEC
                LDA LINE_NUM_HEX
                SBC #9

MOD_TOP_LINE
                STA TAB_COUNTER
TRIPLET
                LDA #0
                PHA
                PLB
                
                ; compute the address of the line
                LDA #LINE_BYTES
                STA @lUNSIGNED_MULT_A
                STZ UNSIGNED_MULT_A + 1
                STZ UNSIGNED_MULT_B + 1
                LDA TAB_COUNTER
                DEC A ; use zero based offset
                STA @lUNSIGNED_MULT_B
                
                
            setal
                LDA @lUNSIGNED_MULT_RESULT
                STA LINE_ADDR
            setas
                LDA TAB_COUNTER
                AND #3
                BEQ draw_tick_line
                
            setal
                LDA #127
                LDX #<>untick_line
                MVN #`untick_line,#$AF
            setas
                JSR DRAW_LINE_DATA
                DEC REM_LINES
                JMP next_line
                
draw_tick_line
            setal
                LDA #127
                LDX #<>tick_line
                MVN #`tick_line,#$AF
            setas
                JSR DRAW_LINE_DATA
                DEC REM_LINES
                
next_line 
                INC TAB_COUNTER
                LDA TAB_COUNTER
                CMP #65
                BEQ DRAW_BOTTOM_BAR
                LDA REM_LINES
                BNE TRIPLET
                BEQ DRAW_LINE_DONE
                
DRAW_BOTTOM_BAR
            setal
                LDA #127
                LDX #<>btm_line
                MVN #`btm_line,#$AF
            setas
                LDA REM_LINES
                BEQ DRAW_LINE_DONE
                
BLANKS_BTM_LOOP
            setal
                LDA #127
                LDX #<>blank_line
                MVN #`blank_line,#$AF
            setas
                DEC REM_LINES
                BNE BLANKS_BTM_LOOP
                
DRAW_LINE_DONE
                PLD
                PLB
                RTS
                
DISPLAY_FILENAME
                .as
                .xl
                LDY #0
                LDX #23*128 + 51
        DF_LOOP
                LDA [SDOS_FILE_REC_PTR],Y
                PHY
                TXY
                STA [SCREENBEGIN], Y
                INX
                PLY
                INY
                CPY #8
                BNE DF_NOT_DOT
                LDA #'.'
                PHY
                TXY
                STA [SCREENBEGIN], Y
                INX
                PLY
        DF_NOT_DOT
                CPY #11
                BNE DF_LOOP
                
                ; add the version
                TXY
                INY
                INY
                LDA #'v'
                STA [SCREENBEGIN], Y
                
                INY
                LDA @lTuneInfo.version
                BIT #2
                BNE DF_V2
                LDA #'1'
                BRA DF_DONE
        DF_V2
                LDA #'2'
    DF_DONE
                STA [SCREENBEGIN], Y
                RTS
                
; ****************************************************
; * Y contains the current draw location (after MVN).
; * TAB_COUNTER contains the line to draw.
; * PTRN_ADDR is the address of the pattern.
DRAW_LINE_DATA
                .as
                PHY
                PHX

                LDA #9 ; number of channels to populate
                STA RAD_CHANNEL
                
                ; compute the location to write to
                
                setal
                TYA ; copy Y into A
                SEC
                SBC #$A080
                TAX
                setas
                
                LDY LINE_ADDR
                INY ; skip the line number
    NEXT_CHANNEL
                ; clear the instrument number byte
                STZ RAD_TEMP
                ; display the note in the first column
                LDA [PTRN_ADDR],Y ; note/octave
                INX ; skip the first column
                INY
                CMP #0
                BNE DL_DRAW_NOTE
                ; the note contains 0
                INX
                INX
                BRA DL_SKIP_NOTE_DISPLAY

        DL_DRAW_NOTE
                JSR DISPLAY_NOTE_OCTAVE
        DL_SKIP_NOTE_DISPLAY
                ROL A ; put bit 7 into the carry
                BCC SKIP_MID_COL
                LDA #'1'
                PHY
                TXY
                STA [SCREENBEGIN], Y
                PLY
                LDA #$10
                STA RAD_TEMP
                
        SKIP_MID_COL
                INX ; skip the middle column
                LDA [PTRN_ADDR],Y ; instrument/effect
                INY
                
                JSR DISPLAY_VALUE_SKIP_LOW_NIBBLE_IF_ZERO
                CMP #0 ; if the effect byte is 0, don't display the next value
                BNE SHOW_EFFECT
                INX
                INX 
                BRA DL_SKIP_EFFECT
                
        SHOW_EFFECT
                ; display the effect parameter
                LDA [PTRN_ADDR],Y ;
                JSR DISPLAY_DEC_VALUE
        DL_SKIP_EFFECT
                INY
                INX ; skip the vertical bar
                DEC RAD_CHANNEL
                BNE NEXT_CHANNEL

                PLX
                PLY
                RTS
                
                
; ***********************************************************************
; Display the first nibble and only display the second nibble if non-zero
; If first nibble is zero and RAD_TEMP is also zero, don't display it.
; A contains the value to display
; X contains the screen location
; ***********************************************************************
DISPLAY_VALUE_SKIP_LOW_NIBBLE_IF_ZERO
                .as
                PHY
                PHA
                TXY
                LDX #0
                XBA
                LDA #0
                XBA
                
                AND #$F0 ; high-nibble
                BNE DV_DISPLAY_VALUE
                
                LDA RAD_TEMP
                BNE DV_DISPLAY_ZERO
                INY
                BRA DV_LOW_NIBBLE
                
        DV_DISPLAY_ZERO
                LDA #0
        DV_DISPLAY_VALUE
                LSR
                LSR
                LSR
                LSR
                
                TAX
                LDA HEX_MAP, X
                
                STA [SCREENBEGIN],Y
                INY
                
        DV_LOW_NIBBLE
                PLA
                AND #$F ; low-nibble - effect
                BEQ SKIP_VALUE
                
                TAX
                LDA HEX_MAP, X
                
                STA [SCREENBEGIN],Y
    SKIP_VALUE
                INY
                
                TYX
                PLY
                RTS
                
DISPLAY_VALUE
                .as
                PHY
                PHA
                TXY
                
                AND #$F0 ; high-nibble
                LSR
                LSR
                LSR
                LSR
                
                TAX
                LDA HEX_MAP, X
                
                STA [SCREENBEGIN],Y
                INY
                
                PLA
                AND #$F ; low-nibble
                TAX
                LDA HEX_MAP, X
                
                STA [SCREENBEGIN],Y
                INY
                
                TYX
                PLY
                RTS
                
; ***********************************************************************
; A contains the hex value to convert
; ***********************************************************************
DISPLAY_DEC_VALUE
                .as
                PHA
                
                AND #$7
                STA DEC_MEM
                
                PLA
                AND #$F8 ; count in BCD in factors of 8
                CLC
                LSR
                LSR
                LSR
                STA CONV_VAL
                 
                SED  ; switch to decimal mode
                BEQ ADD_DEC
                CLC
                LDA #0
        MULT_DEC
                ADC #$8
                DEC CONV_VAL
                BNE MULT_DEC
        ADD_DEC
                ADC DEC_MEM
                JSR DISPLAY_VALUE
                CLD
                RTS
; ***********************************************************************
; A contains the value to display: ignore bit 7, octave is bit 6-4, note is bits 3-0
; X contains the screen location
; ***********************************************************************
DISPLAY_NOTE_OCTAVE
                .as
                PHY
                PHA
                PHA
                
                TXY
                setal
                AND #$F ; low-nibble - C#=1, D=2, ... C=12, 0 is no note and $F is Key Off
                TAX
                setas
                LDA @lnote_array, X 
                STA [SCREENBEGIN], Y
                INY
                
                PLA
                AND #$70 ; high-nibble
                LSR
                LSR
                LSR
                LSR
                CLC
                ADC #$30
                STA [SCREENBEGIN], Y
                INY
                
                TYX
                PLA
                PLY
                RTS
                
; ***********************************************************************
; * Draw one line with reverse background
; ***********************************************************************
REVERSE_LUT     ; write 2 to reverse the characters
                .as
                PHB
                LDA #`CS_COLOR_MEM_PTR
                PHA
                PLB
                .databank `CS_COLOR_MEM_PTR
                LDA #9
                STA TAB_COUNTER

                
REVERSE_LUT_TABS
                LDA #$42 ; purple background and white foreground
                STA CS_COLOR_MEM_PTR, Y
                INY
                STA CS_COLOR_MEM_PTR, Y
                INY
                STA CS_COLOR_MEM_PTR, Y
                INY
                
                LDA #$52 ; purple background and yellow foreground
                STA CS_COLOR_MEM_PTR, Y
                INY
                STA CS_COLOR_MEM_PTR, Y
                INY
                
                LDA #$42 ; purple background and white foreground
                STA CS_COLOR_MEM_PTR, Y
                INY
                STA CS_COLOR_MEM_PTR, Y
                INY
                STA CS_COLOR_MEM_PTR, Y
                INY
                
                INY ; skip separator
                DEC TAB_COUNTER
                BNE REVERSE_LUT_TABS
                
                .databank 0
                PLB
                RTS
                
; ***********************************************************************
; * Display Beats per minute
; ***********************************************************************
INSTR_HL_SCR     = 128 * 5 + 6
INSTR_NUM_HL_SCR = 128 * 6 + 4
ORDER_HL_SCR     = 128 * 5 + 53
PTTRN_HL_SCR     = 128 * 26 + 1

DISPLAY_SPEED
                .as
                PHY
                LDA @lTuneInfo.InitialSpeed
                LDY #23*128 + 40
                JSR WRITE_HEX
                LDA @lTuneInfo.hasSlowTimer
                BEQ DS_DONE
                LDA #'*'
                LDY #23*128 + 39
                STA [SCREENBEGIN], Y
        DS_DONE
                PLY
                RTS
                
DISPLAY_BPM
                .as
                RTS
                
; ***********************************************************************
; * Display Highlight - 0: instrument, 1: order: 2: pattern
; ***********************************************************************
HL_CLR_TABLE
                .byte $40, $20, $20, $10
                .byte $20, $40, $20, $30
                .byte $20, $20, $40, $20
HIGHLIGHT_MODE 
                .as
                LDA #0
                XBA
                ; Read the mode and highlight the proper section
                LDA STATE_MACHINE
                AND #$30
                LSR
                LSR
                PHA
                PHA
                TAX
                LDA HL_CLR_TABLE,X
                LDX #10
                LDY #$2000 + INSTR_HL_SCR
    INSTR_HIGHLIGHT_LOOP
                STA [SCREENBEGIN], Y
                INY
                DEX
                BNE INSTR_HIGHLIGHT_LOOP
                ; Highlight the '1' INSTR
                LDY #$2000 + INSTR_NUM_HL_SCR
                STA [SCREENBEGIN], Y 
                
                PLA
                TAX
                LDA HL_CLR_TABLE+1,X
                LDX #5
                LDY #$2000 + ORDER_HL_SCR
    ORDER_HIGHLIGHT_LOOP
                STA [SCREENBEGIN], Y
                INY
                DEX
                BNE ORDER_HIGHLIGHT_LOOP
                
                
                ; Highlight the '-' in the PATTERN header
                PLA
                TAX
                LDA HL_CLR_TABLE+2,X
                LDX #9
                LDY #$2000 + PTTRN_HL_SCR
    HL_PATTERN_LOOP
                
                STA [SCREENBEGIN], Y
                INY 
                INY 
                INY 
                INY 
                INY
                STA [SCREENBEGIN], Y
                INY 
                INY 
                INY 
                INY
                DEX 
                BNE HL_PATTERN_LOOP
                
                JSR DISPLAY_ACTIVE_CHANNELS
                RTS
                
; ***********************************************************************
; * Display Orders for each pattern in the song length
; ***********************************************************************
DISPLAY_ORDERS
                .as
                
                LDA @lTuneInfo.songLength 
                BEQ DO_DONE
                CMP #14
                BCC DO_DISPLAY_ORDERS
                LDA #14 ; only display up to 14 orders
                
        DO_DISPLAY_ORDERS
                STA TAB_COUNTER
                LDX #0
                LDY #128 * 7 + 53
                
                setal
                LDA #<>ORDERS
                STA RAD_ADDR
                LDA #<`ORDERS
                STA RAD_ADDR + 2
                setas
                
        NEXT_ORDER
                TXA
                JSR WRITE_HEX
                INY
                INY
                INY
                
                PHY
                TXY
                LDA [RAD_ADDR],Y
                INC A 
                PLY
                
                JSR WRITE_HEX
                INX
                setal
                TYA
                CLC
                ADC #128 - 3
                TAY
                setas
                DEC TAB_COUNTER
                BNE NEXT_ORDER
        DO_DONE
                RTS
                
; ************************************************************************
; Read the values in CHANNELS and highlight (white font) when active
; ************************************************************************
DISPLAY_ACTIVE_CHANNELS
                LDX #9
                LDY #$2000 + 128 * 26 + 75
        DAC_LOOP
                LDA CHANNELS-1,X
                BEQ INACTIVE_CHANNEL
                LDA #$40 ; white
                STA [SCREENBEGIN], Y
                BRA DAC_CONTINUE
                
        INACTIVE_CHANNEL
                LDA #$20 ; purple
                STA [SCREENBEGIN], Y
        DAC_CONTINUE
                DEY
                DEY
                DEY
                DEY
                DEY
                DEY
                DEY
                DEY
                DEY
                
                DEX 
                BNE DAC_LOOP
                RTS
                
; ************************************************************************
; * Accumulator contains the character to display.
; * Address CURSORX contains the position to write to.
; ************************************************************************
DISPLAY_CHAR
                .as
                .xs
                PHY
                LDY CURSORX
                STA [SCREENBEGIN],Y
                INY
                STY CURSORX
                PLY
                RTL

DISPLAY_NEXT_LINE
                .as
                .xl
                setal
                LDA CURSORX
                AND #$FF80   ; lines are $0, $80, etc
                CLC
                ADC #128+31     ; move to the next line and offset to the file box
                STA CURSORX
                setas
                RTL
                
; ****************************************************
; * X contains the address of the message in the bank
; ****************************************************
DISPLAY_MSG
                .as
                .xl
                PHB
                .setdbr `<sd_card_tester
    MSG_LOOP
                LDA $0,b,x      ; read from the string
                BEQ MSG_DONE
                JSL DISPLAY_CHAR
                INX
                BRA MSG_LOOP
    MSG_DONE    JSL DISPLAY_NEXT_LINE
                
                PLB
                
                RTL
                
; ****************************************************
; * Display data stored in "current_fat_record".
; ****************************************************
DISPLAY_FAT_RECORD
                .as
                .xl
                PHY
                LDY #11 ; record type
                LDA [SDOS_FILE_REC_PTR],Y
                CMP #$10 ; directory
                BNE DISPLAY_FILE
                
                LDA #$E0   ; directory char
                JSL DISPLAY_CHAR
                LDY #0
        DIR_LOOP
                LDA [SDOS_FILE_REC_PTR],Y
                JSL DISPLAY_CHAR
                INY
                CPY #8
                BNE DIR_LOOP
                
        DIR_BLANK_LOOP
                LDA #$20
                JSL DISPLAY_CHAR
                INY
                CPY #17
                BNE DIR_BLANK_LOOP
                
                BRA DISPLAY_FR_DONE
                
    DISPLAY_FILE
                LDA #$20   ; space char
                JSL DISPLAY_CHAR
                LDY #0
        FILENAME_LOOP
                LDA [SDOS_FILE_REC_PTR],Y
                JSL DISPLAY_CHAR
                INY
                CPY #8
                BNE FILENAME_LOOP
                LDA #'.'
                JSL DISPLAY_CHAR
        EXT_LOOP
                LDA [SDOS_FILE_REC_PTR],Y
                JSL DISPLAY_CHAR
                INY
                CPY #11
                BNE EXT_LOOP
                
        FL_BLANK_LOOP
                LDA #$20
                JSL DISPLAY_CHAR
                INY
                CPY #16
                BNE FL_BLANK_LOOP
                
    DISPLAY_FR_DONE
                PLY
                RTL
                
; ***********************************************************
; * Highlight the current item - i.e. reverse the background
; * Accumulator A contains the color to display.
; ***********************************************************
TEXT_COLOUR_SELECTED
                .as
                PHA
                setaxl
                LDA #<>CS_COLOR_MEM_PTR     ; store the initial colour buffer location
                STA CURSORPOS
                
                LDA SDOS_LINE_SELECT
                STA UNSIGNED_MULT_A
                LDA #128
                STA UNSIGNED_MULT_B
                LDA UNSIGNED_MULT_RESULT
                CLC
                ADC #128 * 11 + 31
                TAY
                setas
            
                LDA #`CS_TEXT_MEM_PTR
                STA CURSORPOS+2
                
                LDX #18
                PLA
        HS_LOOP
                STA [CURSORPOS],Y
                INY
                DEX
                BNE HS_LOOP
                
                RTL
                
; ***********************************************************
; * Move down in the file selector
; ***********************************************************
SELECT_NEXT_FILE
                .as
                CLC
                LDA SDOS_LINE_SELECT
                INC A
                CMP #38
                BCS DO_NOT_SELECT
                
                LDA #$50 ; black background
                JSL TEXT_COLOUR_SELECTED
                
                INC SDOS_LINE_SELECT
                
                LDA #5 ; yellow background
                JSL TEXT_COLOUR_SELECTED
                
    DO_NOT_SELECT
                RTL
                
; ***********************************************************
; * Move up in the file selector
; ***********************************************************
SELECT_PREVIOUS_FILE
                .as
                CLC
                LDA SDOS_LINE_SELECT
                DEC A
                BMI DO_NOT_SELECT
                
                LDA #$50 ; black background
                JSL TEXT_COLOUR_SELECTED
                
                DEC SDOS_LINE_SELECT
                
                LDA #5 ; yellow background
                JSL TEXT_COLOUR_SELECTED

                RTL