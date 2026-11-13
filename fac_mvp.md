# Purpose
Test the base functions and usage of the matrix FAC library. The MVP includes one 2x3 matrix packed in S11E4.

## Matrix
The matrix is 2x3, it has elements [ 2 & 3 & 5 \\ 7 & 11 & 13 ].

## Tested Functions
The functions tested are
```asm
FAC_ADD:            2+3=5
FAC_SUB:            7-3=4
FAC_MUL:            7x11=77
Signed Mult.:       -3x2=-6
Exp. Alignment:     2+6=8
Zero Mult.:         0x-3=0
64->32 Norm.:       2047^3
FAC_STORE Pres.:    FAC Unchanged
FAC_SAVE/FAC_RES:   Original value restored
```

## Results
Test results are accessed from 0102-010A, where each byte is written a 1 for success, 0 for failure.
```sh
@0102 01 01 01 01 01 01 01 01 01
```

The address 010B counts the number of failed tests.
```sh
@010B 00
```

010C-010D contains the last packed result, 70 00 is expected if the program successfully runs.
```sh
@010C 70 00
```

010E is an indicator marking that all tests are complete. A 1 is written if the condition is true.
```sh
@010E 01
```
