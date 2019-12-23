LOAD_FILE_DISPLAY
            .as
            .xs
            LDA #2
            STA STATE_MACHINE
            
            ; initialize the search string
            LDA #'/'
            STA sd_card_dir_string
            LDA #'*'
            STA sd_card_dir_string+1
            LDA #'0'
            
            JSL ISDOS_INIT
            
    LOAD_DIRECTORY
            LDA #0
            STA SDOS_LINE_SELECT
            
            ; Set the pointer to the beginning of the struct array
            LDA #`SDCARD_LIST
            STA SDOS_FILE_REC_PTR+2
            STZ SDOS_FILE_REC_PTR+1
            STZ SDOS_FILE_REC_PTR
    
            JSR LOAD_SDCARD_DATA
            JSR SHOW_FILE_MENU
            JSR POPULATE_FILES
            
            RTL
            
; ****************************************************
; * Load SD card data at SDCARD_LIST
; ****************************************************
LOAD_SDCARD_DATA
            .as
            .xs
            ; clear 1K of RAM
            setxl
            LDA #0
            LDY #1024 ; each struct is 16 bytes long, so this allows to load a 64 entries directory
    CLEAR_FILE_AREA
            STA [SDOS_FILE_REC_PTR], Y
            DEY
            BNE CLEAR_FILE_AREA
            
            ; check if the SD card is present
            LDA SDCARD_PRSNT_MNT
            BEQ LOAD_SDCARD_DATA_DONE ; if SD not present, exit
            
            ; show files from the SDRAM
            JSL ISDOS_DIR
            
    LOAD_SDCARD_DATA_DONE
            
            RTS
; ****************************************************
; * Display the file menu box
; ****************************************************
SHOW_FILE_MENU
            .as
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
            
            ; build the screen
COPY_LINE   LDA #20 ; columns to copy
            STA CHAR_COPY
            
COPY_CHAR   LDA FILE_LOAD_SCREEN,X
            STA [SCREENBEGIN],Y
            LDA #$50 ; yellow
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
            
            setxs
            RTS
            
; ****************************************************************
; * Populate the file menu box with the files from SDCARD_LIST
; ****************************************************************
POPULATE_FILES
            .as
            .xs
            setxl
            ; reset the file pointer
            STZ SDOS_FILE_REC_PTR
            STZ SDOS_FILE_REC_PTR+1
            LDA #`SDCARD_LIST
            STA SDOS_FILE_REC_PTR+2
            
            LDX #0
            ; read the record type - if zero, then we're done
    PF_NEXT_FILE
            LDY #11
            LDA [SDOS_FILE_REC_PTR],Y
            BEQ PF_DONE
            
            JSL DISPLAY_FAT_RECORD
            JSL DISPLAY_NEXT_LINE  ; Print the character
            setal
            LDA SDOS_FILE_REC_PTR
            ADC #16
            STA SDOS_FILE_REC_PTR
            CMP #1024
            BCS PF_DONE
            INX 
            CPX #38
            BEQ PF_DONE
            
            setas
            BRA PF_NEXT_FILE
            
    PF_DONE
            setas
            ; Highlight the currently selected items
            LDA #5   ; Yellow Background
            JSL TEXT_COLOUR_SELECTED
            RTS
        
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
            .xl
            ; check if the selection is a directory or file
            LDA SDCARD_PRSNT_MNT
            BNE LF_CARDPRESENT
            BRL LF_DONE
            
      LF_CARDPRESENT
            LDA #0
            XBA
            LDA SDOS_LINE_SELECT
            setal
            ASL A  ; multiply the line # by 16
            ASL A
            ASL A
            ASL A
            STA SDOS_FILE_REC_PTR
            setas
            
            ; Append to the file path
            ; find the * 
            LDX #0
      LF_FIND_STAR
            INX ; the first character is always '/'
            LDA sd_card_dir_string,X
            CMP #'*'
            BNE LF_FIND_STAR

            STZ SDOS_LOOP
            LDY #0
      LF_COPY_DIR_NAME
            LDA [SDOS_FILE_REC_PTR],Y
            BEQ LF_NAME_DONE
            STA sd_card_dir_string,X
            INY
            INX
            LDA SDOS_LOOP
            INC A
            STA SDOS_LOOP
            CMP #8
            BEQ LF_NAME_DONE
            BRA LF_COPY_DIR_NAME
            
      LF_NAME_DONE
            LDY #8
            LDA [SDOS_FILE_REC_PTR],Y
            BEQ LF_DIR_DONE
            LDA #'.'
            STA sd_card_dir_string,X
      LF_COPY_EXT
            INX
            LDA [SDOS_FILE_REC_PTR],Y
            STA sd_card_dir_string,X
            INY
            CPY #11
            BNE LF_COPY_EXT
            
      LF_DIR_DONE
            LDY #11
            LDA [SDOS_FILE_REC_PTR],Y
            CMP #$20
            BEQ LF_LOAD_FILE
      
            
            ; copy the dir name to sd_card_dir_string
            ; add slash star
            LDA #'/'
            STA sd_card_dir_string,X
            INX
            LDA #'*'
            STA sd_card_dir_string,X
            INX
            LDA #0
            STA sd_card_dir_string,X
            
            JML LOAD_DIRECTORY

    LF_LOAD_FILE
            LDA #0
            INX
            STA sd_card_dir_string,X
            
            ; copy the file size
            setal
            LDY #12
            LDA [SDOS_FILE_REC_PTR],Y
            STA SDOS_FILE_SIZE
            INY
            INY
            LDA [SDOS_FILE_REC_PTR],Y
            STA SDOS_FILE_SIZE+2
            
            ; Copy the data from SD card to this memory location
            LDA #<>RAD_FILE_TEMP
            STA SDCARD_FILE_PTR
            setas
            LDA #`RAD_FILE_TEMP
            STA SDCARD_FILE_PTR+2
            
            JSL ISDOS_READ_FILE
            ; Load the file pointed to by SDOS_LINE_SELECT
    
            ; JSL RAD_INIT_PLAYER
            ; Close the load file display
    LF_DONE
            setxs
            JSL EXIT_FILE
            
            ; Display the file name
            setxl
            LDX #0
            LDY #128 * 23 + 50
    LF_DISPLAY_FILE_NAME
            LDA @lSDOS_FILE_NAME,X
            INX
            INY
            STA [SCREENBEGIN], Y
            CMP #0
            BNE LF_DISPLAY_FILE_NAME
            
            LDA #0
    LF_BLANK
            INY
            INX
            STA [SCREENBEGIN], Y
            CPX #20
            BNE LF_BLANK
            
            RTL