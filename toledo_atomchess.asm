        ;
        ; Toledo Atomchess
        ; by Oscar Toledo Gutierrez
        ; http://nanochess.org/
        ;
        ; © Copyright 2015-2019 Oscar Toledo Gutierrez
        ;
        ; Creation: Jan/28/2015 21:00 local time.
        ;
        ; With contributions by Peter Ferrie (qkumba),
        ;                       HellMood, qu1j0t3,
        ;                       and theshich.
        ;
        ; Latest version and logs at https://github.com/nanochess
        ; Previous version published in Programming Boot Sector Games
        ;

        ; Features:
        ;
        ;   o Computer plays legal basic chess movements ;)
        ;   o Player enter moves as algebraic form (D2D4)
        ;     (notice your moves aren't validated)
        ;   o Search depth of 3-ply
        ;   o No promotion of pawns.
        ;   o No castling
        ;   o No en passant.
        ;   o 356 bytes size (runs in a boot sector) or 352 bytes (COM file)
        ;
        ; Enable the HACK label for getting 330 bytes (boot sector)
        ; or 326 bytes (COM file), it will remove the following features:
        ;
        ;   o Game randomization (it will play the same game always).
        ;   o Shortest mate search (it can defer checkmate or delay it).
        ;   o Computer will be unable to play pawns two squares ahead.
        ;     (extremely ugly)
        ;

        cpu 286

HACK:   equ 0

        ; Edit this to 0 for a bootable sector
        ; Edit this to 1 for a COM file
    %ifndef com_file
com_file:       equ 0
    %endif

    %if com_file
        org 0x0100
    %else
        org 0x7c00
    %endif

PAWN:   equ 0x01
ROOK:   equ 0x02
BISHOP: equ 0x03
QUEEN:  equ 0x04
KNIGHT: equ 0x05
KING:   equ 0x06

FRONTIER:       equ 0x07

SIDE:   equ 0x20
                
        ; Note careful use of side-effects along all code.
start:
        ; Housekeeping
        cld
    %if com_file
        ; Saves 4 bytes in COM file because of preset environment ;)
    %else
        push cs
        push cs
        pop ds
        pop es
    %endif
        ; Create board
        mov di,board-8
        mov cx,di       ; Trick: it needs to be at least 0x0108 ;)
sr1:    push di
        pop ax
        and al,0x88     ; 0x88 board
        jz sr2
        mov al,FRONTIER ; Frontier
sr2:    stosb
        loop sr1
        ; Setup board
        mov si,initial
        mov di,board
        mov cl,0x08
sr3:    lodsb           ; Load piece
        stosb           ; Black pieces
        or al,SIDE
        mov [di+0x6f],al ; White pieces
        inc byte [di+0x0f]      ; Black pawn (PAWN)
        mov byte [di+0x5f],PAWN+SIDE    ; White pawn
        loop sr3        ; cx = 0

        ;
        ; Main loop
        ;
        ; Note reversed order of calls
        ;
sr21:
        push sr21               ; 8nd. Repeat loop
        push play               ; 6nd. Computer play. ch = 8=White, 0=Black
        push display_board      ; 5nd. Display board. Returns cx to zero
        mov bx,key2
        push bx                 ; 3nd. Take coordinate
        push bx                 ; 2nd. Take coordinate
        ; Inline function for displaying board
display_board:
        call make_move
        mov si,board-8
sr4:    mov al,[si]
        and al,7
        mov bx,chars    ; Note BH is reused outside this subroutine
        xlatb
        sub al,[si]
        cmp al,0x0d     ; Is it RC?
        jnz sr5         ; No, jump
        add si,byte 7   ; Jump 7 frontier bytes
        call display    ; Display RC
        mov al,0x0a     ; Now display LF
sr5:    call display
        inc si
        jns sr4
        ret             

sr14:   inc dx          ; Shorter than inc dl and because doesn't overflow
        dec dh
        jnz sr12
sr17:   inc si
        jns sr7
sr8:    pop di
        pop si
        ret

        ;
        ; If any response equals to always in check,
        ; it means the move wasn't never saved, so
        ; it moves piece from 0xff80 to 0xff80
        ; (outside the board).
        ;
make_move:
        movsb                   ; Do move
        mov byte [si-1],0       ; Clear origin square
        ret

        ;
        ; Computer plays :)
        ;
play:
        mov bp,-128     ; Current score (notice higher than -384 and -192)
        push bp         ; Origin square
        push bp         ; Target square

        mov si,board
sr7:    mov al,[si]     ; Read square
        xor al,ch       ; XOR with current playing side
        dec ax          ; Empty square 0x00 becomes 0xFF
        cmp al,6        ; Ignore if frontier or empty
        jnc sr17
        cmp byte [si],PAWN+1 ; Is it a black pawn?
        sbb al,0xfb
        mov ah,0x0c
        and ah,al       ; Total movements of piece in ah (later dh)
        mov bl,(offsets-4-start) & 255
        xlatb
        xchg dx,ax      ; Movements offset in dl
sr12:   mov di,si       ; Restart target square
sr9:    mov bl,dl       ; Build index into directions
        xchg ax,di
        add al,[bx]     ; Next target square
        xchg ax,di
        mov al,[di]     ; Content of target square in al
        inc ax
        cmp dl,(16+displacement-start) & 255
        dec al          ; Check for empty square in z flag
        jz sr10         ; Goes to empty square, jump
        jc sr27         ; If not pawn, jump
        cmp dh,3        ; Straight? 
        jb sr17         ; Yes, avoid and cancels any double square movement
sr27:   xor al,ch
        sub al,SIDE+1   ; Is it a valid capture?
        cmp al,KING-1   ; Z set if king, C clear for greater than (invalid)
        ja sr14         ; No, avoid and try next direction
        ; z=0/1 if king captured
        mov al,[di]     ; Restore AL
    %if HACK
    %else
        jne sr20        ; Wizard trick, jump if not captured king
        mov bp,384      ; Maximum score.
        shr bp,cl       ; It gets lower to prefer shortest checkmate
        jmp sr8         ; Ignore values
    %endif

sr20:   push ax         ; Save AH+AL for restoring board
        and al,7
        mov bl,(scores-start) & 255
        xlatb
        cbw
        pusha           ; Save all state (including current side in ch)
        call make_move  ; Do move
;        cmp cl,4  ; 4-ply depth
        cmp cl,3  ; 3-ply depth
;        cmp cl,2  ; 2-ply depth
;        cmp cl,1  ; 1-ply depth
        jnc sr22
        xor ch,SIDE
        inc cx          ; Increase depth
        call play
        mov bx,sp
        sub [bx+14],bp  ; Substract BP from AX
sr22:   popa            ; Save all state (including current side in ch)
        cmp bp,ax       ; Better score?
        jg sr23         ; No, jump
        xchg ax,bp      ; New best score
    %if HACK
    %else
        jne sr23        ; Same score?
        in al,(0x40)
        cmp al,0xaa     ; Randomize it
    %endif
sr23:   pop ax          ; Restore board
        xchg [di],al
        mov [si],al
        jg sr18
        add sp,byte 4
        push si         ; Save movement
        push di

sr18:   cmp byte [di],0 ; To non-empty square?
        jnz sr16        ; Yes, finish streak
        and al,7
        sub al,2
        cmp al,KNIGHT-2 ; Knight, king or pawn?
        jc sr9          ; No, continue streak
sr16:   jmp sr14

sr10:   jc sr20         ; If not pawn, jump,
        cmp dh,2        ; Diagonal? 
        ja sr16         ; Yes, avoid
    %if HACK
        dec dh
    %else
        jnz short sr20  ; Advances one square? No, jump.
        xchg ax,si
        push ax
        sub al,0x20
        cmp al,0x40     ; Moving from the center of the board?
        pop ax
        xchg ax,si
        sbb dh,al       ; Yes, then avoid checking for two squares
    %endif
        jmp short sr20

        ; Read algebraic coordinate
key2:   xchg si,di
        call key        ; Read letter
        xchg di,ax
                        ; Fall through to read number

        ; Read a key and display it
key:
        mov ah,0        ; Read keyboard.
        int 0x16        ; Call BIOS, only affects AX and Flags
    %ifdef bootos
        cmp al,0x1b     ; Esc key pressed?
        jne display     ; No, jump.
        int 0x20        ; Exits to bootOS.
    %endif
display:
        pusha
        mov ah,0x0e     ; Console output
        mov bh,0x00
        int 0x10        ; Call BIOS, can affect AX in older VGA BIOS.
        popa
        and ax,0x0f     ; Extract column
        imul bp,ax,-0x10; Calculate digit row multiplied by 16
        lea di,[bp+di+board+127] ; Substract board column
        ret

initial:
        db ROOK,KNIGHT,BISHOP,QUEEN,KING,BISHOP,KNIGHT,ROOK
scores:
        db FRONTIER     ; Self-modified to zero
        db 1,5,3,9,3
    %if HACK
        db 46
    %endif

chars:
        db 0x2e+0x00
        db 0x70+0x01
        db 0x72+0x02
        db 0x62+0x03
        db 0x71+0x04
        db 0x6e+0x05
        db 0x6b+0x06
        db 0x0d+0x07

offsets:
        db (16+displacement-start) & 255
    %if HACK
        db (19+displacement-start) & 255
    %else
        db (20+displacement-start) & 255
    %endif
        db (8+displacement-start) & 255
        db (12+displacement-start) & 255
        db (8+displacement-start) & 255
        db (0+displacement-start) & 255
        db (8+displacement-start) & 255
displacement:
        db -33,-31,-18,-14,14,18,31,33
        db -16,16,-1,1
        db 15,17,-15,-17
        db 15,17,16
    %if HACK
    %else
        db 32
    %endif
        db -15,-17,-16
    %if HACK
    %else
        db -32
    %endif

    %if com_file
    %else
        ; Many bytes to say something
        db "Toledo Atomchess. Dec/15/2019"
        db " (c) 2015-2019 Oscar Toledo G. "
        db "www.nanochess.org"
        db " Happy coding! :-) "
        db "Most fun MBR ever!!"
        db 0

        times 510-($-$$) db 0x4f

        ;
        ; This marker is required for BIOS to boot floppy disk
        ;

        db 0x55,0xaa
    %endif

board:  equ $7f00
