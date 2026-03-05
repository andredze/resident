# Резидент

Программа выводит на экран значение всех регистров и флагов в рамке каждый тик таймера (активация/выключение рамки происходит по клавише)
с помощью резидентов для прерывания таймера и клавиатуры

Должна быть запущена на DOSBox-е

## Компиляция программы
```powershell
    regs.bat
```
или
```powershell
    tasm /la regs.asm
    tlink /t regs.obj
```

# Запуск программы

```powershell
    regs.com
```

Нажатие '~'   --> включить показ рамки с регистрами

Нажатие 'ESC' --> убрать показ рамки с регистрами

## Пример

Если запущена программа test.com, получаемая при компиляции следующего кода "test.asm"
Программа выставляет значение регистров:
BX = 2222h
CX = 3333h
DX = 4444h
SI = 5555h
DI = 6666h
BP = 7777h
SP = 8888h
DS = 0DEDh
ES = 0DEDh
SS = 0DEDh
IP находится в порядке 0777h

```asm
.model tiny
.code

org 100h

END_SCAN_CODE   equ 79d

Start:
        ; copy code to 0777h --> to set IP ~ 0777h
        ; si --> dest
        mov si, 0777h
        ; di --> src
        mov di, offset StartOfProgram

        ; cx = length of program
        mov cx, offset EndOfProgram
        mov ax, offset StartOfProgram
        sub cx, ax

CopyNext:
        ; AX = word from code src
        mov ax, cs:[di]
        ; word from code dest = AX
        mov cs:[si], ax
        ; go to next bytes
        add si, 2
        add di, 2

        loop CopyNext

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

        ; IP = 0777h (jmp to copied code)
        mov ax, 0777h
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
```

![example](https://github.com/andredze/resident/raw/master/example.png)

# Буферизация экрана
Программа сохраняет экран, находящийся за рамкой с помощью тройной буферизации. Таким образом, рамка не стирает изменения экрана, происходящие под ней

После нажатия '~'
![pressed](https://github.com/andredze/resident/raw/master/pressed.png)

После нажатия 'ESC'
![closed](https://github.com/andredze/resident/raw/master/closed.png)
