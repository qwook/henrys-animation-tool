--[[   _
    ( )
   _| |   __   _ __   ___ ___     _ _
 /'_` | /'__`\( '__)/' _ ` _ `\ /'_` )
( (_| |(  ___/| |   | ( ) ( ) |( (_| |
`\__,_)`\____)(_)   (_) (_) (_)`\__,_)

	DHATScrubber - the timeline's ruler strip: track background, tick marks and the green
	playhead handle, plus drag-to-seek. Its bounds are exactly the strip, so seeking is a plain
	mouse event on this panel rather than a rect test in DFrameHolder.

	It knows nothing about entities or frames: the parent hands it the timeline's pixel mapping
	(TimeToX/XToTime/GetScrollOffsetX, all on the holder) and the time to draw the playhead at,
	and gets an OnScrub(time) callback while the user drags.

--]]

PANEL = {}

function PANEL:Init()
	self.Holder = self:GetParent()

	-- Desc: the parent turns drawing off while there's nothing on the timeline (the "select a
	-- character or prop" empty state), but leaves the panel mouse-active, so a click in the strip
	-- behaves the same as it did when the strip was drawn by DFrameHolder itself.
	self.DrawEnabled = true
	self.HandleWidth = 5
	self.Scrubbing = false

	self:SetDrawBackground(false)
	self:SetCursor("arrow")
end

-- Desc: fired continuously while dragging, with the time under the cursor. The parent seeks,
-- because deciding what "being at time t" means (hat_seek, the highlighted frame) is its job.
function PANEL:OnScrub(time)
end

-- Desc: tick marks every 0.25s, taller every 1s (q % 4) and taller still every 30s (q % 120).
-- Drawn across the whole visible width rather than only up to the timeline's length, so they
-- fill the strip even when the animation is shorter than the panel; VGUI clips whatever falls
-- outside this panel, which is what keeps them off the label column.
function PANEL:Paint(w, h)
	if not self.DrawEnabled then return end

	local holder = self.Holder

	surface.SetDrawColor(Color(56, 56, 56, 250))
	surface.DrawRect(0, 0, w, h)

	surface.SetDrawColor(Color(100, 100, 100))
	local tickOffsetX = holder:GetScrollOffsetX()
	local startQuarter = math.max(0, math.floor((-tickOffsetX / HAT_DEFAULT_FRAME_SIZE) / 0.25))
	local endQuarter = math.ceil(((w - tickOffsetX) / HAT_DEFAULT_FRAME_SIZE) / 0.25)

	for q = startQuarter, endQuarter do
		local t = q * 0.25
		local tickX = tickOffsetX + HAT_DEFAULT_FRAME_SIZE * t
		local tickHeight
		if q % 120 == 0 then
			tickHeight = h * 0.9
		elseif q % 4 == 0 then
			tickHeight = h * 0.75
		else
			tickHeight = h * 0.2
		end
		surface.DrawRect(tickX, h - tickHeight, 1, tickHeight)
	end

	local scrubX = holder:TimeToX(holder.CurrentTime)
	if scrubX then
		surface.SetDrawColor(Color(0, 255, 0))
		surface.DrawRect(scrubX - self.HandleWidth / 2, 0, self.HandleWidth, h)
	end
end

-- Desc: reports the time under the cursor. Measured against the global (longest-entity)
-- timeline, so it can seek past the current entity's own frames - XToTime clamps it to the real
-- end of the timeline.
function PANEL:UpdateScrub()
	local x = self:ScreenToLocal(gui.MouseX(), 0)
	self:OnScrub(self.Holder:XToTime(x))
end

-- Desc: left-click seeks and starts a drag. Middle/right presses belong to the timeline's global
-- pan / pending-right-click gestures, so they go back to the parent untouched.
function PANEL:OnMousePressed(mousecode)
	if mousecode != MOUSE_LEFT then
		return self:GetParent():OnMousePressed(mousecode)
	end

	self:MouseCapture(true)
	self.Scrubbing = true
	self:UpdateScrub()
end

-- Desc: the release is deliberately NOT forwarded to the parent: a scrub used to make
-- DFrameHolder:OnMouseReleased bail out immediately anyway, so swallowing it here is the same
-- thing - and stops a drag-seek from also re-sending a frame selection.
function PANEL:OnMouseReleased(mousecode)
	self.Scrubbing = false
	self:MouseCapture(false)
end

function PANEL:Think()
	if self.Scrubbing then
		self:UpdateScrub()
	end
end

derma.DefineControl("DHATScrubber", "DFrameHolder's timeline ruler and playhead.", PANEL, "DPanel")
