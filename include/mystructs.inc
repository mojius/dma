; TIME TO FUCKING CODE LETS GOO!!!
; Struct GERALD BABY!!
; Remember...
; Pipeline is...
; Every frame in game loop: Add Gerald to

INCLUDE "include/structs.inc"

    struct MainActor
    bytes 1, active
    bytes 2, yPos ; Let's make this the vertical middle of the 16x8 sprite
    bytes 2, xPos ; Horizontal middle...
    bytes 3, spriteData ; byte 1 is gerald sprite, byte 2 is geraldina, byte 3 is misc
    bytes 1, bulletTimer
    end_struct

    struct Bullet
    bytes 1, flags ; Bit 0 is "active", bit 1 is belongs to enemy or not
    bytes 2, yPos ; vertical. little-endian, so the smaller bytes come first.
    bytes 2, xPos ; Horizontal
    bytes 1, spriteData ; Byte 1 is fireball sprite
    end_struct
