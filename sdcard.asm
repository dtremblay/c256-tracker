.cpu "65816"
.include "macros_inc.asm"
.include "bank_00_inc.asm"
.include "io_def.asm"
.include "interrupt_def.asm"
.include "math_def.asm"
.include "vicky_def.asm"
.include "kernel_inc.asm"

LINE_COUNTER            = $B0
; File System Offsets
SD_FIRST_SECTOR         = $5F00 ; 4 bytes
SD_FAT_OFFSET           = $5F04 ; 4 bytes
SD_ROOT_OFFSET          = $5F08 ; 4 bytes
SD_SECTORS              = $5F0C ; 4 bytes

SD_RESERVED_SECTORS     = $5F10 ; 2 bytes
SD_SECTORS_PER_FAT      = $5F12 ; 2 bytes
SD_BYTES_PER_SECTOR     = $5F14 ; 2 bytes
SD_SECTORS_PER_CLUSTER  = $5F16 ; 2 bytes
SD_FAT_COUNT            = $5F18 ; 2 bytes

; Read data here
SD_BLK_BEGIN            = $6000

    
* = HRESET
                CLC
                XCE   ; go into native mode
                SEI   ; ignore interrupts
                JML SDCARD

* = HIRQ       ; IRQ handler.
RHIRQ           setaxl
                PHB
                PHD
                PHA
                PHX
                PHY
                ;
                ; todo: look up IRQ triggered and do stuff
                ;
                JSL IRQ_HANDLER

                PLY
                PLX
                PLA
                PLD
                PLB
                RTI

; Interrupt Vectors
* = VECTORS_BEGIN
JUMP_READY      JML SDCARD     ; Kernel READY routine. Rewrite this address to jump to a custom kernel.
RVECTOR_COP     .addr HCOP     ; FFE4
RVECTOR_BRK     .addr HBRK     ; FFE6
RVECTOR_ABORT   .addr HABORT   ; FFE8
RVECTOR_NMI     .addr HNMI     ; FFEA
                .word $0000    ; FFEC
RVECTOR_IRQ     .addr HIRQ     ; FFEE

RRETURN         JML SDCARD

RVECTOR_ECOP    .addr HCOP     ; FFF4
RVECTOR_EBRK    .addr HBRK     ; FFF6
RVECTOR_EABORT  .addr HABORT   ; FFF8
RVECTOR_ENMI    .addr HNMI     ; FFFA
RVECTOR_ERESET  .addr HRESET   ; FFFC
RVECTOR_EIRQ    .addr HIRQ     ; FFFE

; *****************************************************************************
; *****************************************************************************
; ***                            SDCARD READER                              ***
; *****************************************************************************
; *****************************************************************************
* = $5000
.include "SDOS.asm"

ERROR_MSG       .macro
                setas
                LDA #`\1
                PHB
                PHA
                PLB
                LDX #<>\1
                JSL PUTS
                PLB
                BRL SDCARD_DONE
                .endm

SDCARD
                setas
                setxl
                JSL CLEAR_DISPLAY
                ; initialize the SD Card
                JSL ISDOS_INIT
        ; read sector 0 - the Master Boot Record
                setal
                LDA #0
                STA SDC_SD_ADDR_7_0_REG
                STA SDC_SD_ADDR_23_16_REG
                setas
                JSL ISDOS_READ_BLOCK

                ; check for errors
                LDA SDC_TRANS_ERROR_REG
                BEQ SD_CONTINUE_1
                ERROR_MSG sd_no_card_msg
                
    SD_CONTINUE_1
                ; Read the MBR signature - it should be 55 AA
                setal
                LDA SD_BLK_BEGIN + 510
                CMP #$AA55
                BEQ VALID_SIG
                ERROR_MSG INVALID_SIG_MSG
    VALID_SIG
                setal
                LDX #446 ; offset to first partition
                LDA SD_BLK_BEGIN,X + 8
                STA SD_FIRST_SECTOR
                LDA SD_BLK_BEGIN,X + 10
                STA SD_FIRST_SECTOR+2
                
        ; read the FAT Boot Sector
                LDA SD_FIRST_SECTOR
                ASL A
                STA SDC_SD_ADDR_15_8_REG
                LDA SD_FIRST_SECTOR+2
                STA SDC_SD_ADDR_31_24_REG
                setas
                LDA #0
                STA SDC_SD_ADDR_7_0_REG
                JSL ISDOS_READ_BLOCK
                
                ; check for errors
                LDA SDC_TRANS_ERROR_REG
                BEQ SD_CONTINUE_2
                ERROR_MSG SD_FIRST_SECTOR_MSG
                
    SD_CONTINUE_2

                setal
                LDX #0
                ; bytes per sector - not sure what this is used for
                LDA SD_BLK_BEGIN,X + $B
                STA SD_BYTES_PER_SECTOR
                
                ; sectors per cluster - not sure what this is used for
                LDA SD_BLK_BEGIN,X + $D
                AND #$FF
                STA SD_SECTORS_PER_CLUSTER
                
                ; number of fat tables
                LDA SD_BLK_BEGIN,X + $10
                AND #$FF
                STA SD_FAT_COUNT

                ; how many sectors do we have - small <= 65535
                LDA SD_BLK_BEGIN,X + $13
                BEQ SD_LARGE_SECTORS
                STA SD_SECTORS
                LDA #0
                STA SD_SECTORS + 2

                BRA SDCARD_ROOT
    SD_LARGE_SECTORS
                ; large sectors > 65535
                LDA SD_BLK_BEGIN,X + $20
                STA SD_SECTORS
                LDA SD_BLK_BEGIN,X + $22
                STA SD_SECTORS + 2
    SDCARD_ROOT
                
                LDA SD_BLK_BEGIN,X + $E
                STA SD_RESERVED_SECTORS
                LDA SD_BLK_BEGIN,X + $24
                STA SD_SECTORS_PER_FAT
            
                JSR COMPUTE_FAT_ROOT_OFFSETS

                ; Load the FAT table
                LDA SD_FAT_OFFSET
                ASL A
                STA SDC_SD_ADDR_15_8_REG
                LDA SD_FAT_OFFSET+2
                STA SDC_SD_ADDR_23_16_REG
                setas
                LDA #0
                STA SDC_SD_ADDR_7_0_REG
                JSL ISDOS_READ_BLOCK
                ; check for errors
                LDA SDC_TRANS_ERROR_REG
                BEQ SD_CONTINUE_3
                ERROR_MSG SD_FAT_ERROR_MSG
                
    SD_CONTINUE_3

setas
LDY #$A000 + 20 * 128
;JSL DISPLAY_BLOCK
                setal
                LDA SD_ROOT_OFFSET
                ASL A
                STA SDC_SD_ADDR_15_8_REG
                LDA SD_ROOT_OFFSET + 2
                STA SDC_SD_ADDR_23_16_REG
                setas
                LDA #0
                STA SDC_SD_ADDR_7_0_REG
                JSL ISDOS_READ_BLOCK
                ; check for errors
                LDA SDC_TRANS_ERROR_REG
                BEQ SD_CONTINUE_4
                ERROR_MSG SD_ROOT_ERROR_MSG
                
    SD_CONTINUE_4
                LDX #0
                LDY #20
                JSL LOCATE
                
    SDCARD_DONE
                BRL SDCARD_DONE
                
INVALID_SIG_MSG .text 'Invalid MBR Signature',$D,0

CLEAR_DISPLAY
                .as
                .xl
                LDA #128
                STA COLS_PER_LINE
                LDA #64
                STA LINES_MAX

                ; set the visible display size - 80 x 60
                LDA #80
                STA COLS_VISIBLE
                LDA #60
                STA LINES_VISIBLE
                LDA #16
                STA BORDER_X_SIZE
                STA BORDER_Y_SIZE

                ; set the border to purple
                LDA #$80
                STA BORDER_COLOR_R
                LDA #0
                STA BORDER_COLOR_B
                STA BORDER_COLOR_G
                
                ; set the text color to 2
                LDA #$20
                STA CURCOLOR
                
                ; reset the position of the cursor to 0,0
                LDX #0
                LDY #0
                JSL LOCATE

                ; enable the border
                LDA #Border_Ctrl_Enable
                STA BORDER_CTRL_REG

                ; enable text display
                LDA #Mstr_Ctrl_Text_Mode_En
                STA MASTER_CTRL_REG_L

                setal
                LDA #$60FF
                STA FG_CHAR_LUT_PTR + 8;
                STA BG_CHAR_LUT_PTR + 8;
                LDA #$0080
                STA FG_CHAR_LUT_PTR + 10;
                STA BG_CHAR_LUT_PTR + 10;
                
                LDA #<>CS_TEXT_MEM_PTR      ; store the initial screen buffer location
                STA SCREENBEGIN
                STA CURSORPOS
                setas
                LDA #`CS_TEXT_MEM_PTR
                STA SCREENBEGIN+2
                STA CURSORPOS+2
                
                
                setdbr $af
                LDX #0
                LDY #0
                LDA #$20
        CD_CLEAR_LOOP
                STA #$A000,b,X
                STA #$C000,b,X
                INX
                CPX #$2000
                BNE CD_CLEAR_LOOP
                setdbr $0
                
                RTL
               
; *****************************************************************************
; * Output text to screen - temporary until SDOS is finished
; *****************************************************************************
DISPLAY_MSG
                .as
                .xl
                RTL
                
                
; *****************************************************************************
; * Display a block of data at SD_BLK_BEGIN (512 bytes)
; *****************************************************************************
BLANK = 0
DISPLAY_BLOCK
                .as
                .xl
                PHB
                LDA #$AF
                PHA
                PLB
                
                LDA #32 ; 32 x 16 is 512 bytes
                STA LINE_COUNTER
               
                LDX #0
    DB_LINE_LOOP
                LDA #0
                XBA
        DB_LOOP
                LDA @lSD_BLK_BEGIN,X
                JSR DISPLAY_HEX
                
                ; display a blank
                LDA #BLANK
                STA #0,b,Y
                INY
                
                INX
                TXA
                AND #$F
                CMP #8
                BNE SKIP_COL
                
                ; every 8th column display an extra blank
                LDA #BLANK
                STA #0,b,Y
                INY
        SKIP_COL
                TXA
                AND #$F
                BNE DB_LOOP
                
                setal
                TYA
                AND #$FF80
                CLC
                ADC #$80
                TAY
                setas
                DEC LINE_COUNTER
                BNE DB_LINE_LOOP
                
                PLB
                RTL

; *****************************************************************************
; * Only display the 4 MBR Partition Records
; *****************************************************************************
DISPLAY_PARTITION_RECS
                .as
                .xl
                PHB
                LDA #$AF
                PHA
                PLB
                
                LDA #5 ; display signature and 4 partition lines
                STA LINE_COUNTER
               
                LDX #0
    DPR_LINE_LOOP
                LDA #0
                XBA
        DPR_LOOP
                ; the partition tables start at byte 466
                LDA @lSD_BLK_BEGIN+430,X
                JSR DISPLAY_HEX
                
                ; display a blank
                LDA #BLANK
                STA #0,b,Y
                INY
                
                INX
                TXA
                AND #$F
                CMP #8
                BNE DPR_SKIP_COL
                
                ; every 8th column display an extra blank
                LDA #BLANK
                STA #0,b,Y
                INY
        DPR_SKIP_COL
                TXA
                AND #$F
                BNE DPR_LOOP
                
                setal
                TYA
                AND #$FF80
                CLC
                ADC #$80
                TAY
                setas
                DEC LINE_COUNTER
                BNE DPR_LINE_LOOP
                
                PLB
                RTL

; *****************************************************************************
; * Display a Hex value
; * Accumulator A contains the value to display
; * Bank must be $AF
; * Y is the screen offset
; *****************************************************************************
HEX_VALUES      .text '0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F'
DISPLAY_HEX
                .as
                .xl
                setal
                PHX
                
                PHA
                AND #$F0
                LSR
                LSR
                LSR
                LSR
                AND #$F
                
                ; display the first character in hex
                tax
                LDA @lHEX_VALUES,X
                STA #0,b,Y
                INY
                
                ; display the second character in hex
                PLA
                AND #$F
                tax
                LDA @lHEX_VALUES,X
                STA #0,b,Y
                INY
                
                PLX
                setas
                
                RTS

; *****************************************************************************
; * Handle interrupts
; *****************************************************************************
IRQ_HANDLER
                .as
                .xl
                RTL
                
; *****************************************************************************
; * Add MBR offset and Reserved Sectors
; *****************************************************************************
COMPUTE_FAT_ROOT_OFFSETS
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
                
                
                RTS