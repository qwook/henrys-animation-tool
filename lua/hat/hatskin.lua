-- Client-side custom skin: slices the hatUI sprite-sheet material into named draw functions
-- (hatskin.draw*) used by dhatmenu.lua and dframeholder.lua's Paint code.

-- you know I could probably use garry's default skinning system for this
-- but whatever

-- you might be wondering why I'm using an image for the text
-- it's because I wanted the cool nifty things like glow and shadow
-- and plus the mac version of gmod doesn't render some fonts correctly

surface.CreateFont("Arial18", {
	font = "Arial", -- On Windows/macOS, use the font-name which is shown to you by your operating system Font Viewer. On Linux, the font-name *may* work, but using the file name is more reliable
	extended = false,
	size = 18,
	weight = 100,
	blursize = 0,
	scanlines = 0,
	antialias = true,
	underline = false,
	italic = false,
	strikeout = false,
	symbol = false,
	rotary = false,
	shadow = false,
	additive = false,
	outline = false,
})

surface.CreateFont("Arial18Glow1", {
	font = "Arial", -- On Windows/macOS, use the font-name which is shown to you by your operating system Font Viewer. On Linux, the font-name *may* work, but using the file name is more reliable
	extended = false,
	size = 18,
	weight = 100,
	blursize = 1,
	scanlines = 0,
	antialias = true,
	underline = false,
	italic = false,
	strikeout = false,
	symbol = false,
	rotary = false,
	shadow = false,
	additive = false,
	outline = false,
})

surface.CreateFont("Arial18Glow2", {
	font = "Arial", -- On Windows/macOS, use the font-name which is shown to you by your operating system Font Viewer. On Linux, the font-name *may* work, but using the file name is more reliable
	extended = false,
	size = 18,
	weight = 100,
	blursize = 2,
	scanlines = 0,
	antialias = true,
	underline = false,
	italic = false,
	strikeout = false,
	symbol = false,
	rotary = false,
	shadow = false,
	additive = false,
	outline = false,
})


local hatUI = hatUI
local uiW = 512
local uiH = 256
local white = Color(255, 255, 255)

hatskin = {}
hatskin.sprite = {}

function hatskin.createSprite(sx, sy, sw, sh)
	return function(x, y, w, h, col)
		surface.SetMaterial(hatUI)
		surface.SetDrawColor(col or white)
		surface.DrawTexturedRectUV(x, y, w, h, sx / uiW, sy / uiH, sw / uiW, sh / uiH)
	end
end

hatskin.sprite.Header = hatskin.createSprite(0, 0, 127, 19)

-- 9-slice pieces for the frame's title bar: 3x3 corners, split out of the
-- source region x: 0-7, y: 21-48.
hatskin.sprite.frameTitleBarTL = hatskin.createSprite(0, 21, 3, 24)
hatskin.sprite.frameTitleBarT  = hatskin.createSprite(3, 21, 4, 24)
hatskin.sprite.frameTitleBarTR = hatskin.createSprite(4, 21, 7, 24)

hatskin.sprite.frameTitleBarL  = hatskin.createSprite(0, 24, 3, 45)
hatskin.sprite.frameTitleBarM  = hatskin.createSprite(3, 24, 4, 45)
hatskin.sprite.frameTitleBarR  = hatskin.createSprite(4, 24, 7, 45)

hatskin.sprite.frameTitleBarBL = hatskin.createSprite(0, 45, 3, 48)
hatskin.sprite.frameTitleBarB  = hatskin.createSprite(3, 45, 4, 48)
hatskin.sprite.frameTitleBarBR = hatskin.createSprite(4, 45, 7, 48)

-- 9-slice pieces for the frame body below the title bar: same column
-- (x: 0-7), 3x3 corners, continuing from the title bar's bottom (y: 48)
-- down to the original frame sprite's bottom (y: 155).
hatskin.sprite.frameTL = hatskin.createSprite(0, 48, 3, 51)
hatskin.sprite.frameT  = hatskin.createSprite(3, 48, 4, 51)
hatskin.sprite.frameTR = hatskin.createSprite(4, 48, 7, 51)

hatskin.sprite.frameL  = hatskin.createSprite(0, 51, 3, 152)
hatskin.sprite.frameM  = hatskin.createSprite(3, 51, 4, 152)
hatskin.sprite.frameR  = hatskin.createSprite(4, 51, 7, 152)

hatskin.sprite.frameBL = hatskin.createSprite(0, 152, 3, 155)
hatskin.sprite.frameB  = hatskin.createSprite(3, 152, 4, 155)
hatskin.sprite.frameBR = hatskin.createSprite(4, 152, 7, 155)

-- 9-slice pieces for the frame-holder box: 3 columns (left corner / middle /
-- right corner) x 3 rows (top border / middle / bottom border), split out of
-- the same source region the old single-row L/M/R sprites used (x: 9-28,
-- y: 21-80), with a 6px top and bottom border.
hatskin.sprite.frameHolderTL = hatskin.createSprite(9, 21, 17, 27)
hatskin.sprite.frameHolderT  = hatskin.createSprite(18, 21, 19, 27)
hatskin.sprite.frameHolderTR = hatskin.createSprite(19, 21, 28, 27)

hatskin.sprite.frameHolderL  = hatskin.createSprite(9, 27, 17, 74)
hatskin.sprite.frameHolderM  = hatskin.createSprite(18, 27, 19, 74)
hatskin.sprite.frameHolderR  = hatskin.createSprite(19, 27, 28, 74)

hatskin.sprite.frameHolderBL = hatskin.createSprite(9, 74, 17, 80)
hatskin.sprite.frameHolderB  = hatskin.createSprite(18, 74, 19, 80)
hatskin.sprite.frameHolderBR = hatskin.createSprite(19, 74, 28, 80)

-- 9-slice pieces for the scrollbar grip: 3 columns (left corner / middle /
-- right corner) x 3 rows (top / middle / bottom), split out of the same
-- source region the old single-row L/M/R sprites used (x: 54-76, y: 21-33),
-- with 4x4 corners.
hatskin.sprite.scrollBarTL = hatskin.createSprite(54, 21, 58, 25)
hatskin.sprite.scrollBarT  = hatskin.createSprite(60, 21, 60, 25)
hatskin.sprite.scrollBarTR = hatskin.createSprite(72, 21, 76, 25)

hatskin.sprite.scrollBarL  = hatskin.createSprite(54, 25, 58, 29)
hatskin.sprite.scrollBarM  = hatskin.createSprite(60, 25, 60, 29)
hatskin.sprite.scrollBarR  = hatskin.createSprite(72, 25, 76, 29)

hatskin.sprite.scrollBarBL = hatskin.createSprite(54, 29, 58, 33)
hatskin.sprite.scrollBarB  = hatskin.createSprite(60, 29, 60, 33)
hatskin.sprite.scrollBarBR = hatskin.createSprite(72, 29, 76, 33)

hatskin.sprite.buttonHoverL = hatskin.createSprite(78, 61, 82, 99)
hatskin.sprite.buttonHoverM = hatskin.createSprite(83, 61, 83, 99)
hatskin.sprite.buttonHoverR = hatskin.createSprite(169, 61, 172, 99)

hatskin.sprite.buttonDepressedL = hatskin.createSprite(78, 101, 82, 139)
hatskin.sprite.buttonDepressedM = hatskin.createSprite(83, 101, 83, 139)
hatskin.sprite.buttonDepressedR = hatskin.createSprite(169, 101, 172, 139)

hatskin.sprite.record = hatskin.createSprite(81, 29, 170, 54)
hatskin.sprite.recordHovered = hatskin.createSprite(81, 29 + 40, 170, 54 + 40)
hatskin.sprite.recordDepressed = hatskin.createSprite(81, 29 + 80, 170, 54 + 80)

hatskin.sprite.play = hatskin.createSprite(179, 29, 211, 54)
hatskin.sprite.playHovered = hatskin.createSprite(179, 29 + 40, 211, 54 + 40)
hatskin.sprite.playDepressed = hatskin.createSprite(179, 29 + 80, 211, 54 + 80)

hatskin.sprite.stop = hatskin.createSprite(224, 29, 260, 54)
hatskin.sprite.stopHovered = hatskin.createSprite(224, 29 + 40, 260, 54 + 40)
hatskin.sprite.stopDepressed = hatskin.createSprite(224, 29 + 80, 260, 54 + 80)

hatskin.sprite.new = hatskin.createSprite(273, 29, 350, 54)
hatskin.sprite.newHovered = hatskin.createSprite(273, 29 + 40, 350, 54 + 40)
hatskin.sprite.newDepressed = hatskin.createSprite(273, 29 + 80, 350, 54 + 80)

function hatskin.drawFrameTitleBar(x, y, w, h)
	local leftW, rightW, border = 3, 3, 3
	local midW = w - leftW - rightW
	local midH = h - border * 2

	hatskin.sprite.frameTitleBarTL(x, y, leftW, border)
	hatskin.sprite.frameTitleBarT(x + leftW, y, midW, border)
	hatskin.sprite.frameTitleBarTR(x + w - rightW, y, rightW, border)

	hatskin.sprite.frameTitleBarL(x, y + border, leftW, midH)
	hatskin.sprite.frameTitleBarM(x + leftW, y + border, midW, midH)
	hatskin.sprite.frameTitleBarR(x + w - rightW, y + border, rightW, midH)

	hatskin.sprite.frameTitleBarBL(x, y + h - border, leftW, border)
	hatskin.sprite.frameTitleBarB(x + leftW, y + h - border, midW, border)
	hatskin.sprite.frameTitleBarBR(x + w - rightW, y + h - border, rightW, border)


		surface.SetFont("Arial18");
		surface.SetTextPos(10, 5);
		surface.SetTextColor(200, 200, 200);
		surface.DrawText("Henry's Animation Tool", false);

end

function hatskin.drawFrame(x, y, w, h)
	local titleBarH = 27
	hatskin.drawFrameTitleBar(x, y, w, titleBarH)

	local bodyY = y + titleBarH
	local bodyH = h - titleBarH
	local leftW, rightW, border = 3, 3, 3
	local midW = w - leftW - rightW
	local midH = bodyH - border * 2

	hatskin.sprite.frameTL(x, bodyY, leftW, border)
	hatskin.sprite.frameT(x + leftW, bodyY, midW, border)
	hatskin.sprite.frameTR(x + w - rightW, bodyY, rightW, border)

	hatskin.sprite.frameL(x, bodyY + border, leftW, midH)
	hatskin.sprite.frameM(x + leftW, bodyY + border, midW, midH)
	hatskin.sprite.frameR(x + w - rightW, bodyY + border, rightW, midH)

	hatskin.sprite.frameBL(x, bodyY + bodyH - border, leftW, border)
	hatskin.sprite.frameB(x + leftW, bodyY + bodyH - border, midW, border)
	hatskin.sprite.frameBR(x + w - rightW, bodyY + bodyH - border, rightW, border)
end

function hatskin.drawFrameHolder(x, y, w, h)
	local border = 6
	local leftW = 8
	local rightW = 9
	local midW = w - leftW - rightW
	local midH = h - border * 2

	-- top row
	hatskin.sprite.frameHolderTL(x, y, leftW, border)
	hatskin.sprite.frameHolderT(x + leftW, y, midW, border)
	hatskin.sprite.frameHolderTR(x + w - rightW, y, rightW, border)

	-- middle row
	hatskin.sprite.frameHolderL(x, y + border, leftW, midH)
	hatskin.sprite.frameHolderM(x + leftW, y + border, midW, midH)
	hatskin.sprite.frameHolderR(x + w - rightW, y + border, rightW, midH)

	-- bottom row
	hatskin.sprite.frameHolderBL(x, y + h - border, leftW, border)
	hatskin.sprite.frameHolderB(x + leftW, y + h - border, midW, border)
	hatskin.sprite.frameHolderBR(x + w - rightW, y + h - border, rightW, border)
end

function hatskin.drawScrollBar(x, y, w, h)
	local border = 4
	local leftW = 4
	local rightW = 4
	local midW = w - leftW - rightW
	local midH = h - border * 2

	-- top row
	hatskin.sprite.scrollBarTL(x, y, leftW, border)
	hatskin.sprite.scrollBarT(x + leftW, y, midW, border)
	hatskin.sprite.scrollBarTR(x + w - rightW, y, rightW, border)

	-- middle row
	hatskin.sprite.scrollBarL(x, y + border, leftW, midH)
	hatskin.sprite.scrollBarM(x + leftW, y + border, midW, midH)
	hatskin.sprite.scrollBarR(x + w - rightW, y + border, rightW, midH)

	-- bottom row
	hatskin.sprite.scrollBarBL(x, y + h - border, leftW, border)
	hatskin.sprite.scrollBarB(x + leftW, y + h - border, midW, border)
	hatskin.sprite.scrollBarBR(x + w - rightW, y + h - border, rightW, border)
end

function hatskin.drawButton(depressed, hovered, w, h)
	if depressed then
		hatskin.sprite.buttonDepressedL(0, 0, 4, 38)
		hatskin.sprite.buttonDepressedM(4, 0, w - 7, 38)
		hatskin.sprite.buttonDepressedR(w - 3, 0, 3, 38)
	elseif hovered then
		hatskin.sprite.buttonHoverL(0, 0, 4, 38)
		hatskin.sprite.buttonHoverM(4, 0, w - 7, 38)
		hatskin.sprite.buttonHoverR(w - 3, 0, 3, 38)
	end
end

function hatskin.drawGenericButton(text, width, height, color, depressed, hovered)
	if depressed then
		-- hatskin.sprite.recordDepressed(4, 8, 89, 25)
		surface.SetDrawColor(0, 0, 0, 80);
		surface.DrawRect(0, 0, width, height);
		surface.SetDrawColor(0, 0, 0);
		surface.DrawOutlinedRect(0, 0, width, height, 1);
		surface.SetDrawColor(0, 0, 0, 40);
		surface.DrawLine(1, 1, width - 2, 1);
		surface.SetDrawColor(0, 0, 0, 20);
		surface.DrawLine(1, 2, width - 2, 2);
		surface.DrawLine(1, 1, 1, height - 2);
		surface.DrawLine(width - 2, 1, width - 2, height - 2);

		surface.SetFont("Arial18Glow2");
		local textWidth, textHeight = surface.GetTextSize(text);
		surface.SetTextPos(width / 2 - textWidth / 2, height / 2 - textHeight / 2);
		surface.SetTextColor(color.r, color.g, color.b, 150);
		surface.DrawText(text, false);

		surface.SetFont("Arial18Glow1");
		local textWidth, textHeight = surface.GetTextSize(text);
		surface.SetTextPos(width / 2 - textWidth / 2 - 1, height / 2 - textHeight / 2 + 1);
		surface.SetTextColor(0, 0, 0);
		surface.DrawText(text, false);

		surface.SetFont("Arial18");
		local textWidth, textHeight = surface.GetTextSize(text);
		surface.SetTextPos(width / 2 - textWidth / 2, height / 2 - textHeight / 2);
		surface.SetTextColor(color.r, color.g, color.b);
		surface.DrawText(text, false);
	elseif hovered then
		-- hatskin.sprite.recordHovered(4, 8, 89, 25)
		surface.SetDrawColor(0, 0, 0, 40);
		surface.DrawRect(0, 0, width, height);
		surface.SetDrawColor(0, 0, 0);
		surface.DrawOutlinedRect(0, 0, width, height, 1);
		surface.SetDrawColor(255, 255, 255, 8);
		surface.DrawLine(1, 1, width - 2, 1);
		surface.SetDrawColor(255, 255, 255, 5);
		surface.DrawLine(1, 2, width - 2, 2);
		surface.DrawLine(1, 1, 1, height - 2);
		surface.DrawLine(width - 2, 1, width - 2, height - 2);

		surface.SetFont("Arial18Glow2");
		local textWidth, textHeight = surface.GetTextSize(text);
		surface.SetTextPos(width / 2 - textWidth / 2, height / 2 - textHeight / 2);
		surface.SetTextColor(255, 255, 255, 50);
		surface.DrawText(text, true);

		surface.SetFont("Arial18Glow1");
		local textWidth, textHeight = surface.GetTextSize(text);
		surface.SetTextPos(width / 2 - textWidth / 2 - 1, height / 2 - textHeight / 2 + 1);
		surface.SetTextColor(0, 0, 0);
		surface.DrawText(text, false);

		surface.SetFont("Arial18");
		local textWidth, textHeight = surface.GetTextSize(text);
		surface.SetTextPos(width / 2 - textWidth / 2, height / 2 - textHeight / 2);
		surface.SetTextColor(color.r + 10, color.g + 10, color.b + 10);
		surface.DrawText(text, false);
	else
		surface.SetFont("Arial18Glow1");
		local textWidth, textHeight = surface.GetTextSize(text);
		surface.SetTextPos(width / 2 - textWidth / 2 - 1, height / 2 - textHeight / 2 + 1);
		surface.SetTextColor(0, 0, 0);
		surface.DrawText(text, false);

		surface.SetFont("Arial18");
		local textWidth, textHeight = surface.GetTextSize(text);
		surface.SetTextPos(width / 2 - textWidth / 2, height / 2 - textHeight / 2);
		surface.SetTextColor(color.r, color.g, color.b);
		surface.DrawText(text, false);
	end
end

function hatskin.drawPlayButton(depressed, hovered)
	if depressed then
		hatskin.sprite.playDepressed(4, 8, 32, 25)
	elseif hovered then
		hatskin.sprite.playHovered(4, 8, 32, 25)
	else
		hatskin.sprite.play(4, 8, 32, 25)
	end
end

function hatskin.drawStopButton(depressed, hovered)
	if depressed then
		hatskin.sprite.stopDepressed(4, 8, 36, 25)
	elseif hovered then
		hatskin.sprite.stopHovered(4, 8, 36, 25)
	else
		hatskin.sprite.stop(4, 8, 36, 25)
	end
end

function hatskin.drawNewButton(depressed, hovered)
	if depressed then
		hatskin.sprite.newDepressed(4, 8, 77, 25)
	elseif hovered then
		hatskin.sprite.newHovered(4, 8, 77, 25)
	else
		hatskin.sprite.new(4, 8, 77, 25)
	end
end
