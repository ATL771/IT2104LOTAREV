;Обработка аппаратных прерываний от таймера
IDEAL
P386
model small
stack 100h
;Макрос для отладки
macro debug
   push ax
   push bx
   push cx
   push dx
   push ax

   and  ax, 0F000h
   shr  ax, 12
   mov  bx, offset tbl_hex
   xlat
   mov  [si], al
   pop  ax
   push ax

   and  ax, 0F00h
   shr  ax, 8
   inc  si
   xlat
   mov  [si], al
   pop  ax
   push ax

   and  ax, 0F0h
   shr  ax, 4
   inc  si
   xlat
   mov  [si], al
   pop  ax
   push ax

   and  ax, 0Fh
   inc  si
   xlat
   mov  [si], al

   pop  ax
   pop  dx
   pop  cx
   pop  bx
   pop  ax
endm
struc descr
        limit   dw 0
        base_l  dw 0
        base_m  db 0
        attr_1  db 0
        attr_2  db 0
        base_h  db 0
ends descr
;Структура для шлюзов ловушки
struc trap
        offs_l  dw 0
        sel     dw 16
        rsrv    db 0
        attr    db 8Fh
        offs_h  dw 0
ends trap
;Структура для шлюзов прерываний
struc intr
        offs_l  dw 0
        sel     dw 16
        rsrv    db 0
        attr    db 8Eh
        offs_h  dw 0
ends intr
DATASEG
   gdt_null     descr <0,0,0,0,0,0>             ; Селектор = 0
   gdt_data     descr <data_size-1,0,0,92h,0,0> ; Селектор = 8
   gdt_code     descr <code_size-1,0,0,98h,0,0> ; Селектор = 16
   gdt_stack    descr <100h-1,0,0,92h,0,0>      ; Селектор = 24
   gdt_screen   descr <4095,8000h,0Bh,92h,0,0>  ; Селектор = 32
  gdt_size = $-gdt_null
   ; Исключения 0 - 7 имеют общий обработчик
   idt          trap 10 dup (<dummy_exc>) 
                trap <exc_0a>            ; Исключение 0Ah
                trap <exc_0b>            ; Исключение 0Bh
                trap <exc_0c>            ; Исключение 0Ch

   ; Исключение 0Dh - #GP (General Protection Fault)
                trap <exc_0d>            
                trap <exc_0e>            ; Исключение 0Eh

   ; Исключения 0Fh-1Fh имеют общий обработчик
                trap 17 dup (<dummy_exc>) 
   idt_08       intr <new_08h>           ; Обработчик системного таймера
  idt_size = $-idt

   idtr_real    dw 3FFh, 0, 0
   pdescr       dp 0
   mes          db 10,13,'Real mode','$'
   tbl_hex      db '0123456789ABCDEF'
   string       db '**** **** **** **** **** **** ****'
  len = $-string

   home_sel     dw home
                dw 10h

   mark_08h     dw 480
   color_08h    db 71h
   time_08h     db 0

         idt_09 intr <new_09h>   ; Вектор 21h - прерывание от клавиатуры 
          intr 6 dup (<master>); Векторы 22h...27h – аппаратные, ведущий контроллер
          intr 8 dup (<slave>) ; Векторы 2Eh...2Fh - аппаратные, ведомый контроллер
   mark_09h     dw 800  ; Позиция на экране для вывода обработчиком new_09h 
   color_09h    db 1Eh  ; Атрибут символов

   ; Переменные для маскирования прерываний
   master_mask  db 0
   slave_mask   db 0

  data_size = $-gdt_null
ends
CODESEG
assume cs: @code, ds:@data
sttt equ $
proc dummy_exc ;Обработчик исключений c номерами 0-9 и 0F-1F
   pop  eax
   pop  eax
   mov  si, offset string+5
   debug
   mov  ax, 1111h
   jmp  [dword ptr home_sel]
endp
proc exc_0a ;Обработчик исключения 0A

   pop  eax
   pop  eax
   mov  si, offset string+5
   debug
   mov  ax, 0Ah
   jmp  [dword ptr home_sel]
endp
proc exc_0b ;Обработчик исключения 0B
   pop  eax
   pop  eax
   mov  si, offset string+5
   debug
   mov  ax, 0Bh
   jmp  [dword ptr home_sel]
endp
proc exc_0c ;Обработчик исключения 0C
   pop  eax
   pop  eax
   mov  si, offset string+5
   debug
   mov  ax, 0Ch
   jmp  [dword ptr home_sel]
endp
proc exc_0d ;Обработчик исключения 0D
   pop  eax
   pop  eax
   mov  si, offset string+5
   debug
   mov  ax, 0Dh
   jmp  [dword ptr home_sel]
endp
proc exc_0e ;Обработчик исключения 0E
   pop  eax
   pop  eax
   mov  si, offset string+5
   debug
   mov  ax, 0Eh
   jmp  [dword ptr home_sel]
endp

proc new_08h ;Обработчик прерывания системного таймера (IRQ0)
   ;Аппаратное прерывание - сохранить регистры
   push ax
   push bx

   ;Проверить значение счетчика
   test [time_08h], 03h
   jnz  @@skip

   mov  al, 21h
   mov  ah, [color_08h]
   mov  bx, [mark_08h]
   ; Вывести символ
   mov  [word ptr es:bx], ax
   ; Сместиться
   add  [mark_08h], 2
@@skip:
   inc  [time_08h]      ; Увеличить счетчик

   ;Послать EOI контроллеру прерываний
   mov  al,20h
   out  20h,al

   ;Восстановим регистры
   pop  bx
   pop  ax

   db 66h       ; Префикс замены размера операнда
   iret
endp

; Обработчик прерывания клавиатуры (IRQ1)
; Обрабатываются оба скан-кода и нажатия, и отпускания
proc new_09h far
   push ax      ; Сохраним используемые
   push bx      ; регистры
   in   al, 60h ; Вводим скен-код из порта 60h
   mov  bx, [mark_09h]  ; Текущая позиция на экране
   mov  ah, [color_09h] ; Aтрибут символов
   ;Вывод символа в видеобуфер
   mov  [word ptr es:bx], ax
   cmp  al, 80h ; Скан-код нажатия (<80h) ?
   jb   make
   ; Да, после него сдвинемся на 1 место
   add  [mark_09h], 2
make:
   ;Нет, сдвинемся еще на одно место
   add  [mark_09h], 2
   in   al, 61h ; Получим содержимое порта
   or   al, 80h ; Установкой старшего бита
   out  61h, al ; и последующим  сбросом его
   and  al, 7Eh ; сообщим контроллеру клавиатуры о
   out  61h, al ; приеме скан-кода символа
   mov  al, 20h ; Сигнал конца прерывания ЕOI
   out  20h, al ; в ведущий контроллер
   pop   bx     ; Восстановим используемое
   pop   ax     ; регистры
   db 66h       ; Возврат
   iret         ; в программу 
endp
start:
   xor  eax, eax
   mov  ax, @data
   mov  ds, ax

   shl  eax, 4
   mov  ebp, eax
   mov  bx, offset gdt_data
   mov  [(descr ptr bx).base_l], ax
   rol  eax, 16
   mov  [(descr ptr bx).base_m], al

   xor  eax, eax
   mov  ax, cs
   shl  eax, 4
   mov  bx, offset gdt_code
   mov  [(descr ptr bx).base_l], ax
   rol  eax, 16
   mov  [(descr ptr bx).base_m], al

   xor  eax, eax
   mov  ax, ss
   shl  eax, 4
   mov  bx, offset gdt_stack
   mov  [(descr ptr bx).base_l], ax
   rol  eax, 16
   mov  [(descr ptr bx).base_m], al

   ;Подготовка к загрузке GDTR
   mov  [dword ptr pdescr+2], ebp
   mov  [word ptr pdescr], gdt_size-1
   lgdt [pword ptr pdescr]

   ; Запрет аппаратных прерываний и NMI
   cli

   in   al, 70h
   or   al, 80h
   out  70h, al

   ;Перепрограммируем ведущий контроллер IRQ0-IRQ7

   ; (по умолчанию отображается на int 8h - int 15h)
   mov  dx, 20h ; Поpт ведущего контpоллеpа
   mov  al, 11h ; СКИ1 - инициализиpовать два контpоллеpа
   out  dx, al
   jmp  $+2     ; Задеpжка

   inc  dx      ; Второй порт контроллера (21h)

   mov  al, 20h ; СКИ2 - базовый вектоp 
   out  dx, al
   jmp  $+2

   mov  al, 4   ; СКИ3 - ведомый подключен к IRQ2 (4 = 000000100)
   out  dx, al
   jmp  $+2

   mov  al, 1   ; СКИ4 - 80х86, пpогpаммная генеpация EOI
   out  dx, al

   ; Маскируем прерывания ведущего контроллера
   ; 0FEh = 11111110b -> IRQ0 разрешено, IRQ1-IRQ7 запрещены
   mov  dx, 021h
   in   al, dx  ; Читаем текущее состояние маски
   mov  [master_mask], al       ; Сохраним маску
   mov  al, 0FEh; Разрешим IRQ0 - Системный таймер
   out  dx, al

   ; Маскируем прерывания ведомого контроллера
   mov  dx, 0A1h
   in   al, dx  ; Читаем текущее состояние маски
   mov  [slave_mask], al        ; Сохраним маску
   mov  al, 0FFh; Зпретим все прерывания
   out  dx, al

   ;Подготовка к загрузке IDTR
   mov  [word ptr pdescr], idt_size-1
   xor  eax, eax
   mov  ax, offset idt
   add  eax, ebp
   mov  [dword ptr pdescr+2], eax
   lidt [pword ptr pdescr]

   mov  eax, CR0
   or   eax, 1
   mov  CR0, eax

        db 0EAh
        dw offset continue
        dw 16
;Процедура для ведущего контроллера
proc master
   push ax      ;Сохраним используемый регистр
   mov  al, 20h ; Сигнал EOI
   out  20h, al
   pop  ax      ; Восстановим регистр
   db 66h       ; Возврат
   iret         ; в программу 
endp master
; Процедура для ведомого контроллера
proc slave
   push ax      ; Сохраним используемый регистр
   mov  al,20h  ; Сигнал EOI для
   out  0A0h, al; ведомого контроллера
   mov  al, 20h ; Сигнал EOI для
   out  20h, al ; ведущего контроллера
   pop  ax      ; Восстановим регистр
   db 66h       ; Возврат
   iret         ; в программу 
endp slave
   ;Перепрограммируем ведомый контроллер IRQ8-IRQ16
   ; (по умолчанию отображается на int 70h -int 77h)
   mov  dx, 0A0h; Поpт ведомого контpоллеpа
   mov  al, 11h ; СКИ1 - инициализиpовать два контpоллеpа, будет СКИЗ
   out  dx, al
   jmp  $+2     ; Задеpжка
   inc  dx      ; Второй порт контроллера 0A1h
   mov  al, 28h ; СКИ2: базовый вектор
   out  dx, al
   jmp  $+2
   mov  al, 2   ;СКИЗ: ведомый подключен к IRQ2 
   out  dx, al
   jmp  $+2
   mov  al, 1   ; СКИ4 - 80х86, пpогpаммная генеpация EOI
   out  dx, al
   jmp  $+2

   ;Перепрограммируем ведомый контроллер IRQ8-IRQ16
   ;(по умолчанию отображается на int 70h - int 77h)
   mov  dx, 0A0h; Поpт ведомого контpоллеpа
   mov  al, 11h ; СКИ1 - инициализиpовать два контpоллеpа, будет СКИЗ
   out  dx, al
   jmp  $+2     ; Задеpжка
   inc  dx      ; Второй порт контроллера 0A1h
   mov  al, 70h ; СКИ2: базовый вектор
   out  dx, al
   jmp  $+2
   mov  al, 2   ;СКИЗ: ведомый подключен к IRQ2 
   out  dx, al
   jmp  $+2
   mov  al, 1   ; СКИ4 - 80х86, пpогpаммная генеpация EOI
   out  dx, al

continue:
   mov  ax, 8
   mov  ds, ax

   mov  ax, 24
   mov  ss, ax

   mov  ax, 32
   mov  es, ax

   ;Разрешим аппаратные и немаскируемые прерывания
   sti
   in   al, 70h
   and  al, 07Fh
   out  70h, al

   ; Вывод символов на экарн
   mov  bx, 1600
   mov  cx, 800
   mov  dx, 3001h
xxxx:
   push cx
   mov  cx, 0
zzzz:
   loop zzzz

   mov  [word ptr es:bx], dx
   inc  dl
   add  bx, 2
   pop  cx
   loop xxxx

   mov ax, 0FFFFh
home:
   mov si, offset string
   debug
   mov si, offset string
   mov cx, len
   mov ah, 74h
   mov di, 1280
scr:
   lodsb
   stosw
   loop scr

   ; Запрет аппаратных прерываний и NMI
   cli
   in   al, 70h
   or   al, 80h
   out  70h, al

   ;Возврат в реальный ражим
   mov  eax, CR0
   and  al, 0FEh
   mov  CR0, eax

        db 0EAh
        dw offset return
        dw @code
return:
   ;Восстановим операционную среду реального режима
   mov  ax, @data
   mov  ds, ax
   mov  ax, @stack
   mov  ss, ax
   mov  sp, 100h

   ;Восстановим значение IDTR для работы в реальном режиме
   lidt [fword ptr idtr_real]

   ;Восстановим обратоно контроллер прерываний
   ;Перепрограммируем ведущий контроллер IRQ0-IRQ7

   ; (по умолчанию отображается на int 8h -int 15h)
   mov  dx, 20h ; Поpт ведущего контpоллеpа
   mov  al, 11h ; СКИ1 - инициализиpовать два контpоллеpа
   out  dx, al
   jmp  $+2     ; Задеpжка

   inc  dx      ; Второй порт контроллера (21h)

   mov  al, 08h ; СКИ2 - базовый вектоp 
   out  dx, al
   jmp  $+2

   mov  al, 4   ; СКИ3 - ведомый подключен к IRQ2 (4 = 000000100)
   out  dx, al
   jmp  $+2

   mov  al, 1   ; СКИ4 - 80х86, пpогpаммная генеpация EOI
   out  dx, al

   ; Восстановим маски прерываний
   ; Маскируем прерывания ведущего контроллера
   mov  dx, 021h
   mov  al, [master_mask]
   out  dx, al

   ; Маскируем прерывания ведомого контроллера
   mov  dx, 0A1h
   mov  al, [slave_mask]
   out  dx, al

   ;Разрешим аппаратные и немаскируемые прерывания
   sti
   in   al, 70h
   and  al, 07Fh
   out  70h, al

   mov  ah, 09h
   mov  dx, offset mes
   int  21h

   mov  ax, 4C00h
   int  21h
ends
code_size=$-sttt         
end start
end
