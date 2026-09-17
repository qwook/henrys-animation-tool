--[[   _
    ( )
   _| |   __   _ __   ___ ___     _ _
 /'_` | /'__`\( '__)/' _ ` _ `\ /'_` )
( (_| |(  ___/| |   | ( ) ( ) |( (_| |
`\__,_)`\____)(_)   (_) (_) (_)`\__,_)

	DFrameHolder - the frame-strip timeline widget: draws every object's frames as a row of
	colored blocks stacked vertically (one row per entity), with a fixed-width label on the
	left of each row and a horizontal + vertical scrollbar. Only the current entity's row is
	interactive (dragging/resizing/reordering frames); other rows are drawn statically. One
	PANEL definition (Derma controls must be a single table before derma.DefineControl runs),
	organized below into:
	  1. Init / state
	  2. Entity + frame data (Load/SetEntity/New/Remove/Move Frame)
	  3. Hit-testing math (GetNewFrame/GetIncreaseLengthFrame/GetFrameHovered)
	  4. Playback (Play/Stop/Think)
	  5. Rendering (Paint/GetFramesSize)
	  6. Mouse input (OnMousePressed/OnMouseReleased/Grip/GripY) + PerformLayout
	  7. Stubs / legacy compatibility shims

--]]

HAT_PlayRate = GetConVar("hat_playrate")

PANEL = {}
AccessorFunc(PANEL, "m_bStretchToFit", "StretchToFit")
AccessorFunc(PANEL, "m_iPadding", "Padding")

-- ==================== 1. Init / state ====================

--[[---------------------------------------------------------

-----------------------------------------------------------]]
function PANEL:Init()
	self.Enabled = true

	self:SetDrawBackground(false)
	self:SetStretchToFit(true)
	self:SetPadding(5)

	-- Layout constants.
	self.LabelWidth = 100
	self.LabelGap = 4
	self.RowGap = 4
	self.RowHeight = 30 + self.RowGap
	self.HScrollHeight = 12
	self.VScrollWidth = 12
	self.ScrubberHeight = 32
	self.ScrubberGap = 4
	self.ScrubberHandleWidth = 5

	self.btnGrip = vgui.Create("DScrollBarGrip", self)
	self.btnGrip:SetText("")
	self.btnGrip.Paint = function(self, w, h) hatskin.drawScrollBar(0, 0, w, h) end

	local panel = self
	self.btnGripY = vgui.Create("DScrollBarGrip", self)
	self.btnGripY:SetText("")
	self.btnGripY.Paint = function(self, w, h) hatskin.drawScrollBar(0, 0, w, h) end
	self.btnGripY.OnMousePressed = function() panel:GripY() end

	self.Entities = {}
	self.CurEntity = 1

	self.FramesSize = self:GetFramesSize()
	self.LastFramesSize = self.FramesSize

	self:SetColor(Color(255, 255, 255, 255))

	self.ScrollRatio = 0
	self.ScrollRatioY = 0

	self.DraggingNewFrame = false
	self.HoldingFrame = false
	self.DraggingFrame = false

	self.DragFrameLength = nil
	self.DragFrameMouseX = 0
	self.DragFrameLengthO = 0

	self.CurrentTime = 0
	self.ScrubbingBar = false

	self.Cursor = ""

	self:SetCursor("arrow")
end

-- Desc: local (client-only) frame record: length + a random display color, used purely for drawing.
local function newFrame(length)
	return { l = length, cA = { 0.5, 0.5 }, cB = { 0.5, 0.5 }, c = Color(math.random(180, 225), math.random(180, 225),
		math.random(180, 225)) }
end

-- Desc: sets the panel's mouse cursor only when it actually changes (avoids redundant SetCursor calls).
function PANEL:QueryCursor(cursor)
	if self.Cursor == cursor then return end

	self.Cursor = cursor
	self:SetCursor(cursor)
end

-- Desc: sorted keys of self.Entities, giving every row a stable top-to-bottom order.
function PANEL:GetOrderedEntityIds()
	local ids = {}
	for id in pairs(self.Entities) do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

-- Desc: panel width available to the frame strip once Padding, the label column and the
-- vertical scrollbar are subtracted.
function PANEL:GetContentWide()
	return math.max(self:GetWide() - self:GetPadding() * 2 - self.LabelWidth - self.LabelGap - self.VScrollWidth, 0)
end

-- Desc: panel height available to the stack of entity rows, once Padding, the horizontal
-- scrollbar and the scrubber strip are subtracted.
function PANEL:GetContentTall()
	return math.max(
	self:GetTall() - self:GetPadding() * 2 - self.HScrollHeight - self.RowGap - self.ScrubberHeight - self.ScrubberGap, 0)
end

-- Desc: x position (panel-local) where the scrollable frame strip starts, after the label column.
function PANEL:GetFrameAreaX()
	return self:GetPadding() + self.LabelWidth + self.LabelGap
end

-- Desc: y position (panel-local) where the entity rows start, below the scrubber strip.
function PANEL:GetRowsTopY()
	return self:GetPadding() + self.ScrubberHeight + self.ScrubberGap
end

-- Desc: current vertical scroll offset in pixels, derived from ScrollRatioY.
function PANEL:GetScrollOffsetY()
	local totalTall = #self:GetOrderedEntityIds() * self.RowHeight
	local maxScroll = math.max(totalTall - self:GetContentTall(), 0)
	return self.ScrollRatioY * maxScroll
end

-- Desc: content-space (padding-relative) y position of the current entity's row, accounting
-- for vertical scroll.
function PANEL:GetCurrentRowContentY()
	local ids = self:GetOrderedEntityIds()
	local idx = 1
	for i, v in ipairs(ids) do
		if v == self.CurEntity then
			idx = i
			break
		end
	end
	return (self.ScrubberHeight + self.ScrubberGap) + (idx - 1) * self.RowHeight - self:GetScrollOffsetY()
end

-- Desc: mouse position in content space (panel-local, minus Padding), matching the space the frame
-- strip is hit-tested and laid out in.
function PANEL:ScreenToContent(sx, sy)
	local x, y = self:ScreenToLocal(sx, sy)
	local padding = self:GetPadding()
	return x - padding, y - padding
end

-- Desc: mouse position relative to the current entity's frame strip: x relative to the label
-- column, y relative to that entity's row (so 0-30 covers just that row's frame strip height).
function PANEL:ScreenToFrameSpace(sx, sy)
	local x, y = self:ScreenToContent(sx, sy)
	x = x - self.LabelWidth - self.LabelGap
	y = y - self:GetCurrentRowContentY()
	return x, y
end

-- Desc: truncates text with an ellipsis so it fits within maxWidth pixels in font.
local function TruncateText(text, font, maxWidth)
	surface.SetFont(font)
	if surface.GetTextSize(text) <= maxWidth then return text end

	local truncated = text
	while #truncated > 0 do
		truncated = truncated:sub(1, #truncated - 1)
		if surface.GetTextSize(truncated .. "…") <= maxWidth then
			return truncated .. "…"
		end
	end
	return ""
end

-- Desc: short display label for an entity row: the model's file name if a valid entity is
-- known, otherwise its id.
local function GetEntityLabel(id, entData)
	if IsValid(entData.Ent) then
		local model = entData.Ent:GetModel()
		if model then
			return string.GetFileFromFilename(model):gsub("%.mdl$", "")
		end
	end
	return "#" .. tostring(id)
end

-- ==================== 2. Entity + frame data ====================

-- Desc: rebuilds self.Entities (display-only frame list) from a hat_send_data payload.
function PANEL:Load(toLoad)
	self.Entities = {}
	for k, v in pairs(toLoad.objects) do
		self.Entities[k + 1] = {
			Frames = {},
			SelectedFrame = 1,
			Ent = ents.GetByIndex(v.ent)
		}
		for frame, v in ipairs(v.frames) do
			self.Entities[k + 1].Frames[frame] = newFrame(v)
		end
	end
	self.CurEntity = (toLoad.currentObjId or 0) + 1
end

-- Desc: switches the displayed entity, creating a default empty entry if id is new, and jumps
-- the vertical scroll so its row is visible.
function PANEL:SetEntity(id, ent)
	self.CurEntity = id
	self.Entities[id] = self.Entities[id] or { Frames = {}, SelectedFrame = 1 }
	self.Entities[id].Ent = ent
	self.LastFramesSize = self:GetFramesSize()
	self:JumpToEntity(id)
	self:PerformLayout()
end

function PANEL:RemoveEntity(id)
	self.Entities[id] = nil
	--table.remove( self.Entities, id )
end

-- Desc: inserts a display-only frame at pos (or appended) for an entity.
function PANEL:NewFrame(id, length, pos)
	if pos then
		table.insert(self.Entities[id].Frames, pos, newFrame(length))
	else
		table.insert(self.Entities[id].Frames, newFrame(length))
	end
	self:PerformLayout()
end

function PANEL:RemoveFrame(id, frame)
	table.remove(self.Entities[id].Frames, frame)
end

-- Desc: begins a drag from the "new frame" button; the green insertion marker follows the mouse.
function PANEL:DragNewFrame()
	self.DraggingNewFrame = true
end

-- Desc: on drop, sends hat_frame_add at the hovered insertion point if the drop landed on the strip.
function PANEL:FinishDragNewFrame(shouldMakeNewFrame)
	local x, y = self:ScreenToFrameSpace(gui.MouseX(), gui.MouseY())

	self.DraggingNewFrame = false
	if shouldMakeNewFrame and y >= 0 and y <= 30 then
		local newFrame = self:GetNewFrame()
		RunConsoleCommand("hat_frame_add", newFrame)
	end
end

-- Desc: selects frame within entity id's strip and moves the shared scrubber to that frame's
-- start time, so the timeline playhead follows the selection.
function PANEL:SelectFrame(id, frame)
	self.Entities[id].SelectedFrame = frame

	local frames = self.Entities[id].Frames
	local time = 0
	for i = 1, frame - 1 do
		if frames[i] then time = time + frames[i].l end
	end
	self.CurrentTime = time
end

-- Desc: scrolls vertically so the given entity's row is at the top of the visible area.
function PANEL:JumpToEntity(id)
	local ids = self:GetOrderedEntityIds()
	local idx
	for i, v in ipairs(ids) do
		if v == id then
			idx = i
			break
		end
	end
	if not idx then return end

	local totalTall = #ids * self.RowHeight
	local maxScroll = math.max(totalTall - self:GetContentTall(), 0)

	if maxScroll <= 0 then
		self.ScrollRatioY = 0
		self.ScrollRatioYTarget = 0
		return
	end

	local targetOffset = math.Clamp((idx - 1) * self.RowHeight, 0, maxScroll)
	self.ScrollRatioY = targetOffset / maxScroll
	self.ScrollRatioYTarget = self.ScrollRatioY
end

-- Desc: entity id of the row (label or frame strip) at panel-local y, or nil if y falls between
-- rows / outside them entirely.
function PANEL:GetRowIdAtY(ly)
	local rowsTopY = self:GetRowsTopY()
	local scrollOffsetY = self:GetScrollOffsetY()
	local ids = self:GetOrderedEntityIds()

	for orderIndex, id in ipairs(ids) do
		local rowY = rowsTopY + (orderIndex - 1) * self.RowHeight - scrollOffsetY
		if ly >= rowY and ly <= rowY + 30 then
			return id
		end
	end
end

-- ==================== 3. Hit-testing math ====================

-- Desc: index where a new frame would be inserted, based on which half of the hovered frame the
-- mouse is over (left half = insert before, right half = insert after).
function PANEL:GetNewFrame()
	local x, y = self:ScreenToFrameSpace(gui.MouseX(), gui.MouseY())

	local scrollOffset = self.ScrollRatio * (self.FramesSize - self:GetContentWide())
	local offsetX = math.floor(-scrollOffset)

	if not self.Entities[self.CurEntity] then return 0 end

	local newFrameSpeculation
	local count = 0

	for i, val in pairs(self.Entities[self.CurEntity].Frames) do
		local length = val.l
		local boxWidth = HAT_DEFAULT_FRAME_SIZE * length
		local l, c, r = offsetX, offsetX + boxWidth / 2, offsetX + boxWidth
		if x >= l and x <= c then
			newFrameSpeculation = i
		elseif x >= c and x <= r then
			newFrameSpeculation = i + 1
		end

		offsetX = offsetX + boxWidth
		count = i + 1
	end

	return newFrameSpeculation or count
end

-- Desc: relocates a display-only frame within the current entity's strip.
function PANEL:MoveFrame(id, frameFrom, frameTo)
	local frame = self.Entities[self.CurEntity].Frames[frameFrom]
	self:RemoveFrame(self.CurEntity, frameFrom)
	table.insert(self.Entities[self.CurEntity].Frames, frameTo, frame)
	self:PerformLayout()
end

-- Desc: index of the frame whose right-edge resize handle the mouse is over, if any.
function PANEL:GetIncreaseLengthFrame()
	local x, y = self:ScreenToFrameSpace(gui.MouseX(), gui.MouseY())

	local scrollOffset = self.ScrollRatio * (self.FramesSize - self:GetContentWide())
	local offsetX = math.floor(-scrollOffset)

	if not self.Entities[self.CurEntity] then return end

	local increaseFrameSpeculation

	for i, val in pairs(self.Entities[self.CurEntity].Frames) do
		local length = val.l
		local boxWidth = HAT_DEFAULT_FRAME_SIZE * length

		local l, r = offsetX, offsetX + boxWidth
		if x >= l and x >= r - 5 and x <= r then
			increaseFrameSpeculation = i
		end

		offsetX = offsetX + boxWidth
	end

	return increaseFrameSpeculation
end

-- Desc: index of the frame currently under the mouse (or being dragged), if any.
function PANEL:GetFrameHovered()
	local x, y = self:ScreenToFrameSpace(gui.MouseX(), gui.MouseY())

	local scrollOffset = self.ScrollRatio * (self.FramesSize - self:GetContentWide())
	local offsetX = math.floor(-scrollOffset)

	if not self.Entities[self.CurEntity] then return end

	for i, val in pairs(self.Entities[self.CurEntity].Frames) do
		local length = val.l
		local boxWidth = HAT_DEFAULT_FRAME_SIZE * length

		if (self.DragFrameLength and self.DragFrameLength == i) or (not self.DragFrameLength and x >= offsetX and x <= offsetX + boxWidth and y >= 0 and y <= 30) then
			return i
		end

		offsetX = offsetX + boxWidth
	end
end

-- Desc: pixel x (frame-area-relative, includes horizontal scroll) for timeline time `time`
-- seconds. Strictly linear (HAT_DEFAULT_FRAME_SIZE px/sec), so it lines up with every row's frame
-- boxes (see PaintRow) regardless of which entity is current, and isn't bounded by any single
-- entity's own timeline length. nil if there's nothing on the timeline at all.
function PANEL:TimeToX(time)
	if self.FramesSize <= 0 then return nil end

	local offsetX = math.floor(-self.ScrollRatio * (self.FramesSize - self:GetContentWide()))
	return offsetX + HAT_DEFAULT_FRAME_SIZE * math.max(time, 0)
end

-- Desc: inverse of TimeToX: seconds into the global timeline that pixel x (frame-area-relative)
-- corresponds to, clamped to [0, the longest entity's total length].
function PANEL:XToTime(x)
	if self.FramesSize <= 0 then return 0 end

	local offsetX = math.floor(-self.ScrollRatio * (self.FramesSize - self:GetContentWide()))
	local maxTime = self.FramesSize / HAT_DEFAULT_FRAME_SIZE

	return math.Clamp((x - offsetX) / HAT_DEFAULT_FRAME_SIZE, 0, maxTime)
end

-- Desc: current entity's own frame index that `time` seconds falls within, clamped to its last
-- frame if time runs past its own (possibly shorter than global) timeline.
function PANEL:GetFrameIndexAtTime(entData, time)
	if not entData or #entData.Frames == 0 then return nil end

	local start = 0
	local lastIndex = #entData.Frames

	for i, val in pairs(entData.Frames) do
		local length = val.l
		if time < start + length then
			return i
		end
		lastIndex = i
		start = start + length
	end

	return lastIndex
end

-- Desc: seeks to the mouse's current x position within the scrubber strip: updates
-- self.CurrentTime, tells the server to apply that pose (hat_seek), and locally selects the
-- frame under the scrubber for editing without changing the server's "current frame" cursor.
-- The scrubber position is measured against the global (longest-entity) timeline, so this can
-- seek past the current entity's own frames; its selected frame is then clamped to its last one.
function PANEL:UpdateScrub(sx)
	local x = self:ScreenToContent(sx, 0)
	x = x - self.LabelWidth - self.LabelGap

	local time = self:XToTime(x)
	self.CurrentTime = time

	RunConsoleCommand("hat_seek", time)

	local entData = self.Entities[self.CurEntity]
	local frameIdx = self:GetFrameIndexAtTime(entData, time)
	if entData and frameIdx then
		entData.SelectedFrame = frameIdx
	end
end

-- Desc: recomputes each entity's cumulative per-frame start times (frame.start), used to draw
-- the current-time playhead across every row.
function PANEL:RecalculateFrameStarts()
	for _, entData in pairs(self.Entities) do
		local length = 0
		for _, frame in pairs(entData.Frames) do
			frame.start = length
			length = length + frame.l
		end
		entData.TotalTime = length
	end
end

-- ==================== 4. Playback ====================

-- Desc: begins synced playback `offset` seconds into the timeline, measured from this client's
-- own clock so the scrubber doesn't depend on the server and client clocks lining up.
function PANEL:Play(offset)
	self.StartTime = CurTime() * HAT_PlayRate:GetFloat() - offset
end

function PANEL:Stop()
	self.StartTime = nil
end

-- Desc: per-frame update: scrollbar dragging (both axes), frame-length dragging, and
-- drag-vs-click detection.
function PANEL:Think()
	if self.ScrubbingBar then
		self:UpdateScrub(gui.MouseX())
	end

	if self.Dragging then
		local x, y = gui.MouseX(), 0
		local x, y = self.btnGrip:ScreenToLocal(x, y)

		local ratio = self:GetContentWide() / self.FramesSize
		local fullBarSize = (self:GetContentWide() - 30)

		if ratio <= 1 then
			self.ScrollRatio = self.ScrollRatio + ((x - self.HoldPos) / (fullBarSize - self.BarSize + 1))
		end

		self:PerformLayout()

		self.ScrollRatio = math.Clamp(self.ScrollRatio, 0, 1)
		self.ScrollRatioTarget = self.ScrollRatio
	end

	if self.DraggingY then
		local lx, ly = self.btnGripY:ScreenToLocal(0, gui.MouseY())

		local ids = self:GetOrderedEntityIds()
		local totalTall = math.max(#ids * self.RowHeight, 1)
		local contentTall = self:GetContentTall()
		local ratio = contentTall / totalTall
		local fullBarSize = contentTall

		if ratio <= 1 then
			self.ScrollRatioY = self.ScrollRatioY + ((ly - self.HoldPosY) / (fullBarSize - self.BarSizeY + 1))
		end

		self:PerformLayout()

		self.ScrollRatioY = math.Clamp(self.ScrollRatioY, 0, 1)
		self.ScrollRatioYTarget = self.ScrollRatioY
	end

	-- Ease the wheel-scroll targets in smoothly, instead of snapping straight to them.
	if not self.Dragging and self.ScrollRatioTarget and self.ScrollRatioTarget ~= self.ScrollRatio then
		self.ScrollRatio = Lerp(math.Clamp(FrameTime() * 12, 0, 1), self.ScrollRatio, self.ScrollRatioTarget)
		if math.abs(self.ScrollRatio - self.ScrollRatioTarget) < 0.001 then
			self.ScrollRatio = self.ScrollRatioTarget
		end
		self:PerformLayout()
	end

	if not self.DraggingY and self.ScrollRatioYTarget and self.ScrollRatioYTarget ~= self.ScrollRatioY then
		self.ScrollRatioY = Lerp(math.Clamp(FrameTime() * 12, 0, 1), self.ScrollRatioY, self.ScrollRatioYTarget)
		if math.abs(self.ScrollRatioY - self.ScrollRatioYTarget) < 0.001 then
			self.ScrollRatioY = self.ScrollRatioYTarget
		end
		self:PerformLayout()
	end

	local x, y = gui.MouseX(), 0
	local x, y = self:ScreenToLocal(x, y)

	if self.DragFrameLength then
		local rawLength = self.DragFrameLengthO + (x - self.DragFrameMouseX) / HAT_DEFAULT_FRAME_SIZE
		local snapIncrement = HAT_DEFAULT_LENGTH / 8
		local snappedLength = math.Round(rawLength / snapIncrement) * snapIncrement

		self.Entities[self.CurEntity].Frames[self.DragFrameLength].l = math.max(snappedLength, 0)
	end

	if self.HoldingFrame and self.HoldingFrame ~= self:GetFrameHovered() then
		self.DraggingFrame = true
	end
end

local function drawLine(vecA, vecB)
	surface.DrawLine(vecA.x, vecA.y, vecB.x, vecB.y)
end

local function bezierCurve(t, tbl)
	local newTbl = {}
	for i = 1, #tbl - 1 do
		table.insert(newTbl, LerpVector(t, tbl[i], tbl[i + 1]))
	end
	if #newTbl == 1 then
		return newTbl[1]
	end
	return bezierCurve(t, newTbl)
end

-- ==================== 5. Rendering ====================

-- Desc: draws one entity's row of frame blocks at (drawX, drawY). When interactive is true
-- (the current entity's row), also draws selection/hover highlight, the resize-handle strip,
-- the drag-insertion marker, and updates the cursor; mouseX/mouseY are in that row's frame
-- space (see ScreenToFrameSpace). Returns whether the cursor was changed by this row.
function PANEL:PaintRow(entData, drawX, drawY, interactive, mouseX, mouseY, drawTime, localTime)
	local scrollOffsetX = math.floor(-self.ScrollRatio * (self.FramesSize - self:GetContentWide()))

	local newFrameSpeculation
	local newFrameSpeculationX
	local cursorChanged = false

	-- Every box is positioned by its own cumulative start time (val.start, set in
	-- RecalculateFrameStarts) rather than by accumulating this row's own frame widths, so a
	-- frame always lands at the same x as the shared scrubber and every other row for the same
	-- point in time, regardless of how many frames this or any other entity has.
	for i, val in pairs(entData.Frames) do
		local length = val.l
		local offsetX = scrollOffsetX + HAT_DEFAULT_FRAME_SIZE * val.start
		local boxWidth = HAT_DEFAULT_FRAME_SIZE * length

		-- Draw frame outline.
		if interactive and entData.SelectedFrame == i then
			surface.SetDrawColor(Color(100, 100, 255))
		else
			surface.SetDrawColor(Color(100, 100, 100))
		end
		surface.DrawRect(drawX + offsetX, drawY, boxWidth, 30)

		-- Draw the frame's unique color.
		surface.SetDrawColor(val.c)
		surface.DrawRect(drawX + offsetX + 1, drawY + 1, boxWidth - 2, 28)

		if interactive then
			-- See if this frame is selected
			if entData.SelectedFrame == i then
				-- Set the color to signify we're selecting the frame.
				surface.SetDrawColor(Color(0, 0, 0, 100))
				surface.DrawRect(drawX + offsetX + 3, drawY + 3, boxWidth - 6, 24)
				-- Check to see if we're dragging the frame.
			elseif (self.DragFrameLength and self.DragFrameLength == i) or
					(not self.DragFrameLength and
						-- If not, check to see if the mouse is over the frame.
						mouseX >= offsetX and mouseX <= offsetX + boxWidth and
						mouseY >= 0 and mouseY <= 30) then
				-- Set the color to signify we're highlighting the frame.
				surface.SetDrawColor(Color(225, 225, 225, 50))
				surface.DrawRect(drawX + offsetX + 1, drawY + 1, boxWidth - 2, 28)
			end

			local dX = math.max(offsetX + 1, offsetX + boxWidth - 5)
			local dY = 1
			local dW = math.min(boxWidth - 2, 5)
			local dH = 28
			-- Draw the length dragger area.
			surface.SetDrawColor(Color(0, 0, 0, 50))
			surface.DrawRect(drawX + dX, drawY + dY, dW, dH)

			if (self.DragFrameLength and self.DragFrameLength == i) or (mouseX > dX and mouseX <= dX + dW and mouseY >= dY and mouseY <= dY + dH) then
				self:QueryCursor("sizewe")
				cursorChanged = true
			end

			-- Check to see if this frame is where the player wants to put the new frame.
			local l, c, r = offsetX, offsetX + boxWidth / 2, offsetX + boxWidth
			if (self.DraggingNewFrame or self.DraggingFrame) and mouseY >= 0 and mouseY <= 30 then
				if mouseX >= l and mouseX <= c then
					newFrameSpeculation = i
					newFrameSpeculationX = l - 2
				elseif mouseX >= c and mouseX <= r then
					newFrameSpeculation = i + 1
					newFrameSpeculationX = r - 1
				end
			end
		end

		if drawTime then
			local delta = (localTime - val.start) / val.l
			if delta >= 0 and delta < 1 then
				surface.SetDrawColor(Color(0, 255, 0))
				surface.DrawRect(drawX + offsetX + boxWidth * delta, drawY, 2, 30)
				drawTime = false
			end
		end
	end

	local offsetX = scrollOffsetX + HAT_DEFAULT_FRAME_SIZE * (entData.TotalTime or 0)

	if interactive and (self.DraggingNewFrame or self.DraggingFrame) then
		surface.SetDrawColor(Color(10, 150, 10))
		if newFrameSpeculationX then
			surface.DrawRect(drawX + newFrameSpeculationX, drawY, 4, 30)
		else
			surface.DrawRect(drawX + offsetX - 2, drawY, 4, 30)
		end
	end

	return cursorChanged
end

-- Desc: draws every entity's row (label + frame strip), scrolled both horizontally (shared
-- across rows) and vertically (through entities).
function PANEL:Paint(w, h)
	-- Frame border/background, inset to match the border hatskin draws
	-- around this panel's bounds.
	hatskin.drawFrameHolder(0, 0, w, h)

	if not next(self.Entities) then
		draw.SimpleText("Select a character or prop to start animating. (Right Click)", "Arial18",
			w / 2, h / 2, Color(120, 120, 120), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		self:QueryCursor("arrow")
		return
	end

	local padding = self:GetPadding()
	local frameAreaX = self:GetFrameAreaX()
	local rowsTopY = self:GetRowsTopY()
	local contentTall = self:GetContentTall()
	local contentWide = self:GetContentWide()
	local scrollOffsetY = self:GetScrollOffsetY()

	local mouseX, mouseY = self:ScreenToFrameSpace(gui.MouseX(), gui.MouseY())

	self:RecalculateFrameStarts()

	if self.StartTime then
		self.CurrentTime = CurTime() * HAT_PlayRate:GetFloat() - self.StartTime
	end
	local localTime = self.CurrentTime

	local cursorChanged = false
	local ids = self:GetOrderedEntityIds()

	-- Scrubber track + handle.
	surface.SetDrawColor(Color(0, 0, 0, 80))
	surface.DrawRect(frameAreaX, padding, contentWide, self.ScrubberHeight)

	local scrubX = self:TimeToX(localTime)
	if scrubX then
		surface.SetDrawColor(Color(0, 255, 0))
		surface.DrawRect(frameAreaX + scrubX - self.ScrubberHandleWidth / 2, padding, self.ScrubberHandleWidth,
			self.ScrubberHeight)
	end

	-- Clip the frame strips (but not the labels or the scrubber) to the rows viewport, so
	-- scrolled rows never spill upward into the scrubber strip or past the padding.
	local clipX0, clipY0 = self:LocalToScreen(frameAreaX, rowsTopY)
	render.SetScissorRect(clipX0, clipY0, clipX0 + contentWide, clipY0 + contentTall, true)

	for orderIndex, id in ipairs(ids) do
		local rowY = rowsTopY + (orderIndex - 1) * self.RowHeight - scrollOffsetY

		-- Skip rows that are entirely outside the visible area.
		if rowY + 30 >= rowsTopY and rowY <= rowsTopY + contentTall then
			local entData = self.Entities[id]
			local interactive = (id == self.CurEntity)

			local changed = self:PaintRow(entData, frameAreaX, rowY, interactive, mouseX, mouseY, true, localTime)
			if changed then cursorChanged = true end
		end
	end

	render.SetScissorRect(0, 0, 0, 0, false)

	-- Panel-local mouse position, for hovering a row's label to switch to it (matches the same
	-- full-row hit test OnMousePressed uses, so the cursor/highlight promise what a click will do).
	local plMouseX, plMouseY = self:ScreenToLocal(gui.MouseX(), gui.MouseY())
	local rowHovered = false

	for orderIndex, id in ipairs(ids) do
		local rowY = rowsTopY + (orderIndex - 1) * self.RowHeight - scrollOffsetY

		if rowY + 30 >= rowsTopY and rowY <= rowsTopY + contentTall then
			local entData = self.Entities[id]
			local interactive = (id == self.CurEntity)
			local hovered = not interactive and plMouseY >= rowY and plMouseY <= rowY + 30

			if interactive then
				surface.SetDrawColor(255, 255, 255, 10)
				surface.DrawRect(padding, rowY, self.LabelWidth, self.RowHeight)
			elseif hovered then
				surface.SetDrawColor(255, 255, 255, 20)
				surface.DrawRect(padding, rowY, self.LabelWidth, self.RowHeight)
				rowHovered = true
			end

			-- Fixed-width label, never wider than LabelWidth.
			local label = TruncateText(GetEntityLabel(id, entData), "DermaDefault", self.LabelWidth)
			draw.SimpleText(label, "DermaDefault", padding, rowY + 15, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end

	if rowHovered then
		self:QueryCursor("hand")
		cursorChanged = true
	end

	if not cursorChanged then
		self:QueryCursor("arrow")
	end
end

-- Desc: total pixel width of the longest entity's timeline (used for the shared horizontal
-- scroll-ratio math, and as the extent of the global scrubber). Pixel position is strictly
-- proportional to time (HAT_DEFAULT_FRAME_SIZE px/sec) so every row's frames and the shared
-- scrubber always land on the same x for the same time, regardless of how many frames an entity
-- has.
function PANEL:GetFramesSize()
	local maxLength = 0

	for _, entData in pairs(self.Entities) do
		local length = 0
		for _, val in pairs(entData.Frames) do
			length = length + val.l
		end
		maxLength = math.max(maxLength, HAT_DEFAULT_FRAME_SIZE * length)
	end

	return maxLength
end

-- ==================== 7. Stubs / legacy compatibility ====================

--[[---------------------------------------------------------
	SetColor
-----------------------------------------------------------]]
function PANEL:SetColor(col)

end

--[[---------------------------------------------------------
	SetKeepAspect
-----------------------------------------------------------]]
function PANEL:SetKeepAspect(bKeep)

end

-- This makes it compatible with the older ImageButton
PANEL.SetMaterial = PANEL.SetImage


--[[---------------------------------------------------------
	SizeToContents
-----------------------------------------------------------]]
function PANEL:SizeToContents()

end

-- ==================== 6. Mouse input + layout ====================

--[[---------------------------------------------------------
	OnMousePressed
-----------------------------------------------------------]]
-- Desc: left-click starts a length-drag, frame-hold, or (on the scrubber strip) a time-seek
-- drag.
function PANEL:OnMousePressed(mousecode)
	self:MouseCapture(true)

	local x, y = gui.MouseX(), gui.MouseY()
	local x, y = self:ScreenToLocal(x, y)

	if mousecode == MOUSE_LEFT then
		local padding = self:GetPadding()
		local frameAreaX = self:GetFrameAreaX()
		local contentWide = self:GetContentWide()

		if x >= frameAreaX and x <= frameAreaX + contentWide and y >= padding and y <= padding + self.ScrubberHeight then
			self.ScrubbingBar = true
			self:UpdateScrub(gui.MouseX())
			return
		end

		-- Clicking a different row (its label or its frame strip) selects that row's entity.
		local rowId = self:GetRowIdAtY(y)
		if rowId and rowId ~= self.CurEntity then
			RunConsoleCommand("hat_select_object", rowId - 1)
			return
		end
	end

	local frameHovered = self:GetFrameHovered()

	if mousecode == MOUSE_LEFT then
		self.DragFrameLength = self:GetIncreaseLengthFrame()

		if self.DragFrameLength then
			self.DragFrameLengthO = self.Entities[self.CurEntity].Frames[self.DragFrameLength].l
			self.DragFrameMouseX = x
		else
			if frameHovered then
				self.HoldingFrame = frameHovered
			end
		end
	end
end

--[[---------------------------------------------------------
	OnMouseReleased
-----------------------------------------------------------]]
-- Desc: on release, sends the resulting hat_frame_setlength/hat_frame_select/hat_frame_move command.
function PANEL:OnMouseReleased(mousecode)
	local wasScrubbing = self.ScrubbingBar

	self.Dragging = false
	self.DraggingY = false
	self.DraggingCanvas = nil
	self.ScrubbingBar = false
	self:MouseCapture(false)

	self.btnGrip.Depressed = false
	self.btnGripY.Depressed = false

	if wasScrubbing then return end

	if mousecode == MOUSE_LEFT then
		if self.DragFrameLength and self.Entities[self.CurEntity].Frames[self.DragFrameLength].l ~= self.DragFrameLengthO then
			RunConsoleCommand("hat_frame_setlength", self.DragFrameLength,
				self.Entities[self.CurEntity].Frames[self.DragFrameLength].l)
		else
			RunConsoleCommand("hat_frame_select", self.HoldingFrame or self.DragFrameLength)
		end
		if self.DraggingFrame then
			local newFrame = self:GetNewFrame()
			if newFrame > self.HoldingFrame then
				newFrame = newFrame - 1
			end

			RunConsoleCommand("hat_frame_move", self.HoldingFrame, newFrame)

			self.DraggingFrame = nil
		end
		self.HoldingFrame = nil
		self.DragFrameLength = nil
	end

	self:PerformLayout()
end

--[[---------------------------------------------------------

-----------------------------------------------------------]]
-- Desc: scrolls through entity rows (or, with Shift held, through the frame strip horizontally)
-- on mouse wheel, easing towards the target ratio in Think rather than snapping instantly.
function PANEL:OnMouseWheeled(delta)
	if (! self.Enabled) then return end

	local pixels = delta * self.RowHeight

	if input.IsShiftDown() then
		if (not self.BarSize or self.BarSize == 0) then return end
		local fullBarSizeX = self:GetContentWide()
		local target = self.ScrollRatioTarget or self.ScrollRatio
		self.ScrollRatioTarget = math.Clamp(target - pixels / (fullBarSizeX - self.BarSize + 1), 0, 1)
	else
		if (not self.BarSizeY or self.BarSizeY == 0) then return end
		local fullBarSizeY = self:GetContentTall()
		local target = self.ScrollRatioYTarget or self.ScrollRatioY
		self.ScrollRatioYTarget = math.Clamp(target - pixels / (fullBarSizeY - self.BarSizeY + 1), 0, 1)
	end

	return true
end

function PANEL:PerformLayout()
	local padding = self:GetPadding()
	local contentWide = self:GetContentWide()
	local contentTall = self:GetContentTall()
	local ids = self:GetOrderedEntityIds()

	if #ids == 0 then
		self.btnGrip:SetVisible(false)
		self.btnGripY:SetVisible(false)
		return
	end

	self.btnGrip:SetVisible(true)
	self.btnGripY:SetVisible(true)

	-- Horizontal scrollbar (shared across all rows).
	self.FramesSize = self:GetFramesSize()
	local ratioX = contentWide / math.max(self.FramesSize, 1)

	if self.LastFramesSize != self.FramesSize then
		self.ScrollRatio = math.Clamp(
		(self.ScrollRatio * (self.LastFramesSize - contentWide) / (self.FramesSize - contentWide)), 0, 1)
	end

	if ratioX > 1 then
		self.ScrollRatio = 0
		ratioX = 1
	end

	local fullBarSizeX = contentWide
	self.BarSize = fullBarSizeX * ratioX

	local frameAreaX = self:GetFrameAreaX()
	self.btnGrip:SetPos(frameAreaX + self.ScrollRatio * (fullBarSizeX - self.BarSize + 1),
		self:GetTall() - self.HScrollHeight - padding)
	self.btnGrip:SetSize(self.BarSize, self.HScrollHeight)

	-- Vertical scrollbar (through entity rows).
	local totalTall = math.max(#ids * self.RowHeight, 1)
	local ratioY = contentTall / totalTall

	if ratioY > 1 then
		self.ScrollRatioY = 0
		ratioY = 1
	end

	local fullBarSizeY = contentTall
	self.BarSizeY = fullBarSizeY * ratioY

	self.btnGripY:SetPos(self:GetWide() - padding - self.VScrollWidth,
		self:GetRowsTopY() + self.ScrollRatioY * (fullBarSizeY - self.BarSizeY + 1))
	self.btnGripY:SetSize(self.VScrollWidth, self.BarSizeY)

	self.LastFramesSize = self.FramesSize
end

--[[---------------------------------------------------------
   Name: Grip
-----------------------------------------------------------]]
-- Desc: starts a horizontal scrollbar drag.
function PANEL:Grip()
	if (! self.Enabled) then return end
	if (self.BarSize == 0) then return end

	self:MouseCapture(true)
	self.Dragging = true

	local x, y = gui.MouseX(), 0
	local x, y = self.btnGrip:ScreenToLocal(x, y)
	self.HoldPos = x

	self.btnGrip.Depressed = true
end

--[[---------------------------------------------------------
   Name: GripY
-----------------------------------------------------------]]
-- Desc: starts a vertical scrollbar drag.
function PANEL:GripY()
	if (! self.Enabled) then return end
	if (self.BarSizeY == 0) then return end

	self:MouseCapture(true)
	self.DraggingY = true

	local lx, ly = self.btnGripY:ScreenToLocal(0, gui.MouseY())
	self.HoldPosY = ly

	self.btnGripY.Depressed = true
end

--[[---------------------------------------------------------

-----------------------------------------------------------]]
function PANEL:SetDisabled(bDisabled)
	DButton.SetDisabled(self, bDisabled)
end

--[[---------------------------------------------------------

-----------------------------------------------------------]]
function PANEL:SetOnViewMaterial(MatName, Backup)

end

--[[---------------------------------------------------------
   Name: GenerateExample
-----------------------------------------------------------]]
function PANEL:GenerateExample(ClassName, PropertySheet, Width, Height)

end

derma.DefineControl("DFrameHolder", "Holds frames.", PANEL, "DPanel")
