
.cpu "65816"
.include "OPL2_def.asm"
;.include "OPL2_Instruments.asm"
;.include "OPL2_Midi_Drums.asm"
;.include "OPL2_Midi_Instruments.asm"
;.include "OPL2_Midi_Instruments_Win31.asm"

;In some assemblers, BGE (Branch if Greater than or Equal) and BLT (Branch if Less Than) are synonyms for BCS and BCC, respectively.
; BCS ( A > = DATA )
; BCC (  A < DATA )
; BMI ( < ) (Signed)
; BPL ( > )
; BEQ ( A == DATA )
; BNE ( A < > DATA )
;

IOPL2_TONE_TEST
                setas
                ; Set Op
                LDA #$01
                STA OPL2_OPERATOR
                setaxl
                JSL OPL2_INIT
                setas
                LDA #$00
                STA OPL2_LOOP

;Setup channels 0, 1 and 2 to produce a bell sound.
OPL2_TONE_TESTING_L0

                setas
                LDA OPL2_LOOP
                STA OPL2_CHANNEL
                SEC
                JSL OPL2_SET_TREMOLO
                SEC
                JSL OPL2_SET_VIBRATO
                ; Set Multiplier
                LDA #$04
                STA OPL2_PARAMETER0
                JSL OPL2_SET_MULTIPLIER
                LDA #$0A
                STA OPL2_PARAMETER0
                JSL OPL2_SET_ATTACK
                LDA #$04
                STA OPL2_PARAMETER0
                JSL OPL2_SET_DECAY
                LDA #$0F
                STA OPL2_PARAMETER0
                JSL OPL2_SET_SUSTAIN
                LDA #$0F
                STA OPL2_PARAMETER0
                JSL OPL2_SET_RELEASE
                setas
                INC OPL2_LOOP
                LDA OPL2_LOOP
                CMP #$03
                BNE OPL2_TONE_TESTING_L0

                LDA #$00
                STA OPL2_LOOP

OPL2_TONE_TESTING_L1
                STA OPL2_NOTE
                AND #$03        ; replace modulo 3
                STA OPL2_CHANNEL
                LDA #$03
                STA OPL2_OCTAVE
                JSL OPL2_PLAYNOTE

                setas
                setxl
                LDX #$0000
; Delay around 30ms
OPL2_TONE_TESTING_L2
                NOP
                NOP
                NOP
                NOP
                INX
                CPX #$FFFF
                BNE OPL2_TONE_TESTING_L2
                ;
                ; DELAY of 300ms Here
                ;
                INC OPL2_LOOP
                LDA OPL2_LOOP
                CMP #12
                BNE OPL2_TONE_TESTING_L1

                RTL

;;__________________This ONE
OPL2_INIT
                setal
                ; Just Making sure all the necessary variables are cleared before doing anything
                LDA #$0000
                STA OPL2_REG_REGION
                STA OPL2_REG_OFFSET
                STA OPL2_IND_ADDY_LL
                STA OPL2_IND_ADDY_HL
                STA OPL2_NOTE
                STA OPL2_PARAMETER0
                STA OPL2_PARAMETER2
                RTL


OPL2_Reset
                RTL


OPL2_Get_FrequencyBlock
                RTL
OPL2_Get_Register         ; Return Byte, Param: (byte reg)
                RTL
OPL2_Get_WaveFormSelect   ; Return Bool
                RTL

OPL2_Get_ScalingLevel     ; Return Byte, Param: (byte channel, byte operatorNum);
                RTL


OPL2_Get_Block            ; Return Byte, Param: (byte channel);
                RTL
OPL2_Get_KeyOn            ; Return Bool, Param: (byte channel);
                RTL
OPL2_Get_Feedback         ; Return Byte, Param: (byte channel);
                RTL
OPL2_Get_SynthMode        ; Return Bool, Param: (byte channel);
                RTL
OPL2_Get_DeepTremolo      ; Return Bool, Param: (none);
                RTL
OPL2_Get_DeepVibrato      ; Return Bool, Param: (none);
                RTL
OPL2_Get_Percussion       ; Return Bool, Param: (none);
                RTL
OPL2_Get_Drums            ; Return Byte, Param: (none);
                RTL
OPL2_Get_WaveForm         ; Return Byte, Param: (byte channel, byte operatorNum);

                RTL

OPL2_PLAYNOTE           ;Return void, Param: (byte channel, byte octave, byte note);
                setas
                LDA #$00
                STA OPL2_PARAMETER0 ; Set Keyon False
                JSR OPL2_SET_KEYON
                ; Set Octave
                JSR OPL2_SET_BLOCK  ; OPL2_SET_BLOCK Already to OPL2_OCTAVE
                ; Now lets go pick the FNumber for the note we want
                setxs
                setal
                LDX OPL2_NOTE
                LDA @lnoteFNumbers,X
                STA OPL2_PARAMETER0 ; Store the 16bit in Param OPL2_PARAMETER0 & OPL2_PARAMETER1
                JSL OPL2_SET_FNUMBER
                setas
                LDA #$01
                STA OPL2_PARAMETER0 ; Set Keyon False
                JSR OPL2_SET_KEYON
                RTL

OPL2_PLAYDRUM             ;Return void, Param: (byte drum, byte octave, byte note);
                RTL

OPL2_Set_Instrument         ;Return Byte, Param: (byte channel, const unsigned char *instrument);
                RTL
OPL2_Set_Register           ;Return Byte, Param: (byte reg, byte value);
                RTL
OPL2_Set_WaveFormSelect     ;Return Byte, Param: (bool enable);
                RTL

;OPL2_SET_TREMOLO
; Inputs
; C = Enable (1 = Enable, 0 = Disable)
;OPL2_OPERATOR    = $000028 ;
;OPL2_CHANNEL     = $000029 ;
;OPL2_ENABLE      = $00002A ;
;OPL2_REG_OFFSET  = $00002B ;
; Output
;
; Note: Only Support Stereo (dual Write) - No Individual (R-L Channel) Target
OPL2_SET_TREMOLO            ;Return Byte, Param: (byte channel, byte operatorNum, bool enable);
                PHP ; Push the Carry
                setal
                LDA #$0020;
                STA OPL2_REG_REGION
                JSR OPL2_GET_REG_OFFSET
                ; Now Check if we are going to enable the bit or disable it
                PLP ; Pull the Carry out
                setas
                BCS OPL2_Set_Tremolo_Set;
                ; Clear the Bit
                LDA [OPL2_IND_ADDY_LL]
                AND #$7F
                STA [OPL2_IND_ADDY_LL]
                BRA OPL2_Set_Tremolo_Exit
                ; Set the Bit
OPL2_Set_Tremolo_Set
                LDA [OPL2_IND_ADDY_LL]
                ORA #$80
                STA [OPL2_IND_ADDY_LL]
                ; Let's get out of here
OPL2_Set_Tremolo_Exit
                RTL

;OPL2_SET_TREMOLO
; Inputs
;OPL2_OPERATOR    = $000028 ;
;OPL2_CHANNEL     = $000029 ;
;OPL2_ENABLE      = $00002A ;
;OPL2_REG_OFFSET  = $00002B ;
; Output
; A = Tremolo Status Bit7
OPL2_GET_TREMOLO          ; Return Bool, Param: (byte channel, byte operatorNum);
                setal
                LDA #$0020;
                STA OPL2_REG_REGION
                JSR OPL2_GET_REG_OFFSET
                LDA [OPL2_IND_ADDY_LL]
                AND #$80
                RTL

;OPL2_SET_VIBRATO
; Inputs
; C = Enable
;OPL2_OPERATOR    = $000028 ;
;OPL2_CHANNEL     = $000029 ;
;OPL2_ENABLE      = $00002A ;
;OPL2_REG_OFFSET  = $00002B ;
; C = Enable (1 = Enable, 0 = Disable)
OPL2_SET_VIBRATO            ;Return Byte, Param: (byte channel, byte operatorNum, bool enable);
                PHP ; Push the Carry
                setal
                LDA #$0020;
                STA OPL2_REG_REGION
                JSR OPL2_GET_REG_OFFSET
                ; Now Check if we are going to enable the bit or disable it
                PLP ; Pull the Carry out
                setas
                BCS OPL2_Set_Vibrato_Set;
                ; Clear the Bit
                LDA [OPL2_IND_ADDY_LL]
                AND #$BF
                STA [OPL2_IND_ADDY_LL]
                BRA OPL2_Set_Vibrato_Exit
                ; Set the Bit
OPL2_Set_Vibrato_Set
                LDA [OPL2_IND_ADDY_LL]
                ORA #$40
                STA [OPL2_IND_ADDY_LL]
                ; Let's get out of here
OPL2_Set_Vibrato_Exit
                RTL
;
;OPL2_GET_VIBRATO
; Inputs
;OPL2_OPERATOR    = $000028 ;
;OPL2_CHANNEL     = $000029 ;
;OPL2_ENABLE      = $00002A ;
;OPL2_REG_OFFSET  = $00002B ;
; Output
; A = Tremolo Status Bit6
OPL2_GET_VIBRATO          ; Return Bool, Param: (byte channel, byte operatorNum);
                setal
                LDA #$0020;
                STA OPL2_REG_REGION
                JSR OPL2_GET_REG_OFFSET
                LDA [OPL2_IND_ADDY_LL]
                AND #$40
                RTL
;OPL2_SET_MAINTAINSUSTAIN
;
OPL2_Set_MaintainSustain    ;Return Byte, Param: (byte channel, byte operatorNum, bool enable);

                RTL
;OPL2_GET_MAINTAINSUSTAIN
;
OPL2_Get_MaintainSustain  ; Return Bool, Param: (byte channel, byte operatorNum);

                RTL

OPL2_Set_EnvelopeScaling    ;Return Byte, Param: (byte channel, byte operatorNum, bool enable);

                RTL

OPL2_Get_EnvelopeScaling  ; Return Bool, Param: (byte channel, byte operatorNum);

                RTL


OPL2_Get_Multiplier       ; Return Byte, Param: (byte channel, byte operatorNum);
                RTL
;
;OPL2_SET_MULTIPLIER
; Inputs
; OPL2_OPERATOR    @ $000026 ;
; OPL2_CHANNEL     @ $000027 ;
; OPL2_REG_OFFSET  @ $00002A ;
; OPL2_PARAMETER0 = Multiplier
OPL2_SET_MULTIPLIER         ;Return Byte, Param: (byte channel, byte operatorNum, byte multiplier);
                setal
                LDA #$0020;
                STA OPL2_REG_REGION
                JSR OPL2_GET_REG_OFFSET
                setas
                LDA OPL2_PARAMETER0
                AND #$0F
                STA OPL2_PARAMETER0
                LDA [OPL2_IND_ADDY_LL]
                AND #$F0
                ORA OPL2_PARAMETER0
                STA [OPL2_IND_ADDY_LL]
                RTL
;
;
; REGISTERS REGION $40
;
;OPL2_SET_SCALINGLEVEL
; Inputs
; OPL2_OPERATOR    @ $000026 ;
; OPL2_CHANNEL     @ $000027 ;
; OPL2_REG_OFFSET  @ $00002A ;
; OPL2_PARAMETER0 = ScalingLevel
OPL2_SET_SCALINGLEVEL       ;Return Byte, Param: (byte channel, byte operatorNum, byte scaling);
                setal
                LDA #$0040;
                STA OPL2_REG_REGION
                JSR OPL2_GET_REG_OFFSET
                setas
                LDA OPL2_PARAMETER0 ; Attack
                AND #$03
                ASL
                ASL
                ASL
                ASL
                ASL
                ASL
                STA OPL2_PARAMETER0
                LDA [OPL2_IND_ADDY_LL]
                AND #$3F
                ORA OPL2_PARAMETER0
                STA [OPL2_IND_ADDY_LL]
                RTL
;OPL2_SET_VOLUME
; Inputs
; OPL2_OPERATOR    @ $000026 ;
; OPL2_CHANNEL     @ $000027 ;
; OPL2_REG_OFFSET  @ $00002A ;
; OPL2_PARAMETER0 = Volume
OPL2_SET_VOLUME             ;Return Byte, Param: (byte channel, byte operatorNum, byte volume);
                setal
                LDA #$0040  ;
                STA OPL2_REG_REGION
                JSR OPL2_GET_REG_OFFSET
                setas
                LDA OPL2_PARAMETER0 ; Volume
                AND #$3F
                STA OPL2_PARAMETER0
                LDA [OPL2_IND_ADDY_LL]
                AND #$C0
                ORA OPL2_PARAMETER0
                STA [OPL2_IND_ADDY_LL]
                RTL
;OPL2_GET_VOLUME
; Inputs
; OPL2_OPERATOR    @ $000026 ;
; OPL2_CHANNEL     @ $000027 ;
; OPL2_REG_OFFSET  @ $00002A ;
; Output
; A = Volume
OPL2_GET_VOLUME           ; Return Byte, Param: (byte channel, byte operatorNum);
                setal
                LDA #$0040  ;
                STA OPL2_REG_REGION
                JSR OPL2_GET_REG_OFFSET
                setas
                LDA [OPL2_IND_ADDY_LL]
                AND #$3F
                RTL
;
;
; REGISTERS REGION $60
;
;OPL2_SET_ATTACK
; Inputs
; OPL2_OPERATOR    @ $000026 ;
; OPL2_CHANNEL     @ $000027 ;
; OPL2_REG_OFFSET  @ $00002A ;
; OPL2_PARAMETER0 = Attack
OPL2_SET_ATTACK             ;Return Byte, Param: (byte channel, byte operatorNum, byte attack);
                setal
                LDA #$0060  ;
                STA OPL2_REG_REGION
                JSR OPL2_GET_REG_OFFSET
                setas
                LDA OPL2_PARAMETER0 ; Attack
                AND #$0F
                ASL
                ASL
                ASL
                ASL
                STA OPL2_PARAMETER0
                LDA [OPL2_IND_ADDY_LL]
                AND #$0F
                ORA OPL2_PARAMETER0
                STA [OPL2_IND_ADDY_LL]
                RTL
;
;OPL2_GET_ATTACK
; Inputs
; OPL2_OPERATOR    @ $000026 ;
; OPL2_CHANNEL     @ $000027 ;
; OPL2_REG_OFFSET  @ $00002A ;
; Output
; A = Attack
OPL2_GET_ATTACK           ; Return Byte, Param: (byte channel, byte operatorNum);
                setal
                LDA #$0060
                STA OPL2_REG_REGION
                JSR OPL2_GET_REG_OFFSET
                setas
                LDA [OPL2_IND_ADDY_LL]
                AND #$F0
                LSR
                LSR
                LSR
                LSR
                RTL
;OPL2_Set_Decay
; Inputs
; OPL2_OPERATOR    @ $000026 ;
; OPL2_CHANNEL     @ $000027 ;
; OPL2_REG_OFFSET  @ $00002A ;
; OPL2_PARAMETER0 = Decay
OPL2_SET_DECAY              ;Return Byte, Param: (byte channel, byte operatorNum, byte decay);
                setal
                LDA #$0060;
                STA OPL2_REG_REGION
                JSR OPL2_GET_REG_OFFSET
                setas
                LDA OPL2_PARAMETER0 ; Attack
                AND #$0F
                STA OPL2_PARAMETER0
                LDA [OPL2_IND_ADDY_LL]
                AND #$F0
                ORA OPL2_PARAMETER0
                STA [OPL2_IND_ADDY_LL]
                RTL
;
;OPL2_GET_DECAY
; Inputs
; OPL2_OPERATOR    @ $000026 ;
; OPL2_CHANNEL     @ $000027 ;
; OPL2_REG_OFFSET  @ $00002A ;
; Output
; A = Decay
OPL2_GET_DECAY           ; Return Byte, Param: (byte channel, byte operatorNum);
                setal
                LDA #$0060
                STA OPL2_REG_REGION
                JSR OPL2_GET_REG_OFFSET
                setas
                LDA [OPL2_IND_ADDY_LL]
                AND #$0F
                RTL
;
; REGISTERS REGION $80
;
;OPL2_SET_SUSTAIN
; Inputs
; OPL2_OPERATOR    @ $000026 ;
; OPL2_CHANNEL     @ $000027 ;
; OPL2_REG_OFFSET  @ $00002A ;
; OPL2_PARAMETER0 = Sustain
OPL2_SET_SUSTAIN            ;Return Byte, Param: (byte channel, byte operatorNum, byte sustain);
                setal
                LDA #$0080;
                STA OPL2_REG_REGION
                JSR OPL2_GET_REG_OFFSET
                setas
                LDA OPL2_PARAMETER0 ; Attack
                AND #$0F
                ASL
                ASL
                ASL
                ASL
                STA OPL2_PARAMETER0
                LDA [OPL2_IND_ADDY_LL]
                AND #$0F
                ORA OPL2_PARAMETER0
                STA [OPL2_IND_ADDY_LL]
                RTL
;
; OPL2_GET_SUSTAIN
; Inputs
; OPL2_OPERATOR    @ $000026 ;
; OPL2_CHANNEL     @ $000027 ;
; OPL2_REG_OFFSET  @ $00002A ;
; Output
; A = Decay
OPL2_GET_SUSTAIN          ; Return Byte, Param: (byte channel, byte operatorNum);
                setal
                LDA #$0080
                STA OPL2_REG_REGION
                JSR OPL2_GET_REG_OFFSET
                setas
                LDA [OPL2_IND_ADDY_LL]
                AND #$F0
                LSR
                LSR
                LSR
                LSR
                RTL
;
;OPL2_SET_RELEASE
; Inputs
; OPL2_OPERATOR    @ $000026 ;
; OPL2_CHANNEL     @ $000027 ;
; OPL2_REG_OFFSET  @ $00002A ;
; OPL2_PARAMETER0 = Decay
OPL2_SET_RELEASE            ;Return Byte, Param: (byte channel, byte operatorNum, byte release);
                setal
                LDA #$0080;
                STA OPL2_REG_REGION
                JSR OPL2_GET_REG_OFFSET
                setas
                LDA OPL2_PARAMETER0 ; Attack
                AND #$0F
                STA OPL2_PARAMETER0
                LDA [OPL2_IND_ADDY_LL]
                AND #$F0
                ORA OPL2_PARAMETER0
                STA [OPL2_IND_ADDY_LL]
                RTL
;
; OPL2_GET_RELEASE
; Inputs
; OPL2_OPERATOR    @ $000026 ;
; OPL2_CHANNEL     @ $000027 ;
; OPL2_REG_OFFSET  @ $00002A ;
; Output
; A = Decay
OPL2_GET_RELEASE          ; Return Byte, Param: (byte channel);
                setal
                LDA #$0080
                STA OPL2_REG_REGION
                JSR OPL2_GET_REG_OFFSET
                setas
                LDA [OPL2_IND_ADDY_LL]
                AND #$0F
                RTL
;
; REGISTERS REGION $A0
;
;OPL2_SET_FNUMBER
; Inputs
; OPL2_OPERATOR    @ $000026 ;
; OPL2_CHANNEL     @ $000027 ;
; OPL2_REG_OFFSET  @ $00002A ;
; OPL2_PARAMETER0 = LSB fNumber
; OPL2_PARAMETER1 = MSB fNumber
OPL2_SET_FNUMBER            ;Return Byte, Param: (byte channel, short fNumber);
                setas
                CLC
                LDA OPL2_CHANNEL
                AND #$0F  ; This is just precaution, it should be between 0 to 8
                ADC #$A0
                STA OPL2_REG_OFFSET
                LDA #$00
                STA OPL2_REG_OFFSET+1;
                setaxl
                ;Address Creation in $AFE700 Memory Section
                CLC
                LDA #OPL2_S_BASE_LL
                ADC OPL2_REG_OFFSET
                STA OPL2_IND_ADDY_LL
                LDA #OPL2_S_BASE_HL
                STA OPL2_IND_ADDY_HL
                setas
                LDA OPL2_PARAMETER0     ; Load the 16Bits Value of FNumber
                STA [OPL2_IND_ADDY_LL]  ; Load
                ; Let's go in Region $B0 Now
                CLC
                LDA OPL2_IND_ADDY_LL
                ADC #$10
                STA OPL2_IND_ADDY_LL
                LDA OPL2_PARAMETER1
                AND #$03
                STA OPL2_PARAMETER1
                LDA [OPL2_IND_ADDY_LL]
                AND #$FC
                ORA OPL2_PARAMETER1
                STA [OPL2_IND_ADDY_LL]
                RTL
;
; REGISTERS REGION $A0
;
;OPL2_SET_FNUMBER
; Inputs
; OPL2_OPERATOR    @ $000026 ;
; OPL2_CHANNEL     @ $000027 ;
; OPL2_REG_OFFSET  @ $00002A ;
; OPL2_PARAMETER0 = LSB fNumber
; OPL2_PARAMETER1 = MSB fNumber
OPL2_GET_FNUMBER
                setas
                CLC
                LDA OPL2_CHANNEL
                AND #$0F  ; This is just precaution, it should be between 0 to 8
                ADC #$A0
                STA OPL2_REG_OFFSET
                LDA #$00
                STA OPL2_REG_OFFSET+1;
                setaxl
                ;Address Creation in $AFE700 Memory Section
                CLC
                LDA #OPL2_S_BASE_LL
                ADC OPL2_REG_OFFSET
                STA OPL2_IND_ADDY_LL
                LDA #OPL2_S_BASE_HL
                STA OPL2_IND_ADDY_HL
                setas
                LDA [OPL2_IND_ADDY_LL]
                STA OPL2_PARAMETER0
                CLC
                LDA OPL2_IND_ADDY_LL
                ADC #$10
                STA OPL2_IND_ADDY_LL
                LDA [OPL2_IND_ADDY_LL]
                AND #$03
                STA OPL2_PARAMETER1
                RTL

OPL2_Set_Frequency          ;Return Byte, Param: (byte channel, float frequency);

                RTL
;
OPL2_Get_Frequency        ; Return Float, Param: (byte channel);
                RTL
;
;OPL2_SET_BLOCK
; Inputs
; OPL2_OPERATOR    @ $000026 ;
; OPL2_CHANNEL     @ $000027 ;
; OPL2_REG_OFFSET  @ $00002A ;
; OPL2_OCTAVE      = $000031 ; Destructive
; OPL2_PARAMETER0 = Block
OPL2_SET_BLOCK           ;Return Byte, Param: (byte channel, byte block);
                setas
                CLC
                LDA OPL2_CHANNEL
                AND #$0F  ; This is just precaution, it should be between 0 to 8
                ADC #$B0
                STA OPL2_REG_OFFSET
                LDA #$00
                STA OPL2_REG_OFFSET+1;
                setaxl
                ;Address Creation in $AFE700 Memory Section
                CLC
                LDA #OPL2_S_BASE_LL
                ADC OPL2_REG_OFFSET
                STA OPL2_IND_ADDY_LL
                LDA #OPL2_S_BASE_HL
                STA OPL2_IND_ADDY_HL
                setas
                LDA OPL2_OCTAVE
                AND #$07
                ASL
                ASL
                STA OPL2_OCTAVE
                LDA [OPL2_IND_ADDY_LL]
                AND #$E3
                ORA OPL2_OCTAVE
                STA [OPL2_IND_ADDY_LL]
                RTS
;
;OPL2_SET_KEYON
; Inputs
; OPL2_OPERATOR    @ $000026 ;
; OPL2_CHANNEL     @ $000027 ;
; OPL2_REG_OFFSET  @ $00002A ;
; OPL2_PARAMETER0 = Key On
OPL2_SET_KEYON              ;Return Byte, Param: (byte channel, bool keyOn);
                setas
                CLC
                LDA OPL2_CHANNEL
                AND #$0F  ; This is just precaution, it should be between 0 to 8
                ADC #$B0
                STA OPL2_REG_OFFSET
                LDA #$00
                STA OPL2_REG_OFFSET+1;
                setaxl
                ;Address Creation in $AFE700 Memory Section
                CLC
                LDA #OPL2_S_BASE_LL
                ADC OPL2_REG_OFFSET
                STA OPL2_IND_ADDY_LL
                LDA #OPL2_S_BASE_HL
                STA OPL2_IND_ADDY_HL
                setas
                LDA OPL2_PARAMETER0
                AND #$01
                ASL
                ASL
                ASL
                ASL
                ASL
                STA OPL2_PARAMETER0
                LDA [OPL2_IND_ADDY_LL]
                AND #$DF
                ORA OPL2_PARAMETER0
                STA [OPL2_IND_ADDY_LL]
                RTS

OPL2_Set_Feedback           ;Return Byte, Param: (byte channel, byte feedback);
                RTL
OPL2_Set_SynthMode          ;Return Byte, Param: (byte channel, bool isAdditive);
                RTL
OPL2_Set_DeepTremolo        ;Return Byte, Param: (bool enable);
                RTL
OPL2_Set_DeepVibrato        ;Return Byte, Param: (bool enable);
                RTL
OPL2_Set_Percussion         ;Return Byte, Param: (bool enable);
                RTL
OPL2_Set_Drums              ;Return Byte, Param: (bool bass, bool snare, bool tom, bool cymbal, bool hihat);
                RTL
OPL2_Set_WaveForm           ;Return Byte, Param: (byte channel, byte operatorNum, byte waveForm);
                RTL

                ; Local Routine (Can't be Called by Exterior Code)
OPL2_GET_REG_OFFSET
                setaxs
                ; Get the Right List
                LDA OPL2_CHANNEL
                AND #$0F
                TAX
                LDA OPL2_OPERATOR   ; Check which Operator In used
                AND #$01            ; if ZERO = The operator 1, One = Operator 2
                CMP #$01
                BEQ OPL2_Get_Register_Offset_l0
                LDA @lregisterOffsets_operator0, X
                BRA OPL2_Get_Register_Offset_exit
OPL2_Get_Register_Offset_l0
                LDA @lregisterOffsets_operator1, X
OPL2_Get_Register_Offset_exit
                STA OPL2_REG_OFFSET
                LDA #$00
                STA OPL2_REG_OFFSET+1;
                setaxl
                ;Address Creation in $AFE700 Memory Section
                CLC
                LDA #OPL2_S_BASE_LL
                ADC OPL2_REG_OFFSET
                ADC OPL2_REG_REGION ; Ex: $20, or $40, $60, $80 (in 16bits)
                STA OPL2_IND_ADDY_LL
                LDA #OPL2_S_BASE_HL
                STA OPL2_IND_ADDY_HL
                RTS
