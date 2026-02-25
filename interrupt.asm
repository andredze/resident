.model tiny
.code

org 100h

Start:
    int 09h

    mov ax, 4c00h
    int 21h

end Start
