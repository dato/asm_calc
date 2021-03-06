.include "src/check.S"

/* =====================================================
 * Parse a equation to an array of integers, where every odd
 * element is a operator (see check.S:operator_value).
 * Save the array on the stack with an offset of 64 byte.
 *
 * parameters:
 *  rdi = number of parameters (argc)
 *  rsi = pointer to the address of the first parameter
 *
 * return:
 *  Success (0) | Invalid number (1) | Invalid operator (2)
 */
parse_equation:
    pushq %rbp
    movq %rsp, %rbp
    xorq %r8, %r8 /* total amount of arguments */
    xorq %r9, %r9 /* current index of the argument counter */
    xorq %r10, %r10 /* current offset (index * 8) */
    xorq %r11, %r11 /* length of the array */

    movq %rdi, %r8
    movq %rsi, %rbx

    /* Create a offset of 64 bytes from the SP */
    subq $64, %rsp
    movq %r8, %rax
    imulq $8, %rax
    /* set the stack pointer to (SP - 64) - (argc * 8) */
    subq %rax, %rsp
    movq %rsp, _equation_array
.Leq_parse_loop:
    movq %r9, %r10
    addq $1, %r10
    imull $8, %r10d
    movq (%rbx, %r10), %rdi
    cmpq $0, %rdi
    je .Leq_parse_next
    callq string_check
    cmpl $1, %eax
    jb .Leq_parse_operator
    ja .Leq_parse_next
.Leq_parse_number:
    callq parse_int
    cmpl $0, %eax
    je .Lerrornumber
    movq %rax, (%rsp, %r9, 8)
    incq %r11
    jmp .Leq_parse_next
.Leq_parse_operator:
    callq operator_value
    cmpl $0, %eax
    je .Lerroroperator
    movq %rax, (%rsp, %r9, 8)
    incq %r11
.Leq_parse_next:
    addq $1, %r9
    cmpq %r8, %r9
    jb .Leq_parse_loop
    movq $0, %rax
    jmp .Leq_parse_return
.Lerrornumber:
    movq $1, %rax
    jmp .Leq_parse_return
.Lerroroperator:
    movq $2, %rax
.Leq_parse_return:
    movl %r11d, _equation_array_length
    movq %rbp, %rsp
    popq %rbp
    retq

/* =====================================================
 *
 */
parse_int:
    pushq %rbp
    pushq %rbx
    pushq %rdi
    pushq %r8
    pushq %r9
    pushq %r10

    xorq %r10, %r10

    /* rdi contains the pointer to the string */
    movq %rdi, %r8
    callq get_string_length
    movl %eax, %r9d
.Lparse_int_loop:
    subq $1, %r9

    /* get the correct power of 10 for the digit
     * rdi is the current length */
    movq $10, %rdi
    movzbl %r9b, %esi
    callq power
    movl %eax, %ebx

    movzbl (%r8), %eax
    subl $0x30, %eax
    /* multiply the digit with its power of 10 */
    imull %ebx, %eax
    addl %eax, %r10d

    incq %r8
    cmpq $0, %r9
    ja .Lparse_int_loop

    /* add result to eax */
    movl %r10d, %eax
    nop
    popq %r10
    popq %r9
    popq %r8
    popq %rdi
    popq %rbx
    popq %rbp
    retq

/* =====================================================
 * a ^ b
 * parameter:
 *  a (base) => rdi
 *  b (exponent) => rsi
 */
power:
    pushq %r8
    movzbl %dil, %eax
    movzbl %sil, %ebx
    movl $1, %r8d
.Lpower_loop:
    movl %ebx, %ecx
    andl $1, %ecx
    jz .Levennumber
    imull %eax, %r8d
.Levennumber:
    imull %eax, %eax
    shrl $1, %ebx
    cmpl $0, %ebx
    ja .Lpower_loop
    movl %r8d, %eax
    nop
    popq %r8
    retq

/* =====================================================
 * Get the length of a string
 * parameter:
 *  string (pointer to first char) => rdi
 */
get_string_length:
    pushq %r8
    xorl %r8d, %r8d
.Lget_string_length_loop:
    movzbl (%rdi), %eax
    testb %al, %al
    je .Lfound_nullterminator
    incl %r8d
    incq %rdi
    jmp .Lget_string_length_loop
.Lfound_nullterminator:
    movl %r8d, %eax
    nop
    popq %r8
    retq

/* =====================================================
 * Get the number of digits in a number
 *
 * As long as the given integer is greater than zero, assign the quotient
 * of the division: given integer / 10 to itself.
 *
 * parameter:
 *  integer => rdi
 */
 get_number_of_digits:
    pushq %rbx

    /* idivl requires edx:eax as the dividend, zero edx and sign extend the number */
    xorl %eax, %eax
    movq %rdi, %rax
    movl $10, %ebx
.Lget_number_of_digits_loop:
    cqto
    idivl %ebx
    incq %r8
    cmpl $0, %eax
    ja .Lget_number_of_digits_loop
    movl %r8d, %eax
    nop
    popq %rbx
    retq

/* =============================================
 * Return the predefined value for the operator symbol
 * This is called after operator_check, where the length
 * of the string is tested.
 * parameter:
 *  rdi => string
 * return:
 *  '+' = 1 (Addition)
 *  '-' = 2 (Subtraction)
 *  'x' = 3 (Multiplication)
 *  '/' = 4 (Division)
 *  '^' = 5 (Exponantiation)
 *  'R' = 6 (nth root of)
 */
operator_value:
    pushq %rdi
    pushq %r8

    movzbl (%rdi), %eax
    cmpb $0x2B, %al
    jne .Lsubtract_value
    movl $1, %r8d
    jmp .Loperator_match
.Lsubtract_value:
    cmpb $0x2D, %al
    jne .Lmultiply_value
    movl $2, %r8d
    jmp .Loperator_match
.Lmultiply_value:
    cmpb $0x78, %al
    jne .Ldivsion_value
    movl $3, %r8d
    jmp .Loperator_match
.Ldivsion_value:
    cmpb $0x2F, %al
    jne .Lexponantiation_value
    movl $4, %r8d
    jmp .Loperator_match
.Lexponantiation_value:
    cmpb $0x5E, %al
    jne .Lroot_value
    movl $5, %r8d
    jmp .Loperator_match
.Lroot_value:
    cmpb $0x52, %al
    jne .Linvalid_value
    movl $6, %r8d
    jmp .Loperator_match
.Linvalid_value:
    movl $0, %eax
    popq %r8
    popq %rdi
    ret

.Loperator_match:
    movl %r8d, %eax
    popq %r8
    popq %rdi
    ret
