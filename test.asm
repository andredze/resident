.model tiny
.code

org 100h

Start:
        mov ax, 0DEDh

        mov ds, ax
        mov es, ax
        mov ss, ax

        Next:

        std
        sti
        stc

        mov ax, 1111h
        mov bx, 2222h
        mov cx, 3333h
        mov dx, 4444h

        mov si, 5555h
        mov di, 6666h

        mov bp, 7777h
        mov sp, 8888h

        in al, 60h

        ; scan code of end on kb
        cmp al, 79d
        je Exit

        jmp Next

Exit:

        mov ax, 4c00h
        int 21h

end Start
