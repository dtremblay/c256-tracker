;******************************************************************************
; SD Card OS
; SDOS.asm
;******************************************************************************
.include "SDCard_Controller_def.asm"
.include "GABE_Control_Registers_def.asm"
.include "ch376s_inc.asm"

; File System Offsets
SD_FIRST_SECTOR         = $5F00 ; 4 bytes
SD_FAT_OFFSET           = $5F04 ; 4 bytes
SD_ROOT_OFFSET          = $5F08 ; 4 bytes
SD_DATA_OFFSET          = $5F0C ; 4 bytes

SD_RESERVED_SECTORS     = $5F10 ; 2 bytes
SD_SECTORS_PER_FAT      = $5F12 ; 2 bytes
SD_BYTES_PER_SECTOR     = $5F14 ; 2 bytes
SD_FAT_COUNT            = $5F16 ; 2 bytes
SD_SECTORS              = $5F18 ; 4 bytes
SD_ROOT_ENTRIES         = $5F1C ; 2 bytes
SD_DIR_OFFSET           = $5F20 ; 2 bytes - use this to read the root directory
SD_NEXT_CLUSTER         = $5F22 ; 2 bytes - use this to point to the next file cluster in the FAT
SD_SECTORS_PER_CLUSTER  = $5F24 ; 1 byte
SD_FAT16                = $5F25 ; 1 byte - write 1 for FAT16, 0 for FAT12
CLUSTER_PTR             = $5F26 ; 2 bytes
LOG_CLUSTER_PTR         = $5F28 ; 4 bytes
SD_DATA                 = $0080 ; 3 bytes - used indirect addressing

FAT_DATA                = $6600 ; 512 bytes

simplefilestruct .struct
      name          .fill 8
      extension     .fill 3
      type          .byte 0
      size_l        .word 0
      size_h        .word 0
  .ends
                
fatrec  .struct
      name          .fill 8
      extension     .fill 3
      type          .byte 0
      user_attr     .byte 0
      deleted_char  .byte 0 ; this is only populated when byte 1 is $E5 - deleted_char
      create_time   .word 0
      create_date   .word 0
      access_date   .word 0
      access_rights .word 0
      mod_time      .word 0
      mod_date      .word 0
      cluster       .word 0
      size_l        .word 0
      size_h        .word 0
  .ends
                
TURN_ON_SD_LED  .macro
                ; turn on the LED
                LDA GABE_MSTR_CTRL
                AND #~GABE_CTRL_SDC_LED
                ORA #GABE_CTRL_SDC_LED
                STA GABE_MSTR_CTRL
                .endm
                
TURN_OFF_SD_LED .macro
                ; turn off the LED
                LDA GABE_MSTR_CTRL
                AND #~GABE_CTRL_SDC_LED
                STA GABE_MSTR_CTRL
                .endm

;******************************************************************************
; ISDOS_INIT
; Init the SDCARD
; Inputs:
;  None
; Affects:
;   None
;******************************************************************************
ISDOS_INIT
                .as
                TURN_ON_SD_LED
                
                setal
                LDA #0
                STA SD_ROOT_OFFSET
                STA SD_NEXT_CLUSTER
                setas
                
                ; SD Card is not present
                STA SDCARD_PRSNT_MNT 
                
                ; initialize the SD Card reader
                LDA #SDC_TRANS_INIT_SD
                STA SDC_TRANS_TYPE_REG
                
                LDA #SDC_TRANS_START
                STA SDC_TRANS_CONTROL_REG
              
    SD_WAIT     LDA SDC_TRANS_STATUS_REG
                AND #SDC_TRANS_BUSY
                CMP #SDC_TRANS_BUSY
                BEQ SD_WAIT
                
                ; check for errors
                LDA SDC_TRANS_ERROR_REG
                BEQ SD_INIT_SUCCESS
                ERROR_MSG sd_no_card_msg, SD_INIT_DONE
                
    SD_INIT_SUCCESS
                ; SD Card is present
                LDA #1
                STA SDCARD_PRSNT_MNT 
                
                BRA SD_INIT_DONE
              
    SD_INIT_DONE
                TURN_OFF_SD_LED
                RTL

;******************************************************************************
; ISDOS_READ_MASTERBOOTRECORD
; Read the Master Boot Record - offset 0
; Inputs:
;  None
; Affects:
;   None
;******************************************************************************
SD_BLK_BEGIN = $6000
ISDOS_READ_MBR_BOOT
                LDA SDCARD_PRSNT_MNT ; this must be non-zero
                BNE RMBR_CARD_PRESENT
                ERROR_MSG sd_cant_read_mbr_msg, RMBR_DONE

    RMBR_CARD_PRESENT
        ; read sector 0 - the Master Boot Record
                setal
                ; where is the data going to be written to
                LDA #SD_BLK_BEGIN
                STA SD_DATA
                
                ; initialize registers to load MBR
                LDA #0
                STA SDC_SD_ADDR_7_0_REG
                STA SDC_SD_ADDR_23_16_REG
                setas
                JSL ISDOS_READ_BLOCK

                ; check for errors
                LDA SDC_TRANS_ERROR_REG
                BEQ SD_CONTINUE_1
                ERROR_MSG sd_cant_read_mbr_msg, RMBR_DONE
                
    SD_CONTINUE_1
                ; Read the MBR signature - it should be 55 AA
                setal
                LDA SD_BLK_BEGIN + 510
                CMP #$AA55
                BEQ VALID_SIG
                ERROR_MSG INVALID_SIG_MSG, RMBR_DONE
    VALID_SIG
                setal
                LDX #446 ; offset to first partition
                LDA SD_BLK_BEGIN,X + 8
                STA SD_FIRST_SECTOR
                LDA SD_BLK_BEGIN,X + 10
                STA SD_FIRST_SECTOR+2
                
        ; read the FAT Boot Sector - this overwrites the MBR record
                LDA SD_FIRST_SECTOR
                ASL A
                STA SDC_SD_ADDR_15_8_REG
                setas
                LDA SD_FIRST_SECTOR+2
                STA SDC_SD_ADDR_31_24_REG
                LDA #0
                STA SDC_SD_ADDR_7_0_REG
                JSL ISDOS_READ_BLOCK
                
                ; check for errors
                LDA SDC_TRANS_ERROR_REG
                BEQ SD_CONTINUE_2
                ERROR_MSG SD_FIRST_SECTOR_MSG, RMBR_DONE
                
    SD_CONTINUE_2
                setal
                LDX #0
                ; bytes per sector
                LDA SD_BLK_BEGIN,X + $B
                STA SD_BYTES_PER_SECTOR
                
                setas
                ; logical sectors per cluster
                LDA SD_BLK_BEGIN,X + $D
                STA SD_SECTORS_PER_CLUSTER
                
                setal
                ; number of fat tables
                LDA SD_BLK_BEGIN,X + $10
                AND #$FF
                STA SD_FAT_COUNT
                
                ; number of root entries
                LDA SD_BLK_BEGIN,X + $11
                STA SD_ROOT_ENTRIES

                ; how many sectors do we have - small <= 65535
                LDA SD_BLK_BEGIN,X + $13
                BEQ SD_LARGE_SECTORS
                STA SD_SECTORS
                LDA #0
                STA SD_SECTORS + 2
                
                ; check if this is a FAT12
                LDA SD_SECTORS
                STA D0_OPERAND_B
                LDA SD_SECTORS_PER_CLUSTER
                AND #$FF
                STA D0_OPERAND_A
                LDA D0_RESULT
                CMP #$FF7
                BCS SD_SMALL_SECTORS ; number of sectors is more than fat12 can handle
                setas
                LDA #0
                STA SD_FAT16
                setal

                BRA SD_FAT12
    SD_LARGE_SECTORS
                ; large sectors > 65535
                LDA SD_BLK_BEGIN,X + $20
                STA SD_SECTORS
                LDA SD_BLK_BEGIN,X + $22
                STA SD_SECTORS + 2
    SD_SMALL_SECTORS
                setas
                LDA #1
                STA SD_FAT16
                setal
    SD_FAT12
                LDA SD_BLK_BEGIN,X + $E
                STA SD_RESERVED_SECTORS
                LDA SD_BLK_BEGIN,X + $16
                STA SD_SECTORS_PER_FAT
                
                JSR COMPUTE_FAT_ROOT_DATA_OFFSETS
    RMBR_DONE
                RTL

;******************************************************************************
;* Read a block of data
;* Addresses at SDC_SD_ADDR_7_0_REG to SDC_SD_ADDR_31_24_REG need to be set.
;******************************************************************************
ISDOS_READ_BLOCK
                PHY
                .as
                TURN_ON_SD_LED
                ; check if the SD Card is present
                LDA SDCARD_PRSNT_MNT
                BNE SR_CARD_PRESENT
                ERROR_MSG sd_no_card_msg, SR_DONE

    SR_CARD_PRESENT
                LDA #SDC_TRANS_READ_BLK
                STA SDC_TRANS_TYPE_REG

                LDA #SDC_TRANS_START
                STA SDC_TRANS_CONTROL_REG
                
    SR_WAIT     LDA SDC_TRANS_STATUS_REG
                AND #SDC_TRANS_BUSY
                CMP #SDC_TRANS_BUSY
                BEQ SR_WAIT
                
                ; check for errors
                LDA SDC_TRANS_ERROR_REG
                BEQ SD_READ_BLOCK_OK
                ERROR_MSG SD_FIRST_SECTOR_MSG, SR_DONE
                
                ; SDC_RX_FIFO_DATA_CNT_HI and SDC_RX_FIFO_DATA_CNT_LO may contain how many bytes were read
    SD_READ_BLOCK_OK
                LDY #0
    SR_READ_LOOP
                LDA SDC_RX_FIFO_DATA_REG
                STA [SD_DATA],Y
                INY
                CPY #512
                BNE SR_READ_LOOP
                BRA SR_DONE
                
    SD_READ_BLOCK_FAILED
                LDA #`sd_read_failure
                PHA
                PLB
                LDX #<>sd_read_failure
                
    SR_DONE
                ; discard all other bytes
                LDA #1
                STA SDC_RX_FIFO_CTRL_REG
                
                TURN_OFF_SD_LED
                PLY
                RTL
                
; *****************************************************************************
; Accumulator must contain filetype
; SD_DATA is the location of the last read sector, which must contain dir info.
; *****************************************************************************
DISPLAY_FAT_NAME
                PHA ; - store the value of filetype
                LDY #0
        _RD_VOLNAME_LOOP
                LDA [SD_DATA],Y
                JSL PUTC
                INY
                CPY #8
                BEQ _RD_DOT
                CPY #11
                BNE _RD_VOLNAME_LOOP
                BRA _DFAT_NAME_DONE
                
        _RD_DOT
                PLA ; - read the value of filetype
                PHA ; - store the value of filetype
                BIT #$18
                BNE _RD_VOLNAME_LOOP
                LDA #"."
                JSL PUTC
                BRA _RD_VOLNAME_LOOP
                
        _DFAT_NAME_DONE
                PLA ; - read the value of filetype
                BIT #$18
                BNE RD_DFAT_DONE
                
                ; Get Cluster Position
                LDA #`sd_cluster_str
                PHB
                PHA
                PLB
                LDX #<>sd_cluster_str
                JSL PUTS
                PLB
                
                LDY #fatrec.cluster + 1
                LDA [SD_DATA],Y
                JSL PRINTAH
                LDY #fatrec.cluster
                LDA [SD_DATA],Y
                JSL PRINTAH
                
                ; Get Cluster Position
                LDA #`sd_filesize_str
                PHB
                PHA
                PLB
                LDX #<>sd_filesize_str
                JSL PUTS
                PLB
                
                LDY #fatrec.size_h + 1
        RD_SIZE_LOOP
                LDA [SD_DATA],Y
                JSL PRINTAH
                DEY
                CPY #$1B
                BNE RD_SIZE_LOOP
                
        RD_DFAT_DONE
                ; add CR
                LDA #$D
                JSL PUTC
                RTS
                

;******************************************************************************
;* Read the directory from the Data section
;******************************************************************************
ISDOS_READ_ROOT_DIR
                .as
                .xl
                setal
                LDA #0  ; reset the root entries offset
                STA SD_DIR_OFFSET
                
                LDA #$6200
                STA SD_DATA
                
                ; read the root sector
    NEXT_SECTOR
                LDA SD_ROOT_OFFSET
                CLC
                ADC SD_DIR_OFFSET
                ASL A ; this may cause a carry
                PHP
                STA SDC_SD_ADDR_15_8_REG
                
                LDA SD_ROOT_OFFSET+2
                ASL A
                PLP
                setas
                BCC RT_NO_CARRY
                INC A
        RT_NO_CARRY
                STA SDC_SD_ADDR_31_24_REG
                LDA #0
                STA SDC_SD_ADDR_7_0_REG
                JSL ISDOS_READ_BLOCK
                ; check for errors
                LDA SDC_TRANS_ERROR_REG
                BEQ RD_DIR_ENTRY
                ERROR_MSG SD_ROOT_ERROR_MSG, RD_DONE
                
                
    RD_DIR_ENTRY
                
                LDA [SD_DATA]
                BNE RD_CONTINUE ; if first byte is 0, entry is available and there are no following entries
                JML RD_DONE
                
    RD_CONTINUE
                CMP #$E5
                BEQ RD_SKIP
    RD_LOOP
                ; check the file type
                LDY #fatrec.type
                LDA [SD_DATA],Y
                
                CMP #$F ; long file name
                BNE RD_NOT_VFAT
                JML RD_READ_LONG_FILENAME
                
        RD_NOT_VFAT
                BIT #2 ; hidden
                BEQ RD_NOT_HIDDEN
                BRA RD_SKIP
                
        RD_NOT_HIDDEN
                BIT #8 ; volume name
                BEQ RD_NOT_VOLUME
                JML RD_READ_VOLNAME
                
        RD_NOT_VOLUME
                BIT #$10 ; directory
                BEQ RD_NOT_DIRECTORY
                JML RD_DIRNAME
                
        RD_NOT_DIRECTORY
                ; display "Filename: "
                PHA ; - store the value of filetype
                LDA #`sd_filename
                PHB
                PHA
                PLB
                LDX #<>sd_filename
                JSL PUTS
                PLB
                PLA
                JSR DISPLAY_FAT_NAME
                
    RD_SKIP
                setal
                LDA SD_DATA
                AND #$1E0
                CMP #$1E0
                BNE RD_SKIP_NEXT
                
                LDA #$6200
                STA SD_DATA
                
                ; ensure we don't go over the maximum number of sectors in the ROOT section
                LDA SD_DIR_OFFSET
                INC A
                CMP SD_ROOT_ENTRIES
                BCS RD_DONE
                
                STA SD_DIR_OFFSET ; next sector
                ; A must 16-bit now.
                JMP NEXT_SECTOR
                
                
        RD_SKIP_NEXT
                LDA SD_DATA
                CLC
                ADC #$20
                STA SD_DATA
                setas
                
                JML RD_DIR_ENTRY
                
    RD_DONE
                
                RTL
                
; ********************** JSR AREA *********************
    RD_DIRNAME
                ; display "Directory: "
                PHA ; - store the value of filetype
                LDA #`sd_dir_name
                PHB
                PHA
                PLB
                LDX #<>sd_dir_name
                JSL PUTS
                PLB
                PLA
                JSR DISPLAY_FAT_NAME
                JMP RD_SKIP
                
    RD_READ_VOLNAME
                ; display "Volume Name: "
                PHA ; - store the value of filetype
                LDA #`sd_volume_name
                PHB
                PHA
                PLB
                LDX #<>sd_volume_name
                JSL PUTS
                PLB
                PLA
                JSR DISPLAY_FAT_NAME
                JMP RD_SKIP
                
    RD_READ_LONG_FILENAME
                ; display "VFAT Name: "
                ; LDA #`sd_vfat_name
                ; PHB
                ; PHA
                ; PLB
                ; LDX #<>sd_vfat_name
                ; JSL PUTS
                ; PLB
                
                ; ; read the vfat name here
                ; ; ...
                ; ;
                ; ; add CR
                ; LDA #$D
                ; JSL PUTC
                JMP RD_SKIP

; ***************************************************************
; * Clear the current FAT record
; ***************************************************************
ISDOS_CLEAR_FAT_REC
              LDY #0
              LDA #0
    CLEAR_LOOP
              STA [SDOS_FILE_REC_PTR],Y
              INY
              CPY #32
              BNE CLEAR_LOOP
              RTS
              
;////////////////////////////////////////////////////////
; ISDOS_DIR
;   Upon the Call of this Routine Display the Files on the SDCARD
; Inputs:
;   Pointer to the ASCII File name by
; Located @ $000030..$000032 - SDCARD_FLNMPTR_L
; Affects:
;   None
ISDOS_DIR
              setas
              setxl
              ;** JSR ISDOS_MOUNT_CARD;     First to See if the Card is Present
              
              JSR ISDOS_CLEAR_FAT_REC
              
              STZ SDOS_LINE_SELECT

              ;JSR SDOS_FILE_OPEN     ; Now that the file name is set, go open File

              LDX #0 ; count the number of items displayed - limit to 38
    ISDOS_NEXT_ENTRY
              LDA #CH_CMD_RD_DATA0
              STA SDCARD_CMD
              ;** JSR DLYCMD_2_DTA;      ; Wait 1.5us
              LDA SDCARD_DATA        ;  Load Data Length - should be 32 - we don't care.
              
              ; populate the FAT records - only copy the filename, type and size
              LDY #0
    FAT_REC_LOOP
              ;** JSR DLYDTA_2_DTA       ; Wait 0.6us
              LDA SDCARD_DATA
              STA [SDOS_FILE_REC_PTR],Y
              INY
              CPY #32
              BNE FAT_REC_LOOP
              
              ; copy the filelength bytes from 28-31 to 12-15.
              setal
              LDY #28
              LDA [SDOS_FILE_REC_PTR],Y
              LDY #12
              STA [SDOS_FILE_REC_PTR],Y
              LDY #30
              LDA [SDOS_FILE_REC_PTR],Y
              LDY #14
              STA [SDOS_FILE_REC_PTR],Y
              
              ; move the file pointer ahead
              LDA SDOS_FILE_REC_PTR
              CLC
              ADC #$10
              STA SDOS_FILE_REC_PTR
              setas
              INX
              CPX #64
              BEQ ISDOS_DIR_DONE
              
              ;** JSR DLYCMD_2_DTA;      ; Wait 1.5us
              
              ; Ask Controller to go fetch the next entry in the Directory
              LDA #CH_CMD_FILE_ENUM_GO
              STA SDCARD_CMD
              ;** JSR SDCARD_WAIT_4_INT       ; Go Wait for Interrupt
              CMP #CH376S_STAT_DSK_RD
              BEQ ISDOS_NEXT_ENTRY

    ISDOS_DIR_DONE
              ;JSR SDOS_FILE_CLOSE
              RTL

; Upon the Call of this Routine will Change the pointer to a new Sub-Directory
ISDOS_CHDIR   BRK;

; Upon the Call of this Routine this will Save a file defined by the given name and Location
ISDOS_SAVE    BRK;

; Load a File ".FNX" and execute it
ISDOS_EXEC    BRK;

              
; *****************************************************************************
; * Load the FAT table
; * A must contain the sector to read
; *****************************************************************************
SD_READ_FAT_SECTOR
                .al
                .xl
                ASL A
                PHP
                STA SDC_SD_ADDR_15_8_REG
                LDA SD_FAT_OFFSET+2
                ASL A
                PLP
                setas
                STA SDC_SD_ADDR_31_24_REG
                LDA #0
                STA SDC_SD_ADDR_7_0_REG
                JSL ISDOS_READ_BLOCK
                ; check for errors
                LDA SDC_TRANS_ERROR_REG
                BEQ SD_CONTINUE_FAT
                ERROR_MSG SD_FAT_ERROR_MSG, SD_CONTINUE_FAT
                
    SD_CONTINUE_FAT
                setal
                RTS
                
; *****************************************************************************
; * A contains the cluster to start at
; *****************************************************************************
SD_READ_FILE
                .al
                .xl
                LDA #FAT_DATA ; store the block at SD_DATA
                STA SD_DATA
                STA CLUSTER_PTR
                
                ; READ the FAT for our starting cluster 
                ; for FAT12, table entries are 1.5 bytes, FAT16 are 2 bytes
                
                LDA SD_FAT16
                BNE SD_RAD_FAT16
              
                ; each FAT table page contains 340 entries
              
    SD_RAD_FAT16
                PLA
                ; the first byte is the FAT table page/sector
                LDA CLUSTER_PTR
                XBA
                AND #$FF
                CLC
                ADC SD_FAT_OFFSET
                JSR SD_READ_FAT_SECTOR
              
                ; Place the data here:
                LDA #FAT_DATA+$200 ; store the block at SD_DATA
                STA SD_DATA
                
                ; read the file data
                LDA SD_SECTORS_PER_CLUSTER
                AND #$FF
                TAY ; this will be used to read logical sectors
                STA UNSIGNED_MULT_A
                LDA CLUSTER_PTR
                STA UNSIGNED_MULT_B
                LDA UNSIGNED_MULT_RESULT
                STA LOG_CLUSTER_PTR
                LDA UNSIGNED_MULT_RESULT + 2
                STA LOG_CLUSTER_PTR + 2
                
    SD_READNEXT_SECTOR_16
                LDA LOG_CLUSTER_PTR
                CLC
                ADC SD_DATA_OFFSET
                ASL A
                PHP
                STA SDC_SD_ADDR_15_8_REG
                LDA LOG_CLUSTER_PTR + 2
                ASL A
                PLP
                setas
                BCC SD_READ16_NO_CARRY
                INC A
        SD_READ16_NO_CARRY
                STA SDC_SD_ADDR_31_24_REG
                LDA #0
                STA SDC_SD_ADDR_7_0_REG
                JSL ISDOS_READ_BLOCK
                ; check for errors
                LDA SDC_TRANS_ERROR_REG
                BEQ SD_READ16_CONTINUE_DATA
                ERROR_MSG SD_DATA_ERROR_MSG, SD_READ_FINISHED
                
    SD_READ16_CONTINUE_DATA
                setal
                INC LOG_CLUSTER_PTR
                DEY
                BNE SD_READNEXT_SECTOR_16
                
                ; the second byte is the address within the page
                LDA CLUSTER_PTR
                AND #$FF
                ASL A
                TAX
                LDA FAT_DATA,X
                CMP #$FFFF
                BNE SD_READNEXT_SECTOR_16
              
    SD_READ_FINISHED
              RTL

; ISDOS_READ_FILE
; Go Open and Read a file and store it to prefedined address
; Inputs:
;  Name @ SDOS_FILE_NAME, Pointer to Store the DATA: @ SDCARD_FILE_PTR ($00:00030)
; Affects:
;   A, X probably Y and CC and the whole thing... So don't asume anything...
; Returns:
; Well, you ought to have your file loaded where you asked it.
ISDOS_READ_FILE
              .as
              ;JSR SDOS_FILE_OPEN   ; open the file
              
              ; If successful, get the file sizeof
              LDA SDCARD_DATA
              CMP #CH376S_STAT_SUCCESS ; if the file open successfully, let's go on.
              BEQ SDOS_READ_FILE_KEEP_GOING
              BRL SDOS_READ_DONE
              
    SDOS_READ_FILE_KEEP_GOING

              setal
              JSR SDOS_SET_FILE_LENGTH;
              LDA #$0000
              STA @lSDCARD_BYTE_NUM; Just make sure the High Part of the Size is Zero
              STA @lSDOS_BYTE_PTR   ; Clear the Byte Pointer 32 Bytes Register
              STA @lSDOS_BYTE_PTR+2 ; This is to Relocated the Pointer after you passed the 64K Boundary
              ; Second Step, Setup the Amount of Data to Send
              ; Set the Transfer Size, I will try 256 bytes
              setas
    SDOS_READ_FILE_GO_FETCH_A_NEW_64KBlock
              LDA #CH_CMD_BYTE_READ
              STA SDCARD_CMD;
              ;** JSR DLYCMD_2_DTA;   ; 3us Delay to get the Value Return
              LDA @lSDOS_BYTE_NUMBER
              STA SDCARD_DATA
              ;** JSR DLYDTA_2_DTA;   ; 1.5us Delay to get the Value Return
              LDA @lSDOS_BYTE_NUMBER+1
              STA SDCARD_DATA
              ;** JSR SDCARD_WAIT_4_INT
              CMP #CH376S_STAT_DSK_RD ;
              BEQ SDOS_READ_FILE_GO_FETCH_A_NEW_BLOCK
              BRL SDOS_READ_DONE
    SDOS_READ_FILE_GO_FETCH_A_NEW_BLOCK
              ; Go Read 1 Block and Store it @ ($00:0030)
              ;**** JSR SDOS_READ_BLOCK
              LDA #CH_CMD_BYTE_RD_GO
              STA SDCARD_CMD
              ;Now let's go to Poll the INTERRUPT and wait for
              ;** JSR SDCARD_WAIT_4_INT
              CMP #CH376S_STAT_DSK_RD ;
              BNE SDOS_READ_PROC_DONE
              JSR SDOS_ADJUST_POINTER  ; Go Adjust the Address
              BRA SDOS_READ_FILE_GO_FETCH_A_NEW_BLOCK
              
    SDOS_READ_PROC_DONE
              setal
              LDA @lSDOS_BYTE_NUMBER  ; Load the Previously number of Byte
              CMP #$FFFF
              BNE SDOS_READ_DONE                  ; if it equal 64K, then the file is bigger than 64K
              ; Now let's go compute the Nu Value for the Next Batch
              LDA @lADDER_R
              STA @lADDER_A
              LDA @lADDER_R+2
              STA @lADDER_A+2
              JSR SDOS_SET_FILE_LENGTH ;
              JSR SDOS_COMPUTE_LOCATE_POINTER
              setas
              JSR SDOS_BYTE_LOCATE    ; Apply the new location for the CH376S
              ;** JSR SDCARD_WAIT_4_INT
              CMP #CH376S_STAT_SUCCESS ;
              BNE SDOS_READ_PROC_DONE
              ; Check to see that we have Loaded all the bytes.
              BRA SDOS_READ_FILE_GO_FETCH_A_NEW_64KBlock ; Let's go fetch a new block of 64K or less

    SDOS_READ_DONE
              setas
              RTL

SDOS_ADJUST_POINTER
              setal
              CLC
              LDA SDCARD_FILE_PTR ;Load the Pointer
              ADC SDCARD_BYTE_NUM
              STA SDCARD_FILE_PTR;
              setas
              LDA SDCARD_FILE_PTR+2;
              ADC #$00          ; This is just add up the Carry
              STA SDCARD_FILE_PTR+2;
    SDOS_ADJ_DONE
              RTS

SDOS_BYTE_LOCATE  ; Reposition the Pointer of the CH376S when the File is > 64K
              setas
              LDA #CH_CMD_BYTE_LOCATE
              STA SDCARD_CMD
              ;** JSR DLYCMD_2_DTA
              LDA @lSDOS_BYTE_PTR
              STA SDCARD_DATA
              ;** JSR DLYDTA_2_DTA
              LDA @lSDOS_BYTE_PTR+1
              STA SDCARD_DATA
              ;** JSR DLYDTA_2_DTA
              LDA @lSDOS_BYTE_PTR+2
              STA SDCARD_DATA
              ;** JSR DLYDTA_2_DTA
              LDA @lSDOS_BYTE_PTR+3
              STA SDCARD_DATA
              RTS

; This will increment the pointer for the CH376S
SDOS_COMPUTE_LOCATE_POINTER
              setal
              CLC
              LDA @lSDOS_BYTE_PTR ; $00330
              ADC #$FFFF
              STA @lSDOS_BYTE_PTR
              LDA @lSDOS_BYTE_PTR+2
              ADC #$0000          ; this is to Add the Carry
              STA @lSDOS_BYTE_PTR+2
              RTS

; ********************************************************
; * Prepare the buffer for reading - max 64k bytes
; ********************************************************
SDOS_SET_FILE_LENGTH
              LDA SDOS_FILE_SIZE + 2
              BEQ SFL_DONE
              
              ; the file is too large, just exit
              PLY ; deplete the stack to return back to the long jump
              RTL
              
    SFL_DONE
              LDA SDOS_FILE_SIZE
              STA @lSDOS_BYTE_NUMBER
              RTS
              
; *****************************************************************************
; * Add MBR offset and Reserved Sectors
; *****************************************************************************
COMPUTE_FAT_ROOT_DATA_OFFSETS
                .al
                ; compute the FAT sector offset
                LDA SD_RESERVED_SECTORS ; 16 bit value
                STA ADDER_A
                LDA #0
                STA ADDER_A+2
                
                LDA SD_FIRST_SECTOR ; 32 bit value
                STA ADDER_B
                LDA SD_FIRST_SECTOR + 2
                STA ADDER_B + 2
                
                ; result is 32 bites
                LDA ADDER_R
                STA SD_FAT_OFFSET
                LDA ADDER_R + 2
                STA SD_FAT_OFFSET + 2
                
                ; compute the offset to root
                LDA SD_FAT_COUNT
                STA UNSIGNED_MULT_A
                LDA SD_SECTORS_PER_FAT
                STA UNSIGNED_MULT_B
                LDA UNSIGNED_MULT_RESULT
                STA ADDER_A
                LDA UNSIGNED_MULT_RESULT + 2
                STA ADDER_A + 2
                LDA SD_FAT_OFFSET
                STA ADDER_B
                LDA SD_FAT_OFFSET + 2
                STA ADDER_B +2
                LDA ADDER_R
                STA SD_ROOT_OFFSET
                LDA ADDER_R +2
                STA SD_ROOT_OFFSET + 2
                
                ; compute the offset to data
                LDA SD_ROOT_OFFSET
                STA ADDER_A
                LDA SD_ROOT_OFFSET + 2
                STA ADDER_A + 2
                LDA #32 ; the root contains 512 entries at 32 bytes each
                STA ADDER_B
                LDA #0
                STA ADDER_B + 2
                
                LDA ADDER_R
                STA SD_DATA_OFFSET
                LDA ADDER_R + 2
                STA SD_DATA_OFFSET + 2
                
                RTS

;
; MESSAGES
;
sd_card_dir_string      .text '/*' ,$00
                        .fill 128-3,0  ; leave space for the path
sd_no_card_msg          .text "01 - NO SDCARD PRESENT", $0D, $00
sd_cant_read_mbr_msg    .text "02 - Can't read MBR - No Card present", $D, $0
sd_read_failure         .text "03 - Error during read operation", $d, $0
SD_FIRST_SECTOR_MSG     .text "04 - Error reading boot sector", $d, $0
SD_FAT_ERROR_MSG        .text "05 - Error reading FAT sector", $d, $0
SD_ROOT_ERROR_MSG       .text "05 - Error reading Root sector", $d, $0
SD_DATA_ERROR_MSG       .text "05 - Error reading Data sector", $d, $0
INVALID_SIG_MSG         .text 'Invalid MBR Signature',$D,0

sd_volume_name          .text "Volume Name: ", $0
sd_vfat_name            .text "VFAT Name  : ", $0
sd_dir_name             .text "Directory  : ", $0
sd_filename             .text "Filename   : ", $0
sd_cluster_str          .text ", Cluster:", $0
sd_filesize_str         .text ", Size:", $0

sd_card_err0        .text "ERROR IN READIND CARD", $d, $0
sd_card_err1        .text "ERROR LOADING FILE", $00
sd_card_msg0        .text "Name: ", $0D,$00
sd_card_msg1        .text "SDCARD DETECTED", $00
sd_card_msg2        .text "SDCARD MOUNTED", $00
sd_card_msg3        .text "FAILED TO MOUNT SDCARD", $0D, $00
sd_card_msg4        .text "FILE OPENED", $0D, $00
sd_card_msg5        .text "END OF LINE...", $00
sd_card_msg6        .text "FILE FOUND, LOADING...", $00
sd_card_msg7        .text "FILE LOADED", $00
