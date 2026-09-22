--[[   _
    ( )
   _| |   __   _ __   ___ ___     _ _
 /'_` | /'__`\( '__)/' _ ` _ `\ /'_` )
( (_| |(  ___/| |   | ( ) ( ) |( (_| |
`\__,_)`\____)(_)   (_) (_) (_)`\__,_)

	DHATRow - one entity's row in the timeline: the fixed-width label on the left and the strip
	of colored frame blocks on the right, plus the hit-testing and right-click menus that act on
	that one entity's frames.

	Desc: the row is a real, positioned/visible child panel (of DFrameHolder.rowsViewport), laid
	out every DFrameHolder:Paint via DFrameHolder:LayoutRows - so vertical scrolling/clipping is
	native (rowsViewport's own bounds clip whatever a row draws, including frame boxes that
	overflow its width from horizontal scroll) rather than a manual render.SetScissorRect. The
	row still paints its own label and frame strip itself (below), just via its own Paint(w, h)
	hook instead of being called into by the holder.

	Mouse INPUT still stays centrally dispatched, though (SetMouseInputEnabled(false) here): a
	row being drag-resized has to keep tracking the mouse well outside its own bounds, and clicks
	that miss every row still have to reach DFrameHolder (right-click-hold-to-pan, world select).
	Coordinate math (ScreenToLocal) works fine regardless of that flag, so Paint below still uses
	it to find its own hover state. Cursor resolution (sizewe/hand/arrow) is centralized on the
	holder too (DFrameHolder:UpdateCursor), driven by the same hit-test helpers below, since row
	painting now happens as a deferred child-paint the holder can't observe results from mid-frame.

	Frames themselves are not panels either - they're immediate-mode rectangles hit-tested by
	walking the frame list, since there can be hundreds of them and they're re-laid-out every
	frame as lengths are dragged.

	The row does not own its data: SetRow re-binds it to whichever entity it's currently
	standing in for (DFrameHolder owns self.Entities), and the in-progress drag state
	(DragFrameLength / DraggingFrame / DraggingNewFrame) stays on the holder because only one
	row can be interactive at a time and the "new frame" drag is started by the toolbar.

--]]

PANEL = {}

-- Desc: suffix appended to non-body rows (a single entity can have separate body/face/hand pose
-- rows - see HAT_SELECT_* in hat_init.lua) so they're distinguishable in the label list.
local POSE_TYPE_SUFFIX = {
	[HAT_SELECT_FACE] = ":Face",
	[HAT_SELECT_L_HAND] = ":LHand",
	[HAT_SELECT_R_HAND] = ":RHand",
}

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
-- known, otherwise its id, plus a :Face/:LHand/:RHand suffix for non-body pose rows.
local function GetEntityLabel(id, entData)
	local label
	if IsValid(entData.Ent) then
		local model = entData.Ent:GetModel()
		label = model and string.GetFileFromFilename(model):gsub("%.mdl$", "")
	end
	label = label or ("#" .. tostring(id))

	return label .. (POSE_TYPE_SUFFIX[entData.PoseType] or "")
end

function PANEL:Init()
	self.Holder = self:GetParent()
	self.Id = nil
	self.EntData = nil

	self:SetVisible(false)
	self:SetMouseInputEnabled(false)

	-- Desc: model icon shown right-aligned in the label cell. A real ModelImage (rather than a
	-- manually-drawn material) so GMod handles icon generation/caching for us; it's repositioned
	-- and shown/hidden by hand each DrawLabel since this row's children aren't laid out by Derma.
	self.ModelIcon = vgui.Create("ModelImage", self)
	self.ModelIcon:SetMouseInputEnabled(false)
	self.ModelIcon:SetVisible(false)

	-- Desc: real DLabel for the entity name (replacing a manual draw.SimpleText call), positioned
	-- by hand each Paint same as ModelIcon since neither is laid out by Derma. SetText still only
	-- called when the truncated label actually changes, to avoid re-triggering its own layout
	-- every frame for no reason.
	self.NameLabel = vgui.Create("DLabel", self)
	self.NameLabel:SetMouseInputEnabled(false)
	self.NameLabel:SetFont("DermaDefault")
	self.NameLabel:SetTextColor(Color(255, 255, 255))
	self.NameLabel:SetContentAlignment(4) -- left/middle
end

-- Desc: (re)binds this row to an entity. Rows are pooled per entity id by DFrameHolder, so the
-- data can change under a row between frames.
function PANEL:SetRow(id, entData)
	self.Id = id
	self.EntData = entData
end

-- ==================== Hit-testing ====================
--
-- All three take frame-space coordinates (x relative to the start of the frame strip, y relative
-- to the top of this row) and scrollOffsetX, the shared horizontal scroll offset in pixels.
-- They walk the frame list accumulating box widths rather than using frame.start, so they stay
-- correct in the middle of a length drag, before RecalculateFrameStarts has run again.

-- Desc: index where a new frame would be inserted, based on which half of the hovered frame the
-- mouse is over (left half = insert before, right half = insert after). Falls back to appending
-- past the last frame.
function PANEL:GetNewFrameIndex(x, scrollOffsetX)
	if not self.EntData then return 0 end

	local offsetX = scrollOffsetX
	local newFrameSpeculation
	local count = 0

	for i, val in pairs(self.EntData.Frames) do
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

-- Desc: index of the frame whose right-edge resize handle the mouse is over, if any.
function PANEL:GetIncreaseLengthFrame(x, scrollOffsetX)
	if not self.EntData then return end

	local offsetX = scrollOffsetX
	local increaseFrameSpeculation

	for i, val in pairs(self.EntData.Frames) do
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

-- Desc: index of the frame currently under the mouse. A frame being length-dragged counts as
-- hovered no matter where the cursor actually is, so the drag can't be lost by sliding off it.
function PANEL:GetFrameHovered(x, y, scrollOffsetX)
	if not self.EntData then return end

	local dragFrameLength = self.Holder.DragFrameLength
	local offsetX = scrollOffsetX

	for i, val in pairs(self.EntData.Frames) do
		local length = val.l
		local boxWidth = HAT_DEFAULT_FRAME_SIZE * length

		if (dragFrameLength and dragFrameLength == i) or (not dragFrameLength and x >= offsetX and x <= offsetX + boxWidth and y >= 0 and y <= 30) then
			return i
		end

		offsetX = offsetX + boxWidth
	end
end

-- ==================== Rendering ====================

-- Desc: draws this row's frame blocks at (drawX, drawY). When interactive is true (the current
-- entity's row), also draws selection/hover highlight, the resize-handle strip and the
-- drag-insertion marker; mouseX/mouseY are in this row's frame space. The mouse cursor itself is
-- no longer decided here - see DFrameHolder:UpdateCursor.
function PANEL:DrawStrip(drawX, drawY, scrollOffsetX, interactive, mouseX, mouseY, drawTime, localTime)
	local entData = self.EntData
	if not entData then return end

	local holder = self.Holder

	local newFrameSpeculation
	local newFrameSpeculationX

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
			elseif (holder.DragFrameLength and holder.DragFrameLength == i) or
					(not holder.DragFrameLength and
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

			-- Check to see if this frame is where the player wants to put the new frame.
			local l, c, r = offsetX, offsetX + boxWidth / 2, offsetX + boxWidth
			if (holder.DraggingNewFrame or holder.DraggingFrame) and mouseY >= 0 and mouseY <= 30 then
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

	if interactive and (holder.DraggingNewFrame or holder.DraggingFrame) then
		surface.SetDrawColor(Color(10, 150, 10))
		if newFrameSpeculationX then
			surface.DrawRect(drawX + newFrameSpeculationX, drawY, 4, 30)
		else
			surface.DrawRect(drawX + offsetX - 2, drawY, 4, 30)
		end
	end
end

-- Desc: draws this row's label cell at (drawX, drawY): a faint highlight for the current entity,
-- a brighter one while hovered, and the entity's name clipped to the label column's width.
function PANEL:DrawLabel(drawX, drawY, interactive, hovered)
	local entData = self.EntData
	if not entData then return end

	local holder = self.Holder

	if interactive then
		surface.SetDrawColor(255, 255, 255, 10)
		surface.DrawRect(drawX, drawY, holder.LabelWidth, holder.RowHeight)
	elseif hovered then
		surface.SetDrawColor(255, 255, 255, 20)
		surface.DrawRect(drawX, drawY, holder.LabelWidth, holder.RowHeight)
	end

	-- Model icon, right-aligned in the label cell and sized to fit within the row's height.
	local iconSize = 0
	local model = IsValid(entData.Ent) and entData.Ent:GetModel() or nil
	if model then
		iconSize = math.max(holder.RowHeight - 4, 0)

		if self.IconModel ~= model then
			self.IconModel = model
			self.ModelIcon:SetModel(model)
		end

		self.ModelIcon:SetSize(iconSize, iconSize)
		self.ModelIcon:SetPos(drawX + holder.LabelWidth - iconSize - 2, drawY + (holder.RowHeight - iconSize) / 2)
		self.ModelIcon:SetVisible(true)
	else
		self.IconModel = nil
		self.ModelIcon:SetVisible(false)
	end

	-- Fixed-width label, truncated to leave room for the icon, never wider than LabelWidth.
	local label = TruncateText(GetEntityLabel(self.Id, entData), "DermaDefault", holder.LabelWidth - iconSize - (iconSize > 0 and 4 or 0))
	if self.LabelText ~= label then
		self.LabelText = label
		self.NameLabel:SetText(label)
	end
	self.NameLabel:SetPos(drawX, drawY)
	self.NameLabel:SetSize(holder.LabelWidth - iconSize - (iconSize > 0 and 4 or 0), 30)
end

-- Desc: entry point Derma calls directly now that the row is a real positioned/visible panel
-- (see DFrameHolder:LayoutRows) - draws the frame strip then the label, computing its own
-- row-local mouse position (works regardless of SetMouseInputEnabled(false) above, since
-- ScreenToLocal is pure coordinate math) rather than being handed mouseX/mouseY by the holder.
function PANEL:Paint(w, h)
	local entData = self.EntData
	if not entData then return end

	local holder = self.Holder
	local interactive = (self.Id == holder.CurEntity)

	local mlx, mly = self:ScreenToLocal(gui.MouseX(), gui.MouseY())
	local hovered = not interactive and mlx >= 0 and mlx <= w and mly >= 0 and mly <= h

	local labelWidth = holder.LabelWidth
	local labelGap = holder.LabelGap

	self:DrawStrip(labelWidth + labelGap, 0, holder:GetScrollOffsetX(), interactive,
		mlx - labelWidth - labelGap, mly, true, holder.CurrentTime)
	self:DrawLabel(0, 0, interactive, hovered)
end

-- ==================== Context menus ====================

-- Desc: color used to highlight the currently-selected easing/strength option in a dropdown,
-- instead of marking it with a leading bullet.
local EASING_SELECTED_COLOR = Color(90, 160, 255)

-- Desc: the three easing curves that get their own Weak/Normal/Strong strength submenu (mapped
-- server-side to quad/quart/expo power curves - see HAT.Ease in sv_hat_playback.lua).
local EASING_CURVES = {
	{ label = "Ease In",         kind = "easein" },
	{ label = "Ease Out",        kind = "easeout" },
	{ label = "Ease In and Out", kind = "easeinout" },
}

-- Desc: populates `menu` (either the dedicated Easing select box's dropdown in dhatmenu.lua, or
-- an "Easing" submenu of a frame's right-click menu here) with Stop Motion/Linear plus the three
-- curves above, each themselves a Weak/Normal/Strong submenu, all acting on the given frame
-- index. The currently-set easing/strength is highlighted blue rather than marked with a bullet.
function PANEL:BuildEasingMenu(menu, frame, frameData)
	local function setEasing(kind, strength)
		RunConsoleCommand("hat_frame_seteasing", frame, kind, strength or "normal")
	end

	local function highlightIf(option, isSet)
		if isSet then
			option:SetTextColor(color_white)
			option.Paint = function(pnl, w, h)
				draw.RoundedBox(0, 0, 0, w, h, EASING_SELECTED_COLOR)
				return false
			end
		end
		return option
	end

	highlightIf(menu:AddOption("Stop Motion", function() setEasing("stopmotion") end), frameData.easing == "stopmotion")
	highlightIf(menu:AddOption("Linear", function() setEasing("linear") end),
		not frameData.easing or frameData.easing == "linear")

	for _, curve in ipairs(EASING_CURVES) do
		local curveMenu, curveOption = menu:AddSubMenu(curve.label)
		curveOption.DoClick = function() setEasing(curve.kind, "normal") end
		highlightIf(curveOption, frameData.easing == curve.kind)

		for _, strength in ipairs({ "Weak", "Normal", "Strong" }) do
			local strengthLower = string.lower(strength)
			local isSet = frameData.easing == curve.kind and (frameData.easingStrength or "normal") == strengthLower

			highlightIf(curveMenu:AddOption(strength, function() setEasing(curve.kind, strengthLower) end), isSet)
		end
	end
end

-- Desc: right-click menu for an individual frame on this row: Duplicate, Replace, Delete, an
-- Easing submenu, and Shift Left/Right (adjacent swaps via hat_frame_move). Shift options are
-- omitted when there's no neighbor in that direction. Only ever opened for the current entity's
-- row, so the frame-index-only console commands land on the right object server-side.
function PANEL:OpenFrameContextMenu(frame)
	local entData = self.EntData
	local frameData = entData and entData.Frames[frame]
	if not frameData then return end

	local menu = DermaMenu()

	menu:AddOption("Duplicate", function()
		RunConsoleCommand("hat_frame_duplicate", frame)
	end)
	menu:AddOption("Replace", function()
		RunConsoleCommand("hat_frame_snapshot", frame)
	end)
	menu:AddOption("Delete", function()
		RunConsoleCommand("hat_frame_remove", frame)
	end)

	local easingMenu = menu:AddSubMenu("Easing")
	self:BuildEasingMenu(easingMenu, frame, frameData)

	if frame > 1 then
		menu:AddOption("Shift Left", function()
			RunConsoleCommand("hat_frame_move", frame, frame - 1)
		end)
	end
	if frame < #entData.Frames then
		menu:AddOption("Shift Right", function()
			RunConsoleCommand("hat_frame_move", frame, frame + 1)
		end)
	end

	menu:Open()
end

-- Desc: right-click menu for this row's label: Shift Up/Down (reorders the row locally - the
-- order itself lives on the holder, since it's a property of the stack, not of one row) and Stop
-- Animating (deletes that pose object's frames after a confirmation prompt, since it can't be
-- undone).
function PANEL:OpenLabelContextMenu()
	local holder = self.Holder
	local id = self.Id
	local ids = holder:GetOrderedEntityIds()
	local idx
	for i, v in ipairs(ids) do
		if v == id then
			idx = i
			break
		end
	end
	if not idx then return end

	local menu = DermaMenu()

	if idx > 1 then
		menu:AddOption("Shift Up", function()
			holder:ShiftEntityRow(id, -1)
		end)
	end
	if idx < #ids then
		menu:AddOption("Shift Down", function()
			holder:ShiftEntityRow(id, 1)
		end)
	end

	menu:AddOption("Stop Animating", function()
		Derma_Query(
			"This will delete all the frames associated with this entity. Are you sure?",
			"Stop Animating",
			"Yes", function() RunConsoleCommand("hat_remove_entity", id - 1) end,
			"No", function() end
		)
	end)

	menu:Open()
end

derma.DefineControl("DHATRow", "One entity's row of frames in DFrameHolder.", PANEL, "DPanel")
