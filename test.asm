.model tiny
.code

org 100h

Start:
        xor di, di
        mov ax, 1111h
        mov bx, 2222h
        mov cx, 3333h
        mov dx, 4444h

        L2:
        mov cx, -1
        ; @@Next:
        ; loop @@Next
        inc di
        jmp L2

        mov ax, 4c00h
        int 21h

end Start
