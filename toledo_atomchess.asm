        ;
        ; Toledo Atomchess
        ;
        ; by �scar Toledo Guti�rrez
        ;
        ; � Copyright 2015 �scar Toledo Guti�rrez
        ;
        ; Creation: Jan/28/2015 21:00 local time.
        ; Revision: Jan/29/2015 18:17 local time. Finished.
        ; Revision: Jan/30/2015 13:34 local time. Debugging finished.
        ; Revision: Jun/01/2015 10:08 local time. Solved bug where computer bishops never moved over upper diagonals.
        ; Revision: Oct/06/2015 06:38 local time. Optimized board setup/display, plus tiny bits.
        ; Revision: Oct/07/2015 14:47 local time. More optimization and debugged.
        ; Revision: Oct/10/2015 08:21 local time. More optimization.
        ; Revision: Oct/22/2015 16:59 local time. Now in nasm syntax and uses LEA per HellMood suggestion, 1 byte saved. Relocated sr20 per suggestion of Peter Ferrie (qkumba), saves 2 bytes.
        ; Revision: Oct/23/2015 10:49 local time. Replaced TEST CL,1 with SAL CL,1, and changed AND CL,0x1f CMP CL,0x10 with CMP DL,2. 5 bytes saved.
        ; Revision: Oct/23/2015 16:10 local time. pf: Relocated sr11 and 20 saves 3 bytes, load low offsets saves 1 byte, don't save cx during play saves 3 bytes, replace push/pop with xchg saves 1 byte.

        ; Features:
        ; * Computer plays legal basic chess movements ;)
        ; * Enter moves as algebraic form (D2D4) (note your moves aren't validated)
        ; * Search depth of 3-ply
        ; * No promotion of pawns.
        ; * No castling
        ; * No en passant.
        ; * 438 bytes size (runs in a boot sector) or 432 bytes (COM file)

        use16

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

        ; Housekeeping
        mov sp,stack
        cld
    %if com_file
        ; Saves six bytes in COM file because of preset environment ;)
    %else
        push cs
        push cs
        push cs
        pop ds
        pop es
        pop ss
    %endif
        ; Create board
        mov di,board-8
        mov cx,0x0108
sr1:    push di
        pop ax
        and al,0x88     ; 0x88 board
        jz sr2
        mov al,0x07     ; Frontier
sr2:    stosb
        loop sr1
        ; Setup board
        mov si,initial
        mov di,board
        mov cl,0x08
sr3:    lodsb           ; Load piece
        stosb           ; Black pieces
        or al,8
        mov [di+0x6f],al ; White pieces
        mov byte [di+0x0f],0x01 ; Black pawn
        mov byte [di+0x5f],0x09 ; White pawn
        loop sr3

        ;
        ; Main loop
        ;
sr21:   call display_board
        call key2
        push di
        call key2
        pop si
        call sr28
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
        dec ax          ; Empty square 0x00 becomes 0xFF
        cmp al,6        ; Ignore if frontier or empty
        jnc sr6
        or al,al        ; Is it pawn?
        jnz sr8
        or ch,ch        ; Is it playing black?
        jnz sr25        ; No, jump
sr8:    inc ax
sr25:   dec si
        add al,0x04
        mov dl,al       ; Total movements of piece in dl
        and dl,0x0c
        mov bl,(offsets-4)&255
        xlatb
        add al,displacement&255
        mov dh,al       ; Movements offset in dh
sr12:   mov di,si       ; Restart target square
        mov bl,dh       ; Build index into directions
        mov cl,[bx]     ; Direction in cl
sr9:    add di,cx       ; Calculate target square for piece
        and di,0xff
        or di,board
        mov al,[si]     ; Content of: origin in al, target in ah
        mov ah,[di]
        or ah,ah        ; Empty square?
        jz sr10
        xor ah,ch
        sub ah,0x09     ; Valid capture?
        cmp ah,0x06
        mov ah,[di]
        jnc sr18        ; No, avoid
        cmp dh,(16+displacement)&255 ; Pawn?
        jc sr19
        sar cl,1        ; Straight? (cl can be modified because only used once)
        jnc sr17        ; Yes, avoid and cancels any double square movement
        jmp short sr19

sr11:   cmp dl,2        ; Advanced it first square?
gosr14: jnz sr14
        lea ax,[si-0x20] ; Already checked for move to empty square
        cmp al,0x40     ; At top or bottom firstmost row?
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
sr28:   movsb           ; Do move
        mov byte [si-1],0       ; Clear origin square
sr24:   ret

sr20:   xlatb
        cbw
;        cmp sp,stack-(5+8+5+8+5+8+5+8+4)*2  ; 4-ply depth
        cmp sp,stack-(5+8+5+8+5+8+4)*2  ; 3-ply depth
;        cmp sp,stack-(5+8+5+8+4)*2  ; 2-ply depth
;        cmp sp,stack-(5+8+4)*2  ; 1-ply depth
        jbe sr22
        pusha
        call sr28       ; Do move
        call play
        mov bx,sp
        sub [bx+14],bp  ; Substract BP from AX
        popa
sr22:   cmp bp,ax       ; Better score?
        jg sr23         ; No, jump
        xchg ax,bp      ; New best score
        jne sr23        ; Same score?
        in al,(0x40)
        cmp al,0xaa     ; Randomize it
sr23:   pop ax          ; Restore board
        mov [si],al
        mov [di],ah
        jg sr18
        add sp,4
        push si         ; Save movement
        push di

sr18:   dec ax
        and al,0x07     ; Was it pawn?
        jz sr11         ; Yes, check special
        cmp al,0x04     ; Knight or king?
        jnc sr14        ; End sequence, choose next movement
        or ah,ah        ; To empty square?
        jnz gosr14
        jmp sr9         ; Yes, follow line of squares

sr10:   cmp dh,(16+displacement)&255 ; Pawn?
        jc sr19
        sar cl,1        ; Diagonal? (cl can be modified because only used once)
        jc sr18         ; Yes, avoid

sr19:   push ax         ; Save for restoring in near future
        mov bl,scores&255
        mov al,ah
        and al,7
        cmp al,6        ; King eaten?
        jne sr20
        cmp sp,stack-(5+8+4)*2  ; If in first response...
        mov bp,20000    ; ...maximum score (probably checkmate/slatemate)
        je sr26
        mov bp,7811     ; Maximum score
sr26:   add sp,6        ; Ignore values
        ret

        ; Display board
display_board:
        mov si,board-8
        mov bx,chars
        mov cx,73       ; 1 frontier + 8 rows * (8 cols + 1 frontier)
sr4:    lodsb
        xlatb
        cmp al,0x0d     ; Is it RC?
        jnz sr5         ; No, jump
        add si,7        ; Jump 7 frontier bytes
        call display    ; Display RC
        mov al,0x0a     ; Now display LF
sr5:    call display
        loop sr4
        ret

        ; Read algebraic coordinate
key2:   call key        ; Read letter
        add ax,board+127 ; Calculate board column
        xchg di,ax
        call key        ; Read digit
        shl al,4        ; Substract digit row multiplied by 16
        sub di,ax
        ret
key:
        mov ah,0        ; Read keyboard
        int 0x16        ; Call BIOS
display:
        pusha
        mov ah,0x0e     ; Console output
        mov bh,0x00
        int 0x10        ; Call BIOS
        popa
        and ax,0x0f
        ret

initial:
        db 2,5,3,4,6,3,5,2
scores:
        db 0,10,50,30,90,30

chars:
        db ".prbqnk",0x0d,".PRBQNK"

offsets:
        db 16,20,8,12,8,0,8
displacement:
        db -33,-31,-18,-14,14,18,31,33
        db -16,16,-1,1
        db 15,17,-15,-17
        db -15,-17,-16,-32
        db 15,17,16,32

    %if com_file
board:  equ 0x0300
stack:  equ 0x0500
    %else
        ; 80 bytes to say something
        db "Toledo Atomchess Oct/23/2015"
        db " (c) 2015 Oscar Toledo G. "
        db "www.nanochess.org"
        db 0,0,0,0,0,0,0,0,0

        ;
        ; This marker is required for BIOS to boot floppy disk
        ;

        db 0x55,0xaa

board:  equ $

stack:  equ $+512
    %endif

