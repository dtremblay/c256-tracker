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
                
                LDA #$40 ; white
                LDY #$2000 + INSTR_EDITOR_SCR
                STA [SCREENBEGIN], Y 

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
; * Display a pattern line
; * 
; * LINE_NUM_DEC contains the decimal line number.
; * LINE_NUM_HEX contains the hex line number.
; * We are defaulting to 32 lines of pattern to display.
; * If line number is < 10, display blanks
; * A simple header is displayed above line 1.
; * lines are grouped by 4, every fourth line is a tick line.
DISPLAY_LINE
                .as
                PHB
                
                LDA LINE_NUM_DEC
                ; display the line number at the 'Line:' field
                LDY #23*128 + 7
                JSR WRITE_HEX
                
                LDA #32
                STA REM_LINES
                
                LDY #<>CS_TEXT_MEM_PTR + 128 * 28 ; top of the pattern display
                LDA LINE_NUM_HEX
                CMP #10
                BCS DRAW_DATA ; if line# is greater than 10, skip blank lines and topline
                BEQ BLANKS_LOOP
                
DRAW_BLANK_LINES
                
                SEC
                LDA #9
                SBC LINE_NUM_HEX
                
                STA TAB_COUNTER
                BEQ DRAW_TOP_LINE
                
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
                
DRAW_DATA
                SEC
                LDA LINE_NUM_HEX
                SBC #9
                BPL MOD_TOP_LINE
TOP_LINE_1
                LDA #0
                STA BLNK_BTM
                LDA #1
MOD_TOP_LINE
                BEQ TOP_LINE_1
                STA TAB_COUNTER
TRIPLET
                LDA TAB_COUNTER
                AND #3
                BEQ draw_tick_line
                
                setal
                LDA #127
                LDX #<>untick_line
                MVN #`untick_line,#$AF
                setas
                DEC REM_LINES
                JMP next_line
                
draw_tick_line
                setal
                LDA #127
                LDX #<>tick_line
                MVN #`tick_line,#$AF
                setas
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
                
                ; compute the start of line address
DRAW_LINE_DONE
                LDA #37
                STA M0_OPERAND_A
                STZ M0_OPERAND_A + 1
                STZ M0_OPERAND_B + 1
                LDA LINE_NUM_HEX
                STA M0_OPERAND_B
                LDX M0_RESULT
                INX
                
                ; now draw the pattern screen
                LDA #`PATTERNS
                PHA
                PLB
                .databank `PATTERNS
                
                LDA PATTERNS,X ; line number
                INX
                LDY #38*128
                JSR DRAW_CHANNEL
                
                LDA #0
                PHA
                PLB
                
                .databank 0
                PLB
                setas
                RTS
                
; ***********************************************************************
; A contains the value to display
; Y contains the screen location
DRAW_CHANNEL
                .as
                CLC
                ADC #$30
                STA [SCREENBEGIN], Y
                
                RTS
                
REVERSE_LUT     ; write 2 to reverse the characters
                .as
                LDA #`CS_COLOR_MEM_PTR
                PHA
                PLB
                .databank `CS_COLOR_MEM_PTR
                LDA #9
                STA TAB_COUNTER

                LDA #2
REVERSE_LUT_TABS
                LDX #8
REVERSE_LUT_LOOP
                STA CS_COLOR_MEM_PTR, Y
                INY
                DEX
                BNE REVERSE_LUT_LOOP
                
                INY
                DEC TAB_COUNTER
                BNE REVERSE_LUT_TABS
                
                .databank 0
                RTS
                
DISPLAY_PATTERN
                .as
                LDA PATTERN_NUM
                ; display the pattern number
                LDY #23*128 + 19
                JSR WRITE_HEX
                RTS
                
; ***********************************************************************
; * Display Beats per minute
; ***********************************************************************
DISPLAY_BPM
                .as
                LDA BPM
                LDY #23*128 + 40
                JSR WRITE_HEX
                RTS