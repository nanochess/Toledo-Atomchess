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
        ; Revision: Jun/01/2015 10:08 local time. Solved bug where computer bishops never moved over upper diagonals.
        ; Revision: Oct/06/2015 06:38 local time. Optimized board setup/display, plus tiny bits.
        ; Revision: Oct/07/2015 14:47 local time. More optimization and debugged.
        ; Revision: Oct/10/2015 08:21 local time. More optimization.
        ; Revision: Oct/22/2015 16:59 local time. Now in nasm syntax and uses LEA per HellMood suggestion, 1 byte saved. Relocated sr20 per suggestion of Peter Ferrie (qkumba), saves 2 bytes.
        ; Revision: Oct/23/2015 10:49 local time. Replaced TEST CL,1 with SAL CL,1, and changed AND CL,0x1f CMP CL,0x10 with CMP DL,2. 5 bytes saved.
        ; Revision: Oct/23/2015 19:52 local time.
        ;   Integrated Peter Ferrie suggestions: moved subroutines
        ;   and changed 16-bit load to 8-bit for 4 bytes.
        ; Revision: Oct/23/2015 20:31 local time.
        ;   Constants reduced on my own for other 2 bytes.
        ; Revision: Oct/23/2015 20:45 local time.
        ;   Removed push cx/pop cx because pusha/popa internally
        ;   does the job, changed push di/pop ax to xchg ax,di
        ;   after confirming INT 0x16 doesn't affect di (Peter Ferrie)
        ;   4 bytes less.
        ; Revision: Oct/23/2015 21:09 Solved bug where computer pawn could
        ;   "jump" over own pawn. Saved two bytes more reusing ch as zero
        ;   before first "call play"
        ; Revision: Oct/24/2015 10:09 local time.
        ;   Reduced another 6 bytes redesigning the next target square
        ;   calculation.
        ; Revision: Oct/24/2015 18:21 local time.
        ;   Changed xlat to xlatb for yasm compatibility. (Peter Ferrie)
        ;   CL now used for current ply depth, removes ugly SP code so now MOV SP removed for COM file (Oscar Toledo)
        ;   Integrated offset of movement in table.
        ; Revision: Oct/25/2015 11:07 local time.
        ;   Reduced another 1 byte by reordering registers to enable XCHG. (Peter Ferrie)
        ; Revision: Oct/26/2015 12:48 local time.
        ;   Reduced 2 bytes more exchanging AH and AL in piece move code and an arithmetic trick with CH. (Oscar Toledo)
        ; Revision: Oct/26/2015 13:44 local time.
        ;   Reduced 3 bytes more reusing check comparison.
        ; Revision: Oct/29/2015 09:58 local time.
        ;   Reduced another 1 byte by replacing MOV ,1 with INC. (Peter Ferrie)

        ; Features:
        ; * Computer plays legal basic chess movements ;)
        ; * Enter moves as algebraic form (D2D4) (note your moves aren't validated)
        ; * Search depth of 3-ply
        ; * No promotion of pawns.
        ; * No castling
        ; * No en passant.
        ; * 407 bytes size (runs in a boot sector) or 398 bytes (COM file)

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

        ; Note careful use of side-effects along all code.

        ; Housekeeping
        cld
    %if com_file
        ; Saves 9 bytes in COM file because of preset environment ;)
    %else
        mov sp,stack
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
        inc byte [di+0x0f]      ; Black pawn
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
        call display_board ; returns cx to zero
        call play       ; ch = 8=White, 0=Black
        jmp short sr21

sr11:   cmp dh,2        ; Advanced it first square?
        jnz sr14
        lea ax,[si-0x20] ; Already checked for move to empty square
        cmp al,0x40     ; At top or bottom firstmost row?
        jb sr17         ; No, cancel double-square movement
sr14:   inc dl
        dec dh
        jnz sr12
sr17:   inc si
sr6:    cmp si,board+120
        jne sr7
        pop di
        pop si
        test cl,cl      ; Top call?
        jne sr24
        cmp bp,-127     ; Illegal move? (always in check)
        jl sr24         ; Yes, doesn't move
sr28:   movsb           ; Do move
        mov byte [si-1],0       ; Clear origin square
sr24:   ret

        ;
        ; Computer plays :)
        ;
play:   mov bp,-256     ; Current score
        push bp         ; Origin square
        push bp         ; Target square

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
        mov ah,al       ; Total movements of piece in ah (later dh)
        and ah,0x0c
        mov bl,offsets-4
        xlatb
        xchg dx,ax      ; Movements offset in dl
sr12:   mov di,si       ; Restart target square
sr9:    mov bl,dl       ; Build index into directions
        xchg ax,di
        add al,[bx]     ; Next target square
        xchg ax,di
        mov ah,[si]     ; Content of: origin in ah, target in al
        mov al,[di]
        or al,al        ; Goes to empty square?
        jz sr10
        cmp dl,16+displacement       ; Pawn?
        jc sr27
        cmp dh,3        ; Straight? 
        jb sr17         ; Yes, avoid and cancels any double square movement
sr27:   xor al,ch
        sub al,0x09     ; Valid capture?
        cmp al,0x05     ; Check Z with king, C=0 for higher (invalid)
        mov al,[di]
        ja sr18         ; No, avoid

        ; Comes from sr10 with z=0
        ; Comes from sr27 with z=0/1 if king captured
sr19:   jne sr20        ; Wizard trick, jump if not captured king
        dec cl          ; If not in first response...
        mov bp,78       ; ...maximum score
        jne sr26
        add bp,bp       ; Maximum score (probably checkmate/stalemate)
sr26:   pop ax          ; Ignore values
        pop ax
        ret

sr20:   push ax         ; Save for restoring in near future
        and al,7
        mov bl,scores
        xlatb
        cbw
;        cmp cl,4  ; 4-ply depth
        cmp cl,3  ; 3-ply depth
;        cmp cl,2  ; 2-ply depth
;        cmp cl,1  ; 1-ply depth
        jnc sr22
        pusha           ; Save all state (including current side in ch)
        call sr28       ; Do move
        xor ch,8        ; Change side
        inc cx          ; Increase depth
        call play
        mov bx,sp
        sub [bx+14],bp  ; Substract BP from AX
        popa            ; Save all state (including current side in ch)
sr22:   cmp bp,ax       ; Better score?
        jg sr23         ; No, jump
        xchg ax,bp      ; New best score
        jne sr23        ; Same score?
        in al,(0x40)
        cmp al,0xaa     ; Randomize it
sr23:   pop ax          ; Restore board
        mov [si],ah
        mov [di],al
        jg sr18
        add sp,4
        push si         ; Save movement
        push di

sr18:   dec ah
        xor ah,ch       ; Was it pawn?
        jz sr11         ; Yes, check special
        cmp ah,0x04     ; Knight or king?
        jnc sr16        ; End sequence, choose next movement
        or al,al        ; To empty square?
        jz sr9          ; Yes, follow line of squares
sr16:   jmp sr14

sr10:   cmp dl,16+displacement       ; Pawn?
        jc sr19
        cmp dh,3        ; Diagonal? 
        jnc sr18        ; Yes, avoid
        jmp short sr19

        ; Display board
display_board:
        mov si,board-8
        mov cx,73       ; 1 frontier + 8 rows * (8 cols + 1 frontier)
sr4:    lodsb
        mov bx,chars    ; Note BH is reused outside this subroutine
        xlatb
        cmp al,0x0d     ; Is it RC?
        jnz sr5         ; No, jump
        add si,7        ; Jump 7 frontier bytes
        call display    ; Display RC
        mov al,0x0a     ; Now display LF
sr5:    call display
        loop sr4
        ret             ; cx=0

        ; Read algebraic coordinate
key2:   call key        ; Read letter
        add ax,board+127 ; Calculate board column
        xchg ax,di
        call key        ; Read digit
        shl al,4        ; Substract digit row multiplied by 16
        sub di,ax
        ret

        ; Read a key and display it
key:    mov ah,0        ; Read keyboard
        int 0x16        ; Call BIOS, only affects AX and Flags
display:
        pusha
        mov ah,0x0e     ; Console output
        mov bh,0x00
        int 0x10        ; Call BIOS, can affect AX in older VGA BIOS.
        popa
        and ax,0x0f     ; Extract column
        ret

initial:
        db 2,5,3,4,6,3,5,2
scores:
        db 0,1,5,3,9,3

chars:
        db ".prbqnk",0x0d,".PRBQNK"

offsets:
        db 16+displacement
        db 20+displacement
        db 8+displacement
        db 12+displacement
        db 8+displacement
        db 0+displacement
        db 8+displacement
displacement:
        db -33,-31,-18,-14,14,18,31,33
        db -16,16,-1,1
        db 15,17,-15,-17
        db -15,-17,-16,-32
        db 15,17,16,32

    %if com_file
board:  equ 0x0300
    %else
        ; 103 bytes to say something
        db "Toledo Atomchess Oct/26/2015"
        db " (c)2015 Oscar Toledo G. "
        db "www.nanochess.org"
        db " Happy coding! :-) "
        db 0,0,0,0,0,0,0,0
        db 0,0,0,0,0,0

        ;
        ; This marker is required for BIOS to boot floppy disk
        ;

        db 0x55,0xaa

board:  equ $7e00

stack:  equ $8000
    %endif

