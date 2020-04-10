.cpu "65816"
.include "macros_inc.asm"
.include "bank_00_inc.asm"
.include "io_def.asm"
.include "interrupt_def.asm"
.include "math_def.asm"
.include "vicky_def.asm"
.include "kernel_inc.asm"

LINE_COUNTER            = $B0
    
* = HRESET
                CLC
                XCE   ; go into native mode
                SEI   ; ignore interrupts
                JML SDCARD

* = HIRQ        ; IRQ handler.
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

SDCARD
                setas
                setxl
                JSL CLEAR_DISPLAY
                ; initialize the SD Card
                JSL ISDOS_INIT
                JSL ISDOS_READ_MBR_BOOT
                ; read the root sectors
                JSL ISDOS_DISPLAY_ROOT_DIR
                
                
                ; These are temporary sub-routines to help me debug
                ; READ the First FAT Sectors
                setal
                LDA #$6600 ; store the block at SD_DATA
                STA SD_DATA
                LDA #0
                JSL ISDOS_READ_FAT_SECTOR
                
                LDA #$6800 ; store the block at SD_DATA
                STA SD_DATA
                LDA #1
                JSL ISDOS_READ_FAT_SECTOR
                
                LDA #$6A00 ; store the block at SD_DATA
                STA SD_DATA
                LDA #(4-2) * 2
                JSL ISDOS_READ_DATA_CLUSTER
                
                LDA #$6E00 ; store the block at SD_DATA
                STA SD_DATA
                LDA #(5-2) * 2
                JSL ISDOS_READ_DATA_CLUSTER
                
                LDA #$6E00 ; store the block at SD_DATA
                STA SD_DATA
                setas
                JSR DISPLAY_BLOCK

    SDCARD_DONE
                BRL SDCARD_DONE
                
                ; READ FILE starting at cluster $83 - SUBWAVE.RAD
                LDA #$83
                ;JSR SD_READ_FILE
                
                
    

CLEAR_DISPLAY
                .as
                .xl
                setal
                LDA #128
                STA COLS_PER_LINE
                LDA #64
                STA LINES_MAX
        
                ; set the visible display size - 80 x 60
                LDA #80
                STA COLS_VISIBLE
                LDA #60
                STA LINES_VISIBLE
                setas
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
               
.include "SDOS.asm"

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
                
                LDX SD_DATA
                LDY CURSORPOS
    DB_LINE_LOOP
                LDA #0
                XBA
        DB_LOOP
                LDA 0, X
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