.model tiny
.code

org 100h

locals @@

VIDEO_SEG	equ 0b800h
SCREEN_WIDTH	equ 80d
YELLOW_ON_RED	equ 4eh

Start:		
		call Main
		call Exit

Main		proc

		call InitVram	

		mov bx, (SCREEN_WIDTH * 5 + SCREEN_WIDTH / 2) * 2
		mov ah, YELLOW_ON_RED
		
		@@Next:
			in al, 60h
			mov es:[bx], ax
		cmp al, 1
		jne @@Next							

		ret
Main		endp

InitVram	proc

		mov ax, VIDEO_SEG
		mov es, ax				

		ret
InitVram	endp

Exit		proc

		mov ax, 4c00h
		int 21h

		ret
Exit		endp

end		Start