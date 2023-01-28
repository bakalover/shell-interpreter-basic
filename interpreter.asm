section .bss
proc_code: resd 1 ; код выполнения дочернего процесса
proc_args: resq 4 ; массив на аргументы и саму команду
environ: resq 1 ; переменные среды
?: resb 4
proc_arg0: resb 256
proc_arg1: resb 256
proc_arg2: resb 256
pwd_str: resb 256

section .data
error_msg: db "<No suitable command> Retry: "
cd_command: db "/bin/cd", 0
pwd_command: db "/bin/pwd", 0

section .text
global _start

_start:
mov qword [proc_arg0], 0x0
mov qword [proc_arg0+(8)], 0x0
mov qword [proc_arg1], 0x0
mov qword [proc_arg1+(8)], 0x0
mov qword [proc_arg2], 0x0
mov qword [proc_arg2+(8)], 0x0

mov rdi, 0 ; установка дескриптора
mov rsi, proc_arg0 ; сохранение в буфер начиная с начала
mov rdx, 1 ; число символов на чтение

reading_arg0:
mov rax, 0 ; установка режима чтения
syscall
mov rax, [rsi]
cmp rax, 0x20
jz reading_arg1
cmp rax, 0x0A
jz print_error
inc rsi
jmp reading_arg0

reading_arg1:
mov byte [rsi], 0x0 ; После очередного чтения аргумента у нас в конце хранится пробел, мы заменяем его на 0
mov rsi, proc_arg1

reading_arg1_cycle:
mov rax, 0 ; установка режима чтения
syscall
mov rax, [rsi]
cmp rax, 0x20
jz reading_arg2
cmp rax, 0x24
jz set_var_1
cmp rax, 0x0A
jz print_error
inc rsi
jmp reading_arg1_cycle

reading_arg2:
mov byte [rsi], 0x0
mov rsi, proc_arg2

reading_arg2_cycle: ; если будет попытка ввести более 2-х аргументов - child_process вернёт ошибку, которая обработается далее
mov rax, 0 ; установка режима чтения
syscall
mov rax, [rsi]
cmp rax, 0x24
jz set_var_2 
cmp rax, 0x0A 
jz get_environ
inc rsi
jmp reading_arg2_cycle

print_error:
writing:
mov rdi, 1
mov rsi, error_msg; устанавливаем указатель на начало
mov rdx, 29 ; число символов на вывод
mov rax, 1
syscall
jmp exit

set_var_1:
mov r13, 1
inc rsi
jmp reading_arg1_cycle

set_var_2:
mov r13, 2
inc rsi 
jmp reading_arg2_cycle

get_environ:
mov byte [rsi], 0x0 ; после последнего аргумента у нас хранится символ переноса 0x0A - меняем его на 0

;pop rax ; без переменных среды - работает, с ними - ошибка при множественном исполнении, видимо проблема со стеком
;lea rax, [rsp+(rax+1)*8] 
;mov qword [environ], rax

mov rsi, proc_arg0
mov rdi, cd_command
call cmp_string
cmp rax,0x1
jz cd_exec
mov rsi, proc_arg0
mov rdi, pwd_command
call cmp_string
cmp rax,0x1
jz pwd_exec
jmp fill_args

cd_exec:
mov rdi, proc_arg1
mov rax, 80
syscall
jmp exit

pwd_exec:
mov rdi, pwd_str
mov rsi, 256
mov rax, 79
syscall
mov rdi, 1
mov rsi, pwd_str; устанавливаем указатель на начало
mov rdx, 256; число символов на вывод
mov rax, 1
syscall
jmp exit

cmp_string:

loop:
mov ah, [rdi]
mov al, [rsi]
inc rdi 
inc rsi
cmp ah, 0
jz chk_end
cmp al, 0
jz chk_end
cmp ah,al
jz loop
jmp cmp_string_false

chk_end:
cmp ah,al
jz cmp_string_true

cmp_string_false:
mov rax, 0x0
ret
cmp_string_true:
mov rax, 0x1
ret



fill_args:
cmp r13, 1
jz fill_args_1
cmp r13, 2
jz fill_args_2

mov qword [proc_args+(0*8)], proc_arg0
mov qword [proc_args+(1*8)], proc_arg1
mov qword [proc_args+(2*8)], proc_arg2
mov qword [proc_args+(3*8)], 0 ; указатель на конец массива переменных
jmp run_command

fill_args_1:
mov qword [proc_args+(0*8)], proc_arg0
mov qword [proc_args+(1*8)], ?
mov qword [proc_args+(2*8)], proc_arg2
mov qword [proc_args+(3*8)], 0 ; указатель на конец массива переменных
mov r13, 0
jmp run_command

fill_args_2:
mov qword [proc_args+(0*8)], proc_arg0
mov qword [proc_args+(1*8)], proc_arg1
mov qword [proc_args+(2*8)], ?
mov qword [proc_args+(3*8)], 0 ; указатель на конец массива переменных
mov r13, 0
jmp run_command

run_command:
mov rax, 57 
syscall ; rax is set to the pid of the new process(представляем будто код дальше раздваивается и у каждого свой rax)
cmp rax, 0  
jne .parent_proc

.child_proc: 
mov rax, 59 
mov rdi, proc_arg0 
mov rsi, proc_args 
mov rdx, [environ] 
syscall

.child_proc_failed: 
mov rax, 60  
mov rdi, 255
syscall

.parent_proc: 
mov rdi, rax 
mov rsi, proc_code 
mov rdx, 0   
mov r10, 0   
mov rax, 61  
syscall

xor ax,ax
mov ax, [proc_code+1]
mov	cx,0xA

xor	dx,dx          
div	cx             
xchg ax,dx          
add	al,'0'       
mov byte [?+2], al                 
xchg ax,dx                   

xor	dx,dx          
div	cx             
xchg ax,dx          
add	al,'0'        
mov byte [?+1], al                 
xchg ax,dx          

xor	dx,dx          
div	cx             
xchg ax,dx          
add	al,'0'        
mov byte [?], al                 
xchg ax,dx          
mov byte [?+3],0x0

exit:
jmp _start ; aaa
