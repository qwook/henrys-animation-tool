--[[   _
    ( )
   _| |   __   _ __   ___ ___     _ _
 /'_` | /'__`\( '__)/' _ ` _ `\ /'_` )
( (_| |(  ___/| |   | ( ) ( ) |( (_| |
`\__,_)`\____)(_)   (_) (_) (_)`\__,_)

	DFrameHolder - the frame-strip timeline widget. It owns the animation data (one entry per
	entity, each with its own frame list) and the shared timeline geometry, and coordinates three
	kinds of child panel that do the actual drawing and interacting:

	  * DHATScrubber (dhatscrubber.lua) - the ruler strip and playhead, drag-to-seek.
	  * DHATRow      (dhatrow.lua)      - one entity's label + strip of frame blocks. Pooled per
	                                      entity id, and drawn/hit-tested by this panel rather
	                                      than by Derma (see the header of dhatrow.lua for why).
	  * DHATScrollbar(dhatscrollbar.lua)- one per axis; owns its grip, its drag and its easing.

	What's left here, organized below into:
	  1. Init / state
	  2. Entity ordering + row pool
	  3. Geometry (content rects, scroll offsets, coordinate conversions)
	  4. Entity + frame data (Load/SetEntity/New/Remove/Move Frame) and timeline math
	  5. Playback (Play/Stop) + Think
	  6. Rendering (Paint)
	  7. Mouse input + PerformLayout
	  8. Stubs / legacy compatibility shims

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
	self.ScrubberHeight = 16
	self.ScrubberGap = 4
	self.ScrubberHandleWidth = 5

	self.Entities = {}
	self.CurEntity = 1
	self.EntityOrder = {} -- client-only display order for entity rows; see GetOrderedEntityIds.
	self.Rows = {}        -- id -> DHATRow, created on demand by GetRow.

	self.FramesSize = self:GetFramesSize()
	self.LastFramesSize = self.FramesSize

	self:SetColor(Color(255, 255, 255, 255))

	self.DraggingNewFrame = false
	self.HoldingFrame = false
	self.DraggingFrame = false

	self.HoldingRow = nil
	self.DraggingRow = false

	self.DragFrameLength = nil
	self.DragFrameMouseX = 0
	self.DragFrameLengthO = 0

	self.CurrentTime = 0

	self.Cursor = ""

	local holder = self

	-- Desc: clips whatever the rows inside it draw (label highlight, model icon, frame strip -
	-- including frames that overflow past the horizontal scroll offset) to its own bounds, via
	-- VGUI's native per-panel clipping - see LayoutRows below. Replaces the old manual
	-- render.SetScissorRect calls for the vertical (row-scrolling) axis; the frame strip's own
	-- horizontal scroll stays immediate-mode inside each row's Paint, same as before.
	self.rowsViewport = vgui.Create("DPanel", self)
	self.rowsViewport:SetPaintBackground(false)
	self.rowsViewport:SetMouseInputEnabled(false)

	self.scrubber = vgui.Create("DHATScrubber", self)
	self.scrubber.Holder = self
	self.scrubber.HandleWidth = self.ScrubberHandleWidth
	self.scrubber.OnScrub = function(_, time) holder:OnScrubbed(time) end

	-- Both scrollbars report back the same way: re-lay-out (which repositions their own grips
	-- against the possibly-changed timeline length) so the next Paint uses the new offset.
	self.hScroll = vgui.Create("DHATScrollbar", self)
	self.hScroll:SetOrientation("horizontal")
	self.hScroll.OnUserScroll = function() holder:PerformLayout() end

	self.vScroll = vgui.Create("DHATScrollbar", self)
	self.vScroll:SetOrientation("vertical")
	self.vScroll.OnUserScroll = function() holder:PerformLayout() end

	self:SetCursor("arrow")
end

-- Desc: local (client-only) frame record: length + easing (mirrors the server's frame.easing/
-- easingStrength, kept in sync by hat_frame_easing) + a random display color used purely for drawing.
local function newFrame(length, easing, easingStrength)
	return {
		l = length,
		easing = easing or "linear",
		easingStrength = easingStrength or "normal",
		cA = { 0.5, 0.5 },
		cB = { 0.5, 0.5 },
		c = Color(math.random(180, 225), math.random(180, 225), math.random(180, 225))
	}
end

-- Desc: sets the panel's mouse cursor only when it actually changes (avoids redundant SetCursor calls).
function PANEL:QueryCursor(cursor)
	if self.Cursor == cursor then return end

	self.Cursor = cursor
	self:SetCursor(cursor)
end

-- ==================== 2. Entity ordering + row pool ====================

-- Desc: top-to-bottom order for entity rows. Keeps self.EntityOrder's existing relative order
-- (which Shift Up/Down and drag-to-reorder mutate - see DHATRow:OpenLabelContextMenu/
-- ReorderEntityRow), drops any ids that no longer exist, and appends any new/never-seen ids
-- (ascending) at the bottom - so freshly added/loaded entities show up without disturbing rows
-- the user already reordered.
function PANEL:GetOrderedEntityIds()
	local ordered = {}
	local seen = {}

	for _, id in ipairs(self.EntityOrder) do
		if self.Entities[id] then
			table.insert(ordered, id)
			seen[id] = true
		end
	end

	local newIds = {}
	for id in pairs(self.Entities) do
		if not seen[id] then table.insert(newIds, id) end
	end
	table.sort(newIds)

	for _, id in ipairs(newIds) do
		table.insert(ordered, id)
	end

	self.EntityOrder = ordered
	return ordered
end

-- Desc: swaps an entity row with its immediate upward/downward neighbor (delta -1/+1). No-op if
-- id isn't tracked or there's no neighbor in that direction (already at the top/bottom).
function PANEL:ShiftEntityRow(id, delta)
	local ids = self:GetOrderedEntityIds()
	local idx
	for i, v in ipairs(ids) do
		if v == id then
			idx = i
			break
		end
	end
	if not idx then return end

	local swapIdx = idx + delta
	if swapIdx < 1 or swapIdx > #ids then return end

	ids[idx], ids[swapIdx] = ids[swapIdx], ids[idx]
	self.EntityOrder = ids
end

-- Desc: moves fromId to sit where toId currently is (used by label drag-to-reorder). Same
-- remove-then-insert idiom as PANEL:MoveFrame.
function PANEL:ReorderEntityRow(fromId, toId)
	local ids = self:GetOrderedEntityIds()
	local fromIdx, toIdx

	for i, v in ipairs(ids) do
		if v == fromId then fromIdx = i end
		if v == toId then toIdx = i end
	end
	if not fromIdx or not toIdx then return end

	table.remove(ids, fromIdx)
	table.insert(ids, toIdx, fromId)
	self.EntityOrder = ids
end

-- Desc: the DHATRow standing in for entity id, created on demand and re-bound to that entity's
-- current data every time (rows are pooled by id, and the data table behind an id can be
-- replaced wholesale by Load/SetEntity).
function PANEL:GetRow(id)
	local row = self.Rows[id]
	if not IsValid(row) then
		row = vgui.Create("DHATRow", self.rowsViewport)
		row.Holder = self
		self.Rows[id] = row
	end

	row:SetRow(id, self.Entities[id])
	return row
end

function PANEL:RemoveRow(id)
	if IsValid(self.Rows[id]) then self.Rows[id]:Remove() end
	self.Rows[id] = nil
end

-- Desc: the row for the entity currently being edited, or nil when there isn't one. The only
-- row that's interactive - everything else just draws.
function PANEL:GetCurrentRow()
	if not self.Entities[self.CurEntity] then return nil end
	return self:GetRow(self.CurEntity)
end

-- ==================== 3. Geometry ====================

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

-- Desc: height of the vertical scrollbar's own track, measured from the top of the scrubber
-- strip (where the thumb is positioned - see PerformLayout) rather than from the top of the rows
-- viewport. Only for sizing/positioning the vertical scrollbar; scroll math and row visibility
-- must keep using GetContentTall, since rows still start at GetRowsTopY(), below the scrubber.
function PANEL:GetScrollbarTrackTall()
	return math.max(
		self:GetTall() - self:GetPadding() * 2 - self.HScrollHeight - self.RowGap, 0)
end

-- Desc: x position (panel-local) where the scrollable frame strip starts, after the label column.
function PANEL:GetFrameAreaX()
	return self:GetPadding() + self.LabelWidth + self.LabelGap
end

-- Desc: y position (panel-local) where the entity rows start, below the scrubber strip.
function PANEL:GetRowsTopY()
	return self:GetPadding() + self.ScrubberHeight + self.ScrubberGap
end

function PANEL:GetScrubberTopY()
	return self:GetPadding()
end

-- Desc: current horizontal scroll offset in pixels (negative - it's added to a frame's x), shared
-- by every row, the scrubber's ticks and all hit-testing, so they can never drift apart.
function PANEL:GetScrollOffsetX()
	return math.floor(-self.hScroll:GetScrollRatio() * (self.FramesSize - self:GetContentWide()))
end

-- Desc: current vertical scroll offset in pixels, derived from the vertical scrollbar's ratio.
function PANEL:GetScrollOffsetY()
	local totalTall = #self:GetOrderedEntityIds() * self.RowHeight
	local maxScroll = math.max(totalTall - self:GetContentTall(), 0)
	return self.vScroll:GetScrollRatio() * maxScroll
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

-- ==================== 4. Entity + frame data ====================

-- Desc: rebuilds self.Entities (display-only frame list) from a hat_send_data payload.
function PANEL:Load(toLoad)
	self.Entities = {}
	for id in pairs(self.Rows) do
		self:RemoveRow(id)
	end

	-- Desc: v.order (set by hat_save from the client's row order - see DHATMenu's save()) is
	-- collected here (into orderOf, keyed by the client-space id) and sorted below into
	-- EntityOrder. Objects with no order (older saves, or a save made without going through the
	-- dialog) sort after every ordered one, in ascending id order - i.e. pushed to the bottom,
	-- same as GetOrderedEntityIds' own new-id fallback.
	--
	-- orderOf is read from v directly rather than re-indexing toLoad.objects[id] in the sort
	-- comparator: hat_save now drops empty Face/LHand/RHand objects, which leaves holes in the
	-- saved key range, so util.TableToJSON encodes it as a JSON object (string keys) instead of an
	-- array - re-indexing by a freshly computed numeric key would silently miss.
	local ordered, unordered, orderOf = {}, {}, {}

	for k, v in pairs(toLoad.objects) do
		local id = tonumber(k) + 1
		self.Entities[id] = {
			Frames = {},
			SelectedFrame = 1,
			Ent = ents.GetByIndex(v.ent),
			PoseType = v.posetype
		}
		for frame, v in ipairs(v.frames) do
			self.Entities[id].Frames[frame] = newFrame(v.l, v.easing, v.easingStrength)
		end

		if v.order then
			orderOf[id] = v.order
			table.insert(ordered, id)
		else
			table.insert(unordered, id)
		end
	end
	self.CurEntity = (toLoad.currentObjId or 0) + 1

	table.sort(ordered, function(a, b) return orderOf[a] < orderOf[b] end)
	table.sort(unordered)

	self.EntityOrder = ordered
	for _, id in ipairs(unordered) do
		table.insert(self.EntityOrder, id)
	end

	-- Unlike SetEntity/NewFrame/MoveFrame, this can run while self.FramesSize is still the stale
	-- 0 it was initialized with (loading a save is the very first action taken) - without this,
	-- TimeToX/XToTime keep treating the timeline as empty and the scrubber never works.
	self:PerformLayout()
end

-- Desc: switches the displayed entity, creating a default empty entry if id is new, and jumps
-- the vertical scroll so its row is visible.
function PANEL:SetEntity(id, ent, posetype)
	self.CurEntity = id
	self.Entities[id] = self.Entities[id] or { Frames = {}, SelectedFrame = 1 }
	self.Entities[id].Ent = ent
	self.Entities[id].PoseType = posetype
	self.LastFramesSize = self:GetFramesSize()
	self:JumpToEntity(id)
	self:PerformLayout()
end

function PANEL:RemoveEntity(id)
	self.Entities[id] = nil
	self:RemoveRow(id)
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

-- Desc: mirrors a server-side HAT.setFrameEasing call (see hat_frame_easing net message).
function PANEL:SetFrameEasing(id, frame, easing, easingStrength)
	local entData = self.Entities[id]
	local frameData = entData and entData.Frames[frame]
	if not frameData then return end

	frameData.easing = easing
	frameData.easingStrength = easingStrength
end

-- Desc: relocates a display-only frame within the current entity's strip.
function PANEL:MoveFrame(id, frameFrom, frameTo)
	local frame = self.Entities[self.CurEntity].Frames[frameFrom]
	self:RemoveFrame(self.CurEntity, frameFrom)
	table.insert(self.Entities[self.CurEntity].Frames, frameTo, frame)
	self:PerformLayout()
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

-- Desc: scrolls vertically so the given entity's row is at the top of the visible area. Eases
-- there over time (the scrollbar lerps towards the target ratio) rather than snapping instantly,
-- so switching the selected prop glides the view instead of jump-cutting it.
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
		self.vScroll:SetScrollRatioTarget(0)
		return
	end

	local targetOffset = math.Clamp((idx - 1) * self.RowHeight, 0, maxScroll)
	self.vScroll:SetScrollRatioTarget(targetOffset / maxScroll)
end

-- Desc: hit-testing entry points for the current entity's row. They live here (rather than being
-- called on the row directly) because they all measure from the mouse against the shared
-- timeline: only the parent knows the scroll offset and which row is the interactive one.

-- Desc: index where a new frame would be inserted, based on which half of the hovered frame the
-- mouse is over.
function PANEL:GetNewFrame()
	local row = self:GetCurrentRow()
	if not row then return 0 end

	local x = self:ScreenToFrameSpace(gui.MouseX(), gui.MouseY())
	return row:GetNewFrameIndex(x, self:GetScrollOffsetX())
end

-- Desc: index of the frame whose right-edge resize handle the mouse is over, if any.
function PANEL:GetIncreaseLengthFrame()
	local row = self:GetCurrentRow()
	if not row then return end

	local x = self:ScreenToFrameSpace(gui.MouseX(), gui.MouseY())
	return row:GetIncreaseLengthFrame(x, self:GetScrollOffsetX())
end

-- Desc: index of the frame currently under the mouse (or being dragged), if any.
function PANEL:GetFrameHovered()
	local row = self:GetCurrentRow()
	if not row then return end

	local x, y = self:ScreenToFrameSpace(gui.MouseX(), gui.MouseY())
	return row:GetFrameHovered(x, y, self:GetScrollOffsetX())
end

-- Desc: builds the Easing menu for a frame of the current entity. Kept as a method here because
-- dhatmenu.lua's Easing select box calls it on the frame holder; the menu itself belongs to the
-- row that owns the frame.
function PANEL:BuildEasingMenu(menu, frame, frameData)
	self:GetRow(self.CurEntity):BuildEasingMenu(menu, frame, frameData)
end

-- Desc: pixel x (frame-area-relative, includes horizontal scroll) for timeline time `time`
-- seconds. Strictly linear (HAT_DEFAULT_FRAME_SIZE px/sec), so it lines up with every row's frame
-- boxes regardless of which entity is current, and isn't bounded by any single entity's own
-- timeline length. nil if there's nothing on the timeline at all.
function PANEL:TimeToX(time)
	if self.FramesSize <= 0 then return nil end

	return self:GetScrollOffsetX() + HAT_DEFAULT_FRAME_SIZE * math.max(time, 0)
end

-- Desc: inverse of TimeToX: seconds into the global timeline that pixel x (frame-area-relative)
-- corresponds to, clamped to [0, the longest entity's total length].
function PANEL:XToTime(x)
	if self.FramesSize <= 0 then return 0 end

	local maxTime = self:GetTrueFramesSize() / HAT_DEFAULT_FRAME_SIZE

	return math.Clamp((x - self:GetScrollOffsetX()) / HAT_DEFAULT_FRAME_SIZE, 0, maxTime)
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

-- Desc: the scrubber reports a new time (continuously, while it's being dragged): tell the server
-- to apply that pose (hat_seek), and locally select the frame under the playhead for editing
-- without changing the server's "current frame" cursor. The scrubber measures against the global
-- (longest-entity) timeline, so this can seek past the current entity's own frames; its selected
-- frame is then clamped to its last one.
function PANEL:OnScrubbed(time)
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

-- Desc: extra scrollable space kept past the last frame, so its right edge is never flush with
-- the end of the scroll range - otherwise there'd be nowhere to drop the cursor to grab-drag it
-- wider.
local FRAMES_SIZE_TRAILING_BUFFER = 200

-- Desc: true pixel length of the longest entity's frames, with no trailing buffer - the actual
-- end of the timeline, and the maximum meaningful scrub time (see XToTime). Contrast with
-- GetFramesSize(), which pads this out with extra scroll room so the last frame is easy to
-- grab-resize; using the padded size for scrub bounds would let the playhead be dragged past the
-- real end of the timeline into that empty buffer space.
function PANEL:GetTrueFramesSize()
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

-- Desc: total pixel width of the longest entity's timeline (used for the shared horizontal
-- scroll-ratio math, and as the extent of the global scrubber). Pixel position is strictly
-- proportional to time (HAT_DEFAULT_FRAME_SIZE px/sec) so every row's frames and the shared
-- scrubber always land on the same x for the same time, regardless of how many frames an entity
-- has.
function PANEL:GetFramesSize()
	local maxLength = self:GetTrueFramesSize()

	if maxLength <= 0 then return maxLength end

	return maxLength + FRAMES_SIZE_TRAILING_BUFFER
end

-- ==================== 5. Playback ====================

-- Desc: begins synced playback `offset` seconds into the timeline, measured from this client's
-- own clock so the scrubber doesn't depend on the server and client clocks lining up.
function PANEL:Play(offset)
	self.StartTime = CurTime() * HAT_PlayRate:GetFloat() - offset
end

function PANEL:Stop()
	self.StartTime = nil
end

-- Desc: per-frame update for everything that isn't a scrollbar drag or a scrub (those live on the
-- panels that own them): right-click-hold to pan, the pan itself, frame-length dragging, and
-- drag-vs-click detection for frames and rows.
function PANEL:Think()
	-- Promote a held right-click into a pan (mirrors middle-click pan below) once the mouse has
	-- moved past a small deadzone, cancelling whatever context menu/select it would otherwise
	-- have opened on release.
	if self.PendingRightClick and not self.RightClickDeadzonePassed then
		local dx = gui.MouseX() - self.RightClickStartMouseX
		local dy = gui.MouseY() - self.RightClickStartMouseY
		if dx * dx + dy * dy >= 5 * 5 then
			self.RightClickDeadzonePassed = true
			self.PendingRightClick = false
			self.PendingRightClickAction = nil

			self:StartPanning()
		end
	end

	-- Middle-click grab-and-drag pan: moves both scrollbars at once, directly under the cursor
	-- (dragging right/down reveals earlier content, like grabbing the canvas itself).
	if self.Panning then
		local dx = gui.MouseX() - self.PanStartMouseX
		local dy = gui.MouseY() - self.PanStartMouseY

		local rangeX = self.FramesSize - self:GetContentWide()
		if rangeX > 0 then
			local ratio = math.Clamp(self.PanStartRatio - dx / rangeX, 0, 1)
			self.hScroll:SetScrollRatio(ratio)
			self.hScroll:SetScrollRatioTarget(ratio)
		end

		local ids = self:GetOrderedEntityIds()
		local rangeY = #ids * self.RowHeight - self:GetContentTall()
		if rangeY > 0 then
			local ratio = math.Clamp(self.PanStartRatioY - dy / rangeY, 0, 1)
			self.vScroll:SetScrollRatio(ratio)
			self.vScroll:SetScrollRatioTarget(ratio)
		end

		self:PerformLayout()
	end

	local x, y = gui.MouseX(), 0
	local x, y = self:ScreenToLocal(x, y)

	if self.DragFrameLength then
		local rawLength = self.DragFrameLengthO + (x - self.DragFrameMouseX) / HAT_DEFAULT_FRAME_SIZE
		local snapIncrement = HAT_DEFAULT_LENGTH / 4
		local snappedLength = math.Round(rawLength / snapIncrement) * snapIncrement

		-- Frames can never be dragged down to zero length (or a strip you can no longer see or
		-- grab to resize back).
		self.Entities[self.CurEntity].Frames[self.DragFrameLength].l = math.max(snappedLength, snapIncrement)
	end

	if self.HoldingFrame and self.HoldingFrame ~= self:GetFrameHovered() then
		self.DraggingFrame = true
	end

	if self.HoldingRow then
		local _, my = self:ScreenToLocal(0, gui.MouseY())
		if self.HoldingRow ~= self:GetRowIdAtY(my) then
			self.DraggingRow = true
		end
	end
end

-- ==================== 6. Rendering ====================

-- Desc: positions/shows every currently-ordered entity row inside rowsViewport, and hides any
-- pooled row (see GetRow) that dropped out of the order (removed, or a stale entry no longer in
-- self.Entities). Each visible row then paints itself - label and frame strip both - via its own
-- Paint hook (dhatrow.lua), clipped to rowsViewport's bounds by VGUI natively. Called every Paint
-- (not just PerformLayout) since the vertical scroll offset eases continuously between discrete
-- layout events.
function PANEL:LayoutRows()
	local ids = self:GetOrderedEntityIds()
	local scrollOffsetY = self:GetScrollOffsetY()
	local viewportW = self.rowsViewport:GetWide()

	local visible = {}

	for orderIndex, id in ipairs(ids) do
		visible[id] = true

		local row = self:GetRow(id)
		row:SetSize(viewportW, 30)
		row:SetPos(0, (orderIndex - 1) * self.RowHeight - scrollOffsetY)
		row:SetVisible(true)
	end

	for id, row in pairs(self.Rows) do
		if not visible[id] and IsValid(row) then
			row:SetVisible(false)
		end
	end
end

-- Desc: resolves the mouse cursor purely from hit-tests, independent of row painting (which now
-- happens as a deferred child-paint after this panel's own Paint returns, so it can no longer
-- report "did a row want a special cursor" back into the same frame's decision the way the old
-- single combined Paint pass could). sizewe over the current row's length-drag handle (or while
-- actively dragging it), hand over a hoverable (non-current) row, sizeall while panning, arrow
-- otherwise.
function PANEL:UpdateCursor()
	if self.Panning then
		self:QueryCursor("sizeall")
		return
	end

	if self.DragFrameLength or self:GetIncreaseLengthFrame() then
		self:QueryCursor("sizewe")
		return
	end

	local _, my = self:ScreenToLocal(0, gui.MouseY())
	local rowId = self:GetRowIdAtY(my)
	if rowId and rowId ~= self.CurEntity then
		self:QueryCursor("hand")
		return
	end

	self:QueryCursor("arrow")
end

-- Desc: draws this panel's own background/empty-state text, refreshes the shared playback clock,
-- and lays out the row panels (which paint themselves afterwards - see LayoutRows). The scrubber
-- and the scrollbars are real child panels too, so they paint themselves on top, after this.
function PANEL:Paint(w, h)
	-- Frame border/background, inset to match the border hatskin draws
	-- around this panel's bounds.
	hatskin.drawFrameHolder(0, 0, w, h)

	if not next(self.Entities) then
		-- Checked here (rather than in PerformLayout) so the empty state appears the moment the
		-- data empties out, whether or not anything has invalidated the layout.
		self.scrubber.DrawEnabled = false

		draw.SimpleText("Select a character or prop to start animating. (Right Click)", "Arial18",
			w / 2, h / 2, Color(120, 120, 120), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	else
		self.scrubber.DrawEnabled = true

		self:RecalculateFrameStarts()

		if self.StartTime then
			self.CurrentTime = CurTime() * HAT_PlayRate:GetFloat() - self.StartTime
		end
	end

	self:LayoutRows()
	self:UpdateCursor()
end

-- ==================== 7. Mouse input + layout ====================

-- Desc: starts a grab-and-drag pan of both axes at once, remembering where both scrollbars and
-- the cursor were so Think can move them as one.
function PANEL:StartPanning()
	self.Panning = true
	self.PanStartMouseX, self.PanStartMouseY = gui.MouseX(), gui.MouseY()
	self.PanStartRatio = self.hScroll:GetScrollRatio()
	self.PanStartRatioY = self.vScroll:GetScrollRatio()
	self:QueryCursor("sizeall")
end

--[[---------------------------------------------------------
	OnMousePressed
-----------------------------------------------------------]]
-- Desc: left-click starts a length-drag, frame-hold, or label-hold (for row drag-to-reorder);
-- middle-click starts a grab-and-drag pan across both scrollbars at once; right-click never
-- resolves immediately - it's held pending (see Think/OnMouseReleased) so a plain click opens a
-- frame's/row label's context menu or falls through to the parent's world-entity-select only on
-- release, while dragging past a small deadzone before releasing pans instead (and cancels that
-- pending action), same as middle-click (for players without a middle mouse button). Returns true
-- for every right-click (it's always at least pending), so the parent (DHATMenu) never does its
-- own right-click handling.
--
-- Clicks on the scrubber strip and on either scrollbar track never reach here - those are their
-- own panels now - except that both hand their non-left presses straight back to this function,
-- so pan/right-click gestures still work anywhere over the widget.
function PANEL:OnMousePressed(mousecode)
	self:MouseCapture(true)

	if mousecode == MOUSE_MIDDLE then
		self:StartPanning()
		return
	end

	local x, y = gui.MouseX(), gui.MouseY()
	local x, y = self:ScreenToLocal(x, y)
	local frameAreaX = self:GetFrameAreaX()

	if mousecode == MOUSE_RIGHT then
		-- Never resolve on press - wait to see whether this turns into a drag-to-pan (Think
		-- promotes this past RightClickDeadzone, which cancels it) or a plain click on release
		-- (see OnMouseReleased), which is when whatever this would've opened/selected actually
		-- happens. Figured out now (rather than at release) so it reflects what was under the
		-- cursor at press time, matching the old click-opens-immediately behavior.
		local rowId = self:GetRowIdAtY(y)
		if rowId and x < frameAreaX then
			self.PendingRightClickAction = function() self:GetRow(rowId):OpenLabelContextMenu() end
		else
			local frameHovered = self:GetFrameHovered()
			if frameHovered then
				self.PendingRightClickAction = function()
					local row = self:GetCurrentRow()
					if row then row:OpenFrameContextMenu(frameHovered) end
				end
			else
				self.PendingRightClickAction = function()
					if self.OnRightClickResolved then self:OnRightClickResolved() end
				end
			end
		end

		self.PendingRightClick = true
		self.RightClickDeadzonePassed = false
		self.RightClickStartMouseX, self.RightClickStartMouseY = gui.MouseX(), gui.MouseY()
		return true
	end

	if mousecode == MOUSE_LEFT then
		local rowId = self:GetRowIdAtY(y)

		if rowId and x < frameAreaX then
			-- Grabbing a row's label: don't switch entity yet - wait to see whether this turns
			-- into a drag-to-reorder (Think promotes HoldingRow -> DraggingRow) or resolves as a
			-- plain click-to-select on release (see OnMouseReleased).
			self.HoldingRow = rowId
			return
		end

		-- Clicking a different row's frame strip still switches to it immediately.
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
-- Desc: on release, sends the resulting hat_frame_setlength/hat_frame_select/hat_frame_move
-- command. Also runs for a release that ended a scrollbar drag (the scrollbar forwards it), which
-- is how scrubbing/scrolling has always doubled as a "stop playback" nudge via hat_frame_select.
function PANEL:OnMouseReleased(mousecode)
	self.hScroll:AbortDrag()
	self.vScroll:AbortDrag()

	self.DraggingCanvas = nil
	self.Panning = false
	self:MouseCapture(false)

	if mousecode == MOUSE_RIGHT and self.PendingRightClick then
		-- Deadzone never passed, so this was a plain right-click rather than a pan - run whatever
		-- OnMousePressed decided it should do (open a context menu, or the parent's
		-- world-entity-select) now, on release, instead of on press.
		local action = self.PendingRightClickAction
		self.PendingRightClick = false
		self.PendingRightClickAction = nil
		if action then action() end
		return
	end
	self.PendingRightClick = false
	self.PendingRightClickAction = nil

	if mousecode == MOUSE_LEFT and self.HoldingRow then
		if self.DraggingRow then
			local _, my = self:ScreenToLocal(0, gui.MouseY())
			local dropId = self:GetRowIdAtY(my)
			if dropId and dropId ~= self.HoldingRow then
				self:ReorderEntityRow(self.HoldingRow, dropId)
			end
		elseif self.HoldingRow ~= self.CurEntity then
			RunConsoleCommand("hat_select_object", self.HoldingRow - 1)
		end

		self.HoldingRow = nil
		self.DraggingRow = false
		self:PerformLayout()
		return
	end

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
-- on mouse wheel, easing towards the target ratio rather than snapping instantly. Lets the event
-- bubble when that axis has nothing to scroll.
function PANEL:OnMouseWheeled(delta)
	if (! self.Enabled) then return end

	local pixels = delta * self.RowHeight

	if input.IsShiftDown() then
		if not self.hScroll:ScrollByPixels(pixels) then return end
	else
		if not self.vScroll:ScrollByPixels(pixels) then return end
	end

	return true
end

function PANEL:PerformLayout()
	local padding = self:GetPadding()
	local contentWide = self:GetContentWide()
	local contentTall = self:GetContentTall()
	local frameAreaX = self:GetFrameAreaX()
	local ids = self:GetOrderedEntityIds()

	-- The scrubber keeps its bounds even with nothing on the timeline: it stops drawing (see
	-- Paint) but a click in the strip still seeks, as it did when this panel drew it itself.
	self.scrubber:SetPos(frameAreaX, self:GetScrubberTopY())
	self.scrubber:SetSize(contentWide, self.ScrubberHeight)

	-- rowsViewport spans the label column + gap + frame strip (i.e. everything GetContentWide
	-- already excludes the label/gap for), so its width adds LabelWidth+LabelGap back on top.
	self.rowsViewport:SetPos(padding, self:GetRowsTopY())
	self.rowsViewport:SetSize(math.max(self:GetWide() - padding * 2 - self.VScrollWidth, 0), contentTall)

	if #ids == 0 then
		self.hScroll:SetVisible(false)
		self.vScroll:SetVisible(false)
		return
	end

	self.hScroll:SetVisible(true)
	self.vScroll:SetVisible(true)

	-- Horizontal scrollbar (shared across all rows). When the timeline's length changes, the
	-- scroll ratio is rescaled so the view stays looking at the same pixel offset instead of
	-- sliding as the content grows.
	self.FramesSize = self:GetFramesSize()

	if self.LastFramesSize != self.FramesSize then
		self.hScroll:SetScrollRatio(math.Clamp(
			(self.hScroll:GetScrollRatio() * (self.LastFramesSize - contentWide) / (self.FramesSize - contentWide)), 0, 1))
	end

	self.hScroll:SetPos(frameAreaX, self:GetTall() - self.HScrollHeight - padding)
	self.hScroll:SetSize(contentWide, self.HScrollHeight)
	self.hScroll:SetSizes(self.FramesSize, contentWide)

	-- Vertical scrollbar (through entity rows). Its track spans from the top of the scrubber
	-- strip, which is longer than the rows viewport - the thumb is still sized against the
	-- viewport (GetContentTall), since that's what's actually visible. Keep the two separate, or
	-- the scroll offset and the grip desync.
	self.vScroll:SetPos(self:GetWide() - padding - self.VScrollWidth, self:GetScrubberTopY())
	self.vScroll:SetSize(self.VScrollWidth, self:GetScrollbarTrackTall())
	self.vScroll:SetSizes(math.max(#ids * self.RowHeight, 1), contentTall)

	self.LastFramesSize = self.FramesSize
end

-- ==================== 8. Stubs / legacy compatibility ====================

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
