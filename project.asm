# define addresses and INTR enable
.eqv	MMIO	0x11000000		# first MMIO address
.eqv	STACK	0x10000			#stack address
.eqv	INT_EN	8			# enable interrupts

#define colors
.eqv	BLACK	0
.eqv	WHITE	0xFF
.eqv	RED	0xE0
.eqv	GREEN	0x1C
.eqv	BLUE	0x03

# predefined arrays in data segment
.data
F:	.space	4

# executed code
.text
START:
	# initialize important values/addresses
	li	sp, STACK		# setup sp
        li	s0, MMIO		# setup MMIO pointer
        addi	s1, x0, 0		# set interrupt flag to 0
        
        # fill background with white
        addi	a3, x0, GREEN		# set color
        call	DRAW_BG			# fill background
        
        # setup ISR address
        la	t0, ISR
        csrrw	x0, mtvec, t0
        
        # enable interrupts
        li	t0, INT_EN
        csrrw	x0, mstatus, t0
        
LOOP:
	beqz	s1, LOOP		# check interrupt flag
	addi	s1, x0, 0		# clear interrupt flag
	
	addi	a0, x0, 10
	addi	a1, x0, 10
	addi	a2, a0, 10
	addi	a4, a1, 10
	addi	a3, x0, RED
	call DRAW_RECT
	
	j	LOOP
        
ISR:
	addi	s1, x0, 1		#set interrupt flag high
	mret
	
	
# VGA subroutines #################################################

# draws a horizontal line from (a0,a1) to (a2,a1) using color in a3
# Modifies (directly or indirectly): t0, t1, a0, a2
DRAW_HORIZ_LINE:
	addi	sp, sp, -4
	sw	ra, 0(sp)
	addi	a2, a2, 1		# go from a0 to a2 inclusive
DRAW_HORIZ_1:
	call	DRAW_DOT		# must not modify: a0, a1, a2, a3
	addi	a0, a0, 1
	bne	a0, a2, DRAW_HORIZ_1
	lw	ra, 0(sp)
	addi	sp, sp, 4
	ret

# draws a vertical line from (a0,a1) to (a0,a2) using color in a3
# Modifies (directly or indirectly): t0, t1, a1, a2
DRAW_VERT_LINE:
	addi	sp, sp, -4
	sw	ra, 0(sp)
	addi	a2, a2, 1
DRAW_VERT_1:
	call	DRAW_DOT		# must not modify: a0, a1, a2, a3
	addi	a1, a1, 1
	bne	a1, a2, DRAW_VERT_1
	lw	ra, 0(sp)
	addi	sp, sp, 4
	ret

# Fills the 60x80 grid with color given by a3 using successive calls to draw_horizontal_line
# Modifies (directly or indirectly): t0, t1, t4, a0, a1, a2
DRAW_BG:
	addi	sp, sp, -4
	sw	ra, 0(sp)
	li	a1, 0			# a1= row_counter
	li	t4, 60			# max rows
BG_START:	
	li	a0, 0
	li	a2, 79			# total number of columns
	call	DRAW_HORIZ_LINE		# must not modify: t4, a1, a3
	addi	a1, a1, 1
	bne	t4, a1, BG_START	# branch to draw more rows
	lw	ra, 0(sp)
	addi	sp, sp, 4
	ret
	
# Draws rectangle (a0, a1) to (a2, a4) color given by a3 using successive calls to draw_horizontal_line
# Modifies (directly or indirectly): t0, t1, a0, a1, a4
DRAW_RECT:
	addi	sp, sp, -4
	sw	ra, 0(sp)
	addi	a4, a4, 1
	mv	t2, a0			# save start x
RECT_START:
	call	DRAW_HORIZ_LINE		# must not modify: a1, a3
	mv	a0, t2			# restore start x
	addi	a2, a2, -1		# restore end x
	addi	a1, a1, 1		# increment row num
	bne	a1, a4, RECT_START	# branch to draw more rows
	lw	ra, 0(sp)
	addi	sp, sp, 4
	ret

# draws a dot on the display at the given coordinates:
# 	(X,Y) = (a0,a1) with a color stored in a3
# 	(col, row) = (a0,a1)
# Modifies (directly or indirectly): t0, t1
DRAW_DOT:
	andi	t0, a0, 0x7F		# select bottom 7 bits (col)
	andi	t1, a1, 0x3F		# select bottom 6 bits  (row)
	slli	t1, t1, 7		# {a1[5:0],a0[6:0]} 
	or	t0, t1, t0		# 13-bit address
	li	t1, MMIO		# ADDED - load MMIO address
	sw	t0, 0x120(t1)		# write 13 address bits to register
	sw	a3, 0x140(t1)		# write color data to frame buffer
	ret
