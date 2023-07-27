# define addresses and INTR enable
.eqv	MMIO		0x11000000	# first MMIO address
.eqv	STACK		0x10000		# stack address
.eqv	INT_EN		8		# enable interrupts

# define dimensions
.eqv	WIDTH		80
.eqv	HEIGHT		60
.eqv	P_WIDTH		3
.eqv	P_HEIGHT	5
.eqv	P_AREA		15		# must be P_WIDTH * P_HEIGHT
.eqv	T_SIZE		5		# width and height of square tiles
.eqv	T_PER_ROW	20		# number of tiles per row, 16 fills exactly with 5x5
.eqv	T_PER_COL	12		# number of tiles per column, 12 fills exactly with 5x5
.eqv	NUM_TILES	240		# total number of tiles in world, must be T_PER_ROW * T_PER_COL

# define colors
.eqv	BLACK		0
.eqv	WHITE		0xFF
.eqv	RED		0xE0
.eqv	GREEN		0x1C
.eqv	BLUE		0x03
.eqv	D_GREEN		0x08
.eqv	BROWN		0x89
.eqv	WALL_COLOR	D_GREEN

# define key codes
.eqv	A_CODE	0x1C
.eqv	D_CODE	0x23
.eqv	S_CODE	0x1B
.eqv	W_CODE	0x1D

# define bitmasks
.eqv	UPPER_MASK	0xFFFF0000
.eqv	LOWER_MASK	0x0000FFFF

# predefined arrays in data segment
.data
# player data:
# 0: x coord of top of rectangle
# 1: y coord of top of rectange
# 2: orientation (0=down, 1=up, 2=left, 3=right)
# 3-17: pixels behind it that can be redrawn after. amount of bytes must equal P_AREA (P_WIDTH*P_HEIGHT)
PLAYER:	.space	18

# world tiles data:
# number of bytes = number of tiles, number corresponds to which tile is drawn
# 0 - empty
# 1 - wall
TILES: .space NUM_TILES

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
        
        # load world tiles
        la	t0, TILES		# get tiles array address
        addi	t2, t0, NUM_TILES	# get end of array
LOAD_T_ROW:
        li	t1, 0x00000000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x00000000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x00000000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01000000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01000000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        blt	t0, t2, LOAD_T_ROW	# check if not at end of array yet
        
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
TITLE_UPDATE:
	beqz	s1, TITLE_UPDATE	# check for interrupt
	
	# on interrupt
	addi	s1, x0, 0		# clear interrupt flag
	lw	t0, 0x100(s0)		# read keyboard input
	addi	t1, x0, A_CODE
	beq	t0, t1, WORLD_START	# check if key pressed was 'A'
	j	TITLE_UPDATE
	
# page opened after title page
WORLD_START:
	# initialize player offset
        addi	s2, x0, 0		# pixel offset - 4 lsb for x, 4 msb for y
        addi	s3, x0, 0		# tile offset - 4 lsb for x, 4 msb for y

	# fill background with tiles
        call	DRAW_WORLD		# fill background
        
        call	READ_PLAYER		# read player pixels before drawing player for first time
WORLD_UPDATE:
        call	DRAW_PLAYER		# draw player
WORLD_PAGE:
	beqz	s1, WORLD_PAGE	# check for interrupt
	
	# on interrupt
	addi	s1, x0, 0		# clear interrupt flag
	
	# move character
	lw	t0, 0x100(s0)		# read keyboard input
	addi	t1, x0, A_CODE
	beq	t0, t1, P_MOVE_LEFT	# check if 'A' was pressed
	addi	t1, x0, D_CODE
	beq	t0, t1, P_MOVE_RIGHT	# check if 'D' was pressed
	addi	t1, x0, W_CODE
	beq	t0, t1, P_MOVE_UP	# check if 'W' was pressed
	addi	t1, x0, S_CODE
	beq	t0, t1, P_MOVE_DOWN	# check if 'S' was pressed
	j	WORLD_PAGE
P_MOVE_LEFT:
	la	t2, PLAYER
	
	# set orientation to left
	addi	t0, x0, 2		
	sb	t0, 2(t2)
	
	# get player x and check if can move left
	lb	t3, 0(t2)		# load player x
	beqz	t3, WORLD_UPDATE	# if player x already 0, can't move left
	
	# check player head for wall
	addi	a0, t3, -1		# get x that player would be entering
	lb	a1, 1(t2)		# get y that player would be entering
	call	READ_DOT		# get color at that pixel
	addi	t0, x0, WALL_COLOR
	beq	a3, t0, WORLD_UPDATE	# if player is moving into wall, can't move left
	
	# check player foot for wall
	addi	a1, a1, P_HEIGHT
	addi	a1, a1, -1
	call	READ_DOT		# get color at that pixel
	addi	t0, x0, WALL_COLOR
	beq	a3, t0, WORLD_UPDATE	# if player is moving into wall, can't move left
	
	# can move left
	addi	t3, t3, -1		# decrement x by 1
	sb	t3, 0(t2)		# store decremented x
	addi	s2, s2, -1		# decrement pixel offset x by 1
	li	t1, LOWER_MASK
	and	t1, s2, t1		# mask to get lower bits of pixel offset
	addi	t4, x0, -T_SIZE
	bgt	t1, t4, SKIP_T_INC_L	# if pixel offset x gets to tile size, dec tile offset
	
	# dec tile offset and reset pixel offset
	addi	s3, s3, -1		# dec tile offset
	li	t1, UPPER_MASK
	and	s2, s2, t1		# mask pixel offset to set x offset to 0
	
	# clear pixels where player was
SKIP_T_INC_L:
	addi	a0, t3, 1
	lb	a1, 1(t2)
	call	CLEAR_PLAYER
	
	call	READ_PLAYER		# read player pixels into memory before drawing
	
	j	WORLD_UPDATE
P_MOVE_RIGHT:
	la	t2, PLAYER
	
	# set orientation to right
	addi	t0, x0, 3		
	sb	t0, 2(t2)
	
	# get player x and inc by 1, if allowed
	lb	t3, 0(t2)		# load player x
	
	# get max possible x
	addi	t4, x0, WIDTH	
	addi	t4, t4, -P_WIDTH
	beq	t3, t4, WORLD_UPDATE	# if player x already WIDTH-P_WIDTH, can't move right
	
	# check player head for wall
	addi	a0, t3, P_WIDTH		# get x that player would be entering
	lb	a1, 1(t2)		# get y that player would be entering
	call	READ_DOT		# get color at that pixel
	addi	t0, x0, WALL_COLOR
	beq	a3, t0, WORLD_UPDATE	# if player is moving into wall, can't move right
	
	# check player foot for wall
	addi	a1, a1, P_HEIGHT
	addi	a1, a1, -1
	call	READ_DOT		# get color at that pixel
	addi	t0, x0, WALL_COLOR
	beq	a3, t0, WORLD_UPDATE	# if player is moving into wall, can't move right
	
	# can move right
	addi	t3, t3, 1		# increment x by 1
	sb	t3, 0(t2)		# store incremented x
	addi	s2, s2, 1		# increment pixel offset x by 1
	li	t1, LOWER_MASK
	and	t1, s2, t1		# mask to get lower bits of pixel offset
	addi	t4, x0, T_SIZE
	blt	t1, t4, SKIP_T_INC_R	# if pixel offset x gets to tile size, inc tile offset
	
	# inc tile offset and reset pixel offset
	addi	s3, s3, 1		# inc tile offset
	li	t1, UPPER_MASK
	and	s2, s2, t1		# mask pixel offset to set x offset to 0
	
	# clear pixels where player was
SKIP_T_INC_R:
	addi	a0, t3, -1
	lb	a1, 1(t2)
	call	CLEAR_PLAYER
	
	call	READ_PLAYER		# read player pixels into memory before drawing
	
	j	WORLD_UPDATE
P_MOVE_UP:
	la	t2, PLAYER
	
	# set orientation to up
	addi	t0, x0, 1		
	sb	t0, 2(t2)
	
	# get player y and dec by 1, if allowed
	lb	t3, 1(t2)		# load player y
	beqz	t3, WORLD_UPDATE	# if player y already 0, can't move up
	
	# check player top left for wall
	addi	a1, t3, -1		# get y that player would be entering
	lb	a0, 0(t2)		# get x that player would be entering
	call	READ_DOT		# get color at that pixel
	addi	t0, x0, WALL_COLOR
	beq	a3, t0, WORLD_UPDATE	# if player is moving into wall, can't move up
	
	# check player top right for wall
	addi	a0, a0, P_WIDTH
	addi	a0, a0, -1
	call	READ_DOT		# get color at that pixel
	addi	t0, x0, WALL_COLOR
	beq	a3, t0, WORLD_UPDATE	# if player is moving into wall, can't move up
	
	# can move up
	addi	t3, t3, -1		# decrement y by 1
	sb	t3, 1(t2)		# store decremented y
	li	t0, 0x10000
	sub	s2, s2, t0		# decrement pixel offset y by 1
	
	# clear pixels where player was
	addi	a1, t3, 1
	lb	a0, 0(t2)
	call	CLEAR_PLAYER
	
	call	READ_PLAYER		# read player pixels into memory before drawing
	
	j	WORLD_UPDATE
P_MOVE_DOWN:
	la	t2, PLAYER
	
	# set orientation to down
	addi	t0, x0, 0		
	sb	t0, 2(t2)
	
	# get player y and inc by 1, if allowed
	lb	t3, 1(t2)		# load player y
	
	# get max possible x
	addi	t4, x0, HEIGHT
	addi	t4, t4, -P_HEIGHT
	beq	t3, t4, WORLD_UPDATE	# if player y already HEIGHT-P_HEIGHT, can't move down
	
	# check player bottom left for wall
	addi	a1, t3, P_HEIGHT	# get y that player would be entering
	lb	a0, 0(t2)		# get x that player would be entering
	call	READ_DOT		# get color at that pixel
	addi	t0, x0, WALL_COLOR
	beq	a3, t0, WORLD_UPDATE	# if player is moving into wall, can't move up
	
	# check player bottom right for wall
	addi	a0, a0, P_WIDTH
	addi	a0, a0, -1
	call	READ_DOT		# get color at that pixel
	addi	t0, x0, WALL_COLOR
	beq	a3, t0, WORLD_UPDATE	# if player is moving into wall, can't move up
	
	# can move down
	addi	t3, t3, 1		# increment y by 1
	sb	t3, 1(t2)		# store incremented y
	li	t0, 0x10000
	add	s2, s2, t0		# increment pixel offset y by 1
	
	# clear pixels where player was
	addi	a1, t3, -1
	lb	a0, 0(t2)
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
	addi	t4, t2, P_AREA		# get end of array
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
	la	t3, PLAYER
	addi	t3, t3, 3		# initialize pointer to colors array
	addi	t2, t3, P_AREA		# get end of array
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
	
# draw tiles on screen from world array
# modifies t0, t1, t2, t3, t4, t5, t6, a0, a1, a2, a3, a4
DRAW_WORLD:
	addi	sp, sp, -4
	sw	ra, 0(sp)
	
	la	t3, TILES		# get tiles array pointer
	addi	t6, t3, T_PER_ROW	# get start index of next row
	addi	t4, x0, WIDTH		# get screen end x and y
	addi	t5, x0, HEIGHT
	addi	a0, x0, 0		# initialize drawing coords
	addi	a1, x0, 0		
LOAD_W_LOOP:
	addi	a2, a0, T_SIZE		# get tile end coords
	addi	a2, a2, -1
	addi	a4, a1, T_SIZE
	addi	a4, a4, -1
	lb	t0, 0(t3)		# get tile byte
	addi	t3, t3, 1		# go to next byte
	bnez	t0, WALL_TILE		# draw tile using code from t5
EMPTY_TILE:
	addi	a3, x0, GREEN		# tile=0, blank background
	j	DRAW_TILE
WALL_TILE:
	addi	a3, x0, WALL_COLOR	# tile=1, wall tile
	j	DRAW_TILE
DRAW_TILE:
	call	DRAW_RECT		# draw tile
	addi	a0, a0, T_SIZE		# move x to next tile
	addi	a1, a1, -T_SIZE		# move y back to start
	blt	a0, t4, LOAD_W_LOOP	# check if x is off screen
	
	# x off screen
	addi	a0, x0, 0		# reset x
	addi	a1, a1, T_SIZE		# put y back to next row
	mv	t3, t6			# set tile array pointer to beginning of new row
	addi	t6, t3, T_PER_ROW	# get start index of next row (after new row)
	blt	a1, t5, LOAD_W_LOOP	# check if all tiles have been drawn

	# all tiles drawn - done	
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
