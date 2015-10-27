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
        ; Revision: 06-oct-2015. Optimized board initialization/display and other tiny bits.
        ; Revision: 26-oct-2015 18:35 local time.
        ;   Passed some optimization from basic Atomchess.

        ; Features:
        ; * Full chess movements (except promotion only to queen)
        ; * Enter moves as algebraic form (D2D4) (your moves are validated)
        ; * Search depth of 3-ply
        ; * 779 bytes size (bootable disk) or 754 bytes (COM file)
     
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
        cld
        mov sp,stack
    %if com_file
        ; Saves 25 bytes in COM file because of preset environment ;)
    %else
        push cs         ; 1
        push cs         ; 2
        push cs         ; 3
        pop ds          ; 4
        pop es          ; 5
        pop ss          ; 6
        ; Load second sector
sr0:    push ds         ; 7
        push es         ; 8
        mov ax,0x0201   ; 11
        mov bx,0x7e00   ; 14
        mov cx,0x0002   ; 17
        xor dx,dx       ; 19
        int 0x13        ; 21
        pop es          ; 22
        pop ds          ; 23
        jb sr0          ; 25
    %endif
        ; Create board
        mov di,board-8
        mov cx,0x0108
sr1:    push di
        pop ax
        and al,0x88      ; 0x88 board
        jz sr2
        mov al,0x07      ; Frontier
sr2:    stosb
        loop sr1
        ; Setup board
        mov si,initial
        mov [enp],si    ; Reset en passant state
        mov di,board
        mov cl,0x08
sr3:    lodsb           ; Load piece
        stosb           ; Black pieces
        or al,8
        mov [di+0x6f],al ; White pieces
        mov byte [di+0x0f],0x11 ; Black pawn
        mov byte [di+0x5f],0x19 ; White pawn
        loop sr3

        ;
        ; Main loop
        ;
sr21:   call display_board
        call key2
        push di
        call key2
        pop si
        mov ch,0x08     ; Current turn (8=White, 0=Black)
        call play_validate
        cmp bp,-127     ; Valid score?
        jl sr21         ; No, wasn't valid
        call display_board
        mov ch,0x00     ; Current turn (8=White, 0=Black)
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

        mov si,board
sr7:    lodsb           ; Read square
        xor al,ch       ; XOR with current playing side
        and al,0x0f     ; Remove moved bit
        dec ax          ; Translate to 0-5 (255=empty)
        cmp al,6        ; Is it frontier or empty square?
        jnc sr6         ; Yes, jump
        or al,al        ; Is it pawn?
        jnz sr8         ; No, jump
        or ch,ch        ; Is it playing black?
        jnz sr25        ; No, jump
sr8:    inc ax          ; Inverse direction for pawn
sr25:   dec si
        add al,0x04
        mov ah,al       ; Total movements of piece in ah (later dh)
        and ah,0x0c
        mov bx,offsets-4
        xlatb
        xchg dx,ax      ; Movements offset in dl
sr12:   mov di,si       ; Restart target square
sr9:    mov bx,displacement
        mov bl,dl
        xchg ax,di
        add al,[bx]     ; Next target square
        xchg ax,di
        mov al,[si]     ; Content of origin square in al
        mov ah,[di]     ; Content of target square in ah
        and ah,0x0f     ; Empty square?
        jz sr10         ; Yes, jump
        cmp dl,16+displacement ; Moving pawn?
        jc sr35
        cmp dh,3        ; Straight advance?
        jc sr17         ; Yes, avoid
sr35:   xor ah,ch
        sub ah,0x09     ; Is it a valid capture?
        cmp ah,0x06
        mov ah,[di]
        jnc sr18        ; No, jump to avoid
        jmp short sr19

sr10:   cmp dl,16+displacement ; Moving pawn?
        jc sr19         ; No, jump
        cmp dh,3        ; Diagonal?
        jc sr19         ; No, jump
        lea bx,[si-1]
        jne sr29        ; Going right? jump
        inc bx
        inc bx
sr29:   cmp bx,[enp]    ; Is it a valid en passant?
        jne sr18        ; No, avoid

sr19:   push ax         ; Save origin and target square in stack
        mov al,ah
        and al,7
        cmp al,6        ; King eaten?
        jne sr20
        cmp sp,stack-(4+8+4)*2  ; If not in first response...
        mov bp,78       ; ...maximum score
        jne sr26
        add bp,bp       ; Maximum score (probably checkmate/stalemate)
sr26:   add sp,6        ; Ignore values
        ret

sr20:   mov bx,scores
        xlat
        cbw             ; ax = score for capture (guarantees ah = 0)
        mov bx,[enp]    ; bx = current pawn available for en passant
        cmp sp,[depth]
        jbe sr22
        pusha
        mov [enp],ax    ; En passant not possible
        mov al,[si]     ; Read origin square
        and al,0x0f     ; Clear bit 4 (marks piece moved)
        cmp al,0x0e     ; Is it a king?
        je sr36
        cmp al,0x06
        jne sr37        ; No, jump
sr36:   mov bx,si
        sub bx,di
        mov bh,ch       ; Create moved rook
        xor bh,0x02     ;
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
        cmp al,0x09     ; We have a pawn?
        je sr31
        cmp al,0x01
        jne sr30        ; No, jump
sr31:   mov bp,sp
        mov bx,di
        cmp bl,0x10     ; Going to uppermost row?
        jc sr32         ; Yes, jump
        cmp bl,0x70     ; Going to lowermost row?
        jc sr33         ; No, jump
sr32:   xor al,0x05     ; Promote to queen
        add word [bp+14],9      ; Add points for queen
sr33:   sub bx,si
        call en_passant_test
        jnc sr41
        mov [bx],ah     ; Clean en passant square
        inc word [bp+14]        ; Add points for pawn
        jmp sr30

sr41:   and bx,0x001f   ; Moving two squares ahead?
        jne sr30        ; No, jump
        mov [enp],di    ; Take note of en passant
sr30:   mov [di],al
        mov [si],ah     ; Clear origin square
        xor ch,8        ; Change side
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
        cmp ax,-127     ; Illegal movement?
        jl sr23
        xor bp,bp
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
        inc bx
        inc bx
sr42:   ret

        ; Display board
display_board:
        mov si,board-8
        mov cx,73       ; 1 frontier + 8 rows * (8 cols + 1 frontier)
sr4:    lodsb
        and al,0x0f     ; Removed "moved" bit
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

    %if com_file
    %else
        ;
        ; This marker is required for BIOS to boot floppy disk
        ;
        resb 0x01fe-($-$$)    
        db 0x55,0xaa     
    %endif

        ; Start of second sector

sr28:   cmp bp,ax       ; Better score?
        jg sr23         ; No, jump
        xchg ax,bp      ; New best score
        jne sr27
        in al,(0x40)
        cmp al,0xaa     ; Randomize it
        jg sr23
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
        and al,0x07     ; Separate piece
        cmp al,0x01     ; Is it a pawn?
        jne sr43
        call en_passant_test
        jnc sr43
        mov byte [bx],ch ; Clean
        xor byte [bx],9  ; Restore opponent pawn

sr43:   cmp al,0x06     ; Is it a king?
        jne sr18
        mov bh,ch       ; Create unmoved rook
        xor bh,0x12     ;
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
        and al,0x07     ; Was it pawn?
        jz sr11         ; Yes, check special
        cmp al,0x05     ; King?
        jne sr34        ; No, jump
        test byte [si],0x10      ; King already moved?
        je sr34         ; Yes, jump
        cmp word [temp],-40       ; In check?
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
        cmp bh,0x12     ; Unmoved rook?
        je sr9          ; Yes, can move two squares for castling

sr34:   cmp al,0x04     ; Knight or king?
        jnc sr14        ; End sequence, choose next movement
        or ah,ah        ; To empty square?
        jz sr9          ; Yes, follow line of squares
sr16:   jmp short sr14

sr11:   cmp dh,2        ; Advanced it first square?
        jnz sr14
sr15:   lea ax,[si-0x20]  ; Already checked pawn moving to empty square
        cmp al,0x40     ; At first top row or bottom row?
        jb sr17         ; No, cancel double-square movement
sr14:   inc dl
        dec dh
        jnz sr12
sr17:   inc si
sr6:    cmp si,board+120
        jne sr7
        pop di
        pop si
sr24:   ret

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
        db 0x12,0x15,0x13,0x14,0x16,0x13,0x15,0x12
scores:
        db 0,1,5,3,9,3

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
        db -17,-15,-16,-32
        db 15,17,16,32

chars:
        db ".prbqnk",0x0d,".PRBQNK"

    %if com_file
board:  equ 0x0500
depth:  equ 0x0600        ; Depth for search
enp:    equ 0x0602        ; En passant square
temp:   equ 0x0604        ; Working score
legal:  equ 0x0606        ; Flag indicating legal movement validation
stack:  equ 0x0700
    %else
        ; Bytes to say something
        db "Toledo Atomchess reloaded"
        db " (c)2015 Oscar Toledo G. "
        db "nanochess.org"

        resb 0x0400-($-$$)  

board:  equ 0x8000
depth:  equ 0x8100        ; Depth for search
enp:    equ 0x8102        ; En passant square
temp:   equ 0x8104        ; Working score
legal:  equ 0x8106        ; Flag indicating legal movement validation
stack:  equ 0x8200
    %endif

