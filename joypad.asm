; 76543210
; |||||||+- A
; ||||||+-- B
; |||||+--- Select
; ||||+---- Start
; |||+----- Right
; ||+------ Left
; |+------- Up
; +-------- Down


INCLUDE "include/hardware.inc"

SECTION "ram_pads", WRAM0 [$C500]
    cur_keys:: ds 1
    new_keys:: ds 1

SECTION "Joypad Input", ROM0
JoypadHandler::


    ;first get the buttons
    ld a, P1F_GET_BTN ;load $10 into a
    call .halfAByte
    ld b, a ; B7-4 = 1; B3-0 = unpressed buttons (all the 1's are the unpressed stuff)

    ; Poll the other half
    ld a, P1F_GET_DPAD ; load $20 into a
    call .halfAByte
    swap a ; A7-4 = unpressed directions, A3-0 = 1
    xor b ;  A = pressed buttons + directions. For A3-0, all the 1's matched with 1's become 0, but the zeros (actually PRESSED buttons) become 1s through the POWER OF XOR. Same with the top, actually.
        ; A7-4 = pressed directions, A3-0 = pressed buttons.
    ld b, a

    ; "Release the controller"  
    ld a, $00
    ld [rP1],a

    ; Combine with PREVIOUS cur_keys to make new_keys?

    ld a, [cur_keys]
    xor b ; A = keys that changed state. From 0 to 1 or from 1 to 0.
    and b ; A = keys that changed to pressed (which is what we care about!)
    ld [new_keys], a
    ld a, b
    ld [cur_keys], a
    halt
    ret

.halfAByte
    ldh [rP1], a ; load whichever button bit (1 or 2) you want into the joypad register.
    call .knownRet
    ldh a,[rP1] ; "Ignore value while waiting for the key matrix to settle"
    ldh a,[rP1] ; 
    ldh a,[rP1] ; This one will do!
    or $F0 ; A7-4 = 1; A3-0 = unpressed keys (all the 1's are the unpressed stuff)
.knownRet
    ret

