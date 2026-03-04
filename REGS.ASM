.model tiny
.code

org 100h

locals @@

; -------------------------------- CONSTANTS -------------------------------

VIDEO_SEG		            equ 0b800h
SCREEN_WIDTH	            equ 80d
SCREEN_HEIGHT               equ 25d
SCREEN_SIZE                 equ SCREEN_WIDTH * SCREEN_HEIGHT

YELLOW_ON_RED	            equ 4eh
RED_ON_GRAY 	            equ 74h

JMP_BYTECODE                equ 0eah

TILDA_SCAN_CODE             equ 29h
ESC_SCAN_CODE               equ 01h

MAX_ITERS                   equ 200d

END_STR                     equ '$'

REGS_DUMP_ITERS             equ 13d
FLAGS_DUMP_ITERS            equ 9d
REGS_DUMP_LINE_START_LEN    equ 6d
FLAGS_DUMP_LINE_START_LEN   equ 5d

FRAME_HEIGHT                equ 15d
FRAME_WIDTH                 equ 19d
FRAME_SIZE                  equ FRAME_WIDTH * FRAME_HEIGHT

VIDEO_FRAME_POS             equ (SCREEN_WIDTH * 1 + SCREEN_WIDTH / 2 - 4 - 2) * 2

HORIZ_LINE                  equ 0cdh
VERT_LINE                   equ 0bah
LU_CORNER                   equ 0c9h
RU_CORNER                   equ 0bbh
LD_CORNER                   equ 0c8h
RD_CORNER                   equ 0bch
GRAY_BG                     equ 70h
BRT_RED                     equ 0ch
ZERO_BG_COLOR               equ 0afh

; ------------------------------- DATA TYPES -------------------------------

FrameStyle struc
    TextColor    dw ?
    BGColor      dw ?
    LUCorner     dw ?
    UHorizLine   dw ?
    RUCorner     dw ?
    LVertLine    dw ?
    MHorizLine   dw ?
    RVertLine    dw ?
    LDCorner     dw ?
    DHorizLine   dw ?
    RDCorner     dw ?
FrameStyle ends

RegistersStruct struc
    regAX    dw 0
    regBX    dw 0
    regCX    dw 0
    regDX    dw 0
    regSI    dw 0
    regDI    dw 0
    regBP    dw 0
    regSP    dw 0
    regDS    dw 0
    regES    dw 0
    regSS    dw 0
    regCS    dw 0
    regIP    dw 0
    regFlags dw 0
RegistersStruct ends

FlagsStruct struc
    flagCF  db 0
    flagPF  db 0
    flagAF  db 0
    flagZF  db 0
    flagSF  db 0
    flagTF  db 0
    flagIF  db 0
    flagDF  db 0
    flagOF  db 0
FlagsStruct ends

; --------------------------------- START ----------------------------------

Start:
	call Main
	call Exit

; ---------------------------------- DATA ----------------------------------

MyTimerInterruptIsActive db 0

IntValueStr         db '0000$'

RegisterValues      RegistersStruct ?
FlagsValues         FlagsStruct ?

DumpStartLines      db 'AX = $', 'BX = $', 'CX = $', 'DX = $'
                    db 'SI = $', 'DI = $', 'BP = $', 'SP = $'
                    db 'DS = $', 'ES = $', 'SS = $', 'CS = $'
                    db 'IP = $'

                    db 'c = $', 'p = $', 'a = $', 'z = $'
                    db 's = $', 't = $', 'i = $', 'd = $'
                    db 'o = $'

DrawBuffer          dw FRAME_SIZE DUP(0)
SaveBuffer          dw FRAME_SIZE DUP(0)

; ---------------------------------- CODE ----------------------------------

Main proc

    ; zero the MyTimerInterruptIsActive
    mov si, offset MyTimerInterruptIsActive
    mov al, 00h
    mov byte ptr cs:[si], al

    call GetStdTimerInterrupt
	call GetStdKeyboardInterrupt
	call SetMyKeyboardInterrupt

	ret

Main endp

;--------------------------------------------------------------------------------
; Short:   Sets variables for index and segment of
;		   timer interrupt to a standard DOS call
; Destroy: AX, BX, ES
;--------------------------------------------------------------------------------

GetStdTimerInterrupt proc

	; Direct realisation
	; Interrupt Table segment
	mov bx, 00h
	mov es, bx

	; TimerInterrupt index
	mov bx, 4 * 08h

	mov ax, es:[bx]
	mov cs:[StdTimerInterruptIndex], ax

	mov ax, es:[bx + 2]
	mov cs:[StdTimerInterruptSegment], ax

	ret

GetStdTimerInterrupt endp

;--------------------------------------------------------------------------------
; Short:   Sets timer interrupt (08h) to a resident
; Exp:     MyTimerInterrupt = new interrupt 08h function
; Destroy: AX, BX, ES
; Note:    sets IF = 1
;--------------------------------------------------------------------------------

SetMyTimerInterrupt proc

	; Direct realisation
	; Interrupt table segment
	mov ax, 00h
	mov es, ax

	; 4 bytes = function address size
	; 08h = interrupt: IRQ 0 Timer
	mov bx, 4 * 08h

	; prohibit interrupts (IF = 0)
	cli
    ; put my timer interrupt index
	mov es:[bx], offset MyTimerInterrupt
    ; put my timer interrupt segment
	mov ax, cs
	mov es:[bx + 2], ax
	; allow interrupts (IF = 1)
	sti

	ret

SetMyTimerInterrupt endp

;--------------------------------------------------------------------------------
; Short:   Sets default timer interrupt back (08h)
; Exp:     StdTimerInterruptIndex   = interrupt 08h function index
;          StdTimerInterruptSegment = interrupt 08h function segment
; Destroy: AX, BX, ES
; Note:    sets IF = 1
;--------------------------------------------------------------------------------

SetDefaultTimerInterrupt proc

    push di

	; Direct realisation
	; Interrupt table segment
	mov ax, 00h
	mov es, ax

	; 4 bytes = function address size
	; 08h = interrupt: IRQ 0 Timer
	mov bx, 4 * 08h

	; prohibit interrupts (IF = 0)
	cli
    ; put my timer interrupt index
    mov di, cs:[StdTimerInterruptIndex]
	mov es:[bx], di
    ; put my timer interrupt segment
    mov di, cs:[StdTimerInterruptSegment]
	mov es:[bx + 2], di
	; allow interrupts (IF = 1)
	sti

    pop di

	ret

SetDefaultTimerInterrupt endp

;--------------------------------------------------------------------------------
; Short:   Timer interrupt that draws frame with registers on the screen
;--------------------------------------------------------------------------------

MyTimerInterrupt proc

	; int shouldn't destroy
	push ax bx cx dx di si bp es ds

    call MakeTimerIteration

	pop ds es bp si di dx cx bx ax

	; jmp (0eah) StdTimerIntSegment : StdTimerIntIndex
	; in reverse cause of Little-Endian
	db JMP_BYTECODE

MyTimerInterrupt endp

; cpu interprets this two words as args for jmp command
; so it jumps to the old keyboard interrupt
StdTimerInterruptIndex	    dw ?
StdTimerInterruptSegment	dw ?

;--------------------------------------------------------------------------------
; Short:   Refreshes DrawBuffer and SaveBuffer if needed,
;          draws frame with regs in DrawBuffer and vram
; Destroy: AX, BX, CX, DX, SI, DI, BP, DS, ES
;--------------------------------------------------------------------------------

MakeTimerIteration proc

    push ax bx cx dx di si es ds
    call CompareAndRestoreBuffers
    pop ds es si di dx cx bx ax

    ; draw frame with regs in DrawBuffer
    call RegsDump

    ; copy DrawBuffer in vram
    mov si, offset DrawBuffer
    call CopyBufferToVram

    ret

MakeTimerIteration endp

;--------------------------------------------------------------------------------
; Short:   Compares DrawBuffer with vram, if not equal -->
;          Places byte from vram to DrawBuffer and SaveBuffer
; Destroy: AX, BX, CX, DX, SI, DI, DS, ES
;--------------------------------------------------------------------------------

CompareAndRestoreBuffers proc
    ; compare DrawBuffer and vram --> if not equal:
    ; than copy new vram symbol to SaveBuffer and DrawBuffer

    ; ES:[DI] --> frame in vram
    mov ax, VIDEO_SEG
    mov es, ax
    mov di, VIDEO_FRAME_POS

    ; DS:[SI] --> DrawBuffer
    mov si, offset DrawBuffer
    mov ax, cs
    mov ds, ax

    ; DS:[BX] --> SaveBuffer
    mov bx, offset SaveBuffer

    ; cx = counter for loop
    mov cx, FRAME_SIZE
    ; bp = counter for one line
    ; (to know when to go to next line)
    mov bp, FRAME_WIDTH

    @@Next:
        ; ax = symbol in DrawBuffer
        mov ax, ds:[si]
        ; dx = symbol in vram
        mov dx, es:[di]

        cmp ax, dx
        je @@IsEqual

        ; if not equal --> place symbol from vram to DrawBuffer and SaveBuffer
        ; DrawBuffer
        mov ds:[si], dx
        ; SaveBuffer
        mov ds:[bx], dx

        @@IsEqual:

        add si, 2
        add bx, 2
        add di, 2

        dec bp

        ; if went 1 buffer line --> make enter in vram
        cmp bp, 0
        jne @@NotGotoNextLine
        ; restart counter
        mov bp, FRAME_WIDTH
        ; make new line
        add di, (SCREEN_WIDTH - FRAME_WIDTH) * 2
        ; else --> continue
        @@NotGotoNextLine:

    loop @@Next

    ret

CompareAndRestoreBuffers endp

;--------------------------------------------------------------------------------
; Short:   Sets variables for index and segment of
;		   keyboard interrupt to a standard DOS call
; Destroy: AX, BX, ES
;--------------------------------------------------------------------------------

GetStdKeyboardInterrupt proc

	; Direct realisation
	; Interrupt Table segment
	mov bx, 00h
	mov es, bx

	; KeyboardInterrupt index
	mov bx, 4 * 09h

	mov ax, es:[bx]
	mov cs:[StdKeyboardInterruptIndex], ax

	mov ax, es:[bx + 2]
	mov cs:[StdKeyboardInterruptSegment], ax

	ret

GetStdKeyboardInterrupt endp

;--------------------------------------------------------------------------------
; Short:   Sets keyboard interrupt (09h) to a resident
; Exp:     MyKeyboardInterrupt = new interrupt 09h function
; Destroy: AX, BX, ES
; Note:    sets IF = 1
;--------------------------------------------------------------------------------

SetMyKeyboardInterrupt proc

	; Direct realisation
	; Interrupt table segment
	mov ax, 00h
	mov es, ax

	; 4 bytes = function address size
	; 09h = interrupt: IRQ 1 Keyboard
	mov bx, 4 * 09h

	; prohibit interrupts (IF = 0)
	cli
	mov es:[bx], offset MyKeyboardInterrupt
	mov ax, cs
	mov es:[bx + 2], ax
	; allow interrupts (IF = 1)
	sti

	ret

SetMyKeyboardInterrupt endp

;--------------------------------------------------------------------------------
; Short:   Macro that sets needed timer interrupt according to the mode
;          If it was already ser --> jumps to a normal int 08h call
; In:      mode = 00h --> stop timer
;               = 01h --> start timer
;          func_call = function that handles timer change and
;                      sets int 08h to a new one
; Destroy: SI
;--------------------------------------------------------------------------------
; Note: comments are written for the mode --> start timer (01h)
;--------------------------------------------------------------------------------

mHandleTimerChange macro mode, func_call

    ; if curr mode was already set:
    ; if TimerInterruptIsActive == mode --> do nothing
    mov si, offset MyTimerInterruptIsActive
    cmp byte ptr cs:[si], mode
    ; if TimerInterruptIsActive == mode --> jmp to normal int 09h
    je @@NormalKeyboardInterrupt

    ; else
    ; change the flag to current mode
    mov byte ptr cs:MyTimerInterruptIsActive, mode

    ; set TimerInterrupt 08h to a needed one
    ; mode 00h --> set to the default timer int
    ; mode 01h --> set to my timer int
    call func_call

    endm

;--------------------------------------------------------------------------------
; Short:   Keyboard interrupt that draws port value scan code in vram
;--------------------------------------------------------------------------------

MyKeyboardInterrupt proc

	; int shouldn't destroy
    push ax bx cx dx si di bp ds es

    push ax

	; get scan-code of kb input
    ; 60h = KB port for pressed key scan code
	in al, 60h

    cmp al, TILDA_SCAN_CODE
    je @@HandleStartTimer

    cmp al, ESC_SCAN_CODE
    je @@HandleStopTimer

    pop ax

    jmp @@NormalKeyboardInterrupt

@@HandleStartTimer:

    pop ax
    mHandleTimerChange 01h, InitBuffersAndVram
    jmp @@End

@@HandleStopTimer:

    pop ax
    mHandleTimerChange 00h, ClearScreenAndReset

@@End:
    call ResetController

    pop es ds bp di si dx cx bx ax

    ; if pressed hotkey --> don't call default int 09h
    ; iret = popf + jmp far
    iret

@@NormalKeyboardInterrupt:

    pop es ds bp di si dx cx bx ax

	; jmp (0eah) StdKbIntSegment : StdKbIntIndex
	; in reverse cause of Little-Endian
	db JMP_BYTECODE

MyKeyboardInterrupt endp

; cpu interprets this two words as args for jmp command
; so it jumps to the old keyboard interrupt
StdKeyboardInterruptIndex	dw ?
StdKeyboardInterruptSegment	dw ?

;--------------------------------------------------------------------------------
; Short:   Makes first timer iteration and starts timer:
;          1) Saves screen in SaveBuffer
;          2) Draws frame in DrawBuffer
;          3) Copies DrawBuffer to vram
;          4) Sets MyTimerInterrupt
; Destroy: AX, BX, CX, DX, SI, DI, BP, ES, DS
;--------------------------------------------------------------------------------

InitBuffersAndVram proc

    push ax bx cx dx si di
    ; copy vram in SaveBuffer
    mov di, offset SaveBuffer
    call CopyVramToBuffer

    ; copy vram in DrawBuffer
    mov di, offset DrawBuffer
    call CopyVramToBuffer

    pop di si dx cx bx ax
    ; draw frame with regs in DrawBuffer
    call RegsDump

    ; copy DrawBuffer in vram
    mov si, offset DrawBuffer
    call CopyBufferToVram

    ; set TimerInterrupt 08h to regs dump
    call SetMyTimerInterrupt

    ret

InitBuffersAndVram endp

;--------------------------------------------------------------------------------
; Short:   Clears screen (moves SaveBuffer to vram) and sets default int 08h
; Destroy: AX, BX, SI
;--------------------------------------------------------------------------------

ClearScreenAndReset proc

    ; copy SaveBuffer in vram
    mov si, offset SaveBuffer
    call CopyBufferToVram

    call SetDefaultTimerInterrupt

    ret

ClearScreenAndReset endp

;--------------------------------------------------------------------------------
; Short:   Copies frame buffer to the vram
; In:      CS:[SI] --> frame buffer
; Out:     ES:[VIDEO_FRAME_POS] --> copy of the frame buffer
;                                   buffer is drawn in vram in a rectangle
; Destroy: AX, BX, CX, SI, DI
;--------------------------------------------------------------------------------

CopyBufferToVram proc

    push ds es

    ; ES = VIDEO_SEG
    mov ax, VIDEO_SEG
    mov es, ax

    ; DS = CS
    mov ax, cs
    mov ds, ax

    ; SI --> Buffer

    mov cx, FRAME_SIZE
    ; copy buffer to the vram

    ; di = start of the frame position
    mov di, VIDEO_FRAME_POS

    ; bx = one line len (counter for going to new line)
    mov bx, FRAME_WIDTH

    cld

    @@Next:
    ; ax = ds:[si+=2]
    ; es:[di+=2] = ax
        lodsw
        stosw

        dec bx

        ; if drew 1 buffer line --> make enter in vram
        cmp bx, 0
        jne @@NotGotoNewLine
        ; restart counter
        mov bx, FRAME_WIDTH
        ; make new line
        add di, (SCREEN_WIDTH - FRAME_WIDTH) * 2
        ; else --> continue
        @@NotGotoNewLine:

    loop @@Next

    pop es ds

    ret

CopyBufferToVram endp

;--------------------------------------------------------------------------------
; Short:   Copies vram to the frame buffer
; In:      CS:[DI] --> frame buffer
; Destroy: AX, CX, SI, DI
;--------------------------------------------------------------------------------

CopyVramToBuffer proc

    push ds es

    ; DS = VIDEO_SEG
    mov ax, VIDEO_SEG
    mov ds, ax

    ; ES = CS
    mov ax, cs
    mov es, ax

    ; DI --> Buffer

    mov cx, FRAME_SIZE
    ; copy buffer to the vram

    ; si = start of the frame position in vram
    mov si, VIDEO_FRAME_POS

    ; bx = one line len (counter for going to new line)
    mov bx, FRAME_WIDTH

    cld

    @@Next:
    ; ax = ds:[si+=2]
    ; es:[di+=2] = ax
        lodsw
        stosw

        dec bx

        ; if drew 1 buffer line --> make enter in vram
        cmp bx, 0
        jne @@NotGotoNewLine
        ; restart counter
        mov bx, FRAME_WIDTH
        ; make new line
        add si, (SCREEN_WIDTH - FRAME_WIDTH) * 2
        ; else --> continue
        @@NotGotoNewLine:

    loop @@Next

    pop es ds

    ret

CopyVramToBuffer endp

;--------------------------------------------------------------------------------
; Short:   Resets Keyboard Controller and sends an EOI to an Int Controller
; Destroy: AL
;--------------------------------------------------------------------------------

ResetController proc

    ; "touch" kb (Reset keyboard controller)
    ; it allows keyboard controller to call new int's
	in al, 61h
	; disable keyboard
	or al, 80h
	out 61h, al
	; enable keyboard
	and al, not 80h
	out 61h, al

	; send a non-specific End Of Interrupt to an Interrupt Controller
	; port 20h = 20h (non-spec EOI)
	mov al, 20h
	out 20h, al

    ret

ResetController endp

;--------------------------------------------------------------------------------
; Short:   Dumps registers in vram
; Destroy: AX, BX, CX, DX, DI, SI, DS, ES
;--------------------------------------------------------------------------------

RegsDump proc

    push ax bx cx dx si di ds es
    call DrawFramePart
    pop es ds di si dx cx bx ax

    call StoreRegsValues

    call StoreFlagsValues

    call DrawRegsDumpData

    ret

RegsDump endp

;--------------------------------------------------------------------------------
; Short:   Draws frame and it's bg in DrawBuffer
; Destroy: AX, BX, CX, DX, SI, DI, DS, ES
;--------------------------------------------------------------------------------

DrawFramePart proc

    ; DF = 0
    cld

    ; DS = CS
    mov ax, cs
    mov ds, ax

    ; ES = CS
    mov es, ax

    ; DS:[SI] --> frame style
    mov si, offset RegsFrameStyle

    mov dx, FRAME_HEIGHT
    mov bx, FRAME_WIDTH

    ; DI = start position in buffer for frame (zero)
    mov di, offset DrawBuffer

    push ax cx di si
    call DrawFrame
    pop si di cx ax

    mov ax, [si + BGColor]
    call DrawFrameBackground

    ret

DrawFramePart endp

;--------------------------------------------------------------------------------
; Short:   Stores values of all the registers in memory in struct RegisterValues
; Exp:     RegisterValues --> struct to store regs values to
; In:      register values in registers
; Destroy: AX, SI, DI, BP
;--------------------------------------------------------------------------------

;------------------------------------
; + 2 for StoreRegsValues call addr
; + 2 for RegsDumpCall call addr
; + 2 for func call addr
; + 10 * 2 for saved regs in MyKeyboardInterrupt
; = 24
MY_STACK_SHIFT equ 24
;------------------------------------

StoreRegsValues proc

    ; save si in stack (will be used for indexing)
    push si

    mov si, offset RegisterValues

;------------------------------------
; store default registers

    mov cs:[si + regAX], ax
    mov cs:[si + regBX], bx
    mov cs:[si + regCX], cx
    mov cs:[si + regDX], dx
    mov cs:[si + regDI], di
    mov cs:[si + regBP], bp

    ; store si value (was used for indexing)
    ; use di for indexing (as si can't be used)
    mov di, si
    ; get true si value
    pop si
    mov cs:[di + regSI], si

;------------------------------------
; store segment registers

    mov ax, ds
    mov cs:[di + regDS], ax
    mov ax, es
    mov cs:[di + regES], ax
    mov ax, ss
    mov cs:[di + regSS], ax

;------------------------------------
; store flags, cs, ip, sp

    ; (sp can't be indexed, so use bp)
    mov bp, sp

    ; get IRET call stack frame registers
    ; in int call there were: pushf --> push cs --> push ip
    mov ax, ss:[bp + MY_STACK_SHIFT]
    mov cs:[di + regIP], ax

    mov ax, ss:[bp + MY_STACK_SHIFT + 2]
    mov cs:[di + regCS], ax

    mov ax, ss:[bp + MY_STACK_SHIFT + 4]
    mov cs:[di + regFlags], ax

    ; store sp
    mov ax, sp
    add ax, MY_STACK_SHIFT + 6
    mov cs:[di + regSP], ax

;------------------------------------

    ret

StoreRegsValues endp

;--------------------------------------------------------------------------------
; Short:   Stores needed flags values in memory at FlagsValues
;          (from register flag stored in memory)
; Exp:     AX = flag register value (can be shifted)
;          SI --> FlagsValues (can be shifted)
; In:      count = number of flags to store (shifts to do)
;          shift = how much to shift to get next flag (shr ax, shift)
; Out:     AX shifted <count> times by <shift>
;          SI += count
; Destroy: AX, BL, CX
;--------------------------------------------------------------------------------

mStoreFlagsValuesLoop macro count, shift
    local @@Next

    mov cx, count

@@Next:

    ; get curr flag value from al lowest bit
    mov bl, al
    and bl, 01h
    mov byte ptr cs:[si], bl
    inc si

    shr ax, shift

    loop @@Next

    endm

;--------------------------------------------------------------------------------
; Short:   Stores all flags values in memory at FlagsValues
;          (from register flag stored in memory)
; Exp:     cs:[RegisterValues + regFlags] = value of register flag
;          FlagsValues --> memory to store flags bits to
; Destroy: AX, BL, CX, SI
;--------------------------------------------------------------------------------
; Flags are stored in flags reg:
; [-][-][-][-] [O][D][I][T] [S][Z][-][A] [-][P][-][C]
;--------------------------------------------------------------------------------

StoreFlagsValues proc

    ; ax = flags register
    mov si, offset RegisterValues
    mov ax, cs:[si + regFlags]

    ; si --> struct with flag values
    mov si, offset FlagsValues

    ; 3 flags are stored separated by 3 reserved fields (shr ax, 2)
    mStoreFlagsValuesLoop 3, 2

    ; 6 flags are stored continuously (shr ax, 1)
    mStoreFlagsValuesLoop 6, 1

    ret

StoreFlagsValues endp

;--------------------------------------------------------------------------------
; Short:   Draws registers and flags preambula + values in vram
; Destroy: AX, BX, CX, SI, DI, BP
;--------------------------------------------------------------------------------

DrawRegsDumpData proc

    ; set df = 0 in case it's 1
    cld

    ; ES = CS
	mov ax, cs
	mov es, ax

	; ds = cs (data is stored in code segment)
    mov bx, cs
    mov ds, bx

    ; si --> preambula for regs and flags dump
    mov si, offset DumpStartLines

    ; set color for regs dump
    mov ah, RED_ON_GRAY

    ; DI = start position in vram for regs dump
    ; (newline + 1)
    mov di, offset DrawBuffer
    add di, (FRAME_WIDTH + 1) * 2

    call DrawRegs

    ; DI = start position in vram for flags dump
    ; + 10 for skipping registers
    mov di, offset DrawBuffer
    add di, (FRAME_WIDTH + 1) * 2 + 10 * 2

    call DrawFlags

    ret

DrawRegsDumpData endp

;--------------------------------------------------------------------------------
; Short:   Draws registers values with preambula in vram
; Exp:     CS:[RegisterValues] --> words with registers values
; In:      AH = color
;          ES:[DI] --> start position to draw registers
;          CS:[SI] --> start of registers preambula text in memory
; Out:     CS:[SI] --> start of flags preambula text in memory
; Destroy: AL, BL, CX, SI, DI, BP
;--------------------------------------------------------------------------------

DrawRegs proc

    ; cx = regs count
    mov cx, REGS_DUMP_ITERS
    ; bp --> struct with stored regs words
    mov bp, offset RegisterValues

@@Next:
	push di cx
    call DrawSingleReg
    pop cx di

    ; Note: CS:[SI] --> next reg preambula line
    ; in memory automatically

    ; newline
    add di, (FRAME_WIDTH * 2)
    ; to get next reg from memory
    add bp, 2

    loop @@Next

    ret

DrawRegs endp

;--------------------------------------------------------------------------------
; Short:   Dumps current reg in vram with preambula (example: AX = 0DED)
; Exp:     DS = CS
; In:      AH = color
;          ES:[DI] --> pos in vram to draw
;          CS:[SI] --> reg preambula in memory
;          CS:[BP] --> reg value word in memory
; Out:     CS:[SI] --> next flag preambula line in memory
; Destroy: AL, BL, CX, DI
;--------------------------------------------------------------------------------

DrawSingleReg proc

    ; draw preambula text for reg: "AX = "
    ; after this call:
    ; DI --> vram pos after written preambula text
    ; SI --> next reg preambula line in memory
    call DrawData

    ; save new preambula position
    push si

    ; save AH = color
    push ax

    ; AX = reg value word in memory (value to convert)
    mov ax, cs:[bp]
    ; will be: CS:[IntValueStr] --> converted string
    call ConvertIntToString

    ; DS:[SI] --> reg value str
    ; (DS = CS)
    mov si, offset IntValueStr

    ; restore AH = color value
    pop ax

    call DrawData

    ; restore new preambula position
    pop si

    ret

DrawSingleReg endp

;--------------------------------------------------------------------------------
; Short:   Dumps flags with preambula in vram
; Exp:     CS:[FlagsValues] --> bytes with flags values
; In:      AH = color
;          ES:[DI] = start position to draw flags
;          CS:[SI] = start of flags preambula text in memory
; Destroy: AL, BL, CX, DI, SI, BP
;--------------------------------------------------------------------------------

DrawFlags proc

    ; cx = flags count
    mov cx, FLAGS_DUMP_ITERS
    ; bp --> struct with stored flags bits
    mov bp, offset FlagsValues

@@NextFlag:

    push di cx
    call DrawSingleFlag
    pop cx di

    ; Note: CS:[SI] --> next flag preambula line
    ; in memory automatically

    ; newline
    add di, (FRAME_WIDTH * 2)

    ; to get next flag from memory
    add bp, 1

    loop @@NextFlag

    ret

DrawFlags endp

;--------------------------------------------------------------------------------
; Short:   Dumps current flag in vram with preambula (example: c = 1)
; In:      AH = color of symbols
;          ES:[DI] --> pos in vram to draw
;          CS:[SI] --> flag preambula in memory
;          CS:[BP] --> flag value byte in memory
; Out:     CS:[SI] --> next flag preambula line in memory
; Destroy: AL, BL, CL, DI
;--------------------------------------------------------------------------------

DrawSingleFlag proc

    ; draw preambula text for flag: "XF = "
    ; after this call:
    ; DI --> vram pos after written preambula text
    ; SI --> next flag preambula line in memory
    call DrawData

    ; bl = flag value from memory
    mov byte ptr bl, cs:[bp]

    ; cl = ascii code of a symbol
    call ConvertHexDigitToAscii

    ; al = ascii code
    ; ah = color (from arguments)
    mov al, cl

    ; draw flag value in vram
    ; es[di] = ax; di += 2
    stosw

    ret

DrawSingleFlag endp

;--------------------------------------------------------------------------------
; Short:   Converts integer (register value) into string in data at IntValueStr
; In:      AX = value to convert
; Out:     CS:[IntValueStr] = start of converted str
; Destroy: AL, BL, CL, SI
;--------------------------------------------------------------------------------

ConvertIntToString proc

    mov bx, cs
    mov ds, bx
    mov si, offset IntValueStr

    push ax

    ; al = ah (store in Little-endian)
    mov al, ah

    call ConvertByteToString

    ; al = al (get the saved value)
    pop ax

    call ConvertByteToString

    ret

ConvertIntToString endp

;--------------------------------------------------------------------------------
; Short:   Converts 1 byte in ascii str in hex and stores in data
; Exp:     DS = segment with data
; In:      DS:[SI] --> where to write data
;          AL = value to write
; Out:     SI += 2 (for wrote symbols)
; Destroy: BL, CL
;--------------------------------------------------------------------------------

ConvertByteToString proc

    ; store first High bits, then Low bits (Little-endian)

    mov bl, al
    ; get last 4 bits (high)
    shr bl, 4

    call ConvertHexDigitToAscii

    mov ds:[si], cl
    inc si

    mov bl, al
    ; get first 4 bits (low)
    ; 0fh = lower byte mask 00001111b
    and bl, 0fh

    call ConvertHexDigitToAscii

    mov ds:[si], cl
    inc si

    ret

ConvertByteToString endp

;--------------------------------------------------------------------------------
; Short:   Converts given value of digit into an ascii symbol of a hex digit
; In:      BL = value of hex digit
; Out:     CL = ascii code of a digit in hex
;--------------------------------------------------------------------------------

ConvertHexDigitToAscii proc

    ; cl will be ascii code
    mov cl, bl

    ; if value bigger than 16 --> error
    cmp bl, 0fh
    jg @@End

    ; bl >= 10 --> represents in a letter
    cmp bl, 0ah
    jge @@NotDigit

    ; if digit --> add '0' ascii code
    add cl, '0'
    jmp @@End

@@NotDigit:

    ; if letter --> add letter 'A' ascii code
    ; - 10d to get shift from 'A'
    add cl, ('A' - 10d)

@@End:

    ret

ConvertHexDigitToAscii endp

;--------------------------------------------------------------------------------
; Short:   Draws data in vram (until the '$')
; Exp:     DF = 0
; In:      DS:[SI] --> data
;          ES:[DI] --> vram position to write
;          AH = data color
; Destroy: AL, CX, DI, SI
; Out:     SI --> data after '$'
;          DI --> vram after last symbol
;--------------------------------------------------------------------------------

DrawData proc

    ; limit iterations in case there is no '$'
    mov cx, MAX_ITERS

    @@Next:
        ; al = symbol ascii code
        mov byte ptr al, cs:[si]

        ; if (al == '$') --> end
        cmp al, END_STR
        je @@End

        ; es:[di] = ax; di += 2
        stosw
        ; get next symbol from memory
        inc si

    loop @@Next

    @@End:

    ; skip last '$' (end term)
    inc si

    ret

DrawData endp

;================================================================================
; ------------------------------- FRAME_CODE -------------------------------
;================================================================================

;--------------------------------------------------------------------------------
; Short:   Draws a centered const size frame
; Exp:     ES = Video Segment
;          DF = 0
; In:      SI --> frame style format
;          DX = frame height
;          BX = frame width
;          DI = position of left upper corner of a frame
; Out:     -
; Destroy: AX, CX, SI, DI
;--------------------------------------------------------------------------------

DrawFrame proc

; Draw top line
;------------------------------------
    ; get top symbols
    add si, LuCorner
    call DrawHorizontalLine

    ; new line is not needed (buffer width is frame width)
;------------------------------------

; Draw middle part
;------------------------------------
    ; get middle symbols
    ; SI already points to the middle symbols,
    ; as they are stored continuously

    ; cx = middle part height (frame height - 2)
    mov cx, dx
    sub cx, 2

    @@Next:
        push cx si
        call DrawHorizontalLine
        pop si cx

        ; new line not needed (buffer)
    loop @@Next
;------------------------------------

; Draw bottom line
;------------------------------------
    ; get bottom symbols
    ; shift for SI = add 2 bytes * 3 symbols are in 1 line
    add si, (2 * 03d)
    call DrawHorizontalLine
;------------------------------------

    ret

DrawFrame endp

;--------------------------------------------------------------------------------
; Short:   Draws horizontal frame line in vram
; Exp:     ES = Video Segment
;          DF = 0
; In:      SI --> data with line symbols [left, middle, right]
;                 (of 2 bytes: ascii, color)
;          DI = start pos to draw line
;          BX = frame width
; Out:     DI = end pos of newly drown line
; Destroy: AX, CX, SI, DI
;--------------------------------------------------------------------------------

DrawHorizontalLine proc

; draw left symbol
    ; ds[si] = left symbol
    ; ax = ds:[si += 2]
    lodsw
    ; es:[di += 2] = ax
    stosw

; draw middle part
    ; ds[si] = middle symbol
    ; ax = ds:[si += 2]
    lodsw
    ; cx = FRAME_WIDTH - 2 for corners
    mov cx, bx
    sub cx, 2
    ; while (cx--) es:[di += 2] = ax
    rep stosw

    ; ds[si] = right symbol
    ; ax = ds:[si += 2]
    lodsw
    ; es:[di += 2] = ax
    stosw

    ret

DrawHorizontalLine endp

;--------------------------------------------------------------------------------
; Short:   Draws background for the frame
; Exp:     ES = Video Segment
;          DF = 0
; In:      DI = pos of the lu frame corner
;          BX = frame width
;          DX = frame height
;          AH = background color
; Out:     -
; Destroy: SI, DI, CX
;--------------------------------------------------------------------------------

DrawFrameBackground proc

    ; si = iterator for lines
    mov si, dx

    @@NextLine:
        ; cx = iterator for columns
        mov cx, bx

        @@NextSymbol:
            ; set bg bits only
            and byte ptr es:[di + 1], ZERO_BG_COLOR
            or  byte ptr es:[di + 1], ah

            add di, 2

        loop @@NextSymbol

        dec si

    cmp si, 0
    jnz @@NextLine

    ret

DrawFrameBackground endp

;--------------------------------------------------------------------------------

RegsFrameStyle FrameStyle <         \
    (             BRT_RED * 100h),  \
    (             GRAY_BG * 100h),  \
    (LU_CORNER  + BRT_RED * 100h),  \
    (HORIZ_LINE + BRT_RED * 100h),  \
    (RU_CORNER  + BRT_RED * 100h),  \
    (VERT_LINE  + BRT_RED * 100h),  \
    (' '        + BRT_RED * 100h),  \
    (VERT_LINE  + BRT_RED * 100h),  \
    (LD_CORNER  + BRT_RED * 100h),  \
    (HORIZ_LINE + BRT_RED * 100h),  \
    (RD_CORNER  + BRT_RED * 100h)>

;================================================================================

;--------------------------------------------------------------------------------
; Short:   Exit the process, leaving code and data in memory
; Destroy: AX DX
;--------------------------------------------------------------------------------

Exit proc

	; DOS function 31 = Terminate & Stay Resident
	mov ax, 3100h
	; DX = memory size to keep resident in paragraphs
	mov dx, offset ProgramEnd
	; 1 paragraph = 16 bytes
	shr dx, 4
	; in case memory size is not dividable by 16
	inc dx

	; call interruption for DOS funcs
	int 21h

	ret

Exit endp

;--------------------------------------------------------------------------------

ProgramEnd:

end Start
