; So, ISSO had some pretty interesting schematics for his own meta-sprites that I'm deciding to use.
; Start with the total animation length, after which it wraps. This anim stuff is its own function.
; Then # of frames to display the cel -- the DURATION
; THEN a pointer to the site itself.
; Repeat. Give # of frames.
; Then you can basically do this with whatever you want.


; ACTUALLY FUCK IT JUST DRAW ONE SPRITE GOD DAMN

; Take the number of objects and put it in a register... Then multiply it by 4?

SECTION "Metasprites", ROM0, ALIGN[8]

DEF SPR_NO_FLAGS EQU $00

; TODO: Convert to Rangi's helpful Macro (understand macros!)
OctopusIdleDraw:
; Objects arranged clockwise. from upper left.
.frame0
    db 4 ; Number of objects.
    db -4, -4, $07, SPR_NO_FLAGS
    db 4, -4, $08, SPR_NO_FLAGS 
    db 4, 4, $09, SPR_NO_FLAGS 
    db -4, 4, $10, SPR_NO_FLAGS

TwingoIdleDraw:
.frame0
    db 2 ;NumObjs
    db -4, 0, $00, SPR_NO_FLAGS
    db 4, 0, $01, SPR_NO_FLAGS

