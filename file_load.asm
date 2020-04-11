LOAD_FILE_DISPLAY
            .as
            .xs
            setxl
            LDA #2
            STA STATE_MACHINE
            
            ; initialize the SD Card
            JSL ISDOS_INIT
            
    LOAD_DIRECTORY
            ; no file selected
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
            setxs
            RTL
            
; ****************************************************
; * Load SD card data at SDCARD_LIST
; ****************************************************
LOAD_SDCARD_DATA
            .as
            .xl
            ; clear 1K of RAM
            LDA #0
            LDY #1024 ; each struct is 18 bytes long, so this allows to load a 64 entries directory
    CLEAR_FILE_AREA
            STA [SDOS_FILE_REC_PTR], Y
            DEY
            BNE CLEAR_FILE_AREA
            
            ; check if the SD card is present
            LDA SDCARD_PRSNT_MNT
            BEQ LOAD_SDCARD_DATA_DONE ; if SD not present, exit
            
            ; show files from the SDRAM
            JSL ISDOS_READ_MBR_BOOT
            ; read the root directory
            JSL ISDOS_PARSE_ROOT_DIR
            
            setal
            LDA #FAT_DATA
            STA SD_DATA
            LDA #0
            STA SD_DATA + 2
            STA SD_DATA_FAT_PAGE
            JSL ISDOS_READ_FAT_SECTOR
            setas
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
            
            RTS
            
; ****************************************************************
; * Populate the file menu box with the files from SDCARD_LIST
; ****************************************************************
POPULATE_FILES
            .as
            .xl
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
            ADC #18
            STA SDOS_FILE_REC_PTR
            CMP #1152
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
        
READ_FILE
            .as
            .xl
            LDA #0
            XBA
            LDA SDOS_LINE_SELECT
            setaxl
            STA UNSIGNED_MULT_A
            ; multiply by 18
            LDA #18
            STA UNSIGNED_MULT_B
            LDA UNSIGNED_MULT_RESULT
            STA SDOS_FILE_REC_PTR
            
            ; prepare the file pointer
            LDA #<>RAD_FILE_TEMP
            STA SD_DATA
            LDA #`RAD_FILE_TEMP
            STA SD_DATA + 2
            
            ; get the cluster number
            LDY #16
            LDA [SDOS_FILE_REC_PTR],Y
            JSL ISDOS_READ_FILE
            
            setas
            
            JSL OPL2_INIT
            
            ; load the song
            JSL RAD_INIT_PLAYER
            ; close the file loading menu
            JSL EXIT_FILE
            RTL
; ****************************************************************
; * EXIT the Load File Screen
; ****************************************************************
EXIT_FILE
            .as
            .xl
            JSR RESET_STATE_MACHINE
            JSR DRAW_DISPLAY
            JSR DISPLAY_FILENAME
            ;JSR LOAD_INSTRUMENT
            JSR DISPLAY_PATTERN
            JSR DISPLAY_ORDERS
            JSR DISPLAY_SPEED
            
            RTL
