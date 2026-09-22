--[[   _
    ( )
   _| |   __   _ __   ___ ___     _ _
 /'_` | /'__`\( '__)/' _ ` _ `\ /'_` )
( (_| |(  ___/| |   | ( ) ( ) |( (_| |
`\__,_)`\____)(_)   (_) (_) (_)`\__,_)

	DHATScrollbar - one axis of DFrameHolder's scrolling. The panel's own bounds ARE the track
	the grip travels along, so track clicks arrive as ordinary mouse events instead of the
	parent hit-testing a rect by hand. It owns its DScrollBarGrip, the grip drag, and the eased
	"wheel scroll glides toward a target ratio" behaviour; the parent only feeds it sizes
	(SetSizes) and reads/writes the plain scroll ratio.

	Deliberately NOT a general scrollbar: it exists to serve DFrameHolder's horizontal (frame
	strip) and vertical (entity rows) axes, which differ only in orientation plus one quirk -
	the thumb's size is measured against the *viewport* length while the track it slides in can
	be longer (the vertical bar spans the scrubber strip too). Hence the separate ViewSize
	(thumb ratio, wheel step) and track length (the panel's own size).

--]]

PANEL = {}

-- Desc: "horizontal" or "vertical". Set once by the parent right after creation.
AccessorFunc(PANEL, "m_Orientation", "Orientation")

function PANEL:Init()
	self.m_Orientation = "horizontal"
	self.Enabled = true

	-- Total scrollable length, and the length of the viewport looking into it (both in pixels).
	self.ContentSize = 0
	self.ViewSize = 0
	self.BarSize = 0

	self.ScrollRatio = 0
	self.ScrollRatioTarget = nil

	self.Dragging = false
	self.DragCenterOnCursor = false
	self.HoldPos = 0

	self:SetDrawBackground(false)
	self:SetCursor("arrow")

	self.btnGrip = vgui.Create("DScrollBarGrip", self)
	self.btnGrip:SetText("")
	self.btnGrip.Paint = function(_, w, h) hatskin.drawScrollBar(0, 0, w, h) end
end

function PANEL:IsVertical()
	return self:GetOrientation() == "vertical"
end

-- Desc: length of the track in the scrolling direction - i.e. this panel's own size along its
-- axis. Not the same as ViewSize; see the header.
function PANEL:GetTrackLength()
	return self:IsVertical() and self:GetTall() or self:GetWide()
end

function PANEL:GetBarSize()
	return self.BarSize
end

function PANEL:GetViewSize()
	return self.ViewSize
end

function PANEL:GetScrollRatio()
	return self.ScrollRatio
end

function PANEL:GetScrollRatioTarget()
	return self.ScrollRatioTarget
end

-- Desc: mouse position along this scrollbar's axis, relative to the track (this panel).
function PANEL:LocalMousePos()
	if self:IsVertical() then
		return select(2, self:ScreenToLocal(0, gui.MouseY()))
	end
	return (self:ScreenToLocal(gui.MouseX(), 0))
end

-- Desc: mouse position along this scrollbar's axis, relative to the grip itself - the point of
-- the grip that was grabbed, which a grip drag keeps glued under the cursor.
function PANEL:GripMousePos()
	if self:IsVertical() then
		return select(2, self.btnGrip:ScreenToLocal(0, gui.MouseY()))
	end
	return (self.btnGrip:ScreenToLocal(gui.MouseX(), 0))
end

-- Desc: both sizes are set together (rather than through separate setters) because the thumb
-- size is a function of both - setting one at a time would recompute BarSize, and the
-- "content fits, so pin to the top/left" clamp, against a half-updated pair.
function PANEL:SetSizes(contentSize, viewSize)
	self.ContentSize = contentSize
	self.ViewSize = viewSize

	local ratio = viewSize / math.max(contentSize, 1)
	if ratio > 1 then
		self.ScrollRatio = 0
		ratio = 1
	end

	self.BarSize = self:GetTrackLength() * ratio
	self:LayoutGrip()
end

-- Desc: positions the grip for the current ratio. The +1 keeps the grip's far edge reachable at
-- ratio 1 (carried over from the original hand-rolled scrollbar; changing it shifts the grip by a
-- pixel at the end of the track).
function PANEL:LayoutGrip()
	local travel = self.ScrollRatio * (self:GetTrackLength() - self.BarSize + 1)

	if self:IsVertical() then
		self.btnGrip:SetPos(0, travel)
		self.btnGrip:SetSize(self:GetWide(), self.BarSize)
	else
		self.btnGrip:SetPos(travel, 0)
		self.btnGrip:SetSize(self.BarSize, self:GetTall())
	end
end

function PANEL:PerformLayout()
	self:LayoutGrip()
end

-- Desc: sets the scroll position without touching the eased target, for the parent's own
-- scrolling (middle-click pan). Does not fire OnUserScroll - the parent already knows.
function PANEL:SetScrollRatio(ratio)
	self.ScrollRatio = ratio
	self:LayoutGrip()
end

-- Desc: where the scroll should end up; Think eases towards it. The parent uses this for
-- wheel scrolling and for gliding to a row (JumpToEntity) instead of snapping.
function PANEL:SetScrollRatioTarget(ratio)
	self.ScrollRatioTarget = ratio
end

-- Desc: fired whenever the scrollbar moved itself (grip drag, track jump, or an easing step), so
-- the parent can re-lay-out and repaint against the new offset. Overridden by DFrameHolder.
function PANEL:OnUserScroll()
end

-- Desc: mouse-wheel step, in pixels of content. Measured against ViewSize (not the track length)
-- so a wheel notch moves the same amount of content on both axes. Returns false when there's
-- nothing to scroll, so the parent can let the wheel event bubble.
function PANEL:ScrollByPixels(pixels)
	if not self.BarSize or self.BarSize == 0 then return false end

	local target = self.ScrollRatioTarget or self.ScrollRatio
	self.ScrollRatioTarget = math.Clamp(target - pixels / (self.ViewSize - self.BarSize + 1), 0, 1)

	return true
end

-- Desc: jumps the grip so it's centered under track-local position `pos` (a click on empty track
-- space), ready for Grip() to pick up as a drag immediately after.
function PANEL:JumpScrollTo(pos)
	if not self.BarSize or self.BarSize <= 0 then return end

	local travel = self:GetTrackLength() - self.BarSize
	if travel <= 0 then return end

	local target = math.Clamp((pos - self.BarSize / 2) / travel, 0, 1)
	self.ScrollRatio = target
	self.ScrollRatioTarget = target
	self:LayoutGrip()
	self:OnUserScroll()
end

--[[---------------------------------------------------------
   Name: Grip
-----------------------------------------------------------]]
-- Desc: starts a drag. Grabbing the grip itself (DScrollBarGrip:OnMousePressed calls this with
-- 1, not `true`) keeps whatever point on the grip was grabbed under the cursor; centerOnCursor
-- == true (from a track click - see OnMousePressed) instead glues the grip's middle to the
-- cursor for the whole drag.
function PANEL:Grip(centerOnCursor)
	if (! self.Enabled) then return end
	if (self.BarSize == 0) then return end

	self:MouseCapture(true)
	self.Dragging = true
	self.DragCenterOnCursor = centerOnCursor == true

	if not self.DragCenterOnCursor then
		self.HoldPos = self:GripMousePos()
	end

	self.btnGrip.Depressed = true
end

-- Desc: drops any in-progress drag without running the release handling (the parent calls this
-- from its own OnMouseReleased, which can fire for a release that started elsewhere).
function PANEL:AbortDrag()
	self.Dragging = false
	self.btnGrip.Depressed = false
end

-- Desc: per-frame drag tracking plus the eased glide towards ScrollRatioTarget. A drag always
-- wins over easing, and keeps the target pinned to the live ratio so releasing mid-drag doesn't
-- spring back to wherever the wheel last aimed.
function PANEL:Think()
	if self.Dragging then
		if self.DragCenterOnCursor then
			-- Track click: the grip's middle stays glued to the cursor for the whole drag
			-- (clamped at the track's ends by JumpScrollTo).
			self:JumpScrollTo(self:LocalMousePos())
		else
			-- Grabbed the grip itself: keep whatever point on the grip was originally grabbed
			-- (HoldPos) under the cursor, instead of snapping the grip's middle to it.
			local pos = self:GripMousePos()
			local travel = self:GetTrackLength() - self.BarSize
			if travel > 0 then
				self.ScrollRatio = math.Clamp(self.ScrollRatio + (pos - self.HoldPos) / travel, 0, 1)
			end
			self:LayoutGrip()
			self:OnUserScroll()
		end

		self.ScrollRatioTarget = self.ScrollRatio
	end

	-- Ease the wheel-scroll target in smoothly, instead of snapping straight to it.
	if not self.Dragging and self.ScrollRatioTarget and self.ScrollRatioTarget ~= self.ScrollRatio then
		self.ScrollRatio = Lerp(math.Clamp(FrameTime() * 12, 0, 1), self.ScrollRatio, self.ScrollRatioTarget)
		if math.abs(self.ScrollRatio - self.ScrollRatioTarget) < 0.001 then
			self.ScrollRatio = self.ScrollRatioTarget
		end
		self:LayoutGrip()
		self:OnUserScroll()
	end
end

-- Desc: a left-click on empty track space jumps the grip under the cursor and starts dragging it
-- immediately, same as grabbing the grip. Middle/right presses aren't scrolling at all - they're
-- the timeline's global pan / pending-right-click gestures - so they're handed straight back to
-- the parent, exactly as if the track weren't a panel of its own.
function PANEL:OnMousePressed(mousecode)
	if mousecode != MOUSE_LEFT then
		return self:GetParent():OnMousePressed(mousecode)
	end

	self:JumpScrollTo(self:LocalMousePos())
	self:Grip(true)
end

-- Desc: ends the drag, then still forwards to the parent's release handling: this panel captures
-- the mouse for the whole drag, so without forwarding the parent would never see the release
-- that (as before this was split out) also resets panning and re-sends the frame selection.
function PANEL:OnMouseReleased(mousecode)
	self:MouseCapture(false)
	self:AbortDrag()

	local parent = self:GetParent()
	if parent and parent.OnMouseReleased then
		parent:OnMouseReleased(mousecode)
	end
end

derma.DefineControl("DHATScrollbar", "One axis of DFrameHolder's scrolling.", PANEL, "DPanel")
