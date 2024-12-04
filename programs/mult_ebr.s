    addi x6, x6, 3
    addi x5, x5, 2
    bne x5, x6, bt1
    mul	x6,x5,x5 // should skip over this, x6 should not be 4
bt1:
    mul	x5,x6,x6 // but x5 should be 9
    addi x1, x1, 2