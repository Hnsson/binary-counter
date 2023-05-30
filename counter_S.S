	.data
counter:	.quad 0
GPIO:		.quad 0


	.text
	.global setup
	.global interrupt


# ------------------------ Interrupt ------------------------
# keyboard causes the interrupt which handles the calculations for which pin to be on or off
set_currentGPIO_high:
	call set_pin_high
	decq %rsi
	imulq $2, %r10 # Moves the bitmask to next lED (r10 = bitmask)
	jmp interrupt_loop
interrupt:
	push %r10
	incq counter
	movq $4,%rsi # Pin number counter
    movq $1,%r10 # bitmask
	jmp interrupt_loop
interrupt_loop:
	cmpq $0,%rsi
	jz interrupt_end
	movq counter,%rax 
	andq %r10,%rax # andq with bitmask and counter to calculate which value the lED is going to have, on or off
	cmpq $0,%rax # if not 0, turn on
	jne set_currentGPIO_high 
	call set_pin_low 
	decq %rsi	
	imulq $2, %r10 
	jmp interrupt_loop
interrupt_end:
	pop %r10
    ret
# ------------------------ Setup ------------------------
# saves all GPIO pin addresses so we can acces them and then loop through and set pin 1 to input and rest to output
setup:
	call calcGPIO_addr 
	xor %rdi,%rdi
	xor %rsi,%rsi
	movq $1,%rdi # pin counter
	movq GPIO,%rax
    call set_pin_input
	movq $0,%rdi
	movq $1,%rsi
setup_loop:
	push %rsi
	movq GPIO, %rax
	call set_pin_output
	pop %rsi
	incq %rsi
	cmpq $4,%rsi
	jle  setup_loop
setup_end:
    ret

# ------------------------ Manipulate GPIO ------------------------
# functions for calculating pin address, set pin to on or off as well as input or output
calcGPIO_addr:
	movq $16,%rdi
	movq $0xFFFF,%rdx
	movq $0x60,%rsi
	movq $0x9E,%r8
	movq $0x1000,%rcx
	movq $0xFF,%r9
	andq %rcx,%rdx # 0xFFFF & 0x1000
	notq %r8 # ~(0x9E & 0xFF)
	andq %r9,%r8 # 0x9E & 0xFF
	call shift_aritmetic_left # 0x60 << 16
	orq %r8,%rsi # (~(0x9E & 0xFF)) | (0x60 << 16)
	orq %rdx,%rsi # (0xFFFF & 0x1000) | (0x60 << 16)
	movq %rsi, GPIO
	ret
set_pin_high:
	push %rsi
	push %rax
	movq GPIO,%rax
    addq $3,%rax # gpio_addr + 3
	subq $1,%rsi # (gpio_nr-1)
	imulq $8,%rsi # (8*(gpio_nr-1)
	movq %rsi,%rdi
	movq $0x3,%rsi 	
	salq $4,%rsi # (0x3 << 4)
	incq %rsi # ((0x3 << 4)+1)
	call shift_aritmetic_left # ((0x3 << 4)+1) << (8*(gpio_nr-1))
    orq %rsi,(%rax) # *(int*)gpio_addr + 3 |= ((0x3 << 4)+1) << (8*(gpio_nr-1))
	pop %rax
	pop %rsi
   	ret
set_pin_input:
	subq $3,%rsi	# ((3-gpio_nr)*2)
	negq %rsi
	salq $1,%rsi
	push %rax
	xor %rdx,%rdx # division rest stored in rdx
	movq %rsi, %rax
	movq $8,%rcx
	idivq %rcx # (((3-gpio_nr)*2) % 8)
	addq $8,%rdx # (((3-gpio_nr)*2) % 8) + 8
	movq $0x3,%rsi
	movq %rdx,%rdi
	call shift_aritmetic_left # 0x3 << ((((3-gpio_nr)*2) % 8) + 8)
	pop %rax
	orq %rsi,(%rax) # *(short*)gpio_addr + (gpio_nr/8) = 0x3 << ((((3-gpio_nr)*2) % 8) + 8)
	ret
set_pin_low:
	push %rsi
	push %rax	
	movq GPIO,%rax 	
   	addq $3,%rax # gpio_addr + 3
    subq $1,%rsi #( gpio_nr-1)
	imulq $8,%rsi # (gpio_nr-1)*8
	movq %rsi,%rdi
	movq $0xCF,%rsi
	call shift_aritmetic_left 	# 0xCF << (8*(gpio_nr-1)
	notq %rsi 	# ~(0xCF << (8*(gpio_nr-1))
    andq %rsi,(%rax)# *(int*)gpio_addr + 3 &= ~(0xCF << (8*(gpio_nr-1))
	pop %rax
	pop %rsi
    ret
set_pin_output:
    movq $0x2,%rcx	# 0x2 << 6
    salq $6,%rcx
	subq $4,%rsi    # (4-gpio_nr)*2
    negq %rsi       # (or we do (gpio_nr-4)*(-1))
    imulq $2, %rsi # multiply by 2
	push %rsi # so we dont change the values
    push %rdi
    movq %rsi,%rdi	# Move so we have values in rdi and rsi for shift_aritmetic_left
    movq %rcx,%rsi
    call shift_aritmetic_left	# (0x2 << 6) << ((4-gpio_nr)*2)
    movq %rsi,%rcx
    pop %rdi
    pop %rsi
    orq %rcx,(%rax) # *(short*)gpio_addr |= (0x2 << 6) << ((4-gpio_nr)*2)
    ret
shift_aritmetic_left:
    push %rdi # Shift aritmetic left %rsi << %rdi
shift_aritmetic_left_loop:
    cmpq $0,%rdi
    jz shift_aritmetic_left_end
    salq $1,%rsi
    decq %rdi
    jmp shift_aritmetic_left_loop
shift_aritmetic_left_end:
    pop %rdi
    ret
