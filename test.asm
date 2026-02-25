.model tiny
.code

org 100h

Start:
        xor di, di

        Next:

        std

        mov ax, 1111h
        mov bx, 2222h
        mov cx, 3333h
        mov dx, 4444h

        inc di

        cld

        in al, 60h

        ; scan code of end on kb
        cmp al, 79d
        je Exit

        jmp Next

Exit:

        mov ax, 4c00h
        int 21h

end Start
