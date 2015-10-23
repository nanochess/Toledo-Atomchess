        ;
        ; Toledo Atomchess
        ;
        ; by Óscar Toledo Gutiérrez
        ;
        ; © Copyright 2015 Óscar Toledo Gutiérrez
        ;
        ; Creation: Jan/28/2015 21:00 local time.
        ; Revision: Jan/29/2015 18:17 local time. Finished.
        ; Revision: Jan/30/2015 13:34 local time. Debugging finished.
        ; Revision. Jun/01/2015 10:08 local time. Solved bug where computer bishops never moved over upper diagonals.

        ; Features:
        ; * Basic chess movements.
        ; * Enter moves as algebraic form (D2D4) (note your moves aren't validated)
        ; * Search depth of 3-ply
        ; * No promotion of pawns.
        ; * No castling
        ; * No en passant.
        ; * 481 bytes size (fits in a boot sector)

        ; Note: I'm lazy enough to write my own assembler instead of
        ;       searching for one, so you will have to excuse my syntax ;)

        use16

        ; Change to org 0x0100 for COM file
        org 0x7c00

        ; Housekeeping
        mov sp,stack
        cld
        push cs
        push cs
        push cs
        pop ds
        pop es
        pop ss
        ; Create board
        mov bx,board
sr1:    mov al,bl
        and al,0x88      ; 0x88 board
        jz sr2
        mov al,0x07      ; Frontier
sr2:    mov [bx],al
        inc bl
        jnz sr1
        ; Setup board
        mov si,initial
sr3:    lodsb           ; Load piece
        mov [bx],al     ; Black pieces
        or al,8
        mov [bx+0x70],al ; White pieces
        mov al,0x01
        mov [bx+0x10],al ; Black pawn
        mov al,0x09
        mov [bx+0x60],al ; White pawn
        inc bx
        cmp bl,0x08
        jnz sr3

        ;
        ; Main loop
        ;
sr21:   call display_board
        call key2
        push di
        call key2
        pop si
        movsb
        mov byte [si-1],0
        call display_board
        mov ch,0x08      ; Current turn (0=White, 8=Black)
        call play
        jmp short sr21

        ;
        ; Computer plays :)
        ;
play:   mov bp,-32768   ; Current score
        push bp         ; Origin square
        push bp         ; Target square

        xor ch,8        ; Change side

        mov si,board
sr7:    lodsb           ; Read square
        xor al,ch       ; XOR with current playing side
        dec ax
        cmp al,6        ; Ignore if frontier
        jnc sr6
        or al,al        ; Is it pawn?
        jnz sr8
        or ch,ch        ; Is it playing black?
        jnz sr25        ; No, jump
sr8:    inc ax
sr25:   dec si
        mov bx,offsets
        push ax
        xlat
        mov dh,al       ; Movements offset
        pop ax
        mov bl,total
        xlat
        mov dl,al       ; Total movements of piece
sr12:   mov di,si       ; Restart target square
        mov bl,displacement
        mov al,dh
        xlat
        mov cl,al
sr9:    add di,cx
        and di,0xff
        or di,board
        mov al,[si]     ; Content of: origin in al, target in ah
        mov ah,[di]
        or ah,ah        ; Empty square?
        jz sr10
        xor ah,ch
        sub ah,0x09      ; Valid capture?
        cmp ah,0x06
        mov ah,[di]
        jnc sr18        ; No, avoid
        cmp dh,16       ; Pawn?
        jc sr19
        test cl,1       ; Straight?
        je sr18         ; Yes, avoid
        jmp short sr19

sr10:   cmp dh,16       ; Pawn?
        jc sr19
        test cl,1       ; Diagonal?
        jne sr18        ; Yes, avoid

sr19:   push ax         ; Save for restoring in near future
        mov bl,scores
        mov al,ah
        and al,7
        cmp al,6        ; King eaten?
        jne sr20
        cmp sp,stack-(4+8+4)*2  ; If in first response...
        mov bp,20000    ; ...maximum score (probably checkmate/slatemate)
        je sr26
        mov bp,7811     ; Maximum score
sr26:   add sp,6        ; Ignore values
        jmp short sr24

sr20:   xlat
        cbw
;        cmp sp,stack-(4+8+4+8+4+8+4+8+4)*2  ; 4-ply depth
        cmp sp,stack-(4+8+4+8+4+8+4)*2  ; 3-ply depth
;        cmp sp,stack-(4+8+4+8+4)*2  ; 2-ply depth
;        cmp sp,stack-(4+8+4)*2  ; 1-ply depth
        jbe sr22
        pusha
        movsb                   ; Do move
        mov byte [si-1],ah      ; Clear origin square
        call play
        mov bx,sp
        sub [bx+14],bp  ; Substract BP from AX
        popa
sr22:   cmp bp,ax       ; Better score?
        jg sr23         ; No, jump
        mov bp,ax       ; New best score
        jne sr27
        in al,(0x40)
        cmp al,0x55      ; Randomize it
        jb sr23
sr27:   pop ax
        add sp,4
        push si         ; Save movement
        push di
        push ax
sr23:   pop ax          ; Restore board
        mov [si],al
        mov [di],ah

sr18:   dec ax
        and al,0x07      ; Was it pawn?
        jz sr11         ; Yes, check special
        cmp al,0x04      ; Knight or king?
        jnc sr14        ; End sequence, choose next movement
        or ah,ah        ; To empty square?
        jz sr9          ; Yes, follow line of squares
sr16:   jmp short sr14

sr11:   and cl,0x1f      ; Advanced it first square?
        cmp cl,0x10
        jnz sr14
sr15:   or ah,ah        ; Pawn to empty square?
        jnz sr17        ; No, cancel double-square movement
        mov ax,si
        sub al,0x20
        cmp al,0x40      ; At top or bottom firstmost row?
        jb sr17         ; No, cancel double-square movement
sr14:   inc dh
        dec dl
        jnz sr12
sr17:   inc si
sr6:    cmp si,board+120
        jne sr7
        pop di
        pop si
        cmp sp,stack-2
        jne sr24
        cmp bp,-16384   ; Illegal move? (always in check)
        jl sr24         ; Yes, doesn't move
        movsb
        mov byte [si-1],0
sr24:   xor ch,8
        ret

display_board:
        ; Display board
        call display3
        mov si,board
sr4:    lodsb
        mov bx,chars
        xlat
        call display2
sr5:    cmp si,board+128
        jnz sr4
        ret

key2:
        mov di,board+127
        call key
        add di,ax
        call key
        shl al,4
        sub di,ax
        ret
key:
        push di
        mov ah,0
        int 0x16
        push ax
        call display
        pop ax
        and ax,0x0f
        pop di
        ret

display2:
        cmp al,0x0d
        jnz display
display3:
        add si,7
        mov al,0x0a
        call display
        mov al,0x0d
display:
        push si
        mov ah,0x0e
        mov bh,0x00
        int 0x10
        pop si
        ret

initial:
        db 2,5,3,4,6,3,5,2
scores:
        db 0,10,50,30,90,30

chars:
        db ".prbqnk",0x0d,".PRBQNK"

offsets:
        db 16,20,8,12,8,0,8
total:
        db  4, 4,4, 4,8,8,8
displacement:
        db -33,-31,-18,-14,14,18,31,33
        db -16,16,-1,1
        db 15,17,-15,-17
        db -15,-17,-16,-32
        db 15,17,16,32

        ; 29 bytes to say something
        db "Toledo Atomchess"
        db "nanochess.org"

        ;
        ; This marker is required for BIOS to boot floppy disk
        ;
        db 0x55,0xaa

board:  equ $

stack:  equ $+512

