LOAD_FILE
            .as
            .xs
            LDA #1
            STA LOAD_SCREEN
            
            JSL ISDOS_INIT
            
            setaxl
            LDA #<>CS_TEXT_MEM_PTR      ; store the initial screen buffer location
            STA SCREENBEGIN
            LDA #<>CS_COLOR_MEM_PTR     ; store the initial colour buffer location
            STA CURSORPOS
            setas
            
            LDA #`CS_TEXT_MEM_PTR
            STA SCREENBEGIN+2
            STA CURSORPOS+2
            
            ; copy a 20 x 40 portion of the screen into memory
            LDY #128 * 10 + 30
            LDA #40 ; lines to copy
            STA LINE_COPY
            LDX #128 * 11 + 32  ; initialize the cursor position for file display
            STX CURSORX
            
            LDX #0
            
            ; build the screen and load from SD Card
COPY_LINE   LDA #20 ; columns to copy
            STA CHAR_COPY
            
COPY_CHAR   LDA FILE_LOAD_SCREEN,X
            STA [SCREENBEGIN],Y
            LDA #$50
            STA [CURSORPOS],Y
            
            INY
            INX
            DEC CHAR_COPY
            BNE COPY_CHAR
            
            setal
            TYA
            CLC
            ADC #108 ; skip to next line
            TAY
            setas
            DEC LINE_COPY
            BNE COPY_LINE
            
            ; show files from the SDRAM
            JSL ISDOS_DIR
            
            setxs
            RTL
        
; ****************************************************************
; * EXIT the Load File Screen
; ****************************************************************
EXIT_FILE
            .as
            .xs
            LDA #0
            STA LOAD_SCREEN
            
            setxl
            
            JSR DRAW_DISPLAY
            JSR DISPLAY_PATTERN
            
            setxs
            
            RTL