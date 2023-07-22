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
# player data:
# 0: x coord of top of rectangle
# 1: y coord of top of rectange
# 2: orientation (0=down, 1=up, 2=left, 3=right)
# 3-17: pixels behind it that can be redrawn after. amount of bytes must equal P_WIDTH*P_HEIGHT
PLAYER:	.space	18

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
        sb	x0, 2(t0)		# orientation, down to start
        
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
        call	READ_PLAYER		# read player pixels before drawing player for first time
WORLD_UPDATE:
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
	addi	t1, x0, 0x1D
	beq	t0, t1, P_MOVE_UP	# check if 'W' was pressed
	addi	t1, x0, 0x1B
	beq	t0, t1, P_MOVE_DOWN	# check if 'S' was pressed
	j	WORLD_PAGE
P_MOVE_LEFT:
	la	t0, PLAYER
	
	# set orientation to left
	addi	t1, x0, 2		
	sb	t1, 2(t0)
	
	# get player x and dec by 1, if allowed
	lb	t1, 0(t0)		# load player x
	beqz	t1, WORLD_UPDATE	# if player x already 0, can't move left
	addi	t1, t1, -1		# decrement x by 1
	sb	t1, 0(t0)		# store decremented x
	
	# clear pixels where player was
	addi	a0, t1, 1
	lb	a1, 1(t0)
	call	CLEAR_PLAYER
	
	call	READ_PLAYER		# read player pixels into memory before drawing
	
	j	WORLD_UPDATE
P_MOVE_RIGHT:
	la	t0, PLAYER
	
	# set orientation to right
	addi	t1, x0, 3		
	sb	t1, 2(t0)
	
	# get player x and inc by 1, if allowed
	lb	t1, 0(t0)		# load player x
	
	# get max possible x
	addi	t2, x0, WIDTH	
	addi	t2, t2, -P_WIDTH
	beq	t1, t2, WORLD_UPDATE	# if player x already WIDTH-P_WIDTH, can't move right
	
	# can move right
	addi	t1, t1, 1		# increment x by 1
	sb	t1, 0(t0)		# store incremented x
	
	# clear pixels where player was
	addi	a0, t1, -1
	lb	a1, 1(t0)
	call	CLEAR_PLAYER
	
	call	READ_PLAYER		# read player pixels into memory before drawing
	
	j	WORLD_UPDATE
P_MOVE_UP:
	la	t0, PLAYER
	
	# set orientation to up
	addi	t1, x0, 1		
	sb	t1, 2(t0)
	
	# get player y and dec by 1, if allowed
	lb	t1, 1(t0)		# load player y
	beqz	t1, WORLD_UPDATE	# if player y already 0, can't move up
	addi	t1, t1, -1		# decrement y by 1
	sb	t1, 1(t0)		# store decremented y
	
	# clear pixels where player was
	addi	a1, t1, 1
	lb	a0, 0(t0)
	call	CLEAR_PLAYER
	
	call	READ_PLAYER		# read player pixels into memory before drawing
	
	j	WORLD_UPDATE
P_MOVE_DOWN:
	la	t0, PLAYER
	
	# set orientation to down
	addi	t1, x0, 0		
	sb	t1, 2(t0)
	
	# get player y and inc by 1, if allowed
	lb	t1, 1(t0)		# load player y
	
	# get max possible x
	addi	t2, x0, HEIGHT
	addi	t2, t2, -P_HEIGHT
	
	beq	t1, t2, WORLD_UPDATE	# if player y already HEIGHT-P_HEIGHT, can't move down
	addi	t1, t1, 1		# increment y by 1
	sb	t1, 1(t0)		# store incremented y
	
	# clear pixels where player was
	addi	a1, t1, -1
	lb	a0, 0(t0)
	call	CLEAR_PLAYER
	
	call	READ_PLAYER		# read player pixels into memory before drawing
	
	j	WORLD_UPDATE
        
# interrupt service routine
ISR:
	addi	s1, x0, 1		# set interrupt flag high
	mret
	
# draw player on screen using coordinates in memory
# modifies t0, t1, t2, t3, t4, t5, a0, a1, a2, a3, a4
DRAW_PLAYER:
	addi	sp, sp, -4
	sw	ra, 0(sp)
	
	la	t3, PLAYER		# get address of player coords
	# draw body
	lb	a0, 0(t3)		# player x coord
	lb	a1, 1(t3)		# player y coord
	addi	a1, a1, 3
	addi	a2, a0, P_WIDTH
	addi	a2, a2, -1
	addi	a4, a1, 1
	addi	a3, x0, BLUE
	call	DRAW_RECT
	
	# draw head based on orientation
	lb	t2, 2(t3)		# get player orientation
	addi	t5, x0, 1
	beq	t2, t5, OR_UP		# player orientation up
	addi	t5, t5, 1
	beq	t2, t5, OR_LEFT		# player orientation left
	addi	t5, t5, 1
	beq	t2, t5, OR_RIGHT	# player orientation right
OR_DOWN:
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
	j	OR_END
OR_UP:
	#draw hair
	lb	a0, 0(t3)		# player x coord
	lb	a1, 1(t3)		# player y coord
	addi	a2, a0, P_WIDTH
	addi	a2, a2, -1
	addi	a4, a1, 2
	addi	a3, x0, BROWN
	call	DRAW_RECT
	
	# draw rest of head
	lb	a0, 0(t3)		# player x coord
	lb	a1, 1(t3)		# player y coord
	addi	a1, a1, 2
	addi	a2, a0, P_WIDTH
	addi	a2, a2, -1
	addi	a3, x0, WHITE
	call	DRAW_HORIZ_LINE
	j	OR_END
	
OR_LEFT:
	#draw face
	lb	a0, 0(t3)		# player x coord
	lb	a1, 1(t3)		# player y coord
	addi	a1, a1, 1
	addi	a2, a0, P_WIDTH
	addi	a2, a2, -1
	addi	a4, a1, 1
	addi	a3, x0, WHITE
	call	DRAW_RECT

	# draw hair
	lb	a0, 0(t3)		# player x coord
	lb	a1, 1(t3)		# player y coord
	addi	a2, a0, P_WIDTH
	addi	a2, a2, -1
	addi	a3, x0, BROWN
	call	DRAW_HORIZ_LINE
	
	lb	a0, 0(t3)		# player x coord
	lb	a1, 1(t3)		# player y coord
	addi	a0, a0, P_WIDTH
	addi	a0, a0, -1
	addi	a1, a1, 1
	call	DRAW_DOT
	
	#draw face features
	lb	a0, 0(t3)		# player x coord
	lb	a1, 1(t3)		# player y coord
	addi	a1, a1, 1
	addi	a3, x0, BLACK
	call	DRAW_DOT
	
	addi	a1, a1, 1
	addi	a3, x0, RED
	call	DRAW_DOT
	j	OR_END
OR_RIGHT:
	#draw face
	lb	a0, 0(t3)		# player x coord
	lb	a1, 1(t3)		# player y coord
	addi	a1, a1, 1
	addi	a2, a0, P_WIDTH
	addi	a2, a2, -1
	addi	a4, a1, 1
	addi	a3, x0, WHITE
	call	DRAW_RECT

	# draw hair
	lb	a0, 0(t3)		# player x coord
	lb	a1, 1(t3)		# player y coord
	addi	a2, a0, P_WIDTH
	addi	a2, a2, -1
	addi	a3, x0, BROWN
	call	DRAW_HORIZ_LINE
	
	lb	a0, 0(t3)		# player x coord
	lb	a1, 1(t3)		# player y coord
	addi	a1, a1, 1
	call	DRAW_DOT
	
	#draw face features
	lb	a0, 0(t3)		# player x coord
	lb	a1, 1(t3)		# player y coord
	addi	a0, a0, P_WIDTH
	addi	a0, a0, -1
	addi	a1, a1, 1
	addi	a3, x0, BLACK
	call	DRAW_DOT
	
	addi	a1, a1, 1
	addi	a3, x0, RED
	call	DRAW_DOT
	j	OR_END
	
OR_END:
	lw	ra, 0(sp)
	addi	sp, sp, 4
	ret

# read player pixels into player array in data segment of memory
# modifies t0, t1, t2, t3, t4, t5, a0, a1, a3	
READ_PLAYER:
	addi	sp, sp, -4
	sw	ra, 0(sp)
	
	la	t3, PLAYER		# get address of player coords
	
	# read colors of pixels where player will be
	addi	t2, t3, 3		# get address of start of array of pixels
	lb	a0, 0(t3)		# player x coord
	lb	a1, 1(t3)		# player y coord
	addi	t4, t2, 15		# get end of array
	addi	t5, a0, P_WIDTH		# get player width to know when to go to next row
P_READ_LOOP:
	call	READ_DOT
	sb	a3, 0(t2)		# store color at first pixel
	addi	t2, t2, 1		# increment to next index
	addi	a0, a0, 1		# increment x read
	blt	a0, t5, P_READ_LOOP	# if not too far right, go to next loop
	addi	a0, a0, -P_WIDTH	# if too far right, revert x to first pos and inc y
	addi	a1, a1, 1
	blt	t2, t4, P_READ_LOOP
	
	lw	ra, 0(sp)
	addi	sp, sp, 4
	ret
	
	
# clear player and replace with previous background colors
# modifies t0, t1, t2, t3, t4, a0, a1, a3
# a0 and a1 must start as player topleft coords
CLEAR_PLAYER:
	addi	sp, sp, -4
	sw	ra, 0(sp)
	
	# fill the pixels with bg colors
	addi	t3, t0, 3		# initialize pointer to colors array
	addi	t2, t3, 15		# get end of array
	addi	t4, a0, P_WIDTH		# get x limit for drawing player
P_CLEAR_LOOP:
	lb	a3, 0(t3)		# get color at dot
	call	DRAW_DOT		# draw dot where player was
	addi	t3, t3, 1		# increment pointer to next
	addi	a0, a0, 1		# increment x read
	blt	a0, t4, P_CLEAR_LOOP	# if not too far right, go to next loop
	addi	a0, a0, -P_WIDTH	# if too far right, revert x to first pos and inc y
	addi	a1, a1, 1
	blt	t3, t2, P_CLEAR_LOOP	# continue drawing until reach bottom of player
	
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
	sw	t0, 0x120(s0)		# write 13 address bits to register
	sw	a3, 0x140(s0)		# write color data to frame buffer
	lw	ra, 0(sp)
	addi	sp, sp, 4
	ret

# reads color from the display at the given coordinates:
# 	(X,Y) = (a0,a1) with a color stored in a3
# 	(col, row) = (a0,a1)
# Modifies (directly or indirectly): t0, t1, a3
READ_DOT:
	addi	sp, sp, -4
	sw	ra, 0(sp)
	andi	t0, a0, 0x7F		# select bottom 7 bits (col)
	andi	t1, a1, 0x3F		# select bottom 6 bits  (row)
	slli	t1, t1, 7		# {a1[5:0],a0[6:0]} 
	or	t0, t1, t0		# 13-bit address
	sw	t0, 0x120(s0)		# write 13 address bits to register
	lb	a3, 0x160(s0)		# write color data to frame buffer
	lw	ra, 0(sp)
	addi	sp, sp, 4
	ret