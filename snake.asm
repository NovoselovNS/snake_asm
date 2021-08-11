org 7c00h

width=80
height=50

initial_size=4 ;изначальный размер змейки
delay=1 ;чем больше, тем медленнее игра

;цвета
;https://en.wikipedia.org/wiki/VGA_text_mode#Data_arrangement
;https://en.wikipedia.org/wiki/Video_Graphics_Array#Color_palette
body_char=2 shl 12
food_char=6 shl 12
head_char=1 shl 12

;клавиши управления
;https://wiki.osdev.org/PS/2_Keyboard#Scan_Code_Sets
up_key=48h	;код стрелки вверх
down_key=50h
right_key=4Dh
left_key=4Bh


;переключает в текстовый режим 80*50
mov ax,1112h
int 10h


;перехват прерывания таймера и клавиатуры
push 0
pop gs
cli
mov word [gs:8*4+2],cs
mov word [gs:8*4],int8
mov word [gs:9*4+2],cs
mov word [gs:9*4],int9
sti
call start_game


endless_loop:
hlt
jmp endless_loop


rand:
	rdtsc
	add ax,[rng]
	add [rng],ax
ret


add_food:
	rand_place_for_food:
		call rand
		cmp al,width
		ja rand_place_for_food
		cmp ah,height
		ja rand_place_for_food
		cmp al,1
		jb rand_place_for_food
		cmp ah,1
		jb rand_place_for_food

		call get_char_dx
		test dx,dx
		jnz rand_place_for_food
	mov cx,food_char
	call draw_char
ret

calc_coord:	;bx=((ah-1)*width+(al-1))*2
	dec al
	dec ah
	movzx bx,ah
	imul bx,width
	xor ah,ah
	add bx,ax
	shl bx,1
ret


get_char_dx:		;dx=*calc_coord(al,ah)
	push ax
	push bx
	call calc_coord
	mov dx,[es:bx]
	pop bx
	pop ax
ret



draw_char:	;рисует значение cx по координатам ax
	push ax
	push bx

	test ax,ax
	jz @F

	call get_char_dx

	cmp cx,head_char	;if (cx==head_char && dx==body_char) start_game()
	jne just_draw		;if (cx!=head_char) goto just_draw
	cmp dx,body_char
	jne check_food
	call start_game
	jmp @F
	check_food:
		cmp dx,food_char  ;if (cx==head_char && dx==food_char) {...
		jne just_draw
		inc word [last_segm_ptr]
		inc word [last_segm_ptr]
		mov bx,[last_segm_ptr]
		mov word [bx],0
		call add_food
	just_draw:
	call calc_coord
	mov word [es:bx],cx
	@@:
	pop bx
	pop ax
ret


;рисует голову на новом месте
;и стирает последнюю часть хвоста
draw:
	push cs
	pop ds

	mov bx,[last_segm_ptr]
	push bx
	push bx
	mov ax,[bx]

	xor cx,cx
	call draw_char

	pop bx
	dec bx
	dec bx
	shift_array:
		mov ax,[bx]
		mov [bx+2],ax
		dec bx
		dec bx
		cmp bx,first_segm-2
		jne shift_array


	;вычисляем новые координаты головы змейки
	mov ax,[first_segm]
	mov cl,[code]
	cmp cl,up_key
	jne @F
	dec ah
	jnz @F
	mov ah,height
	@@:
	cmp cl,left_key
	jne @F
	dec al
	jnz @F
	mov al,width
	@@:
	cmp cl,down_key
	jne @F
	inc ah
	cmp ah,height
	jbe @F
	mov ah,1
	@@:
	cmp cl,right_key
	jne @F
	inc al
	cmp al,width
	jbe @F
	mov al,1
	@@:
	mov [first_segm],ax

	pop bx

	draw_snake_body:
		mov ax,[bx]
		mov cx,body_char
		call draw_char
		dec bx
		dec bx
		cmp bx,first_segm
		jne draw_snake_body

	mov ax,[bx]
	mov cx,head_char
	call draw_char
ret


start_game:
	mov word [last_segm_ptr],first_segm+2*initial_size
	head_rand_pos:
		call rand
		cmp al,width
		ja head_rand_pos
		cmp ah,height
		ja head_rand_pos
		cmp al,1
		jb head_rand_pos
		cmp ah,1
		jb head_rand_pos
	push cs
	pop es
	mov cx,initial_size
	mov di,first_segm
	rep stosw

	push 0b800h
	pop es
	xor di,di
	mov cx,width*height
	xor ax,ax
	rep stosw
	call add_food
ret


;обработчик прерывания таймера, вызывает функцию draw()
int8:
	cmp [skip8],0
	jne @F
	mov [skip8],delay
	call draw
	jmp end8
	@@:
	dec byte [skip8]
	end8:
jmp end_interrupt
skip8 db 0


;обработчик прерывания клавиатуры, записывает подходящие коды клавиш в переменную code
int9:
	in al,60h
	cmp al,up_key
	je no_skip
	cmp al,down_key
	je no_skip
	cmp al,right_key
	je no_skip
	cmp al,left_key
	je no_skip

	jmp int9_end
	no_skip:

	mov ah,al
	add ah,[code]

	cmp ah,up_key+down_key
	je int9_end
	cmp ah,left_key+right_key
	je int9_end

	cmp [code],al
	je int9_end

	mov [code],al

	call draw
	inc byte [skip8]

	int9_end:
	end_interrupt:
	mov al,20h
	out 20h,al
iret


code db up_key
times 510-($-$$) db ?
db 055h,0AAh
rng dw ?
last_segm_ptr dw ?
first_segm:

