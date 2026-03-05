.model tiny
.code

org 100h

END_SCAN_CODE   equ 79d

Start:
        ; copy code to 9999h --> to set IP ~ 9999h

        ; es:[di] --> dest
        ; ES = CS
        mov ax, cs
        mov es, ax
        mov di, 9999h
        ; ds:[si] --> src
        ; DS = CS
        mov ax, cs
        mov ds, ax
        mov si, offset StartOfProgram

        ; cx = length of program
        mov cx, offset EndOfProgram
        mov ax, offset StartOfProgram
        sub cx, ax

        ; inc in case not div by 2
        inc cx
        ; cx = cx / 2 (moving by 2 bytes)
        shr cx, 1

        ; copy code
        rep movsw

        ; set segments equal to 0DEDh
        ; DS, ES, SS (CS can not be touched)
        mov ax, 0DEDh

        mov ds, ax
        mov es, ax
        mov ss, ax

        ; set regs from bx = 2222h to sp = 8888h
        ; (ax will be for scan-code)
        mov bx, 2222h
        mov cx, 3333h
        mov dx, 4444h
        mov si, 5555h
        mov di, 6666h
        mov bp, 7777h
        mov sp, 8888h

        ; IP = 9999h (jmp to copied code)
        mov ax, 9999h
        jmp ax

StartOfProgram:
        Next:
        mov ah, 00h
        ; get last pressed kb scan-code
        in al, 60h

        ; exit if END was pressed
        cmp al, END_SCAN_CODE
        je Exit

        jmp Next

Exit:
        ; end program with success
        mov ax, 4c00h
        int 21h

EndOfProgram:

end Start
