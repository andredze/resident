# Resident registers

Program makes a resident for a timer interrupt (IRQ 0)
that dumps registers in a frame every tick.

Supposed to be ran on DOSBox

# Build program
```powershell
    regs.bat
```
or
```powershell
    tasm /la regs.asm
    tlink /t regs.obj
```

# Run program

```powershell
    regs.com
```

To see the registers --> press the '~' button (tilda)

To delete the frame  --> press the 'ESC' button (escape)

## Example

When program test.asm is ran:

```asm
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
```

![example](https://github.com/andredze/resident/raw/master/example.png)

# Screen saves
Program remembers the screen that was under the frame and refreshes it when the frame is closed (triple-buffering)

When pressed '~'
![pressed](https://github.com/andredze/resident/raw/master/pressed.png)

When pressed 'ESC'
![closed](https://github.com/andredze/resident/raw/master/closed.png)
