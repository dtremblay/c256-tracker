

EFFECT_NONE              = $00
EFFECT_NOTE_SLIDE_UP     = $01
EFFECT_NOTE_SLIDE_DOWN   = $02
EFFECT_NOTE_SLIDE_TO     = $03
EFFECT_NOTE_SLIDE_VOLUME = $05
EFFECT_VOLUME_SLIDE      = $0A
EFFECT_SET_VOLUME        = $0C
EFFECT_PATTERN_BREAK     = $0D
EFFECT_SET_SPEED         = $0F

FNUMBER_MIN = $0156
FNUMBER_MAX = $02AE

SongData .struct
patternOffsets      .word $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000
                    .word $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000
                    .word $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000
                    .word $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000
orderListOffset     .word $00000000

songLength          .byte $00
InitialSpeed        .byte $06
hasSlowTimer        .byte $00 ;BOOL $00 = False, $01 = True
.ends

PlayerVariables .struct
loopSong            .byte $01 ; Bool
orders              .byte $00
line                .byte $00
tick                .byte $00
speed               .byte $06
endOfPattern        .byte $00 ; Bool
channelNote         .word $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000
pitchSlideDest      .word $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000
efftectParameter    .byte $00, $00, $00, $00, $00, $00, $00, $00, $00
pitchSlideSpeed     .byte $00, $00, $00, $00, $00, $00, $00, $00, $00
patternBreak        .byte $FF
.ends


; ************************************************************************************************
; We are assuming that the RAD File is already Loaded Somewhere
; ************************************************************************************************
RAD_INIT_PLAYER
              JSL OPL2_INIT   ; Init OPL2
              
              ; READ the RAD file
              setaxl
              LDA #<>RAD_FILE_TEMP ; Set the Pointer where the File Begins
              STA OPL2_ADDY_PTR_LO;
              LDA #<`RAD_FILE_TEMP
              STA OPL2_ADDY_PTR_HI;
              setas
              ; get the version of the file
              LDY #$0010
              LDA [OPL2_ADDY_PTR_LO],Y
              CMP #$10 ; BCD version 1.0 or 2.1
              BNE LOAD_VERSION_21
              JSL READ_VERSION_10
              RTL
              
LOAD_VERSION_21
              JSL READ_VERSION_21
              RTL
              
              
READ_VERSION_21
              ;not implemented
              RTL
              
READ_VERSION_10
              JSR PARSER_RAD_FILE_INSTRUMENT_10; Go Parse the Instrument and Order list
              JSR PROCESS_ORDER_LIST_10
              JSR READ_PATTERNS_10
              
              RTL

ADLIB_OFFSETS .byte 7,1,8,2,9,3,10,4,5,11,6

; ************************************************************************************************
; Read the instrument table
; ************************************************************************************************
PARSER_RAD_FILE_INSTRUMENT_10
              INY ; $11 bit 7: description, bit6: slow timer, bits4..0: speed
              
              LDA [OPL2_ADDY_PTR_LO],Y
              ;Will Ignore the has slowSlowTimer for now
              AND #$1F
              STA @lTuneInfo.InitialSpeed
              LDA [OPL2_ADDY_PTR_LO],Y
              AND #$80
              BEQ READ_INSTR_DATA
Not_Done_With_Description
              INY ; Move the Pointer Forward
              LDA [OPL2_ADDY_PTR_LO],Y
              CMP #$00  ; Check for the End of Text
              BNE Not_Done_With_Description
              
READ_INSTR_DATA
              INY ; This points after either After Description or next to Offset 0x11
              
              ; Let's Init the Address Point for the instrument Tables
              
              LDA #<`INSTRUMENT_ACCORDN
              STA RAD_ADDR + 2
              
              ; Let's Read Some Instruments HERE
ProcessNextInstruments
              setas
              LDA [OPL2_ADDY_PTR_LO],Y  ; Read Instrument Number
              BEQ DoneProcessingInstrument;
              
              setal
              ; find the address of the instrument by multiplying by the record length
              DEC A
              STA @lM0_OPERAND_A
              LDA #INSTR_REC_LEN
              STA @lM0_OPERAND_B
              LDA @lM0_RESULT  ; not sure why this one requires a long address - bank is still 0
              
              CLC
              ADC #<>INSTRUMENT_ACCORDN
              STA RAD_ADDR
              LDA #0
              setas
              
              INY
              STZ RAD_TEMP
              STA [RAD_ADDR]  ; Not a drum instrument
              
Transfer_Instrument_Info
              LDX RAD_TEMP
              LDA ADLIB_OFFSETS,X  ; RAD uses a different order for registers
              TAX
              
              LDA [OPL2_ADDY_PTR_LO],Y  ; Read Register
              PHY
              TXY
              STA [RAD_ADDR],Y  ; Write to the instrument table 
              PLY
              INY
              INC RAD_TEMP
              LDA RAD_TEMP
              CMP #11
              BCC Transfer_Instrument_Info
              
              PHY ; store the position in the file on the stack
              LDY #12 ; beginning of text
              LDA #$20
              ;TODO: set description to 'RAD INST #'
    BLANK_INSTR_DESCR
              STA [RAD_ADDR],Y
              INY
              CPY #22
              BNE BLANK_INSTR_DESCR
              PLY
              
              BRA ProcessNextInstruments;
              
DoneProcessingInstrument
              INY
              RTS
              
; ************************************************************************************************
; * Read the orders list
; ************************************************************************************************
PROCESS_ORDER_LIST_10
              LDA [OPL2_ADDY_PTR_LO],Y  ; Read Song Length
              STA @lTuneInfo.songLength
              TAX
              INY
              
              setal
              LDA #<>ORDERS
              STA RAD_ADDR
              LDA #<`ORDERS
              STA RAD_ADDR + 2
              setas
    READ_ORDER
              LDA [OPL2_ADDY_PTR_LO],Y
              INY
              STA [RAD_ADDR]
              INC RAD_ADDR
              BCS ORDER_CONTINUE
              INC RAD_ADDR + 1
        ORDER_CONTINUE
              DEX
              BNE READ_ORDER
              RTS
              
; ************************************************************************************************
; * Read the pattern table
; * Y contains the position in the file
; ************************************************************************************************
READ_PATTERNS_10
              ; RAD_PATTRN holds the pattern number
              STZ RAD_PATTRN
              ; high byte of the pattern address
              LDA #<`PATTERNS
              STA RAD_PTN_DEST + 2
    NEXT_PATTERN
              
              ; read the file offset
              setal
              LDA [OPL2_ADDY_PTR_LO],Y
              BEQ SKIP_PATTERN
              
              PHY
              TAY
              
              ; compute the start address of the pattern
              LDA RAD_PATTRN
              AND #$00FF
              STA @lM0_OPERAND_A
              LDA #PATTERN_BYTES
              STA @lM0_OPERAND_B
              LDA @lM0_RESULT
              INC A ; skip the pattern byte
              STA RAD_PTN_DEST
              
              setas
              JSR READ_PATTERN_10
              PLY
              
    SKIP_PATTERN
              INY
              INY
              setas
              INC RAD_PATTRN
              LDA RAD_PATTRN
              CMP #32
              BNE NEXT_PATTERN
              RTS
              
; ************************************************************************************************
; * Read the pattern table
; * Y contains the position in the RAD 1.0 file
; * RAD_PTN_DEST is the address to write to
; ************************************************************************************************
READ_PATTERN_10
              LDA [OPL2_ADDY_PTR_LO],Y ; read the line number - bit 7 indicates the last line 
              STA @lRAD_LINE
              INY
              setal
              AND #$7F
              STA @lM0_OPERAND_A
              LDA #LINE_BYTES
              STA @lM0_OPERAND_B
              LDA @lM0_RESULT
              INC A ; skip the line number
              STA @lRAD_LINE_PTR
              setas
              
    READ_NOTE
              LDX RAD_LINE_PTR ; X contains the offset in the destination memory

              LDA [OPL2_ADDY_PTR_LO],Y ; channel - bit 7 indicates the last note
              INY
              STA @lRAD_LAST_NOTE
              AND #$F
              STA @lRAD_CHANNEL
              
              setal
              TXA
              CLC
              ADC RAD_CHANNEL ; multiply channel by 3
              ADC RAD_CHANNEL 
              ADC RAD_CHANNEL
              TAX
              setas
              
              LDA [OPL2_ADDY_PTR_LO],Y ; note / octave
              PHY
              TXY
              STA [RAD_PTN_DEST],Y
              PLY
              INY
              INX 
              
              LDA [OPL2_ADDY_PTR_LO],Y ; instrument/effect
              PHY
              TXY
              STA [RAD_PTN_DEST],Y
              PLY
              INY
              INX
              
              AND #$F
              BEQ CHECK_LASTNOTE
              
              LDA [OPL2_ADDY_PTR_LO],Y ; effect parameter
              PHY
              TXY
              STA [RAD_PTN_DEST],Y
              PLY
              INY
              INX
     CHECK_LASTNOTE
              LDA @lRAD_LAST_NOTE
              BPL READ_NOTE
              
              LDA @lRAD_LINE
              BPL READ_PATTERN_10

              RTS

; Output
; Y = Is the Pointer in the File to the next Patternlist.
; This is a 16Bits Offset, it needs to be added to absolute Starting address of the File
;
RADPLAYER_NEXTORDER
              setas
              LDY #$0000
              LDA #$00
              STA RAD_STARTLINE
              ;  order ++;
              LDA @lPlayerInfo.orders
              INC A
              STA @lPlayerInfo.orders
              TAY
              ;  if (order >= songLength && loopSong) {order = 0;}
              CMP @lTuneInfo.songLength
              BCS NotClearingOrder
              LDA @lPlayerInfo.loopSong
              AND #$01
              CMP #$01
              BNE NotClearingOrder
              LDA #$00
              STA @lPlayerInfo.orders

NotClearingOrder
              setal
              ;  radFile.seekSet(orderListOffset + order);
              LDA @lTuneInfo.orderListOffset
              STA OPL2_ADDY_PTR_LO
              LDA @lTuneInfo.orderListOffset+2
              STA OPL2_ADDY_PTR_HI
              setax
              LDA [OPL2_ADDY_PTR_LO],Y ; (Y = orders)
              STA RAD_PATTERN_IDX     ;byte patternIndex = radFile.read();
              AND #$80
              CMP #$80
              BNE NoOrderJump
              ; Read the PatternIndex Again
              LDA [OPL2_ADDY_PTR_LO],Y ; (Y = orders)
              AND #$7F
              STA @lPlayerInfo.orders
              TAY ; Repoint to a new Order
              LDA [OPL2_ADDY_PTR_LO],Y ; (Y = orders)
              STA RAD_PATTERN_IDX     ;byte patternIndex = radFile.read();
NoOrderJump   setal
              AND #$00FF
              TAX
              LDA @lTuneInfo.patternOffsets,X
              TAY ; Keep the Pointer in Y,
              setas
              LDA #$00
              STA @lPlayerInfo.endOfPattern ; Set to False
              STA RAD_LINE
              ;  for (line = 0; line < startLine; line ++) {readLine();}
ReadMoreLine
              LDA RAD_STARTLINE
              CMP RAD_LINE
              BCS NoMoreLine2Read;
              JSL RADPLAYER_READLINE
              INC RAD_LINE
              BRA ReadMoreLine;
NoMoreLine2Read
              STY RAD_Y_POINTER
              RTL


;
RADPLAYER_READLINE
              setas
              LDY RAD_Y_POINTER
              ;  // Reset note data on each channel.
              LDA #$00
              LDX #$0000
ClearChannelNote
              STA @lPlayerInfo.channelNote,X
              INX
              CPX #18
              BCC ClearChannelNote
              ;// If the previous line was the last line of the pattern then we're done.
              LDA @lPlayerInfo.endOfPattern ; if <> 0 (or True) Exit
              CMP #$00
              BNE ReadLineEndOfPattern
              setal
              LDA #<>RAD_FILE_TEMP ; Set the Pointer where the File Begins
              STA OPL2_ADDY_PTR_LO;
              LDA #<`RAD_FILE_TEMP
              STA OPL2_ADDY_PTR_HI;
              setas
              LDA [OPL2_ADDY_PTR_LO],Y
              STA RAD_LINENUMBER
              AND #$3F
              CMP RAD_LINE
              BEQ MoveOnWithReadLine
              DEY
              STY RAD_Y_POINTER
              RTL
MoveOnWithReadLine
              LDA RAD_LINENUMBER
              AND #$80
              STA @lPlayerInfo.endOfPattern
              LDX #$0000
NextChannelProcess
              ;// Read note and effect data for each channel.
              INY
              LDA [OPL2_ADDY_PTR_LO],Y ;byte channelNumber = radFile.read();
              STA RAD_CHANNEL_NUM
              AND #$80            ;   isLastChannel = channelNumber & 0x80;
              STA RAD_ISLASTCHAN
              LDA RAD_CHANNEL_NUM
              AND #$0F            ; channelNumber = channelNumber & 0x0F;
              STA RAD_CHANNEL_NUM
              ASL ;
              TAX
              INY
              LDA [OPL2_ADDY_PTR_LO],Y ;byte channelNumber = radFile.read();
              STA @lPlayerInfo.channelNote+1, X
              INY
              LDA [OPL2_ADDY_PTR_LO],Y ;byte channelNumber = radFile.read();
              STA @lPlayerInfo.channelNote, X
              setal
              LDA @lPlayerInfo.channelNote, X
              AND #$000F
              CMP #$0000
              BEQ NoEffectParameter
              setas
              LDA RAD_CHANNEL_NUM
              TAX
              INY
              LDA [OPL2_ADDY_PTR_LO],Y ;byte channelNumber = radFile.read();
              STA @lPlayerInfo.efftectParameter,X
              BRA MoveOnToNextChannel
NoEffectParameter
              setas
              LDA RAD_CHANNEL_NUM
              TAX
              LDA #$00
              STA @lPlayerInfo.efftectParameter,X
MoveOnToNextChannel
              LDA RAD_ISLASTCHAN
              CMP #$00
              BEQ NextChannelProcess
ReadLineEndOfPattern
              STY RAD_Y_POINTER
              RTL

; This part will be called by the Interrupt Handler
PLAYMUSIC
              setas
              LDA #$00
              STA RAD_CHANNEL_NUM

              setal
              LDA RAD_CHANNEL_NUM
              AND #$00FF
              TAX
              LDA @lPlayerInfo.channelNote, X
              STA RAD_CHANNEL_DATA
              setas
              AND #$0F
              STA RAD_CHANNE_EFFCT

              LDA RAD_TICK
              CMP #$00
              BEQ InstrumentSetup
              BRL NoInstrumentSetup
InstrumentSetup
              CLC
              LDA RAD_CHANNEL_DATA+1
              AND #$80
              LSR A
              LSR A
              LSR A
              STA RAD_TEMP
              LDA RAD_CHANNEL_DATA
              AND #$F0
              LSR A
              LSR A
              LSR A
              LSR A
              ADC RAD_TEMP
              STA OPL2_PARAMETER3 ; Save Instruments
              LDA RAD_CHANNEL_DATA+1
              AND #$70
              LSR A
              LSR A
              LSR A
              LSR A
              STA OPL2_OCTAVE
              LDA RAD_CHANNEL_DATA+1
              AND #$0F
              STA OPL2_NOTE
              LDA RAD_CHANNEL_NUM
              STA OPL2_CHANNEL
              LDA OPL2_PARAMETER3
              CMP #$00
              BEQ BypassSetupInstrument
              JSR RAD_SETINSTRUMENT

BypassSetupInstrument
              setas
              LDA OPL2_NOTE
              CMP #$0F
              BNE NoSetKeyOn
              ;      // Stop note.
              LDA #$00
              STA OPL2_PARAMETER0
              JSL OPL2_SET_KEYON
              BRA MoveOn2ProcessLineEffect
NoSetKeyOn
              LDA RAD_CHANNE_EFFCT
              CMP #EFFECT_NOTE_SLIDE_TO
              BEQ MoveOn2ProcessLineEffect
              ;      // Trigger note.
              JSR RAD_PLAYNOTE

MoveOn2ProcessLineEffect
              setas ; This is for security, just in case
              LDA RAD_CHANNE_EFFCT
              CMP #EFFECT_NOTE_SLIDE_TO
              BNE NoEffectNoteSlideTo
              LDA OPL2_NOTE
              CMP #$00
              BNE NoteBiggerThanZero
              BRL DoneWithEffectSwitchCase
NoteBiggerThanZero
              CMP #$0F
              BCC NoteUnderFifteen
              BRL DoneWithEffectSwitchCase
NoteUnderFifteen
              setal
              LDA RAD_CHANNEL_NUM ; Multiply by 2
              AND #$00FF
              ASL A
              TAX
              setas
              ; Compute the (Note/12) First
              ; Set Octave
              LDA OPL2_NOTE    ;Divide Note/12
              STA D0_OPERAND_A
              LDA #$00
              STA D0_OPERAND_A+1
              STA D0_OPERAND_B+1
              LDA #$0C
              STA D0_OPERAND_B
              CLC
              LDA OPL2_OCTAVE
              ADC D0_RESULT
              ASL A
              ASL A
              ASL A
              ASL A
              STA @lPlayerInfo.pitchSlideDest+1,X
              LDA #$00
              STA @lPlayerInfo.pitchSlideDest,X
              PHX
              setal
              CLC
              LDA OPL2_NOTE
              AND #$00FF
              ADC D0_REMAINDER    ; Remainder of the Division Modulo
              ASL A ;<<<<<<<<<<<<<<<<<<<<<<<<<
              TAX
              CLC
              LDA @lnoteFNumbers,X
              PLX
              ADC @lPlayerInfo.pitchSlideDest,X
              STA @lPlayerInfo.pitchSlideDest,X
              LDA RAD_CHANNEL_NUM
              AND #$00FF
              TAX
              setas
              LDA @lPlayerInfo.efftectParameter,X
              STA @lPlayerInfo.pitchSlideSpeed,X
              BRA DoneWithEffectSwitchCase
NoEffectNoteSlideTo
              CMP #EFFECT_SET_VOLUME
              BNE NoEffectSetVolume
              LDA #$01
              STA OPL2_OPERATOR
              setxs
              LDX OPL2_CHANNEL
              LDA #64
              SBC @lPlayerInfo.efftectParameter,X
              STA OPL2_PARAMETER0
              setxl
              JSL OPL2_SET_VOLUME
              BRA DoneWithEffectSwitchCase

NoEffectSetVolume
              CMP #EFFECT_PATTERN_BREAK
              BNE NoEffectPatternBreak
              LDX OPL2_CHANNEL
              LDA @lPlayerInfo.efftectParameter,X
              STA @lPlayerInfo.patternBreak
              BRA DoneWithEffectSwitchCase

NoEffectPatternBreak
              CMP #EFFECT_SET_SPEED
              BNE DoneWithEffectSwitchCase
              LDX OPL2_CHANNEL
              LDA @lPlayerInfo.efftectParameter,X
              STA @lPlayerInfo.speed
DoneWithEffectSwitchCase


NoInstrumentSetup ; Point outside of Tick == 0
              setas ; This is for security, just in case
              LDA RAD_CHANNE_EFFCT
              CMP #EFFECT_NOTE_SLIDE_UP
              BNE No_Effect_Note_Slide_Up


              BRA DoneWithTickEffects
No_Effect_Note_Slide_Up
              CMP #EFFECT_NOTE_SLIDE_DOWN
              BNE No_Effect_Note_Slide_Down


              BRA DoneWithTickEffects
No_Effect_Note_Slide_Down
              CMP #EFFECT_NOTE_SLIDE_VOLUME
              BNE No_Effect_Note_Slide_Volume



              BRA DoneWithTickEffects
No_Effect_Note_Slide_Volume
              CMP #EFFECT_NOTE_SLIDE_TO
              BNE No_Effect_Note_Slide_To



              BRA DoneWithTickEffects
No_Effect_Note_Slide_To
              CMP #EFFECT_VOLUME_SLIDE
              BNE No_Effect_Volume_Slide
              NOP

DoneWithTickEffects
No_Effect_Volume_Slide
              RTL


RAD_PITCH_ADJUST
              setal
              LDA OPL2_PARAMETER2 ;amount = OPL2_PARAMETER2, OPL2_PARAMETER3
              JSL OPL2_GET_BLOCK
              STA OPL2_BLOCK
              JSL OPL2_GET_FNUMBER ;OPL2_PARAMETER0, OPL2_PARAMETER1
              setal
              CLC
              LDA OPL2_PARAMETER2
              ADC OPL2_PARAMETER0
              STA OPL2_PARAMETER0
              AND #$03FF
              CMP #FNUMBER_MIN ; 0x156
              BCS IncreaseOneOctave
              setas
              LDA OPL2_BLOCK
              CMP #$00
              BEQ ExitDropAnOctave
              DEC OPL2_BLOCK
;
;
;  // Drop one octave (if possible) when the F-number drops below octave minimum.
;  if (fNumber < FNUMBER_MIN) {
;    if (block > 0) {
;      block --;
;      fNumber = FNUMBER_MAX - (FNUMBER_MIN - fNumber);
;    }

;  // Increase one octave (if possible) when the F-number reaches above octave maximum.
;  } else if (fNumber > FNUMBER_MAX) {
;    if (block < 7) {
;      block ++;;
;      fNumber = FNUMBER_MIN + (fNumber - FNUMBER_MAX);;
;    }
;  }




ExitDropAnOctave
IncreaseOneOctave

              RTS


RAD_PLAYNOTE
              setas
              LDA #$00
              STA OPL2_PARAMETER0 ; Set Keyon False
              JSL OPL2_SET_KEYON
              ; Set Octave
              LDA OPL2_NOTE    ;Divide Note/12
              STA D0_OPERAND_A
              LDA #$00
              STA D0_OPERAND_A+1
              STA D0_OPERAND_B+1
              LDA #$0C
              STA D0_OPERAND_B
              CLC
              LDA OPL2_OCTAVE
              PHA
              ADC D0_RESULT
              STA OPL2_OCTAVE
              JSL OPL2_SET_BLOCK  ; OPL2_SET_BLOCK Already to OPL2_OCTAVE
              ; Now lets go pick the FNumber for the note we want
              PLA
              STA OPL2_OCTAVE
              setal
              CLC
              LDA OPL2_NOTE
              AND #$00FF
              ADC D0_REMAINDER    ; Remainder of the Division Modulo
              ASL A ;<<<<<<<<<<<<<<<<<<<<<<<<<
              TAX
              LDA @lnoteFNumbers,X
              ADC D0_REMAINDER    ; Remainder of the Division Modulo
              STA OPL2_PARAMETER0 ; Store the 16bit in Param OPL2_PARAMETER0 & OPL2_PARAMETER1
              JSL OPL2_SET_FNUMBER
              setas
              LDA #$01
              STA OPL2_PARAMETER0 ; Set Keyon False
              JSL OPL2_SET_KEYON
              setxl
              RTS

;
RAD_SETINSTRUMENT
              PHY
              ; Carrier
              setas
              LDA #$01
              STA OPL2_OPERATOR
              setal

              LDA #<`INSTRUMENT_ACCORDN
              STA OPL2_ADDY_PTR_HI
              LDA OPL2_PARAMETER0
              AND #$00FF
              DEC A
              ASL A
              ASL A
              ASL A
              ASL A
              CLC
              ADC #<>INSTRUMENT_ACCORDN
              STA OPL2_ADDY_PTR_LO
              setal
              LDA #$0020
              JSL OPL2_GET_REG_OFFSET
              setas
              LDY #$0000
              LDA [OPL2_ADDY_PTR_LO],Y
              STA [OPL2_IND_ADDY_LL]
              setal
              LDA #$0040
              JSL OPL2_GET_REG_OFFSET
              setas
              LDY #$0002
              LDA [OPL2_ADDY_PTR_LO],Y
              STA [OPL2_IND_ADDY_LL]
              setal
              LDA #$0060
              JSL OPL2_GET_REG_OFFSET
              setas
              LDY #$0004
              LDA [OPL2_ADDY_PTR_LO],Y
              STA [OPL2_IND_ADDY_LL]
              setal
              LDA #$0080
              JSL OPL2_GET_REG_OFFSET
              setas
              LDY #$0006
              LDA [OPL2_ADDY_PTR_LO],Y
              STA [OPL2_IND_ADDY_LL]
              setal
              LDA #$00E0
              JSL OPL2_GET_REG_OFFSET
              setas
              LDY #$0009
              LDA [OPL2_ADDY_PTR_LO],Y
              AND #$0F
              STA [OPL2_IND_ADDY_LL]
              ; MODULATOR
              LDA #$00
              STA OPL2_OPERATOR
              ;  opl2.setRegister(0x20 + registerOffset, instruments[instrumentIndex][1]);
              setal
              LDA #$0020
              JSL OPL2_GET_REG_OFFSET
              setas
              LDY #$0001
              LDA [OPL2_ADDY_PTR_LO],Y
              STA [OPL2_IND_ADDY_LL]
              ;  opl2.setRegister(0x40 + registerOffset, instruments[instrumentIndex][3]);
              setal
              LDA #$0040
              JSL OPL2_GET_REG_OFFSET
              setas
              LDY #$0003
              LDA [OPL2_ADDY_PTR_LO],Y
              STA [OPL2_IND_ADDY_LL]
              ; opl2.setRegister(0x60 + registerOffset, instruments[instrumentIndex][5]);
              setal
              LDA #$0060
              JSL OPL2_GET_REG_OFFSET
              setas
              LDY #$0005
              LDA [OPL2_ADDY_PTR_LO],Y
              STA [OPL2_IND_ADDY_LL]
              ;  opl2.setRegister(0x80 + registerOffset, instruments[instrumentIndex][7]);
              setal
              LDA #$0080
              JSL OPL2_GET_REG_OFFSET
              setas
              LDY #$00071
              LDA [OPL2_ADDY_PTR_LO],Y
              STA [OPL2_IND_ADDY_LL]
              ;  opl2.setRegister(0xE0 + registerOffset, (instruments[instrumentIndex][9] & 0xF0) >> 4);
              setal
              LDA #$00E0
              JSL OPL2_GET_REG_OFFSET
              setas
              LDY #$0009
              LDA [OPL2_ADDY_PTR_LO],Y
              AND #$F0
              LSR A
              LSR A
              LSR A
              LSR A
              STA [OPL2_IND_ADDY_LL]
              ;  opl2.setRegister(0xC0 + channel, instruments[instrumentIndex][8]);
              LDA OPL2_CHANNEL
              CLC
              AND #$0F  ; This is just precaution, it should be between 0 to 8
              ADC #$C0
              STA OPL2_REG_OFFSET
              LDA #$00
              STA OPL2_REG_OFFSET+1;
              setaxl
              CLC
              LDA #<>OPL2_S_BASE
              ADC OPL2_REG_OFFSET
              STA OPL2_IND_ADDY_LL
              LDA #`OPL2_S_BASE
              STA OPL2_IND_ADDY_HL
              setas
              LDY #$0008
              LDA [OPL2_ADDY_PTR_LO],Y
              STA [OPL2_IND_ADDY_LL]
              PLY
              RTS

COMPUTE_POINTER
              setal
              LDA #$000A ; Clear  ; Let's Find the Pointer in the Instruments List
              STA M1_OPERAND_A
              LDA OPL2_PARAMETER0 ; Which Entry in the list
              STA M1_OPERAND_B  ;
              CLC
              LDA OPL2_IND_ADDY_LL
              ADC M1_RESULT
              STA OPL2_IND_ADDY_LL
              RTS
;
;#define OPERATOR1 0
;#define OPERATOR2 1
;#define MODULATOR 0
;#define CARRIER   1

* = $170000
TuneInfo .dstruct SongData

.align 16
PlayerInfo .dstruct PlayerVariables


* = $178000
RAD_FILE_TEMP
.binary "RAD_Files/adlibsp.rad"
