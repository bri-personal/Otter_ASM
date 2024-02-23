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

# party quantities
.eqv	PARTY_SIZE	6	# number of members of party/number of rects to be drawn
.eqv	PARTY_RECT_W	30	# width of party rectangles
.eqv	PARTY_RECT_H	7	# height of party rectangles

# menu quantities
# MUST have 2 rows of equal number of squares and size must WIDTH / MENU_NUM_SQ
.eqv	MENU_NUM_SQ	8	# total number of squares in menu - must be even
.eqv	MENU_SQ_SIZE	10	# width and height of squares on menu page

# define colors
.eqv	BLACK		0
.eqv	WHITE		0xFF
.eqv	L_GRAY		0x92
.eqv	RED		0xE0
.eqv	GREEN		0x1C
.eqv	BLUE		0x03
.eqv	YELLOW		0xFC
.eqv	MAGENTA		0xE3
.eqv	CYAN		0x1F
.eqv	ORANGE		0xF0
.eqv	PURPLE		0xA3
.eqv	D_GREEN		0x08
.eqv	BROWN		0x89
.eqv	WALL_COLOR	D_GREEN
.eqv	M_SEL_COLOR	L_GRAY

# define key codes
.eqv	A_CODE		0x1C
.eqv	D_CODE		0x23
.eqv	S_CODE		0x1B
.eqv	W_CODE		0x1D
.eqv	X_CODE		0x22
.eqv	SPACE_CODE	0x29


# predefined arrays in data segment
.data
# player data:
# 0: x coord of top of rectangle
# 1: y coord of top of rectange
# 2: orientation (0=down, 1=up, 2=left, 3=right)
# 3-17: pixels behind it that can be redrawn after. amount of bytes must equal P_AREA (P_WIDTH*P_HEIGHT)
PLAYER:		.space	18

# player offset data
# 0: pixel offset x - horiz pixel dist from prev tile
# 1: tile offset x - tile dist from left side of world (even offscreen) used to calculate offset of first tile shown in row
# 2: pixel offset y - vert pixel dist from prev tile
# 3: tile offset y - tile dist from top of world (even offscreen) used to calculate offset of first tile shown in column
# NOTE: tile offsets stop increasing/decreasing when end/start of row in world is drawn, even if player continues moving right/left
#	this is to prevent the offset of the first tile shown in the row from going to high/low since it is calculated as the diff btw tile offset and threshold
OFFSET:		.space 4

# world tiles data:
# tiles array is array of addresses to fist tile in each row in ALL_TILES
# size is 4 * TILES_PER_COL
TILES_ARR:	.space 80
# all tiles includes type codes for all tiles in world
# number of bytes = number of tiles, number corresponds to which tile is drawn
# 0 - empty
# 1 - wall
# 2 - red (also empty)
ALL_TILES:	.space NUM_TILES

# menu selection index (2 bytes) and button colors (number of bytes for number of buttons)
# 0 - currently selected index
# 1 - prev selected index
# 2-9 - colors of buttons
MENU_ARR:	.space 10

# party selection index (1 byte)
# 0 - currently selected index
# indices range from PARTY_SIZE (first) to 1 (last)
PARTY_IND:	.space 1

# strings - each byte is a character
# last byte must be 0 as terminator character
TITLE_STR:	.space 43		# title text displayed on title screen
MENU_STR:	.space 5		# title text displayed on menu screen
PARTY_STR:	.space 6		# title text displayed on party screen
BOXES_STR:	.space 6		# title text displayed for boxes on party screen


# executed code
.text
MAIN:
	# initialize important values/addresses
	li	sp, STACK		# setup sp
        li	s0, MMIO		# setup MMIO pointer
        mv	s1, x0			# set interrupt flag to 0
        
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
        la	t0, MENU_ARR		# load menu index address
        sb	x0, 0(t0)		# store 0 to index
        addi	t1, x0, -1
        sb	t1, 1(t0)		# store -1 to prev index
        
        # initialize party index
        la 	t0, PARTY_IND		# load party index address
        addi	t1, x0, PARTY_SIZE
        sb	t1, 0(t0)		# store PARTY_SIZE to current index
        
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
        call	LOAD_DATA
        
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
        la	a2, TITLE_STR		# get title string address
        addi	a0, x0, L_SIZE
        addi	a1, x0, L_SIZE
        addi	a3, x0, WHITE
        
	call DRAW_STRING		# draw title string
TITLE_PAGE:
	beqz	s1, TITLE_PAGE	# check for interrupt
	
	# on interrupt
	addi	s1, x0, 0		# clear interrupt flag
	lw	t0, 0x100(s0)		# read keyboard input
	addi	t1, x0, X_CODE
	beq	t0, t1, WORLD_START	# if key pressed was 'X', go to world view
	j	TITLE_PAGE
	
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
	beq	t0, t1, W_P_MOVE_LEFT	# check if 'A' was pressed
	addi	t1, x0, D_CODE
	beq	t0, t1, W_P_MOVE_RIGHT	# check if 'D' was pressed
	addi	t1, x0, W_CODE
	beq	t0, t1, W_P_MOVE_UP	# check if 'W' was pressed
	addi	t1, x0, S_CODE
	beq	t0, t1, W_P_MOVE_DOWN	# check if 'S' was pressed
	addi	t1, x0, X_CODE
	beq	t0, t1, MENU_START	# go to menu page if space pressed
	j	WORLD_PAGE
# move player left in world view
W_P_MOVE_LEFT:
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
# move player right in world view
W_P_MOVE_RIGHT:
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
# move player up in world view
W_P_MOVE_UP:
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
# move player down in world view
W_P_MOVE_DOWN:
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
	la	a2, MENU_STR
	call	DRAW_STRING
MENU_UPDATE:
	# draw menu squares
	la	t6, MENU_ARR		# get address of menu array
	lb	t5, 0(t6)		# get current menu index
	addi	t6, t6, 2		# set to first index of colors
	
	# save initial coords x
	addi	t3, x0, MENU_SQ_SIZE
	srli	t3, t3, 1		# x starts at half square size
	
	# save initial coords y
	addi	t4, x0, MENU_SQ_SIZE	# y starts at 1.5 square size
	add	t4, t4, t3
	
	addi	a3, x0, WHITE		# set color
MENU_DRAW_LOOP:
	# set coords for drawing rectangle
	mv	a0, t3
	mv	a1, t4
	addi	a2, a0, MENU_SQ_SIZE
	addi	a4, a1, MENU_SQ_SIZE
	
	beqz	t5, MENU_DRAW_SEL	# check if current square is selected
	
	# not selected, draw white
	addi	a3, x0, WHITE
	j	MENU_DRAW_CONT
MENU_DRAW_SEL:
	# selected, draw blue
	addi	a3, x0, M_SEL_COLOR
MENU_DRAW_CONT:
	call	DRAW_RECT		# draw rectangle
	
	# draw image on menu button
	# draw empty square	
	lb	a3, 0(t6)		# set color of inner square
	addi	t6, t6, 1		# go to next index
	
	addi	a0, t3, 1		# get start of inner square x
	addi	a1, t4, 1		# get start of inner square y
	addi	a2, a0, MENU_SQ_SIZE
	addi	a2, a2, -2
	call	DRAW_HORIZ_LINE
	
	addi	a0, t3, 1		# get start of inner square x not filled yet
	addi	a1, t4, 2		# get start of inner square y not filled yet
	addi	a2, a1, MENU_SQ_SIZE
	addi	a2, a2, -3
	call	DRAW_VERT_LINE
	
	addi	a0, t3, 2		# get bottom left of inner square x not filled yet
	addi	a1, t4, MENU_SQ_SIZE	# get bottom left of inner square y not filled yet
	addi	a1, a1, -1
	addi	a2, a0, MENU_SQ_SIZE
	addi	a2, a2, -3
	call	DRAW_HORIZ_LINE
	
	addi	a0, t3, 1		# get top right of inner square x not filled yet
	addi	a0, a0, MENU_SQ_SIZE
	addi	a0, a0, -2
	addi	a1, t4, 2		# get top right of inner square y not filled yet
	addi	a2, a1, MENU_SQ_SIZE
	addi	a2, a2, -4
	call	DRAW_VERT_LINE
	#####
	
	addi	t5, t5, -1		# dec counter for current selected index
	
	# get square size to inc
	addi	t0, x0, MENU_SQ_SIZE
	slli	t0, t0, 1		# add 2x square size to get to next square
	
	# inc x pos and check for overflow
	add	t3, t3, t0		# inc x to next rect
	addi	t0, x0, WIDTH
	addi	t0, t0, -MENU_SQ_SIZE
	blt	t3, t0, MENU_DRAW_LOOP	# if x not too far right, draw next rect
	
	# x too far right
	# reset x
	addi	t3, x0, MENU_SQ_SIZE	# x starts at half square size
	srli	t3, t3, 1
	
	# get square size to inc
	addi	t0, x0, MENU_SQ_SIZE
	slli	t0, t0, 1		# add 2x square size to get to next row
	
	# inc y pos to next row and check for overflow
	add	t4, t4, t0
	addi	t0, x0, HEIGHT
	addi	t0, t0, -MENU_SQ_SIZE
	blt	t4, t0, MENU_DRAW_LOOP	# if y not too far down, draw next rect. otherwise end loop
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
	addi	t1, x0, X_CODE
	beq	t0, t1, M_SEL_BUTTON	# if key pressed was 'X', select button and go to corresponding page
	addi	t1, x0, SPACE_CODE
	beq	t0, t1, WORLD_START	# if key pressed was space, go to world view
	j	MENU_PAGE	
# use current selection index to determine which page to go to next
M_SEL_BUTTON:
	la	t0, MENU_ARR		# get address of index
	lb	t0, 0(t0)		# get index
	beq	t0, x0, MENU_PAGE	# 0 - dex
	addi	t1, x0, 1
	beq	t0, t1, PARTY_START	# 1 - party
	addi	t1, t1, 1
	beq	t0, t1, MENU_PAGE	# 2 - bag
	addi	t1, t1, 1
	beq	t0, t1, MENU_PAGE	# 3 - save
	addi	t1, t1, 1
	beq	t0, t1, MENU_PAGE	# 4 - map
	addi	t1, t1, 1
	beq	t0, t1, MENU_PAGE	# 5 - player info
	addi	t1, t1, 1
	beq	t0, t1, MENU_PAGE	# 6 - battle
	j	MENU_PAGE		# 7 - settings
# move menu selection left
M_MOVE_LEFT:
	# set up menu index
	la	t0, MENU_ARR		# get menu index address
	lb	t1, 0(t0)		# get current menu index
	sb	t1, 1(t0)		# store to prev index
	addi	t1, t1, -1		# dec current index
	
	# set num in each row in advance for checking/calcs
	addi	t2, x0, MENU_NUM_SQ	# get max allowed index
	srli	t2, t2, 1		# halve max allowed to get number in each row
	
	# check for underflow
	bltz	t1, M_M_LEFT_UF		# if current index less than 0, go to end of 1st row
	addi	t2, t2, -1		# get index of rect before 2nd row
	beq	t1, t2, M_M_LEFT_REST	# if gone from 2nd row to 1st, go to end of 2nd row
	j	M_MOVE_END
M_M_LEFT_REST:
	# restore t2 to hold num in each row
	addi	t2, t2, 1		# add 1 since it was subtracted above
M_M_LEFT_UF:
	# row underflow, set to end of row
	add	t1, t1, t2		# add number in each row to go to end of row
	j	M_MOVE_END
# move menu selection right
M_MOVE_RIGHT:
	# set up menu index
	la	t0, MENU_ARR		# get menu index address
	lb	t1, 0(t0)		# get current menu index
	sb	t1, 1(t0)		# store to prev index
	addi	t1, t1, 1		# inc index
	
	# check for overflow
	addi	t2, x0, MENU_NUM_SQ	# get max allowed index
	bge	t1, t2, M_M_RIGHT_REST	# if reached max, go back to beginning of row
	srli	t2, t2, 1		# get half of max amount in row
	beq	t1, t2, M_M_RIGHT_OF	# if reached half of max, go back to beginning of row
	j	M_MOVE_END
M_M_RIGHT_REST:
	# set t2 to hold num in each row
	srli	t2, t2, 1		# halve max allowed to get number in each row
M_M_RIGHT_OF:
	# row overflow, set to beginning of row
	sub	t1, t1, t2		# subtract to go to beginning of row
	j	M_MOVE_END
# move menu selection up
M_MOVE_UP:
	la	t0, MENU_ARR		# get menu index address
	lb	t1, 0(t0)		# get current menu index
	sb	t1, 1(t0)		# store to prev index
	addi	t2, x0, MENU_NUM_SQ	# get max amount of rects
	srli	t2, t2, 1		# halve max allowed to get number in each row
	sub	t1, t1, t2		# dec index
	bgez	t1, M_MOVE_END		# if not gone past first rect, store new index
	
	# gone past first rect
	slli	t2, t2, 1		# get back full number of rects
	add	t1, t1, t2		# add to negative index to go to last row
	j	M_MOVE_END
# move menu selection down
M_MOVE_DOWN:
	la	t0, MENU_ARR		# get menu index address
	lb	t1, 0(t0)		# get current menu index
	sb	t1, 1(t0)		# store to prev index
	addi	t2, x0, MENU_NUM_SQ	# get max amount of rects
	srli	t2, t2, 1		# halve max allowed to get number in each row
	add	t1, t1, t2		# inc index
	slli	t2, t2, 1		# get back total number of rects
	blt	t1, t2, M_MOVE_END	# if not gone past last rect, store new index
	
	# gone past last rect
	sub	t1, t1, t2		# subtract from too high index to go to first row
	j	M_MOVE_END
M_MOVE_END:
	sb	t1, 0(t0)		# store new index
	j	MENU_UPDATE

# party page shows what is in party and reserves
PARTY_START:
	addi	a3, x0, RED
	call	DRAW_BG
	
	# draw party title text
	addi	a0, x0, L_SIZE		# set initial x
	addi	a0, a0, -2		# "
	addi	a1, x0, 1		# set initial y
	addi	a3, x0, WHITE		# set color
	la	a2, PARTY_STR		# get string address
	call	DRAW_STRING
	
	# draw boxes title text
	addi	a0, x0, WIDTH		# set initial x
	srli	a0, a0, 1		# "
	addi	a0, a0, L_SIZE		# "
	addi	a0, a0, -2		# "
	addi	a1, x0, 1		# set initial y
	la	a2, BOXES_STR		# get string address
	call	DRAW_STRING
	
	# draw line
	addi	a0, x0, WIDTH		# set initial x
	srli	a0, a0, 1		# "
	addi	a0, a0, -2		# "
	addi	a1, x0, 2		# set initial y
	addi	a2, x0, HEIGHT
	addi	a2, a2, -2
	call	DRAW_VERT_LINE
PARTY_UPDATE:
	addi	t3, x0, PARTY_SIZE	# counter for drawing rects
	la	t4, PARTY_IND		
	lb	t4, 0(t4)		# get current selection index
	
	# draw rectangles for each member of party
	addi	a0, x0, L_SIZE		# set initial x
	addi	a0, a0, -2		# "
	addi	a1, x0, L_SIZE		# set initial y
	addi	a1, a1, 2		# "
P_DRAW_LOOP:
	beq	t3, t4, P_DRAW_L_CURR	# set color based on index
	addi	a3, x0, WHITE		# set color of rect to WHITE for not selected
	j	P_DRAW_L_CONT
P_DRAW_L_CURR:
	addi	a3, x0, M_SEL_COLOR	# set color of rect to BLUE for selected
P_DRAW_L_CONT:
	addi	a2, a0, PARTY_RECT_W	# get other corner of rect
	addi	a4, a1, PARTY_RECT_H	# "
	call	DRAW_RECT		# draw rect
	mv	a1, a4			# go to y for next rect
	addi	a1, a1, 1		# "
	addi	t3, t3, -1		# dec counter
	bgtz	t3, P_DRAW_LOOP		# if counter reaches 0, done drawing rects
	
	# draw rectangles for boxes
	addi	a0, x0, WIDTH		# set initial x
	srli	a0, a0, 1		# "
	addi	a0, a0, L_SIZE		# "
	addi	a0, a0, -2		# "
	mv	t4, a0			# save this initial x for drawing later
	addi	a1, x0, L_SIZE		# set initial y
	addi	a1, a1, 2		# "
P_B_DRAW_LOOP:
	addi	a3, x0, WHITE		# set color of rect
	addi	a2, a0, PARTY_RECT_H	# get other corner of rect
	addi	a4, a1, PARTY_RECT_H	# "
	call	DRAW_RECT		# draw rect
	mv	a0, a2			# go to x for next rect
	addi	a0, a0, 2		# "
	addi	a1, a1, -PARTY_RECT_H	# reset y
	addi	a1, a1, -1		# "
	addi	t0, a0, -WIDTH		# compare x to width to see if going off screen
	addi	t0, t0, PARTY_RECT_H	# "
	bltz	t0, P_B_DRAW_LOOP	# if right side of rect is not offscreen, draw next one
	mv	a0, t4			# reset x
	addi	a1, a1, PARTY_RECT_H	# set y to next row
	addi	a1, a1, 2		# "
	addi	t0, a1, -HEIGHT		# compare y to height to see if going off screen
	addi	t0, t0, PARTY_RECT_H	# "
	bltz	t0, P_B_DRAW_LOOP	# if bottom of rect is not offscreen, draw next one
PARTY_PAGE:
	beqz	s1, PARTY_PAGE		# check for interrupt
	
	# on interrupt
	addi	s1, x0, 0		# clear interrupt flag
	
	lw	t0, 0x100(s0)		# read keyboard input
	addi	t1, x0, S_CODE
	beq	t0, t1, PARTY_MOVE_DOWN	# if key pressed was S, move party selection down
	addi	t1, x0, W_CODE
	beq	t0, t1, PARTY_MOVE_UP	# if key pressed was W, move party selection up
	addi	t1, x0, SPACE_CODE
	beq	t0, t1, MENU_START	# if key pressed was space, go to menu page
	j	PARTY_PAGE
PARTY_MOVE_DOWN:
	la	t0, PARTY_IND		# get party index address
	lb	t1, 0(t0)		# get party index
	addi	t1, t1, -1		# move index down (decrease by 1)
	# check for overflow
	bgtz	t1, PARTY_MOVE_END	# index still >0 - skip
	addi	t1, x0, PARTY_SIZE	# index too low - set back to party size for first index
	j	PARTY_MOVE_END
PARTY_MOVE_UP:
	la	t0, PARTY_IND		# get party index address
	lb	t1, 0(t0)		# get party index
	addi	t1, t1, 1		# move index down (decrease by 1)
	# check for overflow
	addi	t2, x0, PARTY_SIZE
	ble	t1, t2, PARTY_MOVE_END	# index still <= PARTY_SIZE - skip
	addi	t1, x0, 1		# index too low - set back to party size for first index
	j	PARTY_MOVE_END
PARTY_MOVE_END:
	sb	t1, 0(t0)		# store new index
	j	PARTY_UPDATE
	
                
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
	beq	t2, t5, DP_OR_UP	# player orientation up
	addi	t5, t5, 1
	beq	t2, t5, DP_OR_LEFT	# player orientation left
	addi	t5, t5, 1
	beq	t2, t5, DP_OR_RIGHT	# player orientation right
DP_OR_DOWN:
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
	j	DP_OR_END
DP_OR_UP:
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
	j	DP_OR_END
DP_OR_LEFT:
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
	j	DP_OR_END
DP_OR_RIGHT:
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
	j	DP_OR_END
DP_OR_END:
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
	bge	t0, t2, DW_OFFSET_MAX_Y	# if diff is greater than that^, pointer offset is that^. start each col such that last tile in col on screen is last tile in col of world
	
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
	addi	t0, x0, ' '
	beq	a2, t0, DL_SPACE	# ascii space
	addi	t0, x0, 'A'
	beq	a2, t0, DL_A		# ascii 'A'
	addi	t0, x0, 'B'
	beq	a2, t0, DL_B		# ascii 'B'
	addi	t0, x0, 'C'
	beq	a2, t0, DL_C		# ascii 'C'
	addi	t0, x0, 'D'
	beq	a2, t0, DL_D		# ascii 'D'
	addi	t0, x0, 'E'
	beq 	a2, t0, DL_E		# ascii 'E'
	addi	t0, x0, 'F'
	beq	a2, t0, DL_F		# ascii 'F'
	addi	t0, x0, 'G'
	beq	a2, t0, DL_G		# ascii 'G'
	addi	t0, x0, 'H'
	beq 	a2, t0, DL_H		# ascii 'H'
	addi	t0, x0, 'I'
	beq 	a2, t0, DL_I		# ascii 'I'
	addi	t0, x0, 'J'
	beq 	a2, t0, DL_J		# ascii 'J'
	addi	t0, x0, 'K'
	beq 	a2, t0, DL_K		# ascii 'K'
	addi	t0, x0, 'L'
	beq 	a2, t0, DL_L		# ascii 'L'
	addi	t0, x0, 'M'
	beq 	a2, t0, DL_M		# ascii 'M'
	addi	t0, x0, 'N'
	beq 	a2, t0, DL_N		# ascii 'N'
	addi	t0, x0, 'O'
	beq 	a2, t0, DL_O		# ascii 'O'
	addi	t0, x0, 'P'
	beq 	a2, t0, DL_P		# ascii 'P'
	addi	t0, x0, 'Q'
	beq 	a2, t0, DL_Q		# ascii 'Q'
	addi	t0, x0, 'R'
	beq 	a2, t0, DL_R		# ascii 'R'
	addi	t0, x0, 'S'
	beq 	a2, t0, DL_S		# ascii 'S'
	addi	t0, x0, 'T'
	beq 	a2, t0, DL_T		# ascii 'T'
	addi	t0, x0, 'U'
	beq 	a2, t0, DL_U		# ascii 'U'
	addi	t0, x0, 'V'
	beq 	a2, t0, DL_V		# ascii 'V'
	addi	t0, x0, 'W'
	beq 	a2, t0, DL_W		# ascii 'W'
	addi	t0, x0, 'X'
	beq 	a2, t0, DL_X		# ascii 'X'
	addi	t0, x0, 'Y'
	beq 	a2, t0, DL_Y		# ascii 'Y'
	addi	t0, x0, 'Z'
	beq 	a2, t0, DL_Z		# ascii 'Z'
	addi	t0, x0, '0'
	beq 	a2, t0, DL_0		# ascii '0'
	addi	t0, x0, '1'
	beq 	a2, t0, DL_1		# ascii '1'
	addi	t0, x0, '2'
	beq 	a2, t0, DL_2		# ascii '2'
	addi	t0, x0, '3'
	beq 	a2, t0, DL_3		# ascii '3'
	addi	t0, x0, '4'
	beq 	a2, t0, DL_4		# ascii '4'
	addi	t0, x0, '5'
	beq 	a2, t0, DL_5		# ascii '5'
	addi	t0, x0, '6'
	beq 	a2, t0, DL_6		# ascii '6'
	addi	t0, x0, '7'
	beq 	a2, t0, DL_7		# ascii '7'
	addi	t0, x0, '8'
	beq 	a2, t0, DL_8		# ascii '8'
	addi	t0, x0, '9'
	beq 	a2, t0, DL_9		# ascii '9'
	addi	t0, x0, '.'
	beq	a2, t0, DL_PERIOD	# ascii '.'
	addi	t0, x0, ','
	beq	a2, t0, DL_COMMA	# ascii ','
	addi	t0, x0, '!'
	beq	a2, t0, DL_EXCLAM	# ascii '!'
	addi	t0, x0, '?'
	beq	a2, t0, DL_QUEST	# ascii '?'
	j	DL_UNKNOWN		# unimplemented ascii
DL_SPACE:
	# set t0 to horiz length of this char in pixels + 1
	addi	t0, x0, 6
	j	DL_END
DL_A:
	# draw max 5x5 A
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
	call	DRAW_VERT_LINE
	
	addi	a0, t2, 1
	addi	a1, t3, 2
	addi	a2, a0, 2
	call	DRAW_HORIZ_LINE
	
	# set t0 to horiz length of this char in pixels + 1
	addi	t0, x0, 6
	j	DL_END
DL_B:
	# draw max 5x5 B
	addi	a2, a1, 4
	call	DRAW_VERT_LINE
	
	addi	a0, t2, 1
	mv	a1, t3
	addi	a2, a0, 2
	call	DRAW_HORIZ_LINE
	
	addi	a0, t2, 1
	addi	a1, t3, 2
	addi	a2, a0, 2
	call	DRAW_HORIZ_LINE
	
	addi	a0, t2, 1
	addi	a1, t3, 4
	addi	a2, a0, 2
	call	DRAW_HORIZ_LINE
	
	addi	a0, t2, 4
	addi	a1, t3, 1
	call	DRAW_DOT
	
	addi	a0, t2, 4
	addi	a1, t3, 3
	call	DRAW_DOT
	
	# set t0 to horiz length of this char in pixels + 1
	addi	t0, x0, 6
	j	DL_END
DL_C:
	# draw max 5x5 C
	addi	a1, a1, 1
	addi	a2, a1, 2
	call	DRAW_VERT_LINE
	
	addi	a0, t2, 1
	mv	a1, t3
	addi	a2, a0, 2
	call	DRAW_HORIZ_LINE
	
	addi	a0, t2, 1
	addi	a1, t3, 4
	addi	a2, a0, 2
	call	DRAW_HORIZ_LINE
	
	addi	a0, t2, 4
	addi	a1, t3, 1
	call	DRAW_DOT
	
	addi	a1, t3, 3
	call	DRAW_DOT
	
	# set t0 to horiz length of this char in pixels + 1
	addi	t0, x0, 6
	j	DL_END
DL_D:
	# draw max 5x5 D
	addi	a2, a1, 4
	call	DRAW_VERT_LINE
	
	addi	a0, t2, 1
	mv	a1, t3
	addi	a2, a0, 2
	call	DRAW_HORIZ_LINE
	
	addi	a0, t2, 1
	addi	a1, t3, 4
	addi	a2, a0, 2
	call	DRAW_HORIZ_LINE
	
	addi	a0, t2, 4
	addi	a1, t3, 1
	addi	a2, a1, 2
	call	DRAW_VERT_LINE
	
	# set t0 to horiz length of this char in pixels + 1
	addi	t0, x0, 6
	j	DL_END
DL_E:
	# draw max 5x5 E
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
	
	# set t0 to horiz length of this char in pixels + 1
	addi	t0, x0, 6
	j	DL_END
DL_F:
	# draw max 5x5 F
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
	
	# set t0 to horiz length of this char in pixels + 1
	addi	t0, x0, 6
	j	DL_END
DL_G:	
	# draw max 5x5 G
	addi	a0, a0, 1
	addi	a2, a0, 2
	call	DRAW_HORIZ_LINE
	
	mv	a0, t2
	addi	a1, t3, 1
	addi	a2, a1, 2
	call	DRAW_VERT_LINE
	
	addi	a0, t2, 1
	addi	a1, t3, 4
	addi	a2, a0, 2
	call	DRAW_HORIZ_LINE
	
	addi	a0, t2, 4
	addi	a1, t3, 2
	addi	a2, a1, 1
	call	DRAW_VERT_LINE
	
	addi	a0, t2, 3
	addi	a1, t3, 2
	call	DRAW_DOT
	
	# set t0 to horiz length of this char in pixels + 1
	addi	t0, x0, 6	
	j DL_END
DL_H:
	# draw max 5x5 H
	addi	a2, a1, 4
	call	DRAW_VERT_LINE
	
	addi	a0, t2, 1
	addi	a1, t3, 2
	addi	a2, a0, 2
	call	DRAW_HORIZ_LINE
	
	addi	a0, t2, 4
	mv	a1, t3
	addi	a2, a1, 4
	call	DRAW_VERT_LINE
	
	# set t0 to horiz length of this char in pixels + 1
	addi	t0, x0, 6
	j	DL_END
DL_I:
	# draw max 5x5 I
	addi	a2, a0, 2
	call	DRAW_HORIZ_LINE
	
	addi	a0, t2, 1
	mv	a1, t3
	addi	a2, a1, 3
	call	DRAW_VERT_LINE
	
	mv	a0, t2
	addi	a1, t3, 4
	addi	a2, a0, 2
	call	DRAW_HORIZ_LINE
	
	# set t0 to horiz length of this char in pixels + 1
	addi	t0, x0, 4
	j	DL_END
DL_J:
	# draw max 5x5 J
	addi	a0, a0, 1
	addi	a2, a0, 3
	call	DRAW_HORIZ_LINE
	
	addi	a0, t2, 3
	mv	a1, t3
	addi	a2, a1, 3
	call	DRAW_VERT_LINE
	
	addi	a0, t2, 1
	addi	a1, t3, 4
	addi	a2, a0, 1
	call	DRAW_HORIZ_LINE
	
	addi	a0, t2, 0
	addi	a1, t3, 3
	call	DRAW_DOT
	
	# set t0 to horiz length of this char in pixels + 1
	addi	t0, x0, 6
	j	DL_END
DL_K:
	# draw max 5x5 K
	addi	a2, a1, 4
	call	DRAW_VERT_LINE
	
	addi	a0, t2, 1
	addi	a1, t3, 2
	call	DRAW_DOT
	
	addi	a0, t2, 2
	addi	a1, t3, 1
	call	DRAW_DOT
	
	addi	a0, t2, 3
	mv	a1, t3
	call	DRAW_DOT
	
	addi	a0, t2, 2
	addi	a1, t3, 3
	call	DRAW_DOT
	
	addi	a0, t2, 3
	addi	a1, t3, 4
	call	DRAW_DOT
	
	# set t0 to horiz length of this char in pixels + 1
	addi	t0, x0, 5
	j	DL_END
DL_L:
	# draw max 5x5 L
	addi	a2, a1, 4
	call	DRAW_VERT_LINE
	
	addi	a0, t2, 1
	addi	a1, t3, 4
	addi	a2, a0, 2
	call	DRAW_HORIZ_LINE
	
	# set t0 to horiz length of this char in pixels + 1
	addi	t0, x0, 5
	j	DL_END
DL_M:
	# draw max 5x5 M
	addi	a2, a1, 4
	call	DRAW_VERT_LINE
	
	addi	a0, t2, 1
	addi	a1, t3, 1
	call	DRAW_DOT
	
	addi	a0, t2, 2
	addi	a1, t3, 2
	call	DRAW_DOT
	
	addi	a0, t2, 3
	addi	a1, t3, 1
	call	DRAW_DOT
	
	addi	a0, t2, 4
	mv	a1, t3
	addi	a2, a1, 4
	call	DRAW_VERT_LINE
	
	# set t0 to horiz length of this char in pixels + 1
	addi	t0, x0, 6
	j	DL_END
DL_N:
	# draw max 5x5 N
	addi	a2, a1, 4
	call	DRAW_VERT_LINE
	
	addi	a0, t2, 1
	addi	a1, t3, 1
	call	DRAW_DOT
	
	addi	a0, t2, 2
	addi	a1, t3, 2
	call	DRAW_DOT
	
	addi	a0, t2, 3
	addi	a1, t3, 3
	call	DRAW_DOT
	
	addi	a0, t2, 4
	mv	a1, t3
	addi	a2, a1, 4
	call	DRAW_VERT_LINE
	
	# set t0 to horiz length of this char in pixels + 1
	addi	t0, x0, 6
	j	DL_END
DL_O:
	# draw max 5x5 O
	addi	a1, a1, 1
	addi	a2, a1, 2
	call	DRAW_VERT_LINE
	
	addi	a0, t2, 1
	mv	a1, t3
	addi	a2, a0, 2
	call	DRAW_HORIZ_LINE
	
	addi	a0, t2, 4
	addi	a1, t3, 1
	addi	a2, a1, 2
	call	DRAW_VERT_LINE
	
	addi	a0, t2, 1
	addi	a1, t3, 4
	addi	a2, a0, 2
	call	DRAW_HORIZ_LINE
	
	
	# set t0 to horiz length of this char in pixels + 1
	addi	t0, x0, 6
	j	DL_END
DL_P:
	# draw max 5x5 P
	addi	a2, a1, 4
	call	DRAW_VERT_LINE
	
	addi	a0, t2, 1
	mv	a1, t3
	addi	a2, a0, 2
	call	DRAW_HORIZ_LINE
	
	addi	a0, t2, 1
	addi	a1, t3, 2
	addi	a2, a0, 2
	call	DRAW_HORIZ_LINE
	
	addi	a0, t2, 4
	addi	a1, t3, 1
	call	DRAW_DOT
	
	# set t0 to horiz length of this char in pixels + 1
	addi	t0, x0, 6
	j	DL_END
DL_Q:
	# draw 5x5 Q
	addi	a1, a1, 1
	addi	a2, a1, 2
	call	DRAW_VERT_LINE
	
	addi	a0, t2, 1
	mv	a1, t3
	addi	a2, a0, 2
	call	DRAW_HORIZ_LINE
	
	addi	a0, t2, 4
	addi	a1, t3, 1
	addi	a2, a1, 1
	call	DRAW_VERT_LINE
	
	addi	a0, t2, 1
	addi	a1, t3, 4
	addi	a2, a0, 1
	call	DRAW_HORIZ_LINE
	
	addi	a0, t2, 3
	addi	a1, t3, 3
	call	DRAW_DOT
	
	addi	a0, t2, 4
	addi	a1, t3, 4
	call	DRAW_DOT
	
	# set t0 to horiz length of this char in pixels + 1
	addi	t0, x0, 6
	j	DL_END
DL_R:
	# draw max 5x5 R
	addi	a2, a1, 4
	call	DRAW_VERT_LINE
	
	addi	a0, t2, 1
	mv	a1, t3
	addi	a2, a0, 2
	call	DRAW_HORIZ_LINE
	
	addi	a0, t2, 1
	addi	a1, t3, 2
	addi	a2, a0, 2
	call	DRAW_HORIZ_LINE
	
	addi	a0, t2, 4
	addi	a1, t3, 1
	call	DRAW_DOT
	
	addi	a0, t2, 4
	addi	a1, t3, 3
	addi	a2, a1, 1
	call	DRAW_VERT_LINE
	
	# set t0 to horiz length of this char in pixels + 1
	addi	t0, x0, 6
	j	DL_END
DL_S:
	# draw max 5x5 S
	addi	a0, t2, 1
	addi	a2, a0, 3
	call	DRAW_HORIZ_LINE
	
	mv	a0, t2
	addi	a1, t3, 1
	call	DRAW_DOT
	
	addi	a0, t2, 1
	addi	a1, t3, 2
	addi	a2, a0, 2
	call	DRAW_HORIZ_LINE
	
	addi	a0, t2, 4
	addi	a1, t3, 3
	call	DRAW_DOT
	
	mv	a0, t2
	addi	a1, t3, 4
	addi	a2, a0, 3
	call	DRAW_HORIZ_LINE
	
	# set t0 to horiz length of this char in pixels + 1
	addi	t0, x0, 6
	j	DL_END
DL_T:
	# draw max 5x5 T
	addi	a2, a0, 4
	call	DRAW_HORIZ_LINE
	
	addi	a0, t2, 2
	addi	a1, t3, 1
	addi	a2, a1, 3
	call	DRAW_VERT_LINE
	
	# set t0 to horiz length of this char in pixels + 1
	addi	t0, x0, 6
	j	DL_END
DL_U:
	# draw max 5x5 U
	addi	a2, a1, 3
	call	DRAW_VERT_LINE
	
	addi	a0, t2, 1
	addi	a1, t3, 4
	addi	a2, a0, 2
	call	DRAW_HORIZ_LINE
	
	addi	a0, t2, 4
	mv	a1, t3
	addi	a2, a1, 3
	call	DRAW_VERT_LINE
	
	# set t0 to horiz length of this char in pixels + 1
	addi	t0, x0, 6
	j	DL_END
DL_V:
	# draw max 5x5 V
	addi	a2, a1, 1
	call	DRAW_VERT_LINE
	
	addi	a0, t2, 1
	addi	a1, t3, 2
	addi	a2, a1, 1
	call	DRAW_VERT_LINE
	
	addi	a0, t2, 2
	addi	a1, t3, 4
	call	DRAW_DOT
	
	addi	a0, t2, 4
	mv	a1, t3
	addi	a2, a1, 1
	call	DRAW_VERT_LINE
	
	addi	a0, t2, 3
	addi	a1, t3, 2
	addi	a2, a1, 1
	call	DRAW_VERT_LINE
	
	# set t0 to horiz length of this char in pixels + 1
	addi	t0, x0, 6
	j	DL_END
DL_W:
	# draw max 5x5 W
	addi	a2, a1, 4
	call	DRAW_VERT_LINE
	
	addi	a0, t2, 1
	addi	a1, t3, 3
	call	DRAW_DOT
	
	addi	a0, t2, 2
	addi	a1, t3, 2
	call	DRAW_DOT
	
	addi	a0, t2, 3
	addi	a1, t3, 3
	call	DRAW_DOT
	
	addi	a0, t2, 4
	mv	a1, t3
	addi	a2, a1, 4
	call	DRAW_VERT_LINE
	
	# set t0 to horiz length of this char in pixels + 1
	addi	t0, x0, 6
	j	DL_END
DL_X:
	# draw max 5x5 X
	call	DRAW_DOT
	
	addi 	a0, a0, 1
	addi	a1, a1, 1
	call	DRAW_DOT
	
	addi 	a0, a0, 1
	addi	a1, a1, 1
	call	DRAW_DOT
	
	addi 	a0, a0, 1
	addi	a1, a1, 1
	call	DRAW_DOT
	
	addi 	a0, a0, 1
	addi	a1, a1, 1
	call	DRAW_DOT
	
	addi 	a0, t2, 3
	addi	a1, t3, 1
	call	DRAW_DOT
	
	addi 	a0, t2, 4
	addi	a1, t3, 0
	call	DRAW_DOT
	
	addi 	a0, t2, 1
	addi	a1, t3, 3
	call	DRAW_DOT
	
	addi 	a0, t2, 0
	addi	a1, t3, 4
	call	DRAW_DOT
	
	# set t0 to horiz length of this char in pixels + 1
	addi	t0, x0, 6
	j	DL_END
DL_Y:
	# draw max 5x5 Y
	call	DRAW_DOT
	
	addi 	a0, a0, 1
	addi	a1, a1, 1
	call	DRAW_DOT
	
	addi 	a0, t2, 3
	addi	a1, t3, 1
	call	DRAW_DOT
	
	addi 	a0, t2, 4
	addi	a1, t3, 0
	call	DRAW_DOT
	
	addi	a0, t2, 2
	addi	a1, t3, 2
	addi	a2, a1, 2
	call	DRAW_VERT_LINE
	
	# set t0 to horiz length of this char in pixels + 1
	addi	t0, x0, 6
	j	DL_END
DL_Z:
	# draw max 5x5 Z
	addi	a2, a0, 4
	call	DRAW_HORIZ_LINE
	
	addi	a0, t2, 3
	addi	a1, t3, 1
	call	DRAW_DOT
	
	addi	a0, t2, 2
	addi	a1, t3, 2
	call	DRAW_DOT
	
	addi	a0, t2, 1
	addi	a1, t3, 3
	call	DRAW_DOT
	
	mv	a0, t2
	addi	a1, t3, 4
	addi	a2, a0, 4
	call	DRAW_HORIZ_LINE
	
	# set t0 to horiz length of this char in pixels + 1
	addi	t0, x0, 6
	j	DL_END
DL_PERIOD:
	# draw max 5x5 .
	addi	a1, a1, 4
	call	DRAW_DOT
	
	# set t0 to horiz length of this char in pixels + 1
	addi	t0, x0, 2
	j	DL_END
DL_COMMA:
	# draw max 5x5 ,
	addi	a1, a1, 4
	call	DRAW_DOT
	addi	a0, t2, 1
	addi	a1, t3, 3
	call	DRAW_DOT
	
	# set t0 to horiz length of this char in pixels + 1
	addi	t0, x0, 3
	j	DL_END
DL_EXCLAM:
	# draw max 5x5 !
	addi	a2, a1, 2
	call	DRAW_VERT_LINE
	
	addi	a1, t3, 4
	call	DRAW_DOT
	
	# set t0 to horiz length of this char in pixels + 1
	addi	t0, x0, 2
	j	DL_END
DL_QUEST:
	# draw max 5x5 ?
	addi	a1, a1, 1
	call	DRAW_DOT
	
	addi	a0, t2, 1
	mv	a1, t3
	addi	a2, a0, 2
	call	DRAW_HORIZ_LINE
	
	addi	a0, t2, 4
	addi	a1, t3, 1
	call	DRAW_DOT
	
	addi	a0, t2, 2
	addi	a1, t3, 2
	addi	a2, a0, 1
	call	DRAW_HORIZ_LINE
	
	addi	a0, t2, 2
	addi	a1, t3, 4
	call	DRAW_DOT
	
	# set t0 to horiz length of this char in pixels + 1
	addi	t0, x0, 6
	j	DL_END
DL_0:
	# draw max 5x5 0
	addi	a0, a0, 1
	addi	a2, a0, 1
	call	DRAW_HORIZ_LINE
	
	mv	a0, t2
	addi	a1, t3, 1
	addi	a2, a1, 2
	call	DRAW_VERT_LINE
	
	addi	a0, t2, 3
	addi	a1, t3, 1
	addi	a2, a1, 2
	call	DRAW_VERT_LINE
	
	addi	a0, t2, 1
	addi	a1, t3, 4
	addi	a2, a0, 1
	call	DRAW_HORIZ_LINE
	
	# set t0 to horiz length of this char in pixels + 1
	addi	t0, x0, 5
	j	DL_END
DL_1:
	# draw max 5x5 1
	addi	a0, a0, 1
	addi	a2, a1, 3
	call	DRAW_VERT_LINE
	
	mv	a0, t2
	addi	a1, t3, 4
	addi	a2, a0, 2
	call	DRAW_HORIZ_LINE
	
	mv	a0, t2
	addi	a1, t3, 1
	call	DRAW_DOT
	
	# set t0 to horiz length of this char in pixels + 1
	addi	t0, x0, 4
	j	DL_END
DL_2:
	# draw max 5x5 2
	addi	a1, a1, 1
	call	DRAW_DOT
	
	addi	a0, t2, 1
	mv	a1, t3
	addi	a2, a0, 1
	call	DRAW_HORIZ_LINE
	
	addi	a0, t2, 3
	addi	a1, t3, 1
	call	DRAW_DOT
	
	addi	a0, t2, 2
	addi	a1, t3, 2
	call	DRAW_DOT
	
	addi	a0, t2, 1
	addi	a1, t3, 3
	call	DRAW_DOT
	
	mv 	a0, t2
	addi	a1, t3, 4
	addi	a2, a0, 3
	call	DRAW_HORIZ_LINE
	
	# set t0 to horiz length of this char in pixels + 1
	addi	t0, x0, 5
	j	DL_END
DL_3:
	# draw max 5x5 3
	addi	a1, a1, 1
	call	DRAW_DOT

	addi	a0, t2, 1
	mv	a1, t3
	addi	a2, a0, 1
	call	DRAW_HORIZ_LINE
	
	addi	a0, t2, 3
	addi	a1, t3, 1
	call	DRAW_DOT
	
	addi	a0, t2, 2
	addi	a1, t3, 2
	call	DRAW_DOT
	
	addi	a0, t2, 3
	addi	a1, t3, 3
	call	DRAW_DOT
	
	addi	a0, t2, 1
	addi	a1, t3, 4
	addi	a2, a0, 1
	call	DRAW_HORIZ_LINE
	
	mv	a0, t2
	addi	a1, t3, 3
	call	DRAW_DOT
	
	# set t0 to horiz length of this char in pixels + 1
	addi	t0, x0, 5
	j	DL_END
DL_4:
	# draw max 5x5 4
	addi	a2, a1, 1
	call	DRAW_VERT_LINE
	
	addi	a0, t2, 3
	mv	a1, t3
	addi	a2, a1, 4
	call	DRAW_VERT_LINE
	
	mv	a0, t2
	addi	a1, t3, 2
	addi	a2, a0, 2
	call	DRAW_HORIZ_LINE
	
	# set t0 to horiz length of this char in pixels + 1
	addi	t0, x0, 5
	j	DL_END
DL_5:
	# draw max 5x5 5
	addi	a2, a0, 3
	call	DRAW_HORIZ_LINE
	
	mv	a0, t2
	addi	a1, t3, 1
	addi	a2, a1, 1
	call	DRAW_VERT_LINE
	
	addi	a0, t2, 1
	addi	a1, t3, 2
	addi	a2, a0, 1
	call	DRAW_HORIZ_LINE
	
	addi	a0, t2, 3
	addi	a1, t3, 3
	call	DRAW_DOT
	
	mv	a0, t2
	addi	a1, t3, 4
	addi	a2, a0, 2
	call	DRAW_HORIZ_LINE
	
	# set t0 to horiz length of this char in pixels + 1
	addi	t0, x0, 5
	j	DL_END
DL_6:
	# draw max 5x5 6
	addi	a0, a0, 1
	addi	a2, a0, 1
	call	DRAW_HORIZ_LINE
	
	mv	a0, t2
	addi	a1, t3, 1
	addi	a2, a1, 2
	call	DRAW_VERT_LINE
	
	addi	a0, t2, 1
	addi	a1, t3, 2
	addi	a2, a0, 1
	call	DRAW_HORIZ_LINE
	
	addi	a0, t2, 3
	addi	a1, t3, 3
	call	DRAW_DOT
	
	addi	a0, t2, 1
	addi	a1, t3, 4
	addi	a2, a0, 1
	call	DRAW_HORIZ_LINE
	
	# set t0 to horiz length of this char in pixels + 1
	addi	t0, x0, 5
	j	DL_END
DL_7:
	# draw max 5x5 7
	addi	a2, a0, 3
	call	DRAW_HORIZ_LINE
	
	addi	a0, t2, 3
	addi	a1, t3, 1
	call	DRAW_DOT
	
	addi	a0, t2, 2
	addi	a1, t3, 2
	call	DRAW_DOT
	
	addi	a0, t2, 1
	addi	a1, t3, 3
	addi	a2, a1, 1
	call	DRAW_VERT_LINE
	
	# set t0 to horiz length of this char in pixels + 1
	addi	t0, x0, 5
	j	DL_END
DL_8:
	# draw max 5x5 8
	addi	a0, a0, 1
	addi	a2, a0, 1
	call	DRAW_HORIZ_LINE
	
	mv	a0, t2
	addi	a1, t3, 1
	call	DRAW_DOT
	
	addi	a0, t2, 3
	call	DRAW_DOT
	
	addi	a0, t2, 1
	addi	a1, t3, 2
	addi	a2, a0, 1
	call	DRAW_HORIZ_LINE
	
	mv	a0, t2
	addi	a1, t3, 3
	call	DRAW_DOT
	
	addi	a0, t2, 3
	call	DRAW_DOT
	
	addi	a0, t2, 1
	addi	a1, t3, 4
	addi	a2, a0, 1
	call	DRAW_HORIZ_LINE
	
	# set t0 to horiz length of this char in pixels + 1
	addi	t0, x0, 5
	j	DL_END
DL_9:
	# draw max 5x5 9
	addi	a0, a0, 1
	addi	a2, a0, 1
	call	DRAW_HORIZ_LINE
	
	mv	a0, t2
	addi	a1, t3, 1
	call	DRAW_DOT
	
	addi	a0, t2, 1
	addi	a1, t3, 2
	addi	a2, a0, 1
	call	DRAW_HORIZ_LINE
	
	addi	a0, t2, 3
	addi	a1, t3, 1
	addi	a2, a1, 2
	call	DRAW_VERT_LINE
	
	addi	a0, t2, 1
	addi	a1, t3, 4
	addi	a2, a0, 1
	call	DRAW_HORIZ_LINE
	
	# set t0 to horiz length of this char in pixels + 1
	addi	t0, x0, 5
	j	DL_END
DL_UNKNOWN:
	# draw 5x5 square for unimplemented ascii symbols
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
	
	# set t0 to horiz length of this char in pixels + 1
	addi	t0, x0, 6
	j	DL_END
DL_END:
	# set arg registers to topleft of where next character would be
	add	a0, t2, t0
	mv	a1, t3
	
	lw	ra, 0(sp)
	addi	sp, sp, 4
	ret
	
# draws string of 5x5 characters starting with top left at coords given by x from a0, and y from a1
# with color given by a3 and byte array address given by a2
# modifies t0, t1, t2, t3, t4, a0, a1, a2
DRAW_STRING:
	addi	sp, sp, -4
	sw	ra, 0(sp)
	
	mv	t4, a2			# save address in t4 because a2 is used in DRAW_LETTER
DS_LOOP:
	lb	a2, 0(t4)		# get char from string
        beqz	a2, DS_END		# if terminating 0, done with string
        call	DRAW_LETTER		# draw current letter
        addi	t4, t4, 1		# go to next index of string
        
        # check if need to go to new line
        addi	t0, a0, L_SIZE
        addi	t0, t0, -WIDTH
        bltz	t0, DS_LOOP		# if end of next char is offscreen, go to next line
        addi	a0, x0, L_SIZE		# reset x
        addi	a1, a1, L_SIZE		# go to next line y
        addi	a1, a1, 1
        addi	t0, a1, L_SIZE
        addi	t0, t0, -HEIGHT
        bltz	t0, DS_LOOP		# if bottom of next char is offscreen, end

DS_END:
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
	
# loads all data into data segment that needs to be preset
# # load title string
# # loads button colors into menu array
# # loads tile codes into ALL_TILES array for world
# # should be called in initialization of world page (WORLD_START)
# # modifies t0, t1, t2
LOAD_DATA:
	addi	sp, sp, -4
	sw	ra, 0(sp)
	
	# load title string
	la	t0, TITLE_STR
	
	# show all letters
	addi	t1, x0, 'A'
	addi	t2, t0, 26
LD_TITLE_LOOP:
	sb	t1, 0(t0)
	addi	t0, t0, 1
	addi	t1, t1, 1
	blt	t0, t2, LD_TITLE_LOOP
	
	addi	t1, x0, ' '
	sb	t1, 0(t0)
	addi	t0, t0, 1
	
	# show all numbers
	addi	t2, t0, 10
	addi	t1, x0, '0'
LD_TITLE_LOOP_2:
	sb	t1, 0(t0)
	addi	t0, t0, 1
	addi	t1, t1, 1
	blt	t0, t2, LD_TITLE_LOOP_2
	
	# show punctuation and unknown
	addi	t1, x0, '.'
	sb	t1, 0(t0)
	addi	t1, x0, ','
	sb	t1, 1(t0)
	addi	t1, x0, '!'
	sb	t1, 2(t0)
	addi	t1, x0, '?'
	sb	t1, 3(t0)
	addi	t1, x0, 'a'		# for unknown char
	sb	t1, 4(t0)

	sb	x0, 5(t0)		# last character in array is intentionally left 0 as terminator
	
	# load menu string
	la	t0, MENU_STR
	addi	t1, x0, 'M'
	sb	t1, 0(t0)
	addi	t1, x0, 'E'
	sb	t1, 1(t0)
	addi	t1, x0, 'N'
	sb	t1, 2(t0)
	addi	t1, x0, 'U'
	sb	t1, 3(t0)
	sb	x0, 4(t0)		# last character in array is intentionally left 0 as terminator
	
	# load party string
	la	t0, PARTY_STR
	addi	t1, x0, 'P'
	sb	t1, 0(t0)
	addi	t1, x0, 'A'
	sb	t1, 1(t0)
	addi	t1, x0, 'R'
	sb	t1, 2(t0)
	addi	t1, x0, 'T'
	sb	t1, 3(t0)
	addi	t1, x0, 'Y'
	sb	t1, 4(t0)
	sb	x0, 5(t0)		# last character in array is intentionally left 0 as terminator
	
	# load boxes string
	la	t0, BOXES_STR
	addi	t1, x0, 'B'
	sb	t1, 0(t0)
	addi	t1, x0, 'O'
	sb	t1, 1(t0)
	addi	t1, x0, 'X'
	sb	t1, 2(t0)
	addi	t1, x0, 'E'
	sb	t1, 3(t0)
	addi	t1, x0, 'S'
	sb	t1, 4(t0)
	sb	x0, 5(t0)		# last character in array is intentionally left 0 as terminator
	
	# load menu button colors
	la	t0, MENU_ARR
	addi	t0, t0, 2		# get address of first color, after bytes reserved for button index
	
	# store color bytes in array
	addi	t1, x0, RED		# dex
	sb	t1, 0(t0)
	addi	t0, t0, 1
	addi	t1, x0, MAGENTA		# party
	sb	t1, 0(t0)
	addi	t0, t0, 1
	addi	t1, x0, ORANGE		# bag
	sb	t1, 0(t0)
	addi	t0, t0, 1
	addi	t1, x0, CYAN		# save
	sb	t1, 0(t0)
	addi	t0, t0, 1
	addi	t1, x0, GREEN		# map
	sb	t1, 0(t0)
	addi	t0, t0, 1
	addi	t1, x0, BLUE		# player info
	sb	t1, 0(t0)
	addi	t0, t0, 1
	addi	t1, x0, YELLOW		# battle
	sb	t1, 0(t0)
	addi	t0, t0, 1
	addi	t1, x0, PURPLE		# settings
	sb	t1, 0(t0)
	
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
