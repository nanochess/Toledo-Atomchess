        ;
        ; Toledo Atomchess reloaded
        ;
        ; by Óscar Toledo Gutiérrez
        ;
        ; © Copyright 2015 Óscar Toledo Gutiérrez
        ;
        ; Creation: 28-ene-2015 21:00 local time.
        ; Revision: 29-ene-2015 18:17 local time. Finished.
        ; Revision: 30-ene-2015 13:34 local time. Debugging finished.
        ; Revision: 26-may-2015. Checks for illegal moves. Handles promotion
        ;                        to queen, en passant and castling.
        ; Revision: 04-jun-2015. At last fully debugged.

        ; Features:
        ; * Full chess movements (except promotion only to queen)
        ; * Enter moves as algebraic form (D2D4) (your moves are validated)
        ; * Search depth of 3-ply
        ; * 831 bytes size (fits in two boot sectors)

        ; Note: I'm lazy enough to write my own assembler instead of
        ;       searching for one, so you will have to excuse my syntax ;)

        use16

        ; Search for "REPLACE" to find changes for COM file
        org 0x7c00       ; REPLACE with ORG 0x0100

        ; Housekeeping
        mov sp,stack
        cld
        push cs
        push cs
        push cs
        pop ds
        pop es
        pop ss
        ; Load second sector
sr0:    push ds
        push es
        mov ax,0x0201
        mov bx,0x7e00
        mov cx,0x0002
        xor dx,dx
        int 0x13         ; REPLACE with NOP NOP
        pop es
        pop ds
        jb sr0
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
        mov [enp],si    ; Reset en passant state
sr3:    lodsb           ; Load piece
        mov [bx],al     ; Black pieces
        or al,8
        mov [bx+0x70],al ; White pieces
        mov al,0x11
        mov [bx+0x10],al ; Black pawn
        mov al,0x19
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
        mov ch,0x00      ; Current turn (0=White, 8=Black)
        call play_validate
        test ch,ch      ; Changed turn?
        je sr21         ; No, wasn't valid
        call display_board
        mov ch,0x08      ; Current turn (0=White, 8=Black)
        dec byte [legal]
        mov word [depth],stack-(4+8+4+8+4+8+4)*2
        call play
        call play_validate
        jmp short sr21

        ;
        ; Computer plays :)
        ;
play_validate:
        mov byte [legal],1
        mov word [depth],stack-(4+8+4)*2
play:   mov bp,-32768   ; Current score
        push si         ; Origin square
        push di         ; Target square

        xor ch,8        ; Change side

        mov si,board
sr7:    lodsb           ; Read square
        xor al,ch       ; XOR with current playing side
        and al,0x0f      ; Remove moved bit
        dec ax          ; Translate to 0-5
        cmp al,6        ; Is it frontier or empty square?
        jnc sr6         ; Yes, jump
        or al,al        ; Is it pawn?
        jnz sr8         ; No, jump
        or ch,ch        ; Is it playing black?
        jnz sr25        ; No, jump
sr8:    inc ax          ; Inverse direction for pawn
sr25:   dec si
        mov bx,offsets
        push ax
        xlat
        mov dh,al       ; Movements offset in dh
        pop ax
        add al,total-offsets
        xlat
        mov dl,al       ; Total movements of piece in dl
sr12:   mov di,si       ; Restart target square
        mov bx,displacement
        mov al,dh
        xlat
        mov cl,al       ; Current displacement offset in cl
sr9:    add di,cx
        and di,0xff
        or di,board
        mov al,[si]     ; Content of origin square in al
        mov ah,[di]     ; Content of target square in ah
        and ah,0x0f      ; Empty square?
        jz sr10         ; Yes, jump
        xor ah,ch
        sub ah,0x09      ; Is it a valid capture?
        cmp ah,0x06
        mov ah,[di]
        jnc sr18        ; No, jump to avoid
        cmp dh,16       ; Moving pawn?
        jc sr19
        test cl,1       ; Straight advance?
        je sr18         ; Yes, avoid
        jmp short sr19

sr10:   cmp dh,16       ; Moving pawn?
        jc sr19         ; No, jump
        test cl,1       ; Diagonal?
        je sr19         ; No, jump
        mov bx,si
        dec bx
        test cl,2       ; Going left?
        jne sr29
        inc bx
        inc bx
sr29:   cmp bx,[enp]    ; Is it a valid en passant?
        jne sr18        ; No, avoid

sr19:   push ax         ; Save origin and target square in stack
        mov al,ah
        and al,7
        cmp al,6        ; King eaten?
        jne sr20
        cmp sp,stack-(4+8+4)*2  ; If in first response...
        mov bp,20000    ; ...maximum score (probably checkmate/slatemate)
        je sr26
        mov bp,7811     ; Maximum score
sr26:   add sp,6        ; Ignore values
        jmp sr24

sr20:   mov bx,scores
        xlat
        cbw             ; ax = score for capture (guarantees ah = 0)
        mov bx,[enp]    ; bx = current pawn available for en passant
        cmp sp,[depth]
        jbe sr22
        pusha
        mov [enp],ax    ; En passant not possible
        mov al,[si]     ; Read origin square
        and al,0x0f      ; Clear bit 4 (marks piece moved)
        cmp al,0x0e      ; Is it a king?
        je sr36
        cmp al,0x06
        jne sr37        ; No, jump
sr36:   mov bx,si
        sub bx,di
        mov bh,ch       ; Create moved rook
        xor bh,0x02      ;
        cmp bl,2        ; Is it castling to left?
        jne sr38        ; No, jump
        mov [di+1],bh   ; Put it along king
        mov [di-2],ah
        jmp sr37

sr38:   cmp bl,-2       ; Is it castling to right?
        jne sr37
        mov [di-1],bh   ; Put it along king
        mov [di+1],ah
sr37:
        cmp al,0x09      ; We have a pawn?
        je sr31
        cmp al,0x01
        jne sr30        ; No, jump
sr31:   mov bp,sp
        mov bx,di
        cmp bl,0x10      ; Going to uppermost row?
        jc sr32         ; Yes, jump
        cmp bl,0x70      ; Going to lowermost row?
        jc sr33         ; No, jump
sr32:   xor al,0x05      ; Promote to queen
        add word [bp+14],90     ; Add points for queen
sr33:   sub bx,si
        call en_passant_test
        jnc sr41
        mov [bx],ah     ; Clean en passant square
        add word [bp+14],10     ; Add points for pawn
        jmp sr30

sr41:   and bx,0x001f    ; Moving two squares ahead?
        jne sr30        ; No, jump
        mov [enp],di    ; Take note of en passant
sr30:   mov [di],al
        mov [si],ah     ; Clear origin square
        call play
        mov bx,sp
        sub [bx+14],bp  ; Substract BP from AX
        popa

        ;
        ; If reached maximum depth then the code can
        ; come here >without< moving piece
        ;
sr22:   mov [temp],ax
        cmp sp,stack-4*2        ; First ply?
        jnz sr28        ; No, jump
        test byte [legal],255   ; Checking for legal move?
        jz sr28         ; No, jump
        mov bp,sp
        cmp si,[bp+4]   ; Origin is same?
        jnz sr23
        cmp di,[bp+2]   ; Target is same?
        jnz sr23
        cmp ax,-16384   ; Illegal movement?
        jl sr23
        add sp,6
        ret

        ;
        ; Note: TEST instruction clears carry flag
        ;
en_passant_test:
        test bl,1       ; Diagonal?
        je sr42         ; No, jump
        test byte [di],255 ; Capture?
        jne sr42        ; Yes, jump
        test bl,2       ; Going left?
        stc             ; Set carry
        lea bx,[si-1]
        jne sr42
        lea bx,[si+1]
sr42:   ret

displacement:
        db -33,-31,-18,-14,14,18,31,33
        db -16,16,-1,1
        db 15,17,-15,-17
        db -15,-17,-16,-32
        db 15,17,16,32

scores:
        db 0,10,50,30,90,30

        ;
        ; This marker is required for BIOS to boot floppy disk
        ;
        resb 0x01fe-($-$$)     ; REPLACE with nothing for COM file
        db 0x55,0xaa      ; REPLACE with nothing for COM file

        ; Start of second sector

sr28:   cmp bp,ax       ; Better score?
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

sr23:   mov [enp],bx    ; Restore en passant state
        pop ax          ; Restore board
        mov [si],al
        mov [di],ah
        mov bx,di
        sub bx,si
        and al,0x07      ; Separate piece
        cmp al,0x01      ; Is it a pawn?
        jne sr43
        call en_passant_test
        jnc sr43
        mov byte [bx],ch ; Clean
        xor byte [bx],9  ; Restore opponent pawn

sr43:   cmp al,0x06      ; Is it a king?
        jne sr18
        mov bh,ch       ; Create unmoved rook
        xor bh,0x12      ;
        cmp bl,-2       ; Castling to left?
        jne sr40
        mov [di-2],bh
        mov [di+1],ah
        jmp sr18

sr40:   cmp bl,2        ; Castling to right?
        jne sr18
        mov [di+1],bh
        mov [di-1],ah

sr18:   dec ax
        and al,0x07      ; Was it pawn?
        jz sr11         ; Yes, check special
        cmp al,0x05      ; King?
        jne sr34        ; No, jump
        test byte [si],0x10      ; King already moved?
        je sr34         ; Yes, jump
        cmp word [temp],-4096   ; In check?
        jl sr34         ; Yes, jump
        or ah,ah        ; Moved to empty square?
        jne sr34        ; No, jump
        cmp bl,-1       ; Going left by one?
        je sr44
        cmp bl,1        ; Going right by one?
        jne sr34
        mov bh,[si+3]   ; Read rook
        mov bl,[si+2]   ; Read destination square
        jmp sr46

sr44:   test byte [si-3],255    ; Is empty square just right of rook?
        jne sr34        ; No, jump
        mov bh,[si-4]   ; Read rook
        mov bl,[si-2]   ; Read destination square
sr46:   test bl,bl      ; Ending in empty square?
        jne sr34        ; No, jump
        and bh,0x17
        cmp bh,0x12      ; Unmoved rook?
        je sr9          ; Yes, can move two squares for castling

sr34:   cmp al,0x04      ; Knight or king?
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
        sub al,0x20      ; At first top row?
        cmp al,0x40      ; At first bottom row?
        jb sr17         ; No, cancel double-square movement
sr14:   inc dh
        dec dl
        jnz sr12
sr17:   inc si
sr6:    cmp si,board+120
        jne sr7
        pop di
        pop si
sr24:   xor ch,8
        ret

display_board:
        ; Display board
        call display3
        mov si,board
sr4:    lodsb
        and al,0x0f
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

chars:
        db ".prbqnk",0x0d,".PRBQNK"

initial:
        db 0x12,0x15,0x13,0x14,0x16,0x13,0x15,0x12
offsets:
        db 16,20,8,12,8,0,8
total:
        db  4, 4,4, 4,8,8,8

        ; Bytes to say something
        db "Toledo Atomchess reloaded"
        db "nanochess.org"

        resb 0x0400-($-$$)     

board:  resb 256

depth:  resb 2            ; Depth for search
enp:    resb 2            ; En passant square
temp:   resb 2            ; Working score
legal:  resb 1            ; Flag indicating legal movement validation
        resb 249
stack:

