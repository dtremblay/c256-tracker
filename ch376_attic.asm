CH376_READ_FILE
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

            ; Load the file pointed to by SDOS_LINE_SELECT            
            JSL ISDOS_READ_FILE

            ; clear pattern memory
            LDA #0
            LDX #0
    LF_CLEAR_MEM
            STA @lPATTERNS,X
            INX
            BNE LF_CLEAR_MEM
                        
            ; load the song
            JSL RAD_INIT_PLAYER
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