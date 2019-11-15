LOAD_FILE_DISPLAY
            .as
            .xs
            LDA #2
            STA STATE_MACHINE
            
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
            LDX #128 * 11 + 31  ; initialize the cursor position for file display
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
            
            LDA SDCARD_PRSNT_MNT
            BEQ LD_FILE_DONE ; if SD not present, exit
            
            ; show files from the SDRAM
            JSL ISDOS_DIR
            
    LD_FILE_DONE
            setxs
            RTL
        
; ****************************************************************
; * EXIT the Load File Screen
; ****************************************************************
EXIT_FILE
            .as
            .xs
            LDA #0
            STA STATE_MACHINE
            
            setxl
            JSR DRAW_DISPLAY
            JSR LOAD_INSTRUMENT
            JSR DISPLAY_PATTERN
            JSR DISPLAY_ORDERS
            setxs
            
            RTL
            
LOAD_FILE
            .as
            .xs
            ; check if the selection is a directory or file
            
            ; Load the file pointed to by SDOS_LINE_SELECT
            
            ; Close the load file display
            JSL EXIT_FILE
            
            RTL