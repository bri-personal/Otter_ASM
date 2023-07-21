# define addresses and INTR enable
.eqv	MMIO		0x11000000	# first MMIO address
.eqv	STACK		0x10000		# stack address
.eqv	INT_EN		8		# enable interrupts

# define dimensions
.eqv	WIDTH		80
.eqv	HEIGHT		60
.eqv	P_WIDTH		3
.eqv	P_HEIGHT	5

# define colors
.eqv	BLACK	0
.eqv	WHITE	0xFF
.eqv	RED	0xE0
.eqv	GREEN	0x1C
.eqv	BLUE	0x03
.eqv	D_GREEN	0x08
.eqv	BROWN	0x89

# predefined arrays in data segment
.data
PLAYER:	.space	2	# player x and y coords, top of rectangle

# executed code
.text
MAIN:
	# initialize important values/addresses
	li	sp, STACK		# setup sp
        li	s0, MMIO		# setup MMIO pointer
        addi	s1, x0, 0		# set interrupt flag to 0
        
        # initialize player position
        la	t0, PLAYER		# load address of player pos
        sb	x0, 0(t0)		# x pos
        sb	x0, 1(t0)		# y pos
        
        # setup ISR address
        la	t0, ISR
        csrrw	x0, mtvec, t0
        
        # enable interrupts
        li	t0, INT_EN
        csrrw	x0, mstatus, t0
        
        # go to title page
        j	TITLE_START
	
# title page shown when game first opens
TITLE_START:
	# fill background with dark green
        addi	a3, x0, D_GREEN		# set color
        call	DRAW_BG			# fill background
TITLE_PAGE:
	beqz	s1, TITLE_PAGE		# check for interrupt
	
	# on interrupt
	addi	s1, x0, 0		# clear interrupt flag
	lw	t0, 0x100(s0)		# read keyboard input
	addi	t1, x0, 0x1C
	beq	t0, t1, WORLD_START	# check if key pressed was 'A'
	j	TITLE_PAGE
	
# page opened after title page
WORLD_START:
	# fill background with green
        addi	a3, x0, GREEN		# set color
        call	DRAW_BG			# fill background
        call	DRAW_PLAYER		# draw player
WORLD_PAGE:
	beqz	s1, WORLD_PAGE		# check for interrupt
	
	# on interrupt
	addi	s1, x0, 0		# clear interrupt flag
	
	# move character
	lw	t0, 0x100(s0)		# read keyboard input
	addi	t1, x0, 0x1C
	beq	t0, t1, P_MOVE_LEFT	# check if 'A' was pressed
	addi	t1, x0, 0x23
	beq	t0, t1, P_MOVE_RIGHT	# check if 'D' was pressed
	j	WORLD_PAGE
P_MOVE_LEFT:
	# get player x and dec by 1, if allowed
	la	t0, PLAYER
	lb	t1, 0(t0)		# load player x
	beqz	t1, WORLD_PAGE		# if player x already 0, can't move left
	addi	t1, t1, -1		# decrement x by 1
	sb	t1, 0(t0)		# store decremented x
	j	WORLD_START
P_MOVE_RIGHT:
	# get player x and dec by 1, if allowed
	la	t0, PLAYER
	lb	t1, 0(t0)		# load player x
	
	# get max possible x
	addi	t2, x0, WIDTH	
	addi	t3, x0, P_WIDTH	
	sub	t2, t2, t3
	
	beq	t1, t2, WORLD_PAGE	# if player x already WIDTH-P_WIDTH, can't move right
	addi	t1, t1, 1		# increment x by 1
	sb	t1, 0(t0)		# store incremented x
	j	WORLD_START
        
# interrupt service routine
ISR:
	addi	s1, x0, 1		# set interrupt flag high
	mret
	
# draw player on screen using coordinates in memory
# modifies t0, t1, t3, a0, a1, a2, a3, a4
DRAW_PLAYER:
	addi	sp, sp, -4
	sw	ra, 0(sp)
	
	la	t3, PLAYER		# get address of player coords
	
	# draw hair
	lb	a0, 0(t3)		# player x coord
	lb	a1, 1(t3)		# player y coord
	addi	a2, a0, P_WIDTH
	addi	a2, a2, -1
	addi	a3, x0, BROWN
	call	DRAW_HORIZ_LINE
	
	#draw face
	lb	a0, 0(t3)		# player x coord
	lb	a1, 1(t3)		# player y coord
	addi	a1, a1, 1
	addi	a2, a0, P_WIDTH
	addi	a2, a2, -1
	addi	a4, a1, 1
	addi	a3, x0, WHITE
	call	DRAW_RECT
	
	#draw face features
	lb	a0, 0(t3)		# player x coord
	lb	a1, 1(t3)		# player y coord
	addi	a1, a1, 1
	addi	a3, x0, BLACK
	call	DRAW_DOT
	
	addi	a0, a0, 2
	call	DRAW_DOT
	
	addi	a0, a0, -1
	addi	a1, a1, 1
	addi	a3, x0, RED
	call	DRAW_DOT
	
	#draw body
	lb	a0, 0(t3)		# player x coord
	lb	a1, 1(t3)		# player y coord
	addi	a1, a1, 3
	addi	a2, a0, P_WIDTH
	addi	a2, a2, -1
	addi	a4, a1, 1
	addi	a3, x0, BLUE
	call	DRAW_RECT
	
	lw	ra, 0(sp)
	addi	sp, sp, 4
	ret
	
	
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
	addi	a2, a2, 1		# go from a1 to a2 inclusive
DRAW_VERT_1:
	call	DRAW_DOT		# must not modify: a0, a1, a2, a3
	addi	a1, a1, 1
	bne	a1, a2, DRAW_VERT_1
	lw	ra, 0(sp)
	addi	sp, sp, 4
	ret

# Fills the 60x80 grid with color given by a3 using successive calls to draw_horizontal_line
# Modifies (directly or indirectly): t0, t1, t2, a0, a1, a2, a4
DRAW_BG:
	addi	sp, sp, -4
	sw	ra, 0(sp)
	
	# draw rectangle that fills screen
	addi	a0, x0, 0
	addi	a1, x0, 0
	addi	a2, a0, WIDTH
	addi	a2, a2, -1
	addi	a4, a1, HEIGHT
	addi	a4, a4, -1
	call	DRAW_RECT
	
	lw	ra, 0(sp)
	addi	sp, sp, 4
	ret
	
# Draws rectangle (a0, a1) to (a2, a4) color given by a3 using successive calls to draw_horizontal_line
# Modifies (directly or indirectly): t0, t1, t2, a1, a2, a4 (a0 is modified but ends up same as start)
DRAW_RECT:
	addi	sp, sp, -4
	sw	ra, 0(sp)
	addi	a4, a4, 1		# go from a1 to a4 inclusive
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
	addi	sp, sp, -4
	sw	ra, 0(sp)
	andi	t0, a0, 0x7F		# select bottom 7 bits (col)
	andi	t1, a1, 0x3F		# select bottom 6 bits  (row)
	slli	t1, t1, 7		# {a1[5:0],a0[6:0]} 
	or	t0, t1, t0		# 13-bit address
	li	t1, MMIO		# ADDED - load MMIO address
	sw	t0, 0x120(t1)		# write 13 address bits to register
	sw	a3, 0x140(t1)		# write color data to frame buffer
	lw	ra, 0(sp)
	addi	sp, sp, 4
	ret
