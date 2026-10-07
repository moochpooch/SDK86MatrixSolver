## Memory Structure
#### S11E4 Structure
The floating point representation is 16 bits so that it can be easily stored in a standard 16 bit register,
[ 1 bit sign | 11 bit magnitude | 4 bit signed exponent ]
#### FAC
The S11E4 structures can be unpacked into more precise implementation for operation. In memory, there is one general purpose "floating point register", called the FAC. Similar to how PDP-1 systems have just one AC register to do most of the work, the FAC works in a similar manner. 

The general structure of the FAC is 33 bits, where one bit is signed, and the rest are magnitude. 
[ 1 bit sign (1 byte, 1 bit used) | 8 bit exp | 32 bit magnitude ] = 6 bytes

Like the PDP-1, this general structure introduces -0's. To fix this, during any given operation where FAC is reassigned, a sub routine runs that checks if the maginute is all 0's; if it's found to be the case, the routine will set the sign bit to 0 as well. The general algorithm is as follows:
```asm
cmp FAC_MAG, 0
jne .not_zero

mov byte [FAC_SIGN], 0
mov byte [FAC_EXP],  0
```

The FAC is assigned with FP_LOAD and will unpack a S11E4 structure into the 32-bit variant; any further operations can be done using dedicated functions that use the assigned FP_LOAD as the left hand operand of an operation and SI as the right hand side.

The SI register shall point to a packed S11E4 structure; during the function call, the structure is unpacked into a memory space labeled FAC_TMP, where FAC_TMP holds the 32 bit equivalent of S11E4.
#### FAC Functions
Functions to interface with the floating point registers are
```asm
FP_LOAD ; FAC = [SI]
FP_ADD  ; FAC = FAC + [SI]
FP_SUB  ; FAC = FAC - [SI]
FP_MUL  ; FAC = FAC * [SI]
FP_DIV  ; FAC = FAC / [SI]
FP_STORE; [DI] = FAC
```
The A reg acts like an accumalator register, where the A register is added to, subtracted by, etc. In our actual program, FA shall be a fixed register.

#### Matrix Memory
The matrix will be stored flat in an augmented format; at least for the first implementation. It will also be hard coded, so the order is known. In memory, it would look like:
```asm
dw ...  ; A[0][0]
dw ...  ; A[0][1]
dw ...  ; b[0]

dw ...  ; A[1][0]
dw ...  ; A[1][1]
dw ...  ; b[1]
```
for a matrix of order 2. To access a given row, you first need to choose the row, which is done by $row*order+1$, where the plus one is necessary to skip the b matrix. The specific column is an offset from that row. You also need to account for a word being 2 bytes, so you multiply the final result by 2, this gives a navigation formula of
$$offset = 2[r(N+1)+c]$$
where r is the row, N is the order, and c is the column.

Each element will be a stored S11E4 structure

#### Reserved Memory
The program has reserved memory for the initial 2x2 matrix, the FAC, FAC_TMP, and a Guass-Jordan specific FMULTI S11E4 structure for function specific state tracking.
```asm
; Matrix memory
N:           db 2       ;Order

MATRIX:
    times 6  dw 0       ; 2x3 augmented matrix

; Floating Point Memory
FAC_SIGN:    db 0
FAC_EXP:     db 0
FAC_MAG_LO:  dw 0
FAC_MAG_HI:  dw 0

FTMP_SIGN:   db 0
FTMP_EXP:    db 0
FTMP_MAG_LO: dw 0
FTMP_MAG_HI: dw 0

; Gaussian elimination expanded floating point
FMULTI:      dw 0       ; packed S11E4 multiplier
```
In total, it equates to 27 bytes of reserved memory.

## Matrix Functions
### Addressing
The addressing function will let you address a specific element given AL = row and BL = col. Assumes a constant 2 x 2 matrix with an extra element for the augmented value, so to move to each row, you need to navigate 6 bytes per row
```asm
MATRIX_ADDR:
    xor ah, ah      ; Clear ah, now AX = row
    xor bh, bh      ; clear bh, now BX = col
    
    mov dx, ax      ; set dx 
    shl ax, 1       ; 2*r
    add ax, dx      ; 3*r
    sl ax, 1        ; 6*r

    shl bx, 1       ; 2*c
    add ax, bx      ; final address for given element

    mov si, MATRIX  ; move pointer to start of matrix
    add si, ax      ; add offset to that pointer to get element address.
    
    ret             ; Job is done after this
```

## FP Functions
### FAC_LOAD
Converts the S11E4 into a 33-bit FAC representation. The function also assumed that the SI is pointing to the element that should be unpacked and loaded into FAC.

```asm
FAC_LOAD:
    mov ax, [si]        ; Use AX as the point to extract from using bx

    mov bl, ah
    shr bl, 1           ; extract the high byte of ah, then shift 7 to isolate sign bit
    shr bl, 1 
    shr bl, 1 
    shr bl, 1 
    shr bl, 1 
    shr bl, 1 
    shr bl, 1           ; 8086 doesn't support shifts beyond just one at a time

    mov [FAC_SIGN], bl  ; Store the sign bit into FAC_SIGN

    mov bx, ax
    and bx, 7FF0h               ; Clear low 4 bits and high 1 bit
    shr bx, 1                   ; Shift by 4 to allign mag to lower bits
    shr bx, 1 
    shr bx, 1 
    shr bx, 1

    mov [FAC_MAG_LO], bx        ; Store the unpacked mag into the FAC low memory
    mov word [FAC_MAG_HI], 0    ; Clear the high memory space

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
```
### FTMP Load
Same thing as FAC_LOAD but for the tmp register
```asm
FTMP_LOAD:
    mov ax, [si]        ; Use AX as the point to extract from using bx

    mov bl, ah
    shr bl, 1           ; extract the high byte of ah, then shift 7 to isolate sign bit
    shr bl, 1 
    shr bl, 1 
    shr bl, 1 
    shr bl, 1 
    shr bl, 1 
    shr bl, 1           ; 8086 doesn't support shifts beyond just one at a time

    mov [FTMP_SIGN], bl  ; Store the sign bit into FAC_SIGN

    mov bx, ax
    and bx, 7FF0h               ; Clear low 4 bits and high 1 bit
    shr bx, 1                   ; Shift by 4 to allign mag to lower bits
    shr bx, 1 
    shr bx, 1 
    shr bx, 1

    mov [FTMP_MAG_LO], bx        ; Store the unpacked mag into the FAC low memory
    mov word [FTMP_MAG_HI], 0    ; Clear the high memory space

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
```
### FAC Store
Stores a value from FAC into S11E4 given that the SI pointer is pointing to the location to store into
```asm
FAC_STORE:
    mov ax, [FAC_MAG_LO]
    mov dx, [FAC_MAG_HI]
    
    mov cx, 21              ; loop 21 times to make the 32 bit memory into 11 bits
.normalize:
    cmp dx, 0
    jne .shift

    cmp ax, 07FFh
    jbe .normalized

.shift:
    shr dx, 1
    rcr ax, 1
    inc byte [FAC_EXP]
    jmp .normalize

.normalized:
    shl ax, 1
    shl ax, 1
    shl ax, 1
    shl ax, 1

    mov bl, [FAC_EXP]       ; load and clear lower 4 of exponent, then or with al
    and bl, 0Fh
    or al, bl

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
```
### FTMP Store
Stores a value into from FTMP into S11E4 given an SI pointer to the storage location
```asm
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
```

### FAC_ADD
Adds to FAC given a pointer to the S11E4 structure to add from. Uses the FTMP Load to extract contents then FTMP Store
