.model tiny
.code

org 100h

locals @@

; -------------------------------- CONSTANTS -------------------------------

VIDEO_SEG		            equ 0b800h
SCREEN_WIDTH	            equ 80d

YELLOW_ON_RED	            equ 4eh
RED_ON_GRAY 	            equ 74h

JMP_BYTECODE                equ 0eah

TILDA_SCAN_CODE             equ 29h

MAX_ITERS                   equ 200d

END_STR                     equ '$'

ZERO_ASCII_CODE             equ 48d
BIG_A_ASCII_CODE            equ 65d

REGS_DUMP_ITERS             equ 13d
FLAGS_DUMP_ITERS            equ 9d
REGS_DUMP_LINE_START_LEN    equ 6d
FLAGS_DUMP_LINE_START_LEN   equ 5d

; ------------------------------- DATA TYPES -------------------------------

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
; //TODO: --> rewrite drawX + make it on registers and with arguments
; function clear screen on different scan code
; savebuffer and drawbuffer
; documentation + no copy paste
; add DrawFrame (maybe through inc)
; in frame add symbols from terminal
; //TODO: README

Start:
	call Main
	call Exit

; ---------------------------------- DATA ----------------------------------

IntValueStr     db '0000$'

RegisterValues  RegistersStruct ?
FlagsValues     FlagsStruct ?

DumpStartLines  db 'AX = $', 'BX = $', 'CX = $', 'DX = $'
                db 'SI = $', 'DI = $', 'BP = $', 'SP = $'
                db 'DS = $', 'ES = $', 'SS = $', 'CS = $'
                db 'IP = $'

                db 'c = $', 'p = $', 'a = $', 'z = $'
                db 's = $', 't = $', 'i = $', 'd = $'
                db 'o = $'

; ---------------------------------- CODE ----------------------------------

Main proc

	call GetStdKeyboardInterrupt
	call SetKeyboardInterrupt

	ret

Main endp

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

SetKeyboardInterrupt proc

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

SetKeyboardInterrupt endp

;--------------------------------------------------------------------------------
; Short:   Keyboard interrupt that draws port value scan code in vram
;--------------------------------------------------------------------------------

MyKeyboardInterrupt proc

	; int shouldn't destroy
	push ax bx cx dx di si bp es ds

	push ax

	; get scan-code of kb input
    ; 60h = KB port for pressed key scan code
	in al, 60h

    cmp al, TILDA_SCAN_CODE
    jne @@CleanUpEnd

	pop ax

    call RegsDump

    jmp @@End

@@CleanUpEnd:
    pop ax

@@End:
    call ResetController

	pop ds es bp si di dx cx bx ax

	; jmp (0eah) StdKbIntSegment : StdKbIntIndex
	; in reverse cause of Little-Endian
	db JMP_BYTECODE

MyKeyboardInterrupt endp

; cpu interprets this two words as args for jmp command
; so it jumps to the old keyboard interrupt
StdKeyboardInterruptIndex	dw ?
StdKeyboardInterruptSegment	dw ?

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

    call StoreRegsValues

    call StoreFlagsValues

    ; set df = 0 in case it's 1
    cld

    ; ES = Video segment
	mov ax, VIDEO_SEG
	mov es, ax

	; ds = cs (data is stored in code segment)
    mov bx, cs
    mov ds, bx

    ; si --> preambula for regs and flags dump
    mov si, offset DumpStartLines

    ; set color for regs dump
    mov ah, RED_ON_GRAY

    ; DI = start position in vram for regs dump
    ; -4 for centering
	mov di, (SCREEN_WIDTH * 2 + SCREEN_WIDTH / 2 - 4) * 2

    call DrawRegs

    ; DI = start position in vram for flags dump
    ; + 6 for skipping registers
    mov di, (SCREEN_WIDTH * 2 + SCREEN_WIDTH / 2 + 6) * 2

    call DrawFlags

    ret

RegsDump endp

;--------------------------------------------------------------------------------
; Short:   Stores values of all the registers in memory in struct RegisterValues
; Exp:     RegisterValues --> struct to store regs values to
; In:      register values in registers
; Destroy: AX, SI, DI, BP
;--------------------------------------------------------------------------------

;------------------------------------
; + 2 for StoreRegsValues call addr
; + 2 for RegsDumpCall call addr
; + 9 * 2 for saved regs in MyKeyboardInterrupt
; = 24
MY_STACK_SHIFT equ 22
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
    add di, (SCREEN_WIDTH * 2)
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
    add di, (SCREEN_WIDTH * 2)

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

    ; if digit
    add cl, ZERO_ASCII_CODE
    jmp @@End

@@NotDigit:

    ; if letter
    ; - 10d to get shift from 'A'
    add cl, (BIG_A_ASCII_CODE - 10d)

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
