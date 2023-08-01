# define addresses and INTR enable
.eqv	MMIO		0x11000000	# first MMIO address
.eqv	STACK		0x10000		# stack address
.eqv	INT_EN		8		# enable interrupts

# define dimensions
# screen dimension
.eqv	WIDTH		80
.eqv	HEIGHT		60

# player dimensions
.eqv	P_WIDTH		3
.eqv	P_HEIGHT	5
.eqv	P_AREA		15		# must be P_WIDTH * P_HEIGHT

# tile dimensions
.eqv	T_SIZE		5		# width and height of square tiles

# world dimensions
.eqv	T_PER_ROW	24		# number of tiles per row, max 256. 16 fills exactly with 5x5
.eqv	T_PER_COL	24		# number of tiles per column, max 256. 12 fills exactly with 5x5
.eqv	T_ROW_ON_S	16		# number of tiles per row shown on screen, 16 fills exactly with 5x5
.eqv	T_COL_ON_S	12		# number of tiles per column shown on screen, 12 fills exactly with 5x5
.eqv	NUM_TILES	576		# total number of tiles in world, must be T_PER_ROW * T_PER_COL. max 65536 (256*256)
.eqv	T_MID_X		7		# tile offset to start moving screen view right/left, should be about half of tiles per row-1 shown on screen at once
.eqv	T_MID_Y		5		# tile offset to start moving screen view up/down, should be about half of tiles per col-1 shown on screen at once

# letter dimensions
.eqv	L_SIZE	5		# width and height of letters

# menu quantities - NEED TO USE THESE IN MENU CODE
.eqv	MENU_SQ_SIZE	10	# width and height of squares on menu page
.eqv	MENU_BTW_SIZE	15	# dist from topleft of menu square to topleft of next to right or down
.eqv	MENU_NUM_SQ	8	# number of squares in menu

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
.eqv	A_CODE		0x1C
.eqv	D_CODE		0x23
.eqv	S_CODE		0x1B
.eqv	W_CODE		0x1D
.eqv	SPACE_CODE	0x29


# predefined arrays in data segment
.data
# player data:
# 0: x coord of top of rectangle
# 1: y coord of top of rectange
# 2: orientation (0=down, 1=up, 2=left, 3=right)
# 3-17: pixels behind it that can be redrawn after. amount of bytes must equal P_AREA (P_WIDTH*P_HEIGHT)
PLAYER:	.space	18

# player offset data
# 0: pixel offset x - horiz pixel dist from prev tile
# 1: tile offset x - tile dist from left side of world (even offscreen) used to calculate offset of first tile shown in row
# 2: pixel offset y - vert pixel dist from prev tile
# 3: tile offset y - tile dist from top of world (even offscreen) used to calculate offset of first tile shown in row
# NOTE: tile offsets stop increasing/decreasing when end/start of row in world is drawn, even if plaher continues moving right/left
#	this is to prevent the offset of the first tile shown in the row from going to high/low since it is calculated as the diff btw tile offset and threshold
OFFSET: .space 4

# world tiles data:
# tiles array is array of addresses to fist tile in each row in ALL_TILES
# size is 4 * TILES_PER_COL
TILES_ARR:	.space 80
# all tiles includes type codes for all tiles in world
# number of bytes = number of tiles, number corresponds to which tile is drawn
# 0 - empty
# 1 - wall
# 2 - red (also empty)
ALL_TILES: .space NUM_TILES

# menu selection index
# 0 - selected index
# 1 - previously selected index
MENU_I:	.space 2


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
        addi	t1, x0, 25		# temporary start y for maze - REMOVE LATER
        sb	t1, 1(t0)		# y pos
        sb	x0, 2(t0)		# orientation, down to start
        
        # initialize offsets
        la	t0, OFFSET		# load offset address
        li	t1, 0x0B000000		# temporary start tile offset y for maze - REMOVE LATER
        sw	t1, 0(t0)		# fill with 0 for all offsets
        
        # initialize menu index
        la	t0, MENU_I		# load menu index address
        sb	x0, 0(t0)		# store 0 to index
        addi	t1, x0, -1
        sb	t1, 1(t0)		# store -1 to prev index
        
        # init tiles array
        la	t0, ALL_TILES		# get all tiles address
        la	t1, TILES_ARR		# get tiles array address
        addi	t2, t0, NUM_TILES	# get first address after end of all tiles
TILES_ARR_LOOP:
        sw	t0, 0(t1)		# store address of row in all tiles to entry in tiles array
        addi	t0, t0, T_PER_ROW	# get first address of next row
        addi	t1, t1, 4		# get next word index of tiles array
        blt	t1, t2, TILES_ARR_LOOP	# if new address in all tiles is still within bounds, store addr of next row
        
        # load tile codes into ALL_TILES array
        call	LOAD_WORLD_TILES
        
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
        
        # draw title text
        addi	a0, x0, L_SIZE
        addi	a1, x0, L_SIZE
        addi	a3, x0, WHITE
        addi	a2, x0, 'A'
        call	DRAW_LETTER
        addi	a2, x0, 'E'
        call	DRAW_LETTER
        addi	a2, x0, 'I'
        call	DRAW_LETTER
TITLE_UPDATE:
	beqz	s1, TITLE_UPDATE	# check for interrupt
	
	# on interrupt
	addi	s1, x0, 0		# clear interrupt flag
	lw	t0, 0x100(s0)		# read keyboard input
	addi	t1, x0, A_CODE
	beq	t0, t1, WORLD_START	# if key pressed was 'A', go to world view
	j	TITLE_UPDATE
	
# page opened after title page
WORLD_START:
	# fill background with tiles
        call	DRAW_WORLD		# fill background with tiles
        
        call	READ_PLAYER		# read player pixels before drawing player for first time
WORLD_UPDATE:
        call	DRAW_PLAYER		# draw player
WORLD_PAGE:
	beqz	s1, WORLD_PAGE		# check for interrupt
	
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
	addi	t1, x0, SPACE_CODE
	beq	t0, t1, MENU_START	# go to menu page if space pressed
	j	WORLD_PAGE
P_MOVE_LEFT:
	la	t2, PLAYER		# get player address
	
	# set orientation to left
	addi	t0, x0, 2
	sb	t0, 2(t2)		# store orientation in player array
	
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
	addi	a1, a1, P_HEIGHT	# get y that player bottomleft would be entering
	addi	a1, a1, -1
	call	READ_DOT		# get color at that pixel
	addi	t0, x0, WALL_COLOR
	beq	a3, t0, WORLD_UPDATE	# if player is moving into wall, can't move left
	
	# can move left
	addi	t3, t3, -1		# decrement x by 1
	sb	t3, 0(t2)		# store decremented x
	
	# clear pixels where player was
	addi	a0, t3, 1		# get x where player was before
	lb	a1, 1(t2)		# get player y
	call	CLEAR_PLAYER		# clear player at old coords
	call	READ_PLAYER		# read player pixels at new coords into memory before drawing
	
	# decrement pixel offset by 1
	la	t0, OFFSET		# load offset address
	lb	t1, 0(t0)		# load x pixel offset
	addi	t1, t1, -1		# dec pixel offset x by 1
	sb	t1, 0(t0)		# store dec'd offset
	
	# check pixel offset to see if need tile offset change
	addi	t2, x0, -T_SIZE		# check against negative TILE SIZE for tile offset change
	bgt	t1, t2, WORLD_UPDATE	# if pixel offset x gets to tile size, dec tile offset
	
	# pixel offset reached tile size
	sb	x0, 0(t0)		# reset pixel offset x to 0
	lb	t3, 1(t0)		# get player tile offset x
	addi	t3, t3, -1		# dec tile offset by 1
	sb	t3, 1(t0)		# store new tile offset x
	
	addi	t1, t3, -T_MID_X	# get difference between player tile offset and threshold - potential tile offset of first tile shown in row
	
	# check if tile offset big enough to shift screen
	bltz	t1, WORLD_UPDATE	# if diff btw player tile offset x is not at least 0 after decreasing, don't need to redraw
	
	# check to see if offset is already at max for tiles in row
	addi	t2, x0, T_PER_ROW
	addi	t2, t2, -T_ROW_ON_S	# get greatest offset of first tile in row where last tile in row isn't too far in tiles array
	bge	t1, t2, WORLD_UPDATE	# if offset of first tile in row is greater than that after decreasing, don't need to redraw
	
	# offset big enough, shift tiles and player forward
	la	t0, PLAYER		# get player array address
	lb	t1, 0(t0)		# get player x
	addi	t1, t1, T_SIZE		# inc player x to 1 tile before to account for offset
	sb	t1, 0(t0)		# store new x
	call	DRAW_WORLD		# redraw tiles with new offset
	j	WORLD_UPDATE
	
P_MOVE_RIGHT:
	la	t2, PLAYER		# store orientation in player array
	
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
	addi	a1, a1, P_HEIGHT	# get y that player bottomright would be entering
	addi	a1, a1, -1
	call	READ_DOT		# get color at that pixel
	addi	t0, x0, WALL_COLOR
	beq	a3, t0, WORLD_UPDATE	# if player is moving into wall, can't move right
	
	# can move right
	addi	t3, t3, 1		# increment x by 1
	sb	t3, 0(t2)		# store incremented x
	
	# clear pixels where player was
	addi	a0, t3, -1		# get x where player was before
	lb	a1, 1(t2)		# get player y
	call	CLEAR_PLAYER		# clear player at old coords
	call	READ_PLAYER		# read player pixels at new coords into memory before drawing
	
	# increment pixel offset by 1
	la	t0, OFFSET		# load offset address
	lb	t1, 0(t0)		# load x pixel offset
	addi	t1, t1, 1		# inc pixel offset x by 1
	sb	t1, 0(t0)		# store inc'd offset
	
	# check pixel offset to see if need tile offset change
	addi	t2, x0, T_SIZE		# check against TILE SIZE for tile offset change
	blt	t1, t2, WORLD_UPDATE	# if pixel offset x gets to tile size, inc tile offset
	
	# pixel offset reached tile size
	sb	x0, 0(t0)		# reset pixel offset x to 0
	lb	t3, 1(t0)		# get player tile offset x
	addi	t3, t3, 1		# inc tile offset by 1
	sb	t3, 1(t0)		# store new tile offset x
	
	addi	t1, t3, -T_MID_X	# get difference between player tile offset and threshold - potential tile offset of first tile shown in row
	
	# check if tile offset big enough to shift screen
	blez	t1, WORLD_UPDATE	# if diff btw player tile offset x is not greater than 0 after increasing, don't need to redraw
	
	# check to see if offset is already at max for tiles in row
	addi	t2, x0, T_PER_ROW
	addi	t2, t2, -T_ROW_ON_S	# get greatest offset of first tile in row where last tile in row isn't too far in tiles array
	bgt	t1, t2, WORLD_UPDATE	# if offset of first tile in row is greater than that after increasing, don't need to redraw
	
	# offset big enough, shift tiles and player back
	la	t0, PLAYER		# get player array address
	lb	t1, 0(t0)		# get player x
	addi	t1, t1, -T_SIZE		# dec player x to 1 tile before to account for offset
	sb	t1, 0(t0)		# store new x
	call	DRAW_WORLD		# redraw tiles with new offset
	j	WORLD_UPDATE
	
P_MOVE_UP:
	la	t2, PLAYER		# store orientation in player array
		
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
	
	# clear pixels where player was
	addi	a1, t3, 1
	lb	a0, 0(t2)
	call	CLEAR_PLAYER
	call	READ_PLAYER		# read player pixels into memory before drawing
	
	# decrement pixel offset by 1
	la	t0, OFFSET		# load offset address
	lb	t1, 2(t0)		# load y pixel offset
	addi	t1, t1, -1		# dec pixel offset y by 1
	sb	t1, 2(t0)		# store dec'd offset
	
	# check pixel offset to see if need tile offset change
	addi	t2, x0, -T_SIZE		# check against negative TILE SIZE for tile offset change
	bgt	t1, t2, WORLD_UPDATE	# if pixel offset y gets to tile size, dec tile offset
	
	# pixel offset reached tile size
	sb	x0, 2(t0)		# reset pixel offset y to 0
	lb	t3, 3(t0)		# get player tile offset y
	addi	t3, t3, -1		# dec tile offset by 1
	sb	t3, 3(t0)		# store new tile offset y
	
	addi	t1, t3, -T_MID_Y	# get difference between player tile offset and threshold - potential tile offset of first tile shown in col
	
	# check if tile offset big enough to shift screen
	bltz	t1, WORLD_UPDATE	# if diff btw player tile offset y is not at least 0 after decreasing, don't need to redraw
	
	# check to see if offset is already at max for tiles in row
	addi	t2, x0, T_PER_COL
	addi	t2, t2, -T_COL_ON_S	# get greatest offset of first tile in col where last tile in col isn't too far in tiles array
	bge	t1, t2, WORLD_UPDATE	# if offset of first tile in col is greater than that after decreasing, don't need to redraw
	
	# offset big enough, shift tiles and player down
	la	t0, PLAYER		# get player array address
	lb	t1, 1(t0)		# get player y
	addi	t1, t1, T_SIZE		# inc player y to 1 tile before to account for offset
	sb	t1, 1(t0)		# store new y
	call	DRAW_WORLD		# redraw tiles with new offset
	j	WORLD_UPDATE
	
P_MOVE_DOWN:
	la	t2, PLAYER		# store orientation in player array
	
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
	
	# clear pixels where player was
	addi	a1, t3, -1
	lb	a0, 0(t2)
	call	CLEAR_PLAYER
	call	READ_PLAYER		# read player pixels into memory before drawing
	
	# increment pixel offset by 1
	la	t0, OFFSET		# load offset address
	lb	t1, 2(t0)		# load y pixel offset
	addi	t1, t1, 1		# inc pixel offset y by 1
	sb	t1, 2(t0)		# store inc'd offset
	
	# check pixel offset to see if need tile offset change
	addi	t2, x0, T_SIZE		# check against TILE SIZE for tile offset change
	blt	t1, t2, WORLD_UPDATE	# if pixel offset y gets to tile size, inc tile offset
	
	# pixel offset reached tile size
	sb	x0, 2(t0)		# reset pixel offset y to 0
	lb	t3, 3(t0)		# get player tile offset y
	addi	t3, t3, 1		# inc tile offset by 1
	sb	t3, 3(t0)		# store new tile offset y
	
	addi	t1, t3, -T_MID_Y	# get difference between player tile offset and threshold - potential tile offset of first tile shown in col
	
	# check if tile offset big enough to shift screen
	blez	t1, WORLD_UPDATE	# if diff btw player tile offset y is not greater than 0 after increasing, don't need to redraw
	
	# check to see if offset is already at max for tiles in col
	addi	t2, x0, T_PER_COL
	addi	t2, t2, -T_COL_ON_S	# get greatest offset of first tile in col where last tile in col isn't too far in tiles array
	bgt	t1, t2, WORLD_UPDATE	# if offset of first tile in col is greater than that after increasing, don't need to redraw
	
	# offset big enough, shift tiles and player up
	la	t0, PLAYER		# get player array address
	lb	t1, 1(t0)		# get player y
	addi	t1, t1, -T_SIZE		# dec player y to 1 tile before to account for offset
	sb	t1, 1(t0)		# store new y
	call	DRAW_WORLD		# redraw tiles with new offset
	j	WORLD_UPDATE
	
# menu screen opened from world screen
MENU_START:
	# fill background with red
	addi	a3, x0, RED
	call	DRAW_BG
	
	# draw menu title text
	addi	a0, x0, L_SIZE
	addi	a1, x0, L_SIZE
	addi	a3, x0, WHITE
	addi	a2, x0, 'M'
	call	DRAW_LETTER
	addi	a2, x0, 'E'
	call	DRAW_LETTER
	addi	a2, x0, 'N'
	call	DRAW_LETTER
	addi	a2, x0, 'U'
	call	DRAW_LETTER
	
	# draw menu squares
	addi	t3, x0, 10		# save initial coords x - REMOVE MAGIC NUMBER LATER
	addi	t4, x0, 20		# save initial coords y - REMOVE MAGIC NUMBER LATER
	addi	a3, x0, WHITE		# set color
MENU_DRAW_LOOP:
	# set coords for drawing rectangle
	mv	a0, t3
	mv	a1, t4
	addi	a2, a0, 10
	addi	a4, a1, 10
	
	call	DRAW_RECT		# draw rectangle
	
	addi	t3, t3, 15		# inc x to next rect
	addi	t0, x0, WIDTH
	addi	t0, t0, -10
	blt	t3, t0, MENU_DRAW_LOOP	# if x not too far right, draw next rect
	
	# x too far right
	addi	t3, x0, 10		# reset x
	addi	t4, t4, 15		# inc y to next row
	addi	t0, x0, HEIGHT
	addi	t0, t0, -10
	blt	t4, t0, MENU_DRAW_LOOP	# if y not too far down, draw next rect. otherwise end loop
	
MENU_UPDATE:
	la	t0, MENU_I		# get address of menu index
	lb	t5, 0(t0)		# get current menu index
	lb	t6, 1(t0)		# get prev menu index
	addi	a0, x0, 10		# set initial coords x to find rect to mark - REMOVE MAGIC NUMBER LATER
	addi	a1, x0, 20		# set initial coords y to find rect to mark - REMOVE MAGIC NUMBER LATER
M_I_LOOP:
	beqz	t6, M_CLEAR_SEL		# if counter reached 0, found correct rectangle
	beqz	t5, M_DRAW_SEL		# if counter reached 0, found correct rectangle
	bgez	t6, M_I_CONT
	bltz	t5, MENU_PAGE
M_I_CONT:
	# counter not 0
	addi	t5, t5, -1		# dec current index counter
	addi	t6, t6, -1		# dec prev index counter

	# go to next rect
	addi	a0, a0, 15		# inc x to next rect
	addi	t0, x0, WIDTH
	addi	t0, t0, -10
	blt	a0, t0, M_I_LOOP	# if x not too far right, check counter again
	
	# x too far right
	addi	a0, x0, 10		# reset x
	addi	a1, a1, 15		# inc y to next row
	j	M_I_LOOP		# check counter again
	
M_CLEAR_SEL:
	# save x and y coords
	mv	t3, a0
	mv	t4, a1

	# draw white cleared rectangle
	addi	a2, a0, 10		# set coords of other corner of rect
	addi	a4, a1, 10
	addi	a3, x0, WHITE		# set selection color
	call	DRAW_RECT		# draw over selected rect
	
	# restore x and y coords
	mv	a0, t3
	mv	a1, t4
	
	j	M_I_CONT
	
M_DRAW_SEL:
	# save x and y coords
	mv	t3, a0
	mv	t4, a1

	# draw blue selected rectangle
	addi	a2, a0, 10		# set coords of other corner of rect
	addi	a4, a1, 10
	addi	a3, x0, BLUE		# set selection color
	call	DRAW_RECT		# draw over selected rect
	
	# restore x and y coords
	mv	a0, t3
	mv	a1, t4
	
	j	M_I_CONT
	
MENU_PAGE:
	beqz	s1, MENU_PAGE		# check for interrupt
	
	# on interrupt
	addi	s1, x0, 0		# clear interrupt flag
	
	lw	t0, 0x100(s0)		# read keyboard input
	addi	t1, x0, A_CODE
	beq	t0, t1, M_MOVE_LEFT	# if key pressed was 'A', move selection left
	addi	t1, x0, D_CODE
	beq	t0, t1, M_MOVE_RIGHT	# if key pressed was 'D', move selection right
	addi	t1, x0, W_CODE
	beq	t0, t1, M_MOVE_UP	# if key pressed was 'W', move selection up
	addi	t1, x0, S_CODE
	beq	t0, t1, M_MOVE_DOWN	# if key pressed was 'S', move selection down
	addi	t1, x0, SPACE_CODE
	beq	t0, t1, WORLD_START	# if key pressed was space, go to world view
	j	MENU_PAGE
	
M_MOVE_LEFT:
	la	t0, MENU_I		# get menu index address
	lb	t1, 0(t0)		# get current menu index
	sb	t1, 1(t0)		# store to prev index
	addi	t1, t1, -1		# dec index
	bge	t1, x0, M_MOVE_END	# if at least 0, store new index
	
	# if less than 0, reset to max
	addi	t1, x0, MENU_NUM_SQ
	addi	t1, t1, -1
	j	M_MOVE_END
	
M_MOVE_RIGHT:
	la	t0, MENU_I		# get menu index address
	lb	t1, 0(t0)		# get current menu index
	sb	t1, 1(t0)		# store to prev index
	addi	t1, t1, 1		# dec index
	
	addi	t2, x0, MENU_NUM_SQ	# get max allowed index
	blt	t1, t2, M_MOVE_END	# if less than max, store new index
	
	# if greater than max, reset to max
	addi	t1, x0, 0
	j	M_MOVE_END
	
M_MOVE_UP:
	j	M_MOVE_END
M_MOVE_DOWN:
	j	M_MOVE_END
M_MOVE_END:
	sb	t1, 0(t0)
	j	MENU_UPDATE

                
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
	
	# get start index for tiles
	la	t3, TILES_ARR		# get tiles array pointer
	la	t1, OFFSET		# get tile offset address
	
	# get tile offset y to add to pointer
	lb	t0, 3(t1)		# get player tile offset y
	addi	t0, t0, -T_MID_Y	# get difference between player tile offset and threshold
	
	# check for player offset y too low
	blez	t0, DW_GET_ADDR		# if diff is less than 0 or 0, pointer offset is 0. start each col such that first tile in col on screen is first tile in col of world
	
	# check for player offset y too high
	addi	t2, x0, T_PER_COL
	addi	t2, t2, -T_COL_ON_S	# get diff between total tiles per row and tiles shown per row on screen
	bge	t0, t2, DW_OFFSET_MAX_Y	#if diff is greater than that^, pointer offset is that^. start each col such that last tile in col on screen is last tile in col of world
	
	# player offset y in appropriate range, add diff to pointer directly
	slli	t0, t0, 2		# multiply offset by 4 to account for word addresses
	add	t3, t3, t0		# get tile row offset to start index of tile array
	j	DW_GET_ADDR
DW_OFFSET_MAX_Y:
	slli	t2, t2, 2		# multiply offset by 4 to account for word addresses
	add	t3, t3, t2		# add max allowed offset to pointer, since actual offset is too big
DW_GET_ADDR:
	lw	t3, 0(t3)		# get first address of desired row in all tiles from tiles array
	
	# get tile offset x to add to pointer
	lb	t0, 1(t1)		# get player tile offset x
	addi	t0, t0, -T_MID_X	# get difference between player tile offset and threshold
	
	# check for player offset x too low
	blez	t0, START_DRAW_W	# if diff is less than 0 or 0, pointer offset is 0. start each row such that first tile in row on screen is first tile in row of world
	
	# check for player offset x too high
	addi	t2, x0, T_PER_ROW
	addi	t2, t2, -T_ROW_ON_S	# get diff between total tiles per row and tiles shown per row on screen
	bge	t0, t2, DW_OFFSET_MAX_X	# if diff is greater than that^, pointer offset is that^. start each row such that last tile in row on screen is last tile in row of world
	
	# player offset x in appropriate range, add diff to pointer directly
	add	t3, t3, t0		# add tile col offset to start index of row of all tiles
	j	START_DRAW_W
DW_OFFSET_MAX_X:
	add	t3, t3, t2		# add max allowed offset to pointer, since acutal offset is too big
START_DRAW_W:
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
	addi	t2, x0, 1
	beq	t0, t2, WALL_TILE	# draw tile using code from t0
	addi	t2, t2, 1
	beq	t0, t2, RED_TILE
EMPTY_TILE:
	addi	a3, x0, GREEN		# tile=0, blank background
	j	DRAW_TILE
WALL_TILE:
	addi	a3, x0, WALL_COLOR	# tile=1, wall tile
	j	DRAW_TILE
RED_TILE:
	addi	a3, x0, RED		# tile=2, red (also empty)
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
	
# draw 5x5 letter given by ascii in a2 with topleft at (a0, a1) with color in a3
# modifies t0, t1, t2, t3, a0, a1, a2
DRAW_LETTER:
	addi	sp, sp, -4
	sw	ra, 0(sp)
	
	# save coords to draw lines
	addi	t2, a0, 0 		# x coord
	addi	t3, a1, 0		# y coord
	
	# check which letter it is
	addi	t0, x0, 'A'
	beq	a2, t0, DL_A		# ascii 'A'
	addi	t0, x0, 'E'
	beq 	a2, t0, DL_E		# ascii 'E'
	j	DL_UNKNOWN		# unimplemented ascii
DL_A:
	# draw 5x5 A
	addi	a0, a0, 1
	addi	a2, a0, 2
	call	DRAW_HORIZ_LINE
	
	mv	a0, t2
	addi	a1, t3, 1
	addi	a2, a1, 3
	call	DRAW_VERT_LINE
	
	addi	a0, a0, 4
	addi	a1, t3, 1
	addi	a2, a1, 3
	call DRAW_VERT_LINE
	
	addi	a0, t2, 1
	addi	a1, t3, 2
	addi	a2, a0, 2
	call	DRAW_HORIZ_LINE
	j	DL_END
	
DL_E:
	# draw 5x5 E
	addi	a2, a1, 4
	call	DRAW_VERT_LINE
	
	addi	a0, t2, 1
	mv	a1, t3
	addi	a2, a0, 3
	call	DRAW_HORIZ_LINE
	
	addi	a0, t2, 1
	addi	a1, t3, 2
	addi	a2, a0, 2
	call	DRAW_HORIZ_LINE
	
	addi	a0, t2, 1
	addi	a1, t3, 4
	addi	a2, a0, 3
	call	DRAW_HORIZ_LINE
	j	DL_END
	
DL_UNKNOWN:
	# draw 5x5 square
	addi	a2, a1, 4
	call	DRAW_VERT_LINE
	
	addi	a0, t2, 1
	mv	a1, t3
	addi	a2, a0, 3
	call	DRAW_HORIZ_LINE
	
	addi	a0, t2, 4
	addi	a1, t3, 1
	addi	a2, a1, 3
	call	DRAW_VERT_LINE
	
	addi	a0, t2, 1
	addi	a1, t3, 4
	addi	a2, a0, 2
	call	DRAW_HORIZ_LINE
	j	DL_END
	
DL_END:
	# restore original coords to arg registers
	addi	a0, t2, L_SIZE
	addi	a0, a0, 1
	mv	a1, t3
	
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
	
# loads tile codes into ALL_TILES array for world
# should be called in initialization of world page (WORLD_START)
# modifies t0, t1
LOAD_WORLD_TILES:
	addi	sp, sp, -4
	sw	ra, 0(sp)
	
	# load world tiles
        la	t0, TILES_ARR		# get tiles array address. t2 is still end of all tiles
        lw	t0, 0(t0)		# get first address of all tiles from tiles array
        
        #  rows of maze - REMOVE LATER
LOAD_T_ROW:
	# row 1
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        
        # row 2
        li	t1, 0x00000101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x00000000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x00000000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x00000000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x00000101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x00000000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x00000000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x00000000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        
        # row 3
        li	t1, 0x00000101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x00000101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        
        # row 4
        li	t1, 0x00000101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x00000000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x00000101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x00000000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        
        # row 5
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        
        # row 6
        li	t1, 0x00000202
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x00000000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x00000202
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x00000000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        
        # row 7
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        
        # row 8
        li	t1, 0x00000101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x00000000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x00000000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x00000101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x00000000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x00000000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        
        # row 9
        li	t1, 0x00000101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x00000101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        
        # row 10
        li	t1, 0x00000101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x00000000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x00000101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x00000000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        
        # row 11
        li	t1, 0x00000101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x00000000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x00000000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x00000101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x00000000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x00000000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010000
        sw	t1, 0(t0)
        addi	t0, t0, 4
        
        # row 12
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010202
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010202
        sw	t1, 0(t0)
        addi	t0, t0, 4
        li	t1, 0x01010101
        sw	t1, 0(t0)
        addi	t0, t0, 4
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
