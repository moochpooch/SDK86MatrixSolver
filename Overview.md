## Memory Structure
#### S11E4 Structure
The floating point representation is 16 bits so that it can be easily stored in a standard 16 bit register,
[ 1 bit sign | 11 bit magnitude | 4 bit signed exponent ]
#### FAC
The S11E4 structures can be unpacked into more precise implementation for operation. In memory, there is one general purpose "floating point register", called the FAC. Similar to how PDP-1 systems have just one AC register to do most of the work, the FAC works in a similar manner. 

The general structure of the FAC is 33 bits, where one bit is signed, and the rest are magnitude. 
[ 1 bit sign | 32 bit magnitude ]

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

