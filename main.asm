INCLUDE "include/hardware.inc"
INCLUDE "include/mystructs.inc"
INCLUDE "include/metasprites.inc"

DEF DAS_INITIAL_TIMER EQU $14
DEF DAS_INTERVAL EQU $14
DEF TWINGO_MOVE_SPEED EQU $02

SECTION "Header", ROM0[$100]

EntryPoint: ; This is where execution begins
    ei ; enable interrupts.
    jp Start ; Leave this tiny space

REPT $150 - $104
    db 0
ENDR

SECTION "VBLANK interrupt", ROM0[$0040]
    jp VBlankHandler

SECTION "Game code", ROM0[$300]

Start:
    ; Copy the DMA Routine
    call CopyDMARoutine
    ; Enable VBlank Interrupt
    ld a, IEF_VBLANK
    ld [rIE], a
    ; No need to manually request the interrupt now.

    call WaitVBlank
    ld a, LCDCF_OFF
    ld [rLCDC], a

    ld hl, _SCRN0 
    ld b, HIGH(_SCRN1 - _SCRN0)
    ld c, LOW(_SCRN1 - _SCRN0)
    xor a
    call WipeMaps

    ld hl, _VRAM
    ld b, HIGH(_VRAM8800 - _VRAM)
    ld c, LOW(_VRAM8800 - _VRAM)
    xor a
    call WipeMaps

    ld hl, _VRAM
    ld de, GF  
    ld bc, GFEnd - GF

    call FCopyToVRAM

    ; Wipe the OAM and overwrite it with zeroes
    call WipeOAM

    ld a, HIGH(OAMVars)
    call hOAMDMA

    ; Set BG palette
    ld a, %11100100
    ld [rBGP], a
    ld [rOBP0], a


    ; Loading stuff into Twingo properties.
    ; TODO: fix this up by doing a LOAD
    ld a, $01
    ld [wTwingo_active], a
    ; He're we're loading "50" in hex. When we shift the bits by 4 to get our ultimate value... wait. Do we cut off the top 4 bits?
    ld a, $05
    ld [wTwingo_yPos + 1], a
    ld a, $50
    ld [wTwingo_yPos], a    
    ld a, $05
    ld [wTwingo_xPos], a
    ld a, $00
    ; Let's see if we can comment it out, but un-comment it if shit breaks
    ; ld [wTwingo_spriteData], a
    ; ld a, $01
    ; ld [wTwingo_spriteData + 1], a

    ld a, %10000010
    ld [rLCDC], a

    ld hl, BulletArray
    ld b, HIGH(BulletArrayEnd - BulletArray)
    ld c, LOW(BulletArrayEnd - BulletArray)
    xor a
    call WipeMaps

    
.gameLoop
    call JoypadHandler
    ld b, a

    ; Don't worry about the most significant position nibble for now
    ld a, [wTwingo_xPos +1]
    and $0F
    ld [wTwingo_xPos +1], a

    ld a, [wTwingo_yPos +1]
    and $0F
    ld [wTwingo_yPos +1], a


; TODO: instead of just turning off inputs, what's a better way we could do this? 
.checkCollision

    ; Use your extra HRAM work ram address for extra space, in this case replace "d" with it.

    
    ; How to cp a 16-bit number.
    ; You need two registers free, obviously. Let's just pretend h and l are free.
    ; So, first copy the full 16-bit value into de. HAVE A COPY, not the original.
    ; using a, minus the first part of the value from e, then sbc the next part from d.
    ; Then or d with e and see if it's zero.

    ; TODO: Change this to a more consistent little-Endian

.cCLeft
    ld b, b
    ld a, [wTwingo_xPos]
    ; cp $07
    sub $70 
    ld a, [wTwingo_xPos + 1]
    sbc $00
    jr nc, .cCRight
    res 5, b
.cCRight
    ld a, [wTwingo_xPos]
    ; cp $A1
    sub $10 ;
    ld a, [wTwingo_xPos + 1]
    sbc $0A
    jr c, .cCUp
    res 4, b
.cCUp
    ; cp $0B
    ld a, [wTwingo_yPos]
    sub $B0 ;
    ld a, [wTwingo_yPos + 1]
    sbc $00
    jr nc, .cCDown
    res 6, b
.cCDown
    ; cp $99
    ld a, [wTwingo_yPos]
    sub $90 ;
    ld a, [wTwingo_yPos + 1]
    sbc $09
    jr c, .joypadObject
    res 7, b


.joypadObject
    ; Do all input based calculations.
    ; Check for up/down input.
    ld a, [wTwingo_yPos]
    ld l, a
    ld a, [wTwingo_yPos + 1]
    ld h, a
    ; So right now, b has the joypad buttons, and hl has twingo's full spritepos y.
.checkDown
    bit 7, b ; Is the down key being pressed? If not...
    jr z, .checkUp ; Go check the up key
    ld d, $00
    ld e, 16
    add hl, de ; But if it is, here's 1!! positive = moving down the screen.
.checkUp
    bit 6, b 
    jr z, .udAdd
    ld d, $FF
    ld e, -16
    add hl, de

.udAdd
    ld a, l
    ld [wTwingo_yPos], a
    ld a, h
    ld [wTwingo_yPos + 1], a

    ld a, [wTwingo_xPos]
    ld l, a
    ld a, [wTwingo_xPos + 1]
    ld h, a
.checkRight
    bit 4, b ; Is the right key being pressed? If not...
    jr z, .checkLeft ; Go check the right key
    ld d, $00
    ld e, 16
    add hl, de ; But if it is, here's 1!! positive = moving down the screen.
.checkLeft
    bit 5, b ; Is the left key being pressed?
    jr z, .lrAdd ; If it's not, just go to addition.
    ld d, $FF
    ld e, -16
    add hl, de
.lrAdd
    ld a, l
    ld [wTwingo_xPos], a
    ld a, h
    ld [wTwingo_xPos + 1], a


; As tony soprano would say, "FUck dis, im waiting til I fix the positioning before dealing wit dis shit."
; .bulletShoot
;     ld a, [new_keys] ; Check pressed buttons
;     and PADF_A
;     ld c, a ; Pressed buttons, in this case a
;     jr z, .noDASReset ; If A is not newly pressed...
;     ld a, DAS_INITIAL_TIMER ; If it's a new key, then load the initial timer into wDASTimer
;     ld [wDASTimer], a
; .noDASReset
;     ld a, [cur_keys]
;     and PADF_A ; Check if a is being currently held
;     jr z, .noDAS ; If it's not, then get out of here
;     ld hl, wDASTimer ; If it is, though, decrement the timer...
;     dec [hl]
;     jr nz, .noDAS ; If the timer isn't zero yet, skip... But if it is...
;     ld [hl], DAS_INTERVAL 
;     set PADB_A, c ; Pretend that the A button is pressed
; .noDAS

;     bit PADB_A, c
;     jr z, .bulletUpdate

; .bulletInit
;     ld hl, BulletArray
;     ld d, LOW(BulletArrayEnd - BulletArray) / sizeof_Bullet
; .bulletInitLoop
;     bit 0, [hl]
;     jr z, .bulletInitSlotReady

; .bulletInitSlotFull
;     ld bc, $0004
;     add hl, bc 
;     jr .bulletInitLoopEnd

; .bulletInitSlotReady
;     set 0, [hl]
;     inc hl
;     ld a, [wTwingo_yPos]
;     ld [hli], a
;     ld a, [wTwingo_yPos + 1]
;     ld [hli], a

;     ld [hli], a
;     ld a, [wTwingo_xPos]
;     ld [hli], a
;     ld a, [wTwingo_xPos + 1]
;     ld a, $02
;     ld [hli], a
;     jr .bulletUpdate

; .bulletInitLoopEnd
;     dec d
;     jr nz, .bulletInitLoop

; .bulletUpdate
;     ld hl, BulletArray
;     ld d, LOW(BulletArrayEnd - BulletArray) / sizeof_Bullet
;     ld bc, -2 
; .bulletUpdateLoop
;     ; Check to see if it's past screen boundary
;     inc hl
;     inc hl
;     inc hl
;             ;cp $A9. Indenting this until i truly understand it.
;             ld a, [hli]
;             sub $90 
;             ld e, a
;             ld a, [hl]
;             sbc $0A
;             or e

; 	jp nz, .bulletUpdateReset

;     dec hl
;     dec hl
;     dec hl
;     dec hl
;     jr nz, .bulletUpdateLoopCheckBit
;     res 0, [hl] 

; .bulletUpdateLoopCheckBit
;     bit 0, [hl]
;     jr nz, .bulletUpdatePosition

; .bulletUpdateReset
;     xor a
;     ld [hli], a
;     ld [hli], a   
;     ld [hli], a
;     ld [hli], a
;     ld [hli], a
;     ld [hli], a   

;     jr .bulletUpdateLoopEnd
    
; .bulletUpdatePosition
;     inc hl
;     inc hl
;     inc hl 
;     ld a, [hl]
;     add a, $02
;     ld [hli], a
;     ld a, [hl]
;     adc a, 0
;     ld [hli], a
;     inc hl

; .bulletUpdateLoopEnd
;     dec d
;     jr nz, .bulletUpdateLoop

.objLoadTime
    ld hl, hOAMIndex ; What are we doing here? loading the address of our oam index into hl.
    ld l, [hl] ; Now, into l, we load the lower bit, which is the next open space (ideally) for us to put something into.

.objTwingo
    ld a, [wTwingo_active]

    bit 0, a
    jr z, .objTwingoEnd

    ld bc, wTwingo_yPos

    ; You have the twingo yPos small byte, which is, let's say, $50
    ld a, [bc] ; We start with the twingo ypos little bit. Let's say it's $50.
	ld e, a ; Okay, put that into e.
    inc bc ; Go to the big bit. Let's say it's $00.
	ld a, [bc] ; Put that in a.
	xor e ; You take a, which is $00, and xor it by e, which is $50. So, let's do that bit by bit. $50 = %01010000. So XORing that with zero gets you... $50. Easy example.
    ; $50 xor $00 is $50, right?
    ; 01010000
    ; 00000000
    ;=01010000 ;  YUP!
	and $0F ;Now AND that, so keep only the bottom bits.
	xor e ; Now you XOR that by e again, though. Remember what was in e? $50. $00 xor $50 is $50
    swap a ; But you actually want $05. So swap it.
    ld [hli], a ; Put that into hl.
 
    inc bc ; Here we are with the same algorithm. No real explanation for the crazy spaziness.

    ld a, [bc]
	ld e, a
    inc bc
	ld a, [bc]
	xor e
	and $0F
	xor e
    swap a
    ld [hli], a

    ; Keeping it to one sprite until I can get the fucking positioning working
    ld a, $02
    ld [hli], a

    ld a, $00
    ld [hli], a

    
    ; ld bc, wTwingo_yPos
    ; ld de, TwingoIdleDraw
    ; call MetaSpriteLoader

.objTwingoEnd

; .objBullet
;     ld bc, BulletArray
;     ld d, LOW(BulletArrayEnd - BulletArray) / sizeof_Bullet
; .objBulletLoop
;     ; y pos
;     inc bc
;     ; Bit shift by 4 here.

;     ld a, [bc]
; 	ld e, a
;     inc bc
; 	ld a, [bc]
; 	xor e
; 	and $F0
; 	xor e
;     swap a

;     ld [hli], a
    
;     ;x pos
;     inc bc
;     ; Bit shift by 4 here.

;     ld a, [bc]
; 	ld e, a
;     inc bc
; 	ld a, [bc]
; 	xor e
; 	and $F0
; 	xor e
;     swap a

;     ld [hli], a
    
;     ;sprite data
;     inc bc
;     ld a, [bc]
;     ld [hli], a

;     ;other
;     inc bc
;     inc hl

;     dec d
;     jr nz, .objBulletLoop

.gameLoopEnd
    call WaitVBlank

    ld a, HIGH(OAMVars)
    call hOAMDMA

    ld a, $00
    ld [hOAMIndex], a
    jp .gameLoop


MetaSpriteLoader:
    ; Variables needed:
    ; 2b: address of y position of actor. = BC.
    ; 2b: address of metasprite info. = DE.
    ; 1b: Counter that tracks the remaining number of sprites I have to put on screen. = wMetaSpriteInfo.
    ; So, we need to store that counter in a WRAM variable, I guess.
    
    ; For starters, we need to figure out how many objects we're going to push to OAM.
    ld a, [de]
    ld [wMetaSpriteCounter], a
    ; Now that we have that in the counter, inc de.
    inc de
    ; Now we're at the first y-coord of the sprite. Oh, yeah, uh, loop time.
    .metaSpriteLoop
    ld a, [bc] ; Get y-position of actual actor
    push hl ; Hold on, we need this for something

    push de ; this too
    ld b, b
    ld a, [bc]
	ld e, a
    inc bc
	ld a, [bc]
	xor e
	and $F0
	xor e
    swap a
    pop de
    
    ld h, d ; Put the metasprite info into hl
    ld l, e 
    add a, [hl] ; Add the metasprite's pos to the actor's position
    pop hl ; Get hl back
    
    ld [hli], a ; Put that in OAM
    inc de ; Onto the next bit of data!
    inc bc ; Same for bc

    ld a, [bc] ; Get x-position of actual actor
    push hl ; Hold on, we need this for something

    push de ; this too

    ld a, [bc]
	ld e, a
    inc bc
	ld a, [bc]
	xor e
	and $F0
	xor e
    swap a
    pop de

    ld h, d ; Put the metasprite info into hl
    ld l, e 
    add a, [hl] ; Add the metasprite's pos to the actor's position
    pop hl ; Get hl back
    ld [hli], a ; Put that in OAM
    inc de ; Onto the next bit of data!
    dec bc ; Go back
    dec bc
    dec bc

    ld a, [de] ; Take the next metasprite info
    ld [hli], a ; Put it in OAM
    inc de

    ld a, [de] ; Take the next metasprite info
    ld [hli], a ; Put it in OAM
    inc de

    ld a, [wMetaSpriteCounter]
    dec a
    ld [wMetaSpriteCounter], a
    ret z
    jr .metaSpriteLoop
    
WaitVBlank:
    ld a, [rSTAT]
    and $03 ; get just bits 0-1 
    cp 1
    ret z
    jr WaitVBlank

VBlankHandler:
    reti

FCopyToVRAM:
    ld a, [de] ; Load one byte from the source
    ld [hli], a ; load into address at hl, and increment hl
    inc de ; Go to the next byte
    dec bc ; Decrement the amount of bytes we gotta move
    ld a, b ; Check if the counter is at zero.. since dec bc doesn't set flags
    or c ; make sure c doesn't have anything either
    jr nz, FCopyToVRAM
    ret

WipeOAM:
    ld h, HIGH(OAMVars)
    ld l, $00
    ld bc, OAMVarsEnd - OAMVars
    .wipeOAMLoop
    ld a, 0 
    ld [hli], a ; increment hl
    dec bc ; Decrement the amount of bytes we gotta move
    ld a, b ; Check if the counter is at zero.. since dec bc doesn't set flags
    or c ; make sure c doesn't have anything either
    jr nz, .wipeOAMLoop
    ret

WipeMaps:
; DON'T BE MESSIN W THIS IF IT'S NOT IN VBLANK!!
; hl = start address. bc = size of address to wipe/set. a = value to set it to.
    ld d, a
.wipeMapsJump
    ld [hl], d
    inc hl
    dec bc
    ld a, b
    or c
    jr nz, .wipeMapsJump
    ret

SECTION "OAM DMA routine", ROM0
CopyDMARoutine:
    ld hl, DMARoutine
    ld b, DMARoutineEnd - DMARoutine ; number of bytes to copy
    ld c, LOW(hOAMDMA) ; Low byte of the destination address. We already know the high byte is going to be FF.
.copy
    ld a, [hli] ; start (or continue) loading bytes from that area! Whatever is AT hl, then increment.
    ldh [c], a
    inc c ; go to the next byte we load into!
    dec b ; one less byte to copy.
    jr nz, .copy ; if b is not zero, continue copying.
    ret

DMARoutine:
    ldh [rDMA], a
    ld a, $40 ; Load your counter for 40 seconds, 4 * 40 = 160 machine cycles, which is how long it takes.
.wait
    dec a
    jr nz, .wait
    ret
DMARoutineEnd:

SECTION "Graphics", ROM0
GF:
INCBIN "include/gerald.2bpp"
GFEnd:

SECTION "Shadow OAM Vars", WRAM0, ALIGN[8]
    hOAMIndex: ds 1
    OAMVars:
    DS 160
    OAMVarsEnd:
    
SECTION "OAM DMA", HRAM
hOAMDMA::
    ds DMARoutineEnd - DMARoutine ;reserve space to copy the routine to -- hey CHUCKLENUTS. THIS IS WHERE THE DMA TRANSFER FUNCTION IS GONNA BE, 'KAY?

Section "HRAM Vars", HRAM
    hWorkVar: ds 1

SECTION "Objects", WRAM0, ALIGN[8]
    dstruct MainActor, wTwingo
    BulletArray:
    dstructs 3, Bullet, wBullet
    BulletArrayEnd:

    ; EnemyArray:
    ; dstructs 7, Enemy, wEnemy
    ; EnemyArrayEnd:

SECTION "Other Vars", WRAM0, ALIGN[8]
    wBulletTimer: ds 1
    wDASTimer: ds 1
    wMetaSpriteTemp: ds 1
    wMetaSpriteCounter: ds 1

SECTION "LUT", ROM0, ALIGN[8]
SinTable:
; Generate a 256-byte sine table with values in the range [-64, 64]
; (shifted and scaled from the range [-1.0, 1.0])
ANGLE = 0.0
    REPT 256
        db (MUL(64.0, SIN(ANGLE))) >> 16
ANGLE = ANGLE + 256.0 ; 256.0 = 65536 degrees / 256 entries
    ENDR

Section "Enemy Path Y", ROM0, ALIGN[8]
;12.4 fixed point: 0000 0000 0000 . 0000
; So, max is 4096, and the most precise you can get is 1/2 + 1/4 + 1/8 + 1/16, or 15/16

