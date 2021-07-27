INCLUDE "include/hardware.inc"
INCLUDE "include/mystructs.inc"

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


.bulletShoot
    ld a, [new_keys] ; Check pressed buttons
    and PADF_A
    ld c, a ; Pressed buttons, in this case a
    jr z, .noDASReset ; If A is not newly pressed...
    ld a, DAS_INITIAL_TIMER ; If it's a new key, then load the initial timer into wDASTimer
    ld [wDASTimer], a
.noDASReset
    ld a, [cur_keys]
    and PADF_A ; Check if a is being currently held
    jr z, .noDAS ; If it's not, then get out of here
    ld hl, wDASTimer ; If it is, though, decrement the timer...
    dec [hl]
    jr nz, .noDAS ; If the timer isn't zero yet, skip... But if it is...
    ld [hl], DAS_INTERVAL 
    set PADB_A, c ; Pretend that the A button is pressed
.noDAS

    bit PADB_A, c
    jr z, .bulletUpdate

.bulletInit
    ld hl, BulletArray
    ld d, LOW(BulletArrayEnd - BulletArray) / sizeof_Bullet
.bulletInitLoop
    bit 0, [hl]
    jr z, .bulletInitSlotReady

.bulletInitSlotFull
    ld bc, $0004
    add hl, bc 
    jr .bulletInitLoopEnd

.bulletInitSlotReady
    set 0, [hl]
    inc hl
    ld a, [wTwingo_yPos]
    ld [hli], a
    ld a, [wTwingo_xPos]
    ld [hli], a
    ld a, $02
    ld [hli], a
    jr .bulletUpdate

.bulletInitLoopEnd
    dec d
    jr nz, .bulletInitLoop

.bulletUpdate
    ld hl, BulletArray
    ld d, LOW(BulletArrayEnd - BulletArray) / sizeof_Bullet
    ld bc, -2
.bulletUpdateLoop
    ; Check to see if it's past screen boundary
    inc hl
    inc hl
    ld a, [hl]
    cp $A9
    dec hl
    dec hl
    jr nz, .bulletUpdateLoopCheckBit
    res 0, [hl] 

.bulletUpdateLoopCheckBit
    bit 0, [hl]
    jr nz, .bulletUpdatePosition

.bulletUpdateReset
    xor a
    ld [hli], a
    ld [hli], a   
    ld [hli], a
    ld [hli], a
    jr .bulletUpdateLoopEnd
    
.bulletUpdatePosition
    inc hl
    inc hl
    ld a, [hl]
    inc a
    ld [hli], a
    inc hl

.bulletUpdateLoopEnd
    dec d
    jr nz, .bulletUpdateLoop

.objLoadTime
    ld hl, hOAMIndex ; What are we doing here? loading the address of our oam index into hl.
    ld l, [hl] ; Now, into l, we load the lower bit, which is the next open space (ideally) for us to put something into.

.objTwingo
    ld a, [wTwingo_active]

    cp 0
    jr z, .objTwingoEnd

    ld a, [wTwingo_yPos]
   ; sub a, 4
    ld [hli], a


    ld a, [wTwingo_xPos]
    ;add a, -4
    ld [hli], a

    ld a, [wTwingo_spriteData]
    ld [hli], a
    inc hl

    ;Right part of sprite
    ld a, [wTwingo_yPos]
    ;sub a, 4
    ld [hli], a 

    ld a, [wTwingo_xPos]
    add a, 8
    ld [hli], a 

    ld a, [wTwingo_spriteData + 1]
    ld [hli], a
    inc hl
.objTwingoEnd

.objBullet
    ld bc, BulletArray
    ld d, Low(BulletArrayEnd - BulletArray) / sizeof_Bullet
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

SECTION "Other Vars", WRAM0, ALIGN[8]
    wBulletTimer: ds 1
    wDASTimer: ds 1

