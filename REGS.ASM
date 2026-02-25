.model tiny
.code

org 100h

locals @@

;// FIXXXX!!!! перепутал i и d

; -------------------------------- CONSTANTS -------------------------------

VIDEO_SEG		            equ 0b800h
SCREEN_WIDTH	            equ 80d
YELLOW_ON_RED	            equ 4eh

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

RegisterValuesStruct struc
    SavedAxValue    dw 0
    SavedBxValue    dw 0
    SavedCxValue    dw 0
    SavedDxValue    dw 0
    SavedSiValue    dw 0
    SavedDiValue    dw 0
    SavedBpValue    dw 0
    SavedSpValue    dw 0
    SavedDsValue    dw 0
    SavedEsValue    dw 0
    SavedSsValue    dw 0
    SavedCsValue    dw 0
    SavedIpValue    dw 0
    SavedFlagsValue dw 0
RegisterValuesStruct ends

FlagsStruct struc
    FS_CF db 0
    FS_PF db 0
    FS_AF db 0
    FS_ZF db 0
    FS_SF db 0
    FS_TF db 0
    FS_IF db 0
    FS_DF db 0
    FS_OF db 0
FlagsStruct ends

; ---------------------------------- CODE ----------------------------------
; //TODO: --> flags in different struct + function DrawFlags
; function clear screen on different scan code
; documentation + no copy paste
; + maybe rename struct fields
; + read about flags in thelp

Start:

    ; call RegsDump
	call Main
    int 09h

	call Exit

;--------------------------------------------------------------------------------

Main proc

	call GetStdKeyboardInterrupt
	call SetKeyboardInterrupt

    ; mov ax, 4E4Eh
    ; call RegsDump

    ; int 09h

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
	mov [StdKeyboardInterruptIndex], ax

	mov ax, es:[bx + 2]
	mov [StdKeyboardInterruptSegment], ax

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
    pushf
	push ax bx cx di si bp sp es

	push ax

	; get scan-code of kb input
    ; 60h = KB port for pressed key scan code
	in al, 60h

    ; cmp al, TILDA_SCAN_CODE
    ; jne @@CleanUpEnd

	pop ax

    call RegsDump

    jmp @@End

; @@CleanUpEnd:
;     pop ax

@@End:
    call ResetController

	pop es sp bp si di cx bx ax
    popf

	; jmp (0eah) StdKbIntSegment : StdKbIntIndex
	; in reverse cause of Little-Endian
	db JMP_BYTECODE

MyKeyboardInterrupt endp

StdKeyboardInterruptIndex	dw ?
StdKeyboardInterruptSegment	dw ?

;--------------------------------------------------------------------------------
; Short:   Sets arguments needed to use vram
; Out:     ES = Video segment
; Destroy: AX
;--------------------------------------------------------------------------------

InitVram proc

	mov ax, VIDEO_SEG
	mov es, ax

	ret

InitVram endp

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
; Exp:     -
; In:      -
; Out:     -
; Destroy: AX, BX, CX, DI, SI, ES
;--------------------------------------------------------------------------------

RegsDump proc

    call StoreRegsValues

    call StoreFlagsValues

    call DrawRegs

    call DrawFlags

    ret

RegsDump endp

;--------------------------------------------------------------------------------
; Short:   -
; Exp:     -
; In:      -
; Out:     -
; Destroy: -
;--------------------------------------------------------------------------------

;------------------------------------
; + 2 for StoreRegsValues call addr
; + 6 for pushes in StoreRegsValues
; + 2 for RegsDumpCall call addr
; + 9 * 2 for saved regs in MyKeyboardInterrupt
; = 28
MY_STACK_SHIFT equ 28
;------------------------------------

StoreRegsValues proc

    push si

    mov si, offset RegisterValues

;------------------------------------
; store flags, cs and ip

    push ax bp

    mov bp, sp

    ; in int call there were: pushf --> push cs --> push ip
    mov ax, [bp + MY_STACK_SHIFT]
    mov cs:[si + SavedIpValue], ax

    mov ax, [bp + MY_STACK_SHIFT + 2]
    mov cs:[si + SavedCsValue], ax

    mov ax, [bp + MY_STACK_SHIFT + 4]
    mov cs:[si + SavedFlagsValue], ax

    pop bp ax

;------------------------------------
; store sp
    push ax

    mov ax, sp
    add ax, MY_STACK_SHIFT + 6 - 2
    mov cs:[si + SavedSpValue], ax

    pop ax

;------------------------------------
; store segment registers

    push ax

    mov ax, ds
    mov [si + SavedDsValue], ax

    mov ax, es
    mov [si + SavedEsValue], ax

    mov ax, ss
    mov [si + SavedSsValue], ax

    pop ax

;------------------------------------
; store default registers

    mov [si + SavedAxValue], ax
    mov [si + SavedBxValue], bx
    mov [si + SavedCxValue], cx
    mov [si + SavedDxValue], dx
    mov [si + SavedDiValue], di
    mov [si + SavedBpValue], bp

; store si value (was used for indexing)

    mov di, si
    pop si
    mov [di + SavedSiValue], si

    ret

StoreRegsValues endp

;--------------------------------------------------------------------------------
; Short:   -
; Exp:     -
; In:      -
; Out:     -
; Destroy: -
;--------------------------------------------------------------------------------
; Flags are stored in flags reg:
; [-][-][-][-] [O][D][I][T] [S][Z][-][A] [-][P][-][C]

StoreFlagsValues proc

    xor ax, ax

    mov si, offset RegisterValues

    ; ax = flags reg
    mov ax, [si + SavedFlagsValue]

    mov si, offset FlagsValues

; when they are separated with 1 value
    mov cx, 3

@@NextFlagSep:

    ; get curr flag value from al lowest bit
    mov bl, al
    and bl, 01h
    mov byte ptr [si], bl
    inc si

    ; move 2 because of reserved flag bit
    shr ax, 2

    loop @@NextFlagSep

; when they are stored continuously
    mov cx, 6

@@NextFlagCont:

    ; get curr flag value from al lowest bit
    mov bl, al
    and bl, 01h
    mov byte ptr [si], bl
    inc si

    shr ax, 1

    loop @@NextFlagCont

    ret

StoreFlagsValues endp

;--------------------------------------------------------------------------------
; Short:   -
; Exp:     -
; In:      -
; Out:     -
; Destroy: -
;--------------------------------------------------------------------------------

DrawRegs proc

    ; set df = 0 in case it's 1
    cld

    call InitVram

    ; set drawing pos (-4 for centering)
	mov di, (SCREEN_WIDTH * 2 + SCREEN_WIDTH / 2 - 4) * 2
    mov si, offset DumpStartLines

	; set data pos in ds:[si]
    mov bx, cs
    mov ds, bx

    mov cx, REGS_DUMP_ITERS

    mov bp, offset RegisterValues

;------------------------------------
@@NextReg:

    mov ax, [bp]
	push si di
    mov dx, 0d
    call DrawSingleReg
    pop di si

    ; newline
    add di, (SCREEN_WIDTH * 2)
    add si, REGS_DUMP_LINE_START_LEN

    ; to get next reg from memory
    add bp, 2

    loop @@NextReg
;------------------------------------

    ret

DrawRegs endp

;--------------------------------------------------------------------------------
; Short:   -
; Exp:     -
; In:      -
; Out:     -
; Destroy: -
;--------------------------------------------------------------------------------

DrawFlags proc

    mov cx, FLAGS_DUMP_ITERS

    mov bp, offset FlagsValues

;------------------------------------
@@NextFlag:

    mov ax, [bp]
	push si di
    mov dx, 3d
    call DrawSingleReg
    pop di si

    ; newline
    add di, (SCREEN_WIDTH * 2)
    add si, FLAGS_DUMP_LINE_START_LEN

    ; to get next flag from memory
    add bp, 1

    loop @@NextFlag
;------------------------------------

    ret

DrawFlags endp

;--------------------------------------------------------------------------------
; Short:   -
; Exp:     -
; In:      AX = reg value
;          DX = shift for IntValueStr
; Out:     -
; Destroy: -
;--------------------------------------------------------------------------------

DrawSingleReg proc

    push ax

; set color
	mov ah, YELLOW_ON_RED

    push cx
    call DrawData
    pop cx
;------------------------------------

    mov bh, YELLOW_ON_RED

    pop ax

    push dx di bx ax
    call DrawRegValue
    add sp, 8

    ret

DrawSingleReg endp

;--------------------------------------------------------------------------------
; Short:   -
; Exp:     -
; In:      push arguments in stack in order
;          [0] = shift for IntValueStr  ([bp + 10])
;                (to draw only a part of a word,
;                 for drawing a bit --> shift = 3)
;          [1] = vram pos to write data ([bp + 8])
;          [2] = color in high byte     ([bp + 6])
;          [3] = reg value              ([bp + 4])
; Out:     -
; Destroy: -
;--------------------------------------------------------------------------------

DrawRegValue proc

    push bp
    mov bp, sp

    push ax bx cx si di

    mov ax, [bp + 4]

    call ConvertIntToString

    mov bx, cs
    mov ds, bx
    mov si, offset IntValueStr

    ; add shift for drawing only a part of a word
    mov di, [bp + 10]
    add si, di

    mov ax, [bp + 6]
    mov di, [bp + 8]

    call DrawData

    pop di si cx bx ax

    pop bp

    ret

DrawRegValue endp

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
; In:      SI --> data
;          DI --> vram position to write
;          AH = data color
; Destroy: AL, CX, DI, SI
;--------------------------------------------------------------------------------

DrawData proc

    mov cx, MAX_ITERS

    @@Next:
        mov byte ptr al, [si]

        cmp al, END_STR
        je @@End

        stosw
        inc si

    loop @@Next

    @@End:

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

; ---------------------------------- DATA ----------------------------------

IntValueStr db ?, ?, ?, ?, '$'

RegisterValues RegisterValuesStruct ?

FlagsValues FlagsStruct ?

DumpStartLines  db 'AX = $'
                db 'BX = $'
                db 'CX = $'
                db 'DX = $'
                db 'SI = $'
                db 'DI = $'
                db 'BP = $'
                db 'SP = $'
                db 'DS = $'
                db 'ES = $'
                db 'SS = $'
                db 'CS = $'
                db 'IP = $'
                db 'c = $'
                db 'p = $'
                db 'a = $'
                db 'z = $'
                db 's = $'
                db 't = $'
                db 'i = $'
                db 'd = $'
                db 'o = $'

;--------------------------------------------------------------------------------

ProgramEnd:

end Start
