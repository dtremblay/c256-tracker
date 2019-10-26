LOAD_FILE
            .as
            .xs
            LDA #1
            STA LOAD_SCREEN
            
            setaxl
            LDA #<>CS_TEXT_MEM_PTR      ; store the initial screen buffer location
            STA SCREENBEGIN
            LDA #<>CS_COLOR_MEM_PTR     ; store the initial colour buffer location
            STA CURSORPOS
            setas
            LDA #`CS_TEXT_MEM_PTR
            STA SCREENBEGIN+2 
            STA CURSORPOS+2
            
            ; copy a 20 x 30 portion of the screen into memory
            LDY #128 * 10 + 30
            LDA #40
            STA LINE_COPY
            LDX #0
            
COPY_LINE   LDA #20
            STA CHAR_COPY
            
COPY_CHAR   LDA [SCREENBEGIN],Y
            STA SCRN_COPY,X
            LDA [CURSORPOS],Y
            STA SCRN_COPY_CLR,X
            LDA #0
            STA [SCREENBEGIN],Y
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
            
            ; build the screen and load from SD Card
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
            
            setaxl
            LDA #<>CS_TEXT_MEM_PTR      ; store the initial screen buffer location
            STA SCREENBEGIN
            LDA #<>CS_COLOR_MEM_PTR     ; store the initial colour buffer location
            STA CURSORPOS
            setas
            LDA #`CS_TEXT_MEM_PTR
            STA SCREENBEGIN+2 
            STA CURSORPOS+2
            
            ; copy a 20 x 40 portion from memory to screen
            LDY #128 * 10 + 30
            LDA #40
            STA LINE_COPY
            LDX #0
            
XCOPY_LINE  LDA #20
            STA CHAR_COPY
            
XCOPY_CHAR  LDA SCRN_COPY,X
            STA [SCREENBEGIN],Y
            LDA SCRN_COPY_CLR,X
            STA [CURSORPOS],Y
            INY
            INX
            DEC CHAR_COPY
            BNE XCOPY_CHAR
            
            setal
            TYA
            CLC
            ADC #108 ; skip to next line
            TAY
            setas
            DEC LINE_COPY
            BNE XCOPY_LINE
            
            setxs
            
            RTL