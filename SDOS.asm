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
SD_SECTORS_PER_CLUSTER  = $5F24 ; 2 byte
SD_FAT16                = $5F26 ; 1 byte - write 1 for FAT16, 0 for FAT12
CLUSTER_PTR             = $5F27 ; 2 bytes
LOG_CLUSTER_PTR         = $5F29 ; 4 bytes
SD_DATA                 = $0080 ; 3 bytes - used indirect addressing
SD_MULT_AREA            = $0088 ; 4 bytes
SD_BLK_BEGIN            = $6000 ; 512 bytes
SD_BTSCT_BEGIN          = $6200 ; 512 bytes
SD_ROOT_BEGIN           = $6400 ; 512 bytes
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
                BRA SD_INIT_DONE
                
    SD_INIT_SUCCESS
                ; SD Card is present
                LDA #1
                STA SDCARD_PRSNT_MNT 
                BRA SD_INIT_DONE
              
    SD_INIT_DONE
                TURN_OFF_SD_LED
                RTL

; MULTIPLY A NUMBER by 512 - 32 bits
CALC_OFFSET_BYTES
                .al
                LDA SD_MULT_AREA + 2 ; high 16-bits
                ASL A
                STA SD_MULT_AREA + 3
                CLC
                LDA SD_MULT_AREA
                ASL A
                STA SD_MULT_AREA + 1
                BCC CALC_DONE
                INC SD_MULT_AREA + 3
    CALC_DONE
                setas
                stz SD_MULT_AREA
                setal
                RTS
;******************************************************************************
; ISDOS_READ_MASTERBOOTRECORD
; Read the Master Boot Record - offset 0
; Inputs:
;  None
; Affects:
;   None
;******************************************************************************
ISDOS_READ_MBR_BOOT
                .as
                LDA SDCARD_PRSNT_MNT ; this must be non-zero
                BNE RMBR_CARD_PRESENT
                RTL

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
                RTL
                
    SD_CONTINUE_1
                ; Read the MBR signature - it should be 55 AA
                setal
                LDA SD_BLK_BEGIN + 510
                CMP #$AA55
                BEQ VALID_SIG
                RTL
    VALID_SIG
                setal
                LDX #446 ; offset to first partition
                LDA SD_BLK_BEGIN,X + 8
                STA SD_MULT_AREA
                LDA SD_BLK_BEGIN,X + 10
                STA SD_MULT_AREA + 2
                JSR CALC_OFFSET_BYTES
                
                ; store the value for 
                LDA SD_MULT_AREA
                STA SD_FIRST_SECTOR
                STA SDC_SD_ADDR_7_0_REG
                LDA SD_MULT_AREA + 2
                STA SD_FIRST_SECTOR + 2
                STA SDC_SD_ADDR_23_16_REG
                
                LDA #SD_BTSCT_BEGIN
                STA SD_DATA
                
        ; read the FAT Boot Sector - this overwrites the MBR record
                setas
                JSL ISDOS_READ_BLOCK
                
                ; check for errors
                LDA SDC_TRANS_ERROR_REG
                BEQ SD_CONTINUE_2
                RTL
                
    SD_CONTINUE_2
                setal
                LDX #0
                ; bytes per sector
                LDA SD_BTSCT_BEGIN,X + $B
                STA SD_BYTES_PER_SECTOR
                
                setas
                ; logical sectors per cluster
                LDA SD_BTSCT_BEGIN,X + $D
                STA SD_SECTORS_PER_CLUSTER
                
                setal
                ; number of fat tables
                LDA SD_BTSCT_BEGIN,X + $10
                AND #$FF
                STA SD_FAT_COUNT
                
                ; number of root entries
                LDA SD_BTSCT_BEGIN,X + $11
                STA SD_ROOT_ENTRIES

                ; how many sectors do we have - small <= 65535
                LDA SD_BTSCT_BEGIN,X + $13
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
                LDA SD_BTSCT_BEGIN,X + $20
                STA SD_SECTORS
                LDA SD_BTSCT_BEGIN,X + $22
                STA SD_SECTORS + 2
    SD_SMALL_SECTORS
                setas
                LDA #1
                STA SD_FAT16
                setal
    SD_FAT12
                LDA SD_BTSCT_BEGIN,X + $E
                STA SD_RESERVED_SECTORS
                LDA SD_BTSCT_BEGIN,X + $16
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
                ERROR_MSG sd_read_failure, SR_DONE
                
                ; SDC_RX_FIFO_DATA_CNT_HI and SDC_RX_FIFO_DATA_CNT_LO may contain how many bytes were read
    SD_READ_BLOCK_OK
                LDY #0
    SR_READ_LOOP
                LDA SDC_RX_FIFO_DATA_REG
                STA [SD_DATA],Y
                INY
                CPY #512
                BNE SR_READ_LOOP
                
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
;* Read the directory from the Data section and 
; *     display volume, dir and file names.
;******************************************************************************
ISDOS_DISPLAY_ROOT_DIR
                .as
                .xl
                setal
                LDA #0  ; reset the root entries offset
                STA SD_DIR_OFFSET
                
    RD_NEXT_SECTOR
                LDA #SD_ROOT_BEGIN
                STA SD_DATA
                
                ; read the root sector
                LDA SD_DIR_OFFSET ; multiply by 512
                ASL A
                XBA
                ; add the ROOT offset
                STA ADDER_A
                LDA #0
                STA ADDER_A + 2
                LDA SD_ROOT_OFFSET
                STA ADDER_B
                LDA SD_ROOT_OFFSET+2
                STA ADDER_B + 2
                LDA ADDER_R
                STA SDC_SD_ADDR_7_0_REG
                LDA ADDER_R + 2
                STA SDC_SD_ADDR_23_16_REG
                setas
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
                
                ; ensure we don't go over the maximum number of sectors in the ROOT section
                LDA SD_DIR_OFFSET
                INC A
                CMP SD_ROOT_ENTRIES
                BCS RD_DONE
                
                STA SD_DIR_OFFSET ; next sector
                ; A must 16-bit now.
                JMP RD_NEXT_SECTOR
                
                
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
              

; *****************************************************************************
; * Store the data into our abbreviate FAT structure
; *   Type
; *   Filename
; *   Start Cluster
; *   Size
; *****************************************************************************
STORE_FAT_DATA
                .as
                LDY #11
                CMP #$10
                BEQ SF_DIR
                LDA #1
        SF_DIR
                STA [SDOS_FILE_REC_PTR],Y
                LDY #0
                LDX #11
    SF_LOOP_NAME
                LDA [SD_DATA],Y
                STA [SDOS_FILE_REC_PTR],Y
                INY
                DEX
                BNE SF_LOOP_NAME
                
                setal
                ;read the start cluster
                LDY #fatrec.cluster
                LDA [SD_DATA],Y
                LDY #16
                STA [SDOS_FILE_REC_PTR],Y
                ; read the file size
                LDY #fatrec.size_l
                LDA [SD_DATA],Y
                LDY #12
                STA [SDOS_FILE_REC_PTR],Y
                LDY #fatrec.size_h
                LDA [SD_DATA],Y
                LDY #14
                STA [SDOS_FILE_REC_PTR],Y
                
                ;advance the pointer
                LDA SDOS_FILE_REC_PTR
                CLC
                ADC #18
                STA SDOS_FILE_REC_PTR
                
                setas
                RTS

; *****************************************************************************
; * Read the root directory and parse into an 18 byte struct, 56 max (1024 bytes)
; *****************************************************************************
ISDOS_PARSE_ROOT_DIR
                .as
                .xl
                setal
                LDA #0  ; reset the root entries offset
                STA SD_DIR_OFFSET
                
    SP_NEXT_SECTOR
                LDA #SD_ROOT_BEGIN
                STA SD_DATA
                
                ; read the root sector
                LDA SD_DIR_OFFSET ; multiply by 512
                ASL A
                XBA
                ; add the ROOT offset
                STA ADDER_A
                LDA #0
                STA ADDER_A + 2
                LDA SD_ROOT_OFFSET
                STA ADDER_B
                LDA SD_ROOT_OFFSET+2
                STA ADDER_B + 2
                LDA ADDER_R
                STA SDC_SD_ADDR_7_0_REG
                LDA ADDER_R + 2
                STA SDC_SD_ADDR_23_16_REG
                setas
                JSL ISDOS_READ_BLOCK
                ; check for errors
                LDA SDC_TRANS_ERROR_REG
                BEQ SP_DIR_ENTRY
                JML SP_DONE
                
    SP_DIR_ENTRY
                LDA [SD_DATA]
                BNE SP_CONTINUE ; if first byte is 0, entry is available and there are no following entries
                JML SP_DONE
                
    SP_CONTINUE
                CMP #$E5
                BEQ SP_SKIP
    SP_LOOP
                ; check the file type
                LDY #fatrec.type
                LDA [SD_DATA],Y
                
                CMP #$F ; long file name
                BNE SP_NOT_VFAT
                JML SP_SKIP
                
        SP_NOT_VFAT
                BIT #2 ; hidden
                BEQ SP_NOT_HIDDEN
                BRA SP_SKIP
                
        SP_NOT_HIDDEN
                BIT #8 ; volume name
                BEQ SP_NOT_VOLUME
                JML SP_SKIP
                
        SP_NOT_VOLUME
                BIT #$10 ; directory
                BEQ SP_NOT_DIRECTORY
                JSR STORE_FAT_DATA
                BRA SP_SKIP
                
        SP_NOT_DIRECTORY
                JSR STORE_FAT_DATA
                
    SP_SKIP
                setal
                LDA SD_DATA
                AND #$1E0  ; each record in FAT is $20 bytes long
                CMP #$1E0
                BNE SP_SKIP_NEXT
                
                ; ensure we don't go over the maximum number of sectors in the ROOT section
                LDA SD_DIR_OFFSET
                INC A
                CMP SD_ROOT_ENTRIES
                BCS SP_DONE
                
                STA SD_DIR_OFFSET ; next sector
                ; A must 16-bit now.
                JMP SP_NEXT_SECTOR
                
                
        SP_SKIP_NEXT
                LDA SD_DATA
                CLC
                ADC #$20
                STA SD_DATA
                setas
                
                JML SP_DIR_ENTRY
                
    SP_DONE
                RTL
                
; *****************************************************************************
; * Load the FAT table
; * A must contain the sector to read
; *****************************************************************************
ISDOS_READ_FAT_SECTOR
                .al
                .xl
                STA SD_MULT_AREA
                LDA #0
                STA SD_MULT_AREA + 2
                JSR CALC_OFFSET_BYTES
                LDA SD_MULT_AREA
                STA ADDER_A
                LDA SD_MULT_AREA + 2
                STA ADDER_A + 2
                
                ; add the FAT offset
                LDA SD_FAT_OFFSET
                STA ADDER_B
                LDA SD_FAT_OFFSET+2
                STA ADDER_B + 2
                LDA ADDER_R
                STA SDC_SD_ADDR_7_0_REG
                LDA ADDER_R + 2
                STA SDC_SD_ADDR_23_16_REG
                
                setas
                JSL ISDOS_READ_BLOCK
                ; check for errors
                LDA SDC_TRANS_ERROR_REG
                BEQ SD_CONTINUE_FAT
                ERROR_MSG SD_FAT_ERROR_MSG, SD_CONTINUE_FAT
                
    SD_CONTINUE_FAT
                setal
                RTL
                

; *****************************************************************************
; * Load Data Cluster
; * A must contain the cluster to read - this cluster is multiplied by 
; *   sectors by cluster.
; *****************************************************************************
ISDOS_READ_DATA_CLUSTER
                .al
                .xl
                PHA
                LDX #0
    SDR_NEXT_SECTOR
                STA SD_MULT_AREA
                LDA #0
                STA SD_MULT_AREA + 2
                JSR CALC_OFFSET_BYTES
                
                
                LDA SD_MULT_AREA
                STA ADDER_A
                LDA SD_MULT_AREA + 2
                STA ADDER_A + 2
                
                ; add the Data offset
                LDA SD_DATA_OFFSET
                STA ADDER_B
                LDA SD_DATA_OFFSET+2
                STA ADDER_B + 2
                LDA ADDER_R
                STA SDC_SD_ADDR_7_0_REG
                LDA ADDER_R + 2
                STA SDC_SD_ADDR_23_16_REG

                setas
                JSL ISDOS_READ_BLOCK
                ; check for errors
                LDA SDC_TRANS_ERROR_REG
                BEQ SD_CONTINUE_DATA
                ERROR_MSG SD_DATA_ERROR_MSG, SD_CONTINUE_DATA_DONE
                
    SD_CONTINUE_DATA
                setal
                LDA SD_DATA
                CLC
                ADC #$200
                STA SD_DATA
                PLA
                INC A
                PHA
                INX
                CPX SD_SECTORS_PER_CLUSTER
                BNE SDR_NEXT_SECTOR
                
    SD_CONTINUE_DATA_DONE
                setal
                PLA
                RTL

                
; *****************************************************************************
; * A contains the cluster to start at
; *****************************************************************************
ISDOS_READ_FILE
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
                JSR ISDOS_READ_FAT_SECTOR
              
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
              
; *****************************************************************************
; * Add MBR offset and Reserved Sectors
; *****************************************************************************
COMPUTE_FAT_ROOT_DATA_OFFSETS
                .al
                ; compute the FAT sector offset
                LDA SD_RESERVED_SECTORS ; 16 bit value
                STA SD_MULT_AREA
                LDA #0
                STA SD_MULT_AREA + 2
                JSR CALC_OFFSET_BYTES ; compute the byte offset
                LDA SD_MULT_AREA
                STA ADDER_A
                LDA SD_MULT_AREA + 2
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
                STA SD_MULT_AREA
                LDA UNSIGNED_MULT_RESULT + 2
                STA SD_MULT_AREA + 2
                JSR CALC_OFFSET_BYTES ; compute the byte offset
                LDA SD_MULT_AREA
                STA ADDER_A
                LDA SD_MULT_AREA + 2
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
                STA SD_MULT_AREA
                LDA #0
                STA SD_MULT_AREA + 2
                JSR CALC_OFFSET_BYTES
                LDA SD_MULT_AREA
                STA ADDER_B
                LDA SD_MULT_AREA + 2
                STA ADDER_B + 2
                
                LDA ADDER_R
                STA SD_DATA_OFFSET
                LDA ADDER_R + 2
                STA SD_DATA_OFFSET + 2
                
                RTS

;
; MESSAGES
;
sd_card_tester          .text "00 - Welcome to the SDCard Tester", $d, 0
sd_card_present         .text "01 - Card Present", $d, 0
sd_no_card_msg          .text "01 - NO SDCARD PRESENT", $0D, $00
sd_cant_read_mbr_msg    .text "02 - Can't read MBR - No Card present", $D, $0
sd_read_failure         .text "03 - Error during read operation", $d, $0
SD_BOOT_SECTOR_MSG     .text "04 - Error reading Boot sector", $d, $0
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
