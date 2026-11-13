ORG 100h
BITS 16
; Intel SDK-86 FAC arithmetic MVP test harness (8086 / NASM)
; Assemble: nasm -f bin fac_mvp_sdk86.asm -o fac_mvp_sdk86.bin
; Transfer binary to 0000:0100 (ORG 100h), then GO 0000:0100.
; On completion calls INT 2 to return to the SDK-86 monitor.
; The test results are stored at fixed offsets for easy monitor inspection:
;   0000:0102 - 0000:010A TEST_RESULTS[0..8] (01=pass, FF=fail, 00=not run)
;   0000:010B FAILURES (number of failed tests)
;   0000:010C - 0000:010D TEST_OUT (last packed test result, little endian)
;   0000:010E TEST_DONE (01=finished, 00=not finished)
;
; Uses current monitor-provided SS:SP; do not run if stack is not valid.
; INT 2 behavior is user-confirmed SDK-86 monitor behavior.
;

start:
    jmp short main

TEST_RESULTS: times 9 db 0
FAILURES: db 0
TEST_OUT: dw 0
TEST_DONE: db 0

main:
    push cs
    pop ds
    ; Clear prior results so rerunning doesn't leave stale test marks.
    mov byte [TEST_DONE], 0
    mov byte [FAILURES], 0
    mov di, TEST_RESULTS
    mov cx, 9
.clear:
    mov byte [di], 0
    inc di
    loop .clear

    ; TEST 0: load 2, add 3 => packed 5
    mov si, MATRIX+0
    call FAC_LOAD
    mov si, MATRIX+2
    call FP_ADD
    mov si, TEST_OUT
    call FAC_STORE
    mov ax, 0050h
    mov bx, 0
    call CHECK_PACKED

    ; TEST 1: load 7, subtract 3 => packed 4
    mov si, MATRIX+6
    call FAC_LOAD
    mov si, MATRIX+2
    call FAC_SUB
    mov si, TEST_OUT
    call FAC_STORE
    mov ax, 0040h
    mov bx, 1
    call CHECK_PACKED

    ; TEST 2: load 7, multiply 11 => packed 77
    mov si, MATRIX+6
    call FAC_LOAD
    mov si, MATRIX+8
    call FAC_MUL
    mov si, TEST_OUT
    call FAC_STORE
    mov ax, 04D0h
    mov bx, 2
    call CHECK_PACKED

    ; TEST 3: -3 * 2 => -6
    mov si, NEG_THREE
    call FAC_LOAD
    mov si, MATRIX+0
    call FAC_MUL
    mov si, TEST_OUT
    call FAC_STORE
    mov ax, 8060h
    mov bx, 3
    call CHECK_PACKED

    ; TEST 4: exponent alignment: 2 + (3*2^1) = 8
    mov si, MATRIX+0
    call FAC_LOAD
    mov si, THREE_EXP_ONE
    call FP_ADD
    mov si, TEST_OUT
    call FAC_STORE
    mov ax, 0041h     ; 4*2^1 = 8, after alignment/truncation
    mov bx, 4
    call CHECK_PACKED

    ; TEST 5: zero * negative => canonical zero
    mov si, ZERO_VALUE
    call FAC_LOAD
    mov si, NEG_THREE
    call FAC_MUL
    mov si, TEST_OUT
    call FAC_STORE
    mov ax, 0000h
    mov bx, 5
    call CHECK_PACKED

    ; TEST 6: 2047^3 needs 64 -> 32-bit normalization
    ; 2047^3 = 0x1FF4017FF, so FAC magnitude = 0xFFA00BFF, E=1
    mov si, MAX_MANTISSA
    call FAC_LOAD
    mov si, MAX_MANTISSA
    call FAC_MUL
    mov si, MAX_MANTISSA
    call FAC_MUL
    mov bx, 6
    cmp word [FAC_MAG_LO], 0BFFh
    jne .chain_failed
    cmp word [FAC_MAG_HI], 0FFA0h
    jne .chain_failed
    cmp byte [FAC_EXP], 1
    jne .chain_failed
    call MARK_PASS
    jmp .chain_done
.chain_failed:
    call MARK_FAIL
.chain_done:

    ; TEST 7: FAC_STORE does not mutate the FAC source
    ; 2047^2 = 0x003FF001, exponent=0
    mov si, MAX_MANTISSA
    call FAC_LOAD
    mov si, MAX_MANTISSA
    call FAC_MUL
    mov si, TEST_OUT
    call FAC_STORE
    mov bx, 7
    cmp word [FAC_MAG_LO], 0F001h
    jne .preserve_failed
    cmp word [FAC_MAG_HI], 003Fh
    jne .preserve_failed
    cmp byte [FAC_EXP], 0
    jne .preserve_failed
    call MARK_PASS
    jmp .preserve_done
.preserve_failed:
    call MARK_FAIL
.preserve_done:

    ; TEST 8: FAC_SAVE / FAC_RES restore loaded 7
    mov si, MATRIX+6
    call FAC_LOAD
    call FAC_SAVE
    mov si, MATRIX+0
    call FAC_LOAD
    call FAC_RES
    mov si, TEST_OUT
    call FAC_STORE
    mov ax, 0070h
    mov bx, 8
    call CHECK_PACKED

    mov byte [TEST_DONE], 1
    int 2                ; SDK-86 monitor return (not DOS)
.after_return:
    jmp .after_return    ; Defensive: if monitor unexpectedly returns

; AX expected packed value; BX = 0-based test index
CHECK_PACKED:
    cmp ax, [TEST_OUT]
    jne MARK_FAIL
    jmp MARK_PASS

MARK_PASS:
    mov byte [TEST_RESULTS+bx], 1
    ret

MARK_FAIL:
    mov byte [TEST_RESULTS+bx], 0FFh
    inc byte [FAILURES]
    ret

; 2x3 augmented matrix, row-major; S11E4 packed M*2^E
; row0: [2, 3 | 5]; row1: [7, 11 | 13]
N: db 2
MATRIX: dw 0020h,0030h,0050h,0070h,00B0h,00D0h
NEG_THREE: dw 8030h
THREE_EXP_ONE: dw 0031h
ZERO_VALUE: dw 0000h
MAX_MANTISSA: dw 7FF0h

; Floating-point registers and multiplication scratch
FAC_SIGN: db 0
FAC_EXP: db 0
FAC_MAG_LO: dw 0
FAC_MAG_HI: dw 0
FTMP_SIGN: db 0
FTMP_EXP: db 0
FTMP_MAG_LO: dw 0
FTMP_MAG_HI: dw 0
FSRC_SIGN: db 0
FSRC_EXP: db 0
FSRC_MAG_LO: dw 0
FSRC_MAG_HI: dw 0
FMULTI: dw 0
FMUL_0: dw 0
FMUL_1: dw 0
FMUL_2: dw 0
FMUL_3: dw 0

; === Original routines, with minimal assembly/test fixes ===
; ----- MATRIX_ADDR -----
MATRIX_ADDR:
    xor ah, ah      ; Clear ah, now AX = row
    xor bh, bh      ; clear bh, now BX = col
    
    mov dx, ax      ; set dx 
    shl ax, 1       ; 2*r
    add ax, dx      ; 3*r
    shl ax, 1        ; 6*r

    shl bx, 1       ; 2*c
    add ax, bx      ; final address for given element

    mov si, MATRIX  ; move pointer to start of matrix
    add si, ax      ; add offset to that pointer to get element address.
    
    ret             ; Job is done after this

; ----- FAC_LOAD -----
FAC_LOAD:
    mov ax, [si]        ; Use AX as the point to extract from using bx

.extract_sign:
    mov bl, ah
    shr bl, 1           ; extract the high byte of ah, then shift 7 to isolate sign bit
    shr bl, 1 
    shr bl, 1 
    shr bl, 1 
    shr bl, 1 
    shr bl, 1 
    shr bl, 1           ; 8086 doesn't support shifts beyond just one at a time

    mov [FAC_SIGN], bl  ; Store the sign bit into FAC_SIGN

.extract_magnitude:
    mov bx, ax
    and bx, 7FF0h               ; Clear low 4 bits and high 1 bit
    shr bx, 1                   ; Shift by 4 to allign mag to lower bits
    shr bx, 1 
    shr bx, 1 
    shr bx, 1

    mov [FAC_MAG_LO], bx        ; Store the unpacked mag into the FAC low memory
    mov word [FAC_MAG_HI], 0    ; Clear the high memory space

.extract_exponent:
    mov bl, al                  ; Move the exponent into b low
    and bl, 0Fh                 ; Clear high nibble, keep low since we only need the low 4 bits
    
    shl bl, 1                   ; Align the cleared 4 bit to the left of the 8 bit reg
    shl bl, 1
    shl bl, 1
    shl bl, 1

    sar bl, 1                   ; Shift the exponent to the right but while preserving the sign
    sar bl, 1
    sar bl, 1
    sar bl, 1

    mov [FAC_EXP], bl
    
    ret

; ----- FTMP_LOAD -----
FTMP_LOAD:
    mov ax, [si]        ; Use AX as the point to extract from using bx

.extract_sign:
    mov bl, ah
    shr bl, 1           ; extract the high byte of ah, then shift 7 to isolate sign bit
    shr bl, 1 
    shr bl, 1 
    shr bl, 1 
    shr bl, 1 
    shr bl, 1 
    shr bl, 1           ; 8086 doesn't support shifts beyond just one at a time

    mov [FTMP_SIGN], bl  ; Store the sign bit into FAC_SIGN

.extract_magnitude:
    mov bx, ax
    and bx, 7FF0h               ; Clear low 4 bits and high 1 bit
    shr bx, 1                   ; Shift by 4 to allign mag to lower bits
    shr bx, 1 
    shr bx, 1 
    shr bx, 1

    mov [FTMP_MAG_LO], bx        ; Store the unpacked mag into the FAC low memory
    mov word [FTMP_MAG_HI], 0    ; Clear the high memory space

.extract_exponent:
    mov bl, al                  ; Move the exponent into b low
    and bl, 0Fh                 ; Clear high nibble, keep low since we only need the low 4 bits
    
    shl bl, 1                   ; Align the cleared 4 bit to the left of the 8 bit reg
    shl bl, 1
    shl bl, 1
    shl bl, 1

    sar bl, 1                   ; Shift the exponent to the right but while preserving the sign
    sar bl, 1
    sar bl, 1
    sar bl, 1

    mov [FTMP_EXP], bl
    
    ret

; ----- FAC_STORE -----
FAC_STORE:
    mov ax, [FAC_MAG_LO]
    mov dx, [FAC_MAG_HI]
    mov cl, [FAC_EXP]

.normalize:
    cmp dx, 0
    jne .shift

    cmp ax, 07FFh
    jbe .normalized

.shift:
    shr dx, 1
    rcr ax, 1
    inc cl
    jmp .normalize

.normalized:
    ; Move mag into bits 4-14
    shl ax, 1
    shl ax, 1
    shl ax, 1
    shl ax, 1

    ; Exponent in bits 0-3
    mov bl, cl              ; use normalized exponent copy, not FAC_EXP
    and bl, 0Fh
    or al, bl

    ; Sign bit 15
    mov bl, [FAC_SIGN]     ; Load the sign byte into bl
    shl bl, 1              ; Shift left by 7 to get sign bit to left side of reg
    shl bl, 1
    shl bl, 1
    shl bl, 1
    shl bl, 1
    shl bl, 1
    shl bl, 1
    or ah, bl             ; Join bl to ah    

    mov [si], ax
    ret

; ----- FTMP_STORE -----
FTMP_STORE:
    mov ax, [FTMP_MAG_LO]
    mov dx, [FTMP_MAG_HI]
    
    mov cx, 21              ; loop 21 times to make the 32 bit memory into 11 bits
.normalize:
    cmp dx, 0
    jne .shift

    cmp ax, 07FFh
    jbe .normalized

.shift:
    shr dx, 1
    rcr ax, 1
    inc byte [FTMP_EXP]
    jmp .normalize

.normalized:
    shl ax, 1
    shl ax, 1
    shl ax, 1
    shl ax, 1

    mov bl, [FTMP_EXP]       ; load and clear lower 4 of exponent, then or with al
    and bl, 0Fh
    or al, bl

    mov bl, [FTMP_SIGN]     ; Load the sign byte into bl
    shl bl, 1              ; Shift left by 7 to get sign bit to left side of reg
    shl bl, 1
    shl bl, 1
    shl bl, 1
    shl bl, 1
    shl bl, 1
    shl bl, 1

    or ah, bl             ; Join bl to ah
    mov [si], ax

    ret

; ----- EXP_ALIGN -----
EXP_ALIGN:
.find_smallest_exp:
    mov al, [FAC_EXP]
    cmp al, [FTMP_EXP]

    jl .shift_fac_exp           ; FAC exponent is smaller
    jg .shift_ftmp_exp          ; FTMP exponent is smalelr
    jmp .end                    ; already equal

.shift_ftmp_exp:                ; Exponent shifting done on ftmp
    mov bl, [FAC_EXP]           ; Load FAC_EXP into bl for optimization, pointless right now, but im new to this so chill

    mov dx, [FTMP_MAG_HI]
    mov ax, [FTMP_MAG_LO]

.ftmp_loop:                     ; Loop to shift ftmp exponent
    cmp [FTMP_EXP], bl
    je .ftmp_done

    add byte [FTMP_EXP], 1      ; Add one to increase the exponent

    shr dx, 1                   ; Shift the magnitude to match the increase in exponent
    rcr ax, 1

    jmp .ftmp_loop

.ftmp_done:                     ; Store magnitude values
    mov [FTMP_MAG_HI], dx
    mov [FTMP_MAG_LO], ax
    
    jmp .end

.shift_fac_exp:
    mov bl, [FTMP_EXP] 

    mov dx, [FAC_MAG_HI]
    mov ax, [FAC_MAG_LO]
    
.fac_loop:                      ; Loop to shift ftmp exponent
    cmp [FAC_EXP], bl
    je .fac_done

    add byte [FAC_EXP], 1       ; Add one to increase the exponent

    shr dx, 1                   ; Shift the magnitude to match the increase in exponent
    rcr ax, 1

    jmp .fac_loop

.fac_done:
    mov [FAC_MAG_HI], dx        ; Store magnitude values
    mov [FAC_MAG_LO], ax

    jmp .end

.end:
    ret

; ----- FP_ADD -----
FP_ADD:
    call FTMP_LOAD              ; Load pointed to value into FTMP
    call EXP_ALIGN              ; Align exponents and adjust mags

.addition:
    mov ax, [FAC_MAG_LO]        ; Load the regs with FAC
    mov dx, [FAC_MAG_HI]
    
    add ax, [FTMP_MAG_LO]       ; Add low mags together
    adc dx, [FTMP_MAG_HI]       ; Important use of adc, if there was a carry on the low words, 1 should be added to the higher mag
    
    mov [FAC_MAG_LO], ax        ; Store final values
    mov [FAC_MAG_HI], dx

    ret

; ----- FAC_SUB -----
FAC_SUB:
    call FTMP_LOAD              ; Load ftmp and align exponents
    call EXP_ALIGN

.subtraction:
    mov ax, [FAC_MAG_LO]        ; Load regs
    mov dx, [FAC_MAG_HI]

    sub ax, [FTMP_MAG_LO]       ; Subtract low mags, then ensure you borrow when dealing with high
    sbb dx, [FTMP_MAG_HI]

    mov [FAC_MAG_LO], ax        ; Store result back into FAC
    mov [FAC_MAG_HI], dx

    ret

; ----- FAC_MUL -----
FAC_MUL:
    call FTMP_LOAD

.compute_sign:
    mov al, [FAC_SIGN]
    xor al, [FTMP_SIGN]

    mov [FAC_SIGN], al

.multiply_mags:
    ; Clear upper result words
    mov word [FMUL_0], 0
    mov word [FMUL_1], 0
    mov word [FMUL_2], 0
    mov word [FMUL_3], 0

    ; FAC_LO * FTMP_LO
    mov ax, [FAC_MAG_LO]
    mul word [FTMP_MAG_LO]

    mov [FMUL_0], ax
    mov [FMUL_1], dx


    ; FAC_HI * FTMP_LO
    mov ax, [FAC_MAG_HI]
    mul word [FTMP_MAG_LO]

    add [FMUL_1], ax
    adc dx, 0
    mov [FMUL_2], dx

    ; FAC_LO * FTMP_HI
    mov ax, [FAC_MAG_LO]
    mul word [FTMP_MAG_HI]

    add [FMUL_1], ax
    adc [FMUL_2], dx
    adc word [FMUL_3], 0

    ; FAC_HI * FTMP_HI
    mov ax, [FAC_MAG_HI]
    mul word [FTMP_MAG_HI]

    add [FMUL_2], ax
    adc [FMUL_3], dx

    ; Exponent A*B = (M_A * M_B) * 2^(E_A + E_B)
    mov al, [FAC_EXP]
    add al, [FTMP_EXP]
    mov [FAC_EXP], al

.normalize:
    ; If either FMUL_2, FMUL_3 have some number stored, then keep shifting
    mov ax, [FMUL_3]
    or ax, [FMUL_2]
    jz .normalized

    ; NASM doesn't automatically remember allocation type of memory
    shr word [FMUL_3], 1
    rcr word [FMUL_2], 1
    rcr word [FMUL_1], 1
    rcr word [FMUL_0], 1

    inc byte [FAC_EXP]
    jmp .normalize

.normalized:
    ; Move multiplication result to FAC
    mov ax, [FMUL_1]
    mov bx, [FMUL_0]

    mov [FAC_MAG_LO], bx
    mov [FAC_MAG_HI], ax

    ; Check if mag is 0, if yes, clear exponent to prevent -0
    mov ax, [FAC_MAG_LO]
    or ax, [FAC_MAG_HI]
    jnz .done

    mov byte [FAC_SIGN], 0
    mov byte [FAC_EXP], 0

    .done:
    ret

; ----- FAC_SAVE -----
FAC_SAVE:
    
    mov al, [FAC_SIGN]
    mov ah, [FAC_EXP]

    mov [FSRC_SIGN], al
    mov [FSRC_EXP], ah

    mov ax, [FAC_MAG_HI]
    mov bx, [FAC_MAG_LO]

    mov [FSRC_MAG_HI], ax
    mov [FSRC_MAG_LO], bx

    ret

; ----- FAC_RES -----
FAC_RES:
    
    mov al, [FSRC_SIGN]
    mov ah, [FSRC_EXP]

    mov [FAC_SIGN], al
    mov [FAC_EXP], ah

    mov ax, [FSRC_MAG_HI]
    mov bx, [FSRC_MAG_LO]

    mov [FAC_MAG_HI], ax
    mov [FAC_MAG_LO], bx

    ret
