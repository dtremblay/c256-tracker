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
          .text '[Version 0.0.2]' ; 15 characters
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
          .fill 5, 0
          .text 'Instrument [01]:'  ; 16 chars
          .fill 2, 0
          .text '        .INS' ; 13 chars`
          .fill 15, 0
          .byte $c2
          .fill 2, 0
          .text 'Order'
          .fill 20,0
          .byte $c2
          .fill UNUSED_SCR, 0

line7     .byte $ab
          .fill 50, $C3
          .byte $db
          .fill SCREEN_WIDTH - 50 -3, $C3
          .byte $b3
          .fill UNUSED_SCR, 0

lines8to22
          .rept 14
          .byte $c2
          .fill 50, 0
          .byte $c2
          .fill SCREEN_WIDTH - 50 -3,0
          .byte $c2
          .fill UNUSED_SCR, 0
          .next

line22    .byte $ab
          .fill 8, $C3  ; line
          .byte $b2
          .fill 11, $C3 ; pattern
          .byte $b2
          .fill 10, $C3 ; octave
          .byte $b2
          .fill 9, $C3 ; speed
          .byte $b2
          .fill 8, $C3
          .byte $b1
          .fill SCREEN_WIDTH - 50 -3, $C3
          .byte $b3
          .fill UNUSED_SCR, 0

line23
          .byte $c2
          .text 'Line: 01'   ; 8 chars
          .byte $c2
          .text 'Pattern: 01';11 chars
          .byte $c2
          .text 'Octave:  3' ;10 chars
          .byte $c2
          .text 'Speed:  4'  ; 9 chars
          .byte $c2
          .fill 2, 0
          .text '    TEST.TRK' ; 12 chars
          .fill 22, 0
          .byte $c2
          .fill UNUSED_SCR, 0

line24    .byte $ca
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

line25    .rept 8 ; 8 * 9
          .fill 8,$c3
          .byte $b2
          .next
          .fill 8,$c3
          .fill UNUSED_SCR, 0

line26    .for col = '1', col <= '9', col += 1
          .text ' - ',col,'  - '
          .byte $c2
          .next
          .fill UNUSED_SCR-1, 0

line27    .rept 9
          .fill 8,$c3
          .byte $db
          .next
          .fill UNUSED_SCR-1, 0

lines28to59
  .rept 8
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

line60    .rept 9
          .fill 8,$c3
          .byte $b1
          .next
          .fill UNUSED_SCR-1, 0

FNXFONT
          .binary "Font/FOENIX-CHARACTER-ASCII.bin", 0, 2048

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