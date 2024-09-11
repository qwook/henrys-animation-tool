
-- you know I could probably use garry's default skinning system for this
-- but whatever

-- you might be wondering why I'm using an image for the text
-- it's because I wanted the cool nifty things like glow and shadow
-- and plus the mac version of gmod doesn't render some fonts correctly

local hatUI = hatUI
local uiW = 512
local uiH = 256
local white = Color( 255, 255, 255 )

hatskin = {}
hatskin.sprite = {}

function hatskin.createSprite( sx, sy, sw, sh )
	return function( x, y, w, h, col )
		surface.SetMaterial( hatUI )
		surface.SetDrawColor( col or white )
		surface.DrawTexturedRectUV( x, y, w, h, sx / uiW, sy / uiH, sw / uiW, sh / uiH )
	end
end

hatskin.sprite.Header = hatskin.createSprite( 0, 0, 127, 19 )
hatskin.sprite.frameL = hatskin.createSprite( 1, 21, 2, 155 )
hatskin.sprite.frameM = hatskin.createSprite( 4, 21, 5, 155 )
hatskin.sprite.frameR = hatskin.createSprite( 5, 21, 6, 155 )

hatskin.sprite.frameHolderL = hatskin.createSprite( 9, 21, 17, 80 )
hatskin.sprite.frameHolderM = hatskin.createSprite( 18, 21, 19, 80 )
hatskin.sprite.frameHolderR = hatskin.createSprite( 19, 21, 28, 80 )

hatskin.sprite.scrollBarL = hatskin.createSprite( 54, 21, 58, 33 )
hatskin.sprite.scrollBarM = hatskin.createSprite( 60, 21, 60, 33 )
hatskin.sprite.scrollBarR = hatskin.createSprite( 72, 21, 76, 33 )

hatskin.sprite.buttonHoverL = hatskin.createSprite( 78, 61, 82, 99 )
hatskin.sprite.buttonHoverM = hatskin.createSprite( 83, 61, 83, 99 )
hatskin.sprite.buttonHoverR = hatskin.createSprite( 169, 61, 172, 99 )

hatskin.sprite.buttonDepressedL = hatskin.createSprite( 78, 101, 82, 139 )
hatskin.sprite.buttonDepressedM = hatskin.createSprite( 83, 101, 83, 139 )
hatskin.sprite.buttonDepressedR = hatskin.createSprite( 169, 101, 172, 139 )

hatskin.sprite.record = hatskin.createSprite( 81, 29, 170, 54 )
hatskin.sprite.recordHovered = hatskin.createSprite( 81, 29 + 40, 170, 54 + 40 )
hatskin.sprite.recordDepressed = hatskin.createSprite( 81, 29 + 80, 170, 54 + 80 )

hatskin.sprite.play = hatskin.createSprite( 179, 29, 211, 54 )
hatskin.sprite.playHovered = hatskin.createSprite( 179, 29 + 40, 211, 54 + 40 )
hatskin.sprite.playDepressed = hatskin.createSprite( 179, 29 + 80, 211, 54 + 80 )

hatskin.sprite.stop = hatskin.createSprite( 224, 29, 260, 54 )
hatskin.sprite.stopHovered = hatskin.createSprite( 224, 29 + 40, 260, 54 + 40 )
hatskin.sprite.stopDepressed = hatskin.createSprite( 224, 29 + 80, 260, 54 + 80 )

hatskin.sprite.new = hatskin.createSprite( 273, 29, 350, 54 )
hatskin.sprite.newHovered = hatskin.createSprite( 273, 29 + 40, 350, 54 + 40 )
hatskin.sprite.newDepressed = hatskin.createSprite( 273, 29 + 80, 350, 54 + 80 )

function hatskin.drawFrame( x, y, w, h )
	hatskin.sprite.frameL( x, y, 1, 134 )
	hatskin.sprite.frameM( x + 1, y, w - 2, 134 )
	hatskin.sprite.frameR( w - 1, y, 1, 134 )
	hatskin.sprite.Header( x + 4, y + 5, 127, 19 )
end

function hatskin.drawFrameHolder( x, y, w, h )
	hatskin.sprite.frameHolderL( x, y, 8, 59 )
	hatskin.sprite.frameHolderM( x + 8, y, w - 16, 59 )
	hatskin.sprite.frameHolderR( w - 8, y, 8, 59 )
end

function hatskin.drawScrollBar( x, y, w, h )
	hatskin.sprite.scrollBarL( x, y, 4, 12 )
	hatskin.sprite.scrollBarM( x + 4, y, w - 8, 12 )
	hatskin.sprite.scrollBarR( w - 4, y, 4, 12 )
end

function hatskin.drawButton( depressed, hovered, w, h )
	if depressed then
		hatskin.sprite.buttonDepressedL( 0, 0, 4, 38 )
		hatskin.sprite.buttonDepressedM( 4, 0, w - 7, 38 )
		hatskin.sprite.buttonDepressedR( w - 3, 0, 3, 38 )
	elseif hovered then
		hatskin.sprite.buttonHoverL( 0, 0, 4, 38 )
		hatskin.sprite.buttonHoverM( 4, 0, w - 7, 38 )
		hatskin.sprite.buttonHoverR( w - 3, 0, 3, 38 )
	end
end

function hatskin.drawRecordButton( depressed, hovered )
	if depressed then
		hatskin.sprite.recordDepressed( 4, 8, 89, 25 )
	elseif hovered then
		hatskin.sprite.recordHovered( 4, 8, 89, 25 )
	else
		hatskin.sprite.record( 4, 8, 89, 25 )
	end
end

function hatskin.drawPlayButton( depressed, hovered )
	if depressed then
		hatskin.sprite.playDepressed( 4, 8, 32, 25 )
	elseif hovered then
		hatskin.sprite.playHovered( 4, 8, 32, 25 )
	else
		hatskin.sprite.play( 4, 8, 32, 25 )
	end
end

function hatskin.drawStopButton( depressed, hovered )
	if depressed then
		hatskin.sprite.stopDepressed( 4, 8, 36, 25 )
	elseif hovered then
		hatskin.sprite.stopHovered( 4, 8, 36, 25 )
	else
		hatskin.sprite.stop( 4, 8, 36, 25 )
	end
end

function hatskin.drawNewButton( depressed, hovered )
	if depressed then
		hatskin.sprite.newDepressed( 4, 8, 77, 25 )
	elseif hovered then
		hatskin.sprite.newHovered( 4, 8, 77, 25 )
	else
		hatskin.sprite.new( 4, 8, 77, 25 )
	end
end
