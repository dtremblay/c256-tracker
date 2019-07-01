; each line is 80 characters
SCREEN_WIDTH = 80
UNUSED_SCR   = 128 - SCREEN_WIDTH
TRACKER_SCREEN

line1     .byte $D5
          .fill SCREEN_WIDTH - 2, $C3
          .byte $C9
          .fill 128 - SCREEN_WIDTH, 0

line2     .byte $c2
          .fill SCREEN_WIDTH - 2, 0
          .byte $c2
          .fill UNUSED_SCR, 0

line3     .byte $c2
          .fill (SCREEN_WIDTH - 40) / 2, 0
          .text 'C256 Foenix Tracker' ; 19 characters
          .fill 4, 0
          .text '[Version 0.0.3]' ; 15 characters
          .fill (SCREEN_WIDTH - 40) / 2, 0
          .byte $c2
          .fill UNUSED_SCR, 0

line4     .byte $c2
          .fill SCREEN_WIDTH - 2, 0
          .byte $c2
          .fill UNUSED_SCR, 0

line5     .byte $ab
          .fill 50, $C3
          .byte $b2
          .fill SCREEN_WIDTH - 50 -3, $C3
          .byte $b3
          .fill UNUSED_SCR, 0

line6     .byte $c2
          .fill 2, 0
          .byte $b0, $c3, $ae
          .text 'Instrument [---]:'  ; 16 chars
          .fill 2, 0
          .text '            ' ; 13 chars`
          .fill 9, 0
          .byte $b0, $c3, $ae
          .fill 2, 0
          .byte $c2
          .fill 2, 0
          .text 'Order'
          .fill 20,0
          .byte $c2
          .fill UNUSED_SCR, 0

line7     .byte $ab
          .fill 2, $C3
          .byte $bd
          .text '1'
          .byte $ad
          .fill 6, $C3
          .byte $b2
          .fill 3, $C3
          .byte $b2
          .fill 9, $C3
          .byte $99
          .fill 11, $C3
          .byte $b2
          .fill 3, $C3
          .byte $b2
          .fill 3, $C3
          .byte $bd
          .text '2'
          .byte $ad
          .fill 2, $C3
          .byte $db
          .fill SCREEN_WIDTH - 50 -3, $C3
          .byte $b3
          .fill UNUSED_SCR, 0

lines8
          .byte $c2
          .text 'Tremolo    '
          .byte $c2
          .text 'Off'
          .byte $c2
          .fill 9, 0
          .byte $9a
          .text 'Tremolo    '
          .byte $c2
          .text 'Off'
          .byte $c2
          .fill 8, 0
          .byte $c2
          .fill SCREEN_WIDTH - 50 -3,0
          .byte $c2
          .fill UNUSED_SCR, 0
          
lines9
          .byte $c2
          .text 'Vibrato    '
          .byte $c2
          .text 'Off'
          .byte $c2
          .fill 9, 0
          .byte $9a
          .text 'Vibrato    '
          .byte $c2
          .text 'Off'
          .byte $c2
          .fill 8, 0
          .byte $c2
          .fill SCREEN_WIDTH - 50 -3,0
          .byte $c2
          .fill UNUSED_SCR, 0
          
lines10
          .byte $c2
          .text 'Sustaining '
          .byte $c2
          .text 'Off'
          .byte $c2
          .fill 9, 0
          .byte $9a
          .text 'Sustaining '
          .byte $c2
          .text 'Off'
          .byte $c2
          .fill 8, 0
          .byte $c2
          .fill SCREEN_WIDTH - 50 -3,0
          .byte $c2
          .fill UNUSED_SCR, 0
          
lines11
          .byte $c2
          .text 'Scale Rate '
          .byte $c2
          .text 'Off'
          .byte $c2
          .fill 9, 0
          .byte $9a
          .text 'Scale Rate '
          .byte $c2
          .text 'Off'
          .byte $c2
          .fill 8, 0
          .byte $c2
          .fill SCREEN_WIDTH - 50 -3,0
          .byte $c2
          .fill UNUSED_SCR, 0
          
lines12
          .byte $c2
          .text 'Multiplier '
          .byte $c2
          .text ' 00'
          .byte $c2
          .fill 9, 0
          .byte $9a
          .text 'Multiplier '
          .byte $c2
          .text ' 00'
          .byte $c2
          .fill 8, 0
          .byte $c2
          .fill SCREEN_WIDTH - 50 -3,0
          .byte $c2
          .fill UNUSED_SCR, 0

lines13
          .byte $c2
          .text 'Scale Level'
          .byte $c2
          .text ' 00'
          .byte $c2
          .fill 9, 0
          .byte $9a
          .text 'Scale Level'
          .byte $c2
          .text ' 00'
          .byte $c2
          .fill 8, 0
          .byte $c2
          .fill SCREEN_WIDTH - 50 -3,0
          .byte $c2
          .fill UNUSED_SCR, 0
          
lines14
          .byte $c2
          .text 'Volume     '
          .byte $c2
          .text ' 00'
          .byte $c2
          .fill 9, 0
          .byte $9a
          .text 'Volume     '
          .byte $c2
          .text ' 00'
          .byte $c2
          .fill 8, 0
          .byte $c2
          .fill SCREEN_WIDTH - 50 -3,0
          .byte $c2
          .fill UNUSED_SCR, 0
          
lines15
          .byte $c2
          .text 'Attack     '
          .byte $c2
          .text ' 00'
          .byte $c2
          .fill 9, 0
          .byte $9a
          .text 'Attack     '
          .byte $c2
          .text ' 00'
          .byte $c2
          .fill 8, 0
          .byte $c2
          .fill SCREEN_WIDTH - 50 -3,0
          .byte $c2
          .fill UNUSED_SCR, 0
          
lines16
          .byte $c2
          .text 'Decay      '
          .byte $c2
          .text ' 00'
          .byte $c2
          .fill 9, 0
          .byte $9a
          .text 'Decay      '
          .byte $c2
          .text ' 00'
          .byte $c2
          .fill 8, 0
          .byte $c2
          .fill SCREEN_WIDTH - 50 -3,0
          .byte $c2
          .fill UNUSED_SCR, 0
          
lines17
          .byte $c2
          .text 'Sustain    '
          .byte $c2
          .text ' 00'
          .byte $c2
          .fill 9, 0
          .byte $9a
          .text 'Sustain    '
          .byte $c2
          .text ' 00'
          .byte $c2
          .fill 8, 0
          .byte $c2
          .fill SCREEN_WIDTH - 50 -3,0
          .byte $c2
          .fill UNUSED_SCR, 0
          
lines18
          .byte $c2
          .text 'Release    '
          .byte $c2
          .text ' 00'
          .byte $c2
          .fill 9, 0
          .byte $9a
          .text 'Release    '
          .byte $c2
          .text ' 00'
          .byte $c2
          .fill 8, 0
          .byte $c2
          .fill SCREEN_WIDTH - 50 -3,0
          .byte $c2
          .fill UNUSED_SCR, 0
          
lines19
          .byte $c2
          .text 'Wave Type  '
          .byte $c2
          .text ' 00'
          .byte $c2
          .fill 9, 0
          .byte $9a
          .text 'Wave Type  '
          .byte $c2
          .text ' 00'
          .byte $c2
          .fill 8, 0
          .byte $c2
          .fill SCREEN_WIDTH - 50 -3,0
          .byte $c2
          .fill UNUSED_SCR, 0
          
line20    .byte $ab
          .fill 11, $C3
          .byte $db
          .fill 3, $C3
          .byte $db
          .fill 9, $C3
          .byte $9b
          .fill 11, $C3
          .byte $db
          .fill 3, $C3
          .byte $db
          .fill 8, $C3
          .byte $db
          .fill SCREEN_WIDTH - 50 -3, $C3
          .byte $b3
          .fill UNUSED_SCR, 0
          
line21
          .byte $c2
          .text 'Panning    '
          .byte $c2
          .text ' 00'
          .byte $c2
          .fill 9, 0
          .byte $9a
          .text ' Feedback  '
          .byte $c2
          .text ' 00'
          .byte $c2
          .fill 8, 0
          .byte $c2
          .fill SCREEN_WIDTH - 50 -3,0
          .byte $c2
          .fill UNUSED_SCR, 0

line22
          .byte $c2
          .text 'Riff Speed '
          .byte $c2
          .text ' 00'
          .byte $c2
          .fill 9, 0
          .byte $9a
          .text ' Algorithm '
          .byte $c2
          .text ' 00'
          .byte $c2
          .fill 8, 0
          .byte $c2
          .fill SCREEN_WIDTH - 50 -3,0
          .byte $c2
          .fill UNUSED_SCR, 0

line23    .byte $ab
          .fill 8, $C3  ; line
          .byte $b2
          .fill 2, $C3 ; pattern
          .byte $b1
          .fill 3, $C3
          .byte $b1
          .fill 4, $C3
          .byte $b2
          .fill 4, $C3 ; octave
          .byte $9c
          .fill 5, $C3
          .byte $b2
          .fill 5, $C3 ; speed
          .byte $b1
          .fill 3, $C3
          .byte $db
          .fill 8, $C3
          .byte $b1
          .fill SCREEN_WIDTH - 50 -3, $C3
          .byte $b3
          .fill UNUSED_SCR, 0

line24
          .byte $c2
          .text 'Line: NA'   ; 8 chars
          .byte $c2
          .text 'Pattern: NA';11 chars
          .byte $c2
          .text 'Octave:  N' ;10 chars
          .byte $c2
          .text 'Speed:  N'  ; 9 chars
          .byte $c2
          .fill 2, 0
          .text '    TEST.TRK' ; 12 chars
          .fill 22, 0
          .byte $c2
          .fill UNUSED_SCR, 0

line25    .byte $ca
          .fill 8, $C3  ; line
          .byte $b1
          .fill 11, $C3 ; pattern
          .byte $b1
          .fill 10, $C3 ; octave
          .byte $b1
          .fill 9, $C3 ; speed
          .byte $b1
          .fill 8, $C3
          .byte $c3
          .fill 27, $C3
          .byte $cb
          .fill UNUSED_SCR, 0

line26    .rept 8 ; 8 * 9
          .fill 8,$c3
          .byte $b2
          .next
          .fill 8,$c3
          .fill UNUSED_SCR, 0

line27    .for col = '1', col <= '9', col += 1
          .text ' - ',col,'  - '
          .byte $c2
          .next
          .fill UNUSED_SCR-1, 0

line28    .rept 9
          .fill 8,$c3
          .byte $db
          .next
          .fill UNUSED_SCR-1, 0

lines29to56
  .rept 7
      .rept 3
          .rept 9
          .text '--- ----'
          .byte $c2
          .next
          .fill UNUSED_SCR-1, 0
      .next

      .rept 9
      .text '--- ----'
      .byte $db
      .next
      .fill UNUSED_SCR-1, 0
  .next

lines57to59
      .rept 3
          .rept 9
          .text '--- ----'
          .byte $c2
          .next
          .fill UNUSED_SCR-1, 0
      .next
      
line60    .rept 9
          .fill 8,$c3
          .byte $b1
          .next
          .fill UNUSED_SCR-1, 0

FNXFONT
          .binary "Font/FOENIX-CHARACTER-ASCII-2.bin", 0, 2048

.align 16

MOUSE_POINTER_PTR     .text $00,$01,$01,$00,$00,$00,$00,$00,$01,$01,$01,$00,$00,$00,$00,$00
                      .text $01,$FF,$FF,$01,$00,$00,$01,$01,$FF,$FF,$FF,$01,$00,$00,$00,$00
                      .text $01,$FF,$FF,$FF,$01,$01,$55,$FF,$01,$55,$FF,$FF,$01,$00,$00,$00
                      .text $01,$55,$FF,$FF,$FF,$FF,$01,$55,$FF,$FF,$FF,$FF,$01,$00,$00,$00
                      .text $00,$01,$55,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$01,$FF,$FF,$01,$00,$00
                      .text $00,$00,$01,$55,$FF,$FF,$FF,$FF,$01,$FF,$FF,$01,$FF,$01,$00,$00
                      .text $00,$00,$01,$01,$55,$FF,$FF,$FF,$FF,$01,$FF,$FF,$FF,$01,$00,$00
                      .text $00,$00,$01,$55,$01,$55,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$01,$01,$00
                      .text $00,$00,$01,$55,$55,$55,$FF,$FF,$FF,$FF,$FF,$FF,$01,$FF,$FF,$01
                      .text $00,$00,$00,$01,$55,$55,$55,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$01
                      .text $00,$00,$00,$00,$01,$55,$55,$55,$55,$55,$01,$FF,$FF,$55,$01,$00
                      .text $00,$00,$00,$00,$00,$01,$01,$01,$01,$01,$55,$FF,$55,$01,$00,$00
                      .text $00,$00,$00,$00,$00,$00,$00,$00,$01,$55,$55,$55,$01,$00,$00,$00
                      .text $00,$00,$00,$00,$00,$00,$00,$00,$01,$55,$55,$01,$00,$00,$00,$00
                      .text $00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$01,$00,$00,$00,$00,$00
                      .text $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00