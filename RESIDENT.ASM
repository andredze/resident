.model tiny
.code

org 100h

locals @@

; -------------------------------- CONSTANTS -------------------------------

VIDEO_SEG		equ 0b800h
SCREEN_WIDTH	equ 80d
YELLOW_ON_RED	equ 4eh

; ---------------------------------- CODE ----------------------------------

Start:

	call Main
	call Exit

;--------------------------------------------------------------------------------

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

	; DOS int realisation
;------------------------------------
	; DOS func 35h = get INT Vector
	; 09h = kb int number
; 	mov ax, 3509h
	; DOS func int
; 	int 21h
	; func should be at es:[bx]
; 	mov StdKeyboardInterruptIndex, bx
; 	mov bx, es
; 	mov StdKeyboardInterruptSegment, bx
;------------------------------------

	; Direct realisation
;------------------------------------
	; Interrupt Table segment
	mov bx, 00h
	mov es, bx

	; KeyboardInterrupt index
	mov bx, 4 * 09h

	mov ax, es:[bx]
	mov [StdKeyboardInterruptIndex], ax

	mov ax, es:[bx + 2]
	mov [StdKeyboardInterruptSegment], ax
;------------------------------------

	ret

GetStdKeyboardInterrupt endp

;--------------------------------------------------------------------------------
; Short:   Sets keyboard interrupt (09h) to a resident
; Exp:     MyKeyboardInterrupt = new interrupt 09h function
; Destroy: AX, BX, ES
; Note:    sets IF = 1
;--------------------------------------------------------------------------------

SetKeyboardInterrupt proc

	; DOS int realisation
;------------------------------------
; 	; DOS func 25h = set INT Vector
; 	; 09h = kb int number
; 	mov ax, 2509h
; 	; new func should be at ds:[dx]
; 	mov bx, cs
; 	mov ds, bx
; 	mov dx, offset MyKeyboardInterrupt
;
; 	; DOS func int
; 	int 21h
;------------------------------------

	; Direct realisation
;------------------------------------
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
;------------------------------------

	ret

SetKeyboardInterrupt endp

;--------------------------------------------------------------------------------
; Short:   Keyboard interrupt that draws port value scan code in vram
;--------------------------------------------------------------------------------

MyKeyboardInterrupt proc

	; int shouldn't destroy
	push ax bx es

	call InitVram

	; set drawing pos
	mov bx, (SCREEN_WIDTH * 5 + SCREEN_WIDTH / 2) * 2
	; set color
	mov ah, YELLOW_ON_RED

	; put scan-code of input in vram
	in al, 60h
	mov es:[bx], ax

	; "touch" kb
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

	pop es bx ax

	; jmp (0eah) StdKbIntSegment : StdKbIntIndex
	; in reverse cause of Little-Endian
	db 0eah

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
; Short:   Exit the process, leaving code and data in memory
; Destroy: AX DX
;--------------------------------------------------------------------------------

Exit proc

	; DOS function 31 = Terminate & Stay Resident
	mov ax, 3100h
	int 21h

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
