INCLUDE "include/hardware.inc"
INCLUDE "include/mystructs.inc"
INCLUDE "include/metasprites.inc"

DEF DAS_INITIAL_TIMER EQU 20
DEF DAS_INTERVAL EQU 20

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
    ld a, $50
    ld [wTwingo_yPos], a
    ld a, $50
    ld [wTwingo_xPos], a
    ld a, $00
    ld [wTwingo_spriteData], a
    ld a, $01
    ld [wTwingo_spriteData + 1], a

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

; TODO: instead of just turning off inputs, what's a better way we could do this? 
.checkCollision
    ld a, [wTwingo_xPos]

.cCLeft
    cp $07
    jr nz, .cCRight
    res 5, b
.cCRight
    cp $A1
    jr nz, .cCUp
    res 4, b
.cCUp
    ld a, [wTwingo_yPos]
    cp $0B
    jr nz, .cCDown
    res 6, b
.cCDown
    cp $99
    jr nz, .joypadObject
    res 7, b

.joypadObject
    ; Do all input based calculations.
    ; Check for up/down input.
    ld c, a
    ld d, 0 ; So, zero is currently in d.
    ; So right now, b has the joypad buttons, and c has twingo's spritepos y.
.checkDown
    bit 7, b ; Is the down key being pressed? If not...
    jr z, .checkUp ; Go check the up key
    inc d ; But if it is, here's 1!! positive = moving down the screen.
.checkUp
    bit 6, b 
    jr z, .udAdd
    dec d
.udAdd
    ld a, d
    add a, c
    ld [wTwingo_yPos], a
    ld d, 0

    ld a, [wTwingo_xPos]
    ld c, a
.checkRight
    bit 4, b ; Is the down key being pressed? If not...
    jr z, .checkLeft ; Go check the up key
    inc d ; But if it is, here's 1!! positive = moving to the right of the screen.
.checkLeft
    bit 5, b ; Is the up key being pressed?
    jr z, .lrAdd ; If it's not, just go to addition.
    dec d ; But if it is, here's -1! negative = moving to the left of the screen.
.lrAdd
    ld a, d ; load whatever the up/down value is into a
    add a, c
    ld [wTwingo_xPos], a

INCLUDE "bullet.asm"

.objLoadTime
    ld hl, hOAMIndex ; What are we doing here? loading the address of our oam index into hl.
    ld l, [hl] ; Now, into l, we load the lower bit, which is the next open space (ideally) for us to put something into.

.objTwingo
    ld a, [wTwingo_active]

    bit 0, a
    jr z, .objTwingoEnd

    ld bc, wTwingo_yPos
    ld de, TwingoIdleDraw
    call MetaSpriteLoader

.objTwingoEnd

.objBullet
    ld bc, BulletArray
    ld d, LOW(BulletArrayEnd - BulletArray) / sizeof_Bullet
.objBulletLoop
    ; y pos
    inc bc
    ld a, [bc]
    ld [hli], a
    
    ;x pos
    inc bc
    ld a, [bc]
    ld [hli], a
    
    ;sprite data
    inc bc
    ld a, [bc]
    ld [hli], a

    ;other
    inc bc
    inc hl

    dec d
    jr nz, .objBulletLoop

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
    ld h, d ; Put the metasprite info into hl
    ld l, e 
    add a, [hl] ; Add the metasprite's pos to the actor's position
    pop hl ; Get hl back
    ld b, b
    ld [hli], a ; Put that in OAM
    inc de ; Onto the next bit of data!
    inc bc ; Same for bc

    ld a, [bc] ; Get x-position of actual actor
    push hl ; Hold on, we need this for something
    ld h, d ; Put the metasprite info into hl
    ld l, e 
    add a, [hl] ; Add the metasprite's pos to the actor's position
    pop hl ; Get hl back
    ld [hli], a ; Put that in OAM
    inc de ; Onto the next bit of data!
    dec bc ; Go back

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

SECTION "Graphics", ROM0
GF:
INCBIN "include/gerald.2bpp"
GFEnd:

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

SECTION "Shadow OAM Vars", WRAM0, ALIGN[8]
    hOAMIndex: ds 1
    OAMVars:
    DS 160
    OAMVarsEnd:
    
SECTION "OAM DMA", HRAM
hOAMDMA::
    ds DMARoutineEnd - DMARoutine ;reserve space to copy the routine to -- hey CHUCKLENUTS. THIS IS WHERE THE DMA TRANSFER FUNCTION IS GONNA BE, 'KAY?

SECTION "Objects", WRAM0, ALIGN[8]
    dstruct MainActor, wTwingo
    BulletArray:
    dstructs 3, Bullet, wBullet
    BulletArrayEnd:

    EnemyArray:
    dstructs 7, Enemy, wEnemy
    EnemyArrayEnd:

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

;Test