INCLUDE "include/hardware.inc"
INCLUDE "include/structs.asm"

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

    ld a, LCDCF_OFF
    ld [rLCDC], a


    ld hl, $9800
    ld b, $9C
    call WipeMaps

    ld hl, $8000
    ld b, $88
    call WipeMaps

    ld hl, $8000
    ld de, GF  
    ld bc, GFEnd - GF

    call FCopyToVRAM

    ; Copy our starting OAM vars to C100

    call WipeOAM


    ; Now we define gerald's properties
    ld a, $50
    ld [gerald_sprite], a
    ld a, $50
    ld [gerald_sprite + 1], a
    ld a, $00
    ld [gerald_sprite + 2], a

    ld a, $50
    ld [geraldina_sprite], a
    ld a, $50
    ld [geraldina_sprite + 1], a
    ld a, $01
    ld [geraldina_sprite + 2], a
    ld a, $00
    ld [geraldina_sprite + 3], a



    ld a, HIGH(gerald_sprite)
    call hOAMDMA

    ;Set BG palette
    ld a, %11100100
    ld [rBGP], a
    ld [rOBP0], a




    ld a, %10000010
    ld [rLCDC], a

.gameLoop
    call JoypadHandler
    ld b, a

.checkCollision
    ld a, [gerald_sprite + $01]

.cCLeft
    cp $07
    jr nz, .cCRight
    res 5, b
.cCRight
    ld a, [geraldina_sprite + $01]
    cp $A1
    jr nz, .cCUp
    res 4, b
.cCUp
    ld a, [gerald_sprite]
    cp $0F
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
    ; So right now, b has the joypad buttons, and c has gerald's spritepos y.
.checkDown
    bit 7, b ; Is the down key being pressed? If not...
    jr z, .checkUp ; Go check the up key
    ld d, 1 ; But if it is, here's 1!! positive = moving down the screen.
.checkUp
    bit 6, b ; Is the up key being pressed?
    jr z, .udAdd ; If it's not, just go to addition.
    ld d, -1 ; But if it is, here's -1! negative = moving up the screen.
.udAdd
    ld a, d ; load whatever the up/down value is into a
    add a, c
    ld [gerald_sprite], a


    ; Now for left/right.
ld a, [gerald_sprite + 1]
    ld c, a
    ld d, 0 ; So, zero is currently in d.
    ; So right now, b has the joypad buttons, and c has gerald's spritepos x.
.checkLeft
    bit 5, b ; Is the left key being pressed? If not...
    jr z, .checkRight ; Go check the left key
    ld d, -1 ; But if it is, here's -1! negative = moving left of the screen.
.checkRight
    bit 4, b ; Is the right key being pressed?
    jr z, .lrAdd ; If it's not, just go to addition.
    ld d, 1 ; But if it is, here's 1!! positive = moving to the right of the screen. 
.lrAdd
    ld a, d ; load whatever the up/down value is into a
    add a, c
    ld [gerald_sprite + 1], a

    ld a, [gerald_sprite]
    ld [geraldina_sprite], a

    ld a, [gerald_sprite + 1]
    add a, $08
    ld [geraldina_sprite + 1], a

    ; So, we want Geraldina to shoot a missle.
    ; First, we check for input - is A being pressed?
    ; If it is, now we have to figure out how to handle objects.
    ; For the sake of simplicity, let's assume that the first two slots (8 bytes) are off limits.
    ; I want to reserve the next infinite amount of objects just for the fireballs for now.
    ; We need to sort a lot of this out.

    ; How does a fireball travel after it is created?
    ; We need to control a few things:
    ; Its speed, how rapidly we shoot them,
    ; and what happens when they leave the screen boundary.

    ; SHOOTING
    ; We'll use cur_keys and prev_keys to figure out whether or not the button was JUST pressed, or being held.
    ; If A was just pressed (the cur_keys bit is 1 and the prev_keys bit is 0), then shoot the fireball.
    ; Otherwise, if those two bits are the SAME, do a bit check on bit 5, 6, 7, whatever, so it's shot on a timer.

    ld a, [prev_keys]
    ld b, a
    ld a, [cur_keys]
    and b

    bit a, 0

    jr z, .shoot


.shoot
    call FindEmptyOAM


    ; MOVING

    ; The simple way to do it would be to comb through OAM... but that's slow
    ; We could store some values sequentially in HRAM...
    ; This is sloppy, but I'll do it.
    ; We'll store 6 bytes in WRAM. 2 for each fireball.
    ; One will be the position from C0 in which the fireball is stored.
    ; The other will be its X position.
    ; When we WANT to create a fireball...
    ; Check to see if any of those 3 empty slots in WRAM are zero (reset). So, byte 0, byte 2, byte 4.
    ; If one of them is, then create the fireball.
    ; And store its address and x position into those two registers.
    ; If a fireball finds that it's past FF or whatever, it will wipe itself.




.gameLoopEnd
    call WaitVBlank

    ld a, HIGH(gerald_sprite)
    call hOAMDMA


    jr .gameLoop

WaitVBlank:
    ld a, [rSTAT]
    and $03 ; get just bits 0-1 
    cp 1
    ret z
    jr WaitVBlank


VBlankHandler:

reti

;Comb through our shadow OAM until you find an empty spot
FindEmptyOAM:
    ld hl, $C100
    ld c, OAMVarsEnd - OAMVars

.findEmptyOAMLoop 

    ; See if what's at a is zero. If it is, time to start combing.
    ld a, [hl]
    ld b, a
    
    ; increment hl for the next loop and decrement c. THEN check on c.
    add hl, 4
    ld a, c
    sub a, 4
    ld c, a
    cp 0
    ret z


    inc b
    dec b

    ; So, is b (actually a) zero? If it is, move onto the next proper loop. 
    ; If not, carry on. 
    jr nz, .findEmptyOAMLoop
    ; Once you find a zero, set a timer and increment slowly through, checking that everything else is zero
    ; If something isn't zero, you can just add what's left in the timer to hl
    ld b, 4
.findEmptyOAMLoopComb
    ; See if the other three registers are zero. If each is, decrement b and increase hl.
    ; If b AND a is zero, load the address of hl into "a" finally and return. Uhhh, minus 4 first.
    ; Conditions: b is not zero and [hl] is zero.
    ; b is zero and [hl] is zero.
    ; b is zero and [hl] is not zero.
    inc hl
    dec b
    ld a, [hl]
    cp 0
    ; If [hl] is zero, continue
    jr z, findEmptyOAMLoopComb

    ; If you're here, then [hl] is not zero.
    and b

    jr z, findEmptyOAMLoopSuccessCondition ; So if b AND whatever is at "a" is zero, we're good to go!


    ; If for some reason it is not, then load the rest of the counter bits from b to hl, subtract b from c, and resume the sequence
    ; we want to do "add b, hl"

    ld a, b
    cpl
    inc a

    ld d, $FF
    ld e, a

    add hl, de

    ld a, c
    sub a, b
    ld c, a

    jr .findEmptyOAMLoop

.findEmptyOAMLoopSuccessCondition
    add hl, -4
    ld a, hl
    ret

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
    ld hl, $C100
    ld de, OAMVars
    ld bc, OAMVarsEnd - OAMVars
    .wipeOAMLoop
    ld a, 0 
    ld [hli], a ; increment hl
    inc de ; Go to the next byte
    dec bc ; Decrement the amount of bytes we gotta move
    ld a, b ; Check if the counter is at zero.. since dec bc doesn't set flags
    or c ; make sure c doesn't have anything either
    jr nz, .wipeOAMLoop
    ret



WipeMaps:
; DON'T BE MESSIN W THIS IF IT'S NOT IN VBLANK!!
; hl = start address. b = high bit of end address.
.wipeMapsJump
    ld a, $00
    ld [hli], a
    ld a, h
    xor b ; xor it with the high bit of the destination address

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


SECTION "Shadow OAM Vars", ALIGN[8]
OAMVars:
gerald_sprite: DS 4
geraldina_sprite: DS 4
DS 152
OAMVarsEnd:

SECTION "Fireball info", WRAM0
fireballs: ds 6

SECTION "OAM DMA", HRAM

hOAMDMA::
    ds DMARoutineEnd - DMARoutine ;reserve space to copy the routine to -- hey CHUCKLENUTS. THIS IS WHERE THE DMA TRANSFER FUNCTION IS GONNA BE, 'KAY?


