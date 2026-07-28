; TIPCPWM.ASM - PC Speaker Pulse Width Modulation Sound Player
; based on PCS_PWM.ASM for the IBM PCs by Bumbershoot Software 
;
; adapted and optimized for the Texas Instruments Professional Computer
; support for >64k raw samples added to allow for larger sequences
;
; note - the PWM sample needs to be pre-calculated to speed up the ISR   
;
; see https://github.com/burbon04/TIPC_pwm_sounds
;
; Build: nasm -f bin TIPCPWM.ASM -o TIPCPWM.EXE
;

        cpu 8086
        bits 16
        org 0

; let's directly create a single-pass .EXE as documented in NASM manual
mz_header:
        db 'M','Z'
        dw (exe_end-$$) & 511
        dw ((exe_end-$$)+511)/512
        dw 0
        dw 2
        dw 0
        dw 0FFFFh
        dw stack_segment
        dw stack_top-stack_area
        dw 0
        dw start-program_start
        dw 0
        dw 001Ch
        dw 0
        times 32-($-$$) db 0

program_start:                                     ; and we start here
AUDIO_SEGS equ audio_size >> 16                    ; calculate no of segments
AUDIO_LASTFILL equ audio_size & 0FFFFh             ; usage of last seg

%if AUDIO_LASTFILL
AUDIO_TOTAL_SEGMENTS equ AUDIO_SEGS+1              ; remainder in most cases
%else
AUDIO_TOTAL_SEGMENTS equ AUDIO_SEGS                ; unless we hit exactly
%endif

start:
        cld     
        push cs                                    
        pop ds                                     ; DS=CS to begin with
        mov dx,text_hello-program_start            ; show text message 
        mov ah,09h
        int 21h
        mov ax,3543h                               ; TIPC Timer 1 INT 43h
        int 21h
        mov [old43_off-program_start],bx           ; save orig. IVT
        mov [old43_seg-program_start],es
        mov dx,sound_isr-program_start
        mov ax,2543h                               ; and reprogram
        int 21h
        mov ah,03h                                 ; TIPC DSR - Beeper ON                       
        int 48h                                    
        mov ah,09h                                 ; Get sysconf in ES:BX
        int 48h
        sub bx,3                                   ; see TIPC ROM listing
        mov al,[es:bx]                             ; QCONFQ section, offs -3
        mov ah,al                                  ; contains timer
        and al,0FDh
        mov [latch_irq_off-program_start],al       ; get prev. TIPC IRQ latch
        mov al,ah                                  ; as I/O port is R/O
        or al,02h
        mov [latch_irq_on-program_start],al        ; bitmask for "ON"
        push cs
        pop ax
        add ax,audio_segment                       ; move to start pos
        mov es,ax
        xor si,si                                  ; 16 byte aligned, so :0
        mov word [segments_left-program_start],AUDIO_TOTAL_SEGMENTS

%if AUDIO_SEGS                                     ; more than a single 64k?
        xor cx,cx                                  ; yes, deal with segments
%else
        mov cx,AUDIO_LASTFILL                      ; no, just remaining bits
%endif
        mov byte [done-program_start],0            ; mark "not done yet".

        ; get ready
        cli                                        ; do-not-disturb
        mov al,30h                                 ; channel 0 mode 0
        out 17h,al
        mov al,76h                                 ; channel 1 mode 3
        out 17h,al                    
        mov ax,62                                  ; divisor 62
        out 15h,al                                 ; i.e. 1.25 Mhz / 62 
        mov al,ah                                  ; about 20.161 Hz
        out 15h,al
        sti                                        ; relax

        ; "worker loop"
mainlp: hlt                                        ; stand still, we're
        cmp byte [done-program_start],0            ; event-triggered
        je mainlp                                  ; except we are done

        ; back to normal
        cli                                        ; do-not-disturb
        mov al,76h
        out 17h,al
        mov ax,31250                               ; restore default
        out 15h,al                                 ; TIPC divisor
        mov al,ah
        out 15h,al
        sti                                        ; and relax again

        push ds
        mov dx,[old43_off-program_start]
        mov ax,[old43_seg-program_start]
        mov ds,ax
        mov ax,2543h                               ; restore INT 43h
        int 21h
        pop ds
        mov ah,04h
        int 48h
        mov dx,text_done-program_start             ; send "done" message
        mov ah,09h
        int 21h
        mov ax,4C00h                               ; terminate program
        int 21h

sound_isr:                                         ; wide open throttle here
        push ax
        mov al,[cs:latch_irq_off-program_start]    ; carrier freq OFF
        out 00h,al
        mov al,[cs:latch_irq_on-program_start]     ; carrier freq ON
        out 00h,al
        mov al,[es:si]                             ; get next PWM data
        out 14h,al                                 ; send data
        xor al,al                                  ; reset
        out 14h,al                                 ; send reset
        inc si                                     ; increase pointer
        dec cx                                     ; decrease remaining
        jnz endofseg                               ; a whole 64k done?
        dec word [cs:segments_left-program_start]  ; next segment?
        jz finished
        mov ax,es
        add ax,1000h                               ; adjust seg  
        mov es,ax
        xor si,si                                  ; reset offs

%if AUDIO_LASTFILL                                 ; if sample not 64k aligned
        cmp word [cs:segments_left-program_start],1
        jne nextseg
        mov cx,AUDIO_LASTFILL
        jmp short endofseg
nextseg:
%endif
        xor cx,cx                                  ; reset counter (will wrap)

endofseg:
        mov al,20h
        out 18h,al                                 ; PIC CMD
        pop ax
        iret

finished:
        mov byte [cs:done-program_start],1         ; declare done
        mov al,20h
        out 18h,al
        pop ax
        iret

; some space for our variables
old43_off dw 0
old43_seg dw 0
segments_left dw 0
done db 0
latch_irq_off db 0
latch_irq_on db 0

; textarea
text_hello db 13,10,'TIPCPWM - segmented 20kHz PWM player for TIPC',13,10,'$'
text_done db 'done.',13,10,'$'

; align
times ((10000h-(($-program_start)&0FFFFh))&0FFFFh) db 0   

; import pre-formatted PCM data
audio_data:
        incbin "SAMPLE.PCM"
audio_end:
audio_size equ audio_end-audio_data

; align
audio_segment equ (audio_data-program_start)>>4
        align 16,db 0

; a bit of a stack space, 4096 byte ought to be enough for everybody
stack_area:
        times 4096 db 0
stack_top:
stack_segment equ (stack_area-program_start)>>4

; EOF marker to get calculations right
exe_end:
