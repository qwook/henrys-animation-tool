local vgui = vgui

--[[   _
    ( )
   _| |   __   _ __   ___ ___     _ _
 /'_` | /'__`\( '__)/' _ ` _ `\ /'_` )
( (_| |(  ___/| |   | ( ) ( ) |( (_| |
`\__,_)`\____)(_)   (_) (_) (_)`\__,_)

	DHATMenu - the main tool window: menu bar, record/play/stop/new-frame buttons, embeds
	DFrameHolder, owns the save/load/new-project dialogs, and does entity/hand/face
	hit-testing on right-click to decide what gets posed.

--]]

local FacePoser = surface.GetTextureID("gui/faceposer_indicator")
local FrozenIcon = Material("icon16/bullet_blue.png")

-- View menu display toggles (see the View menu built in PANEL:Init). hat_onionskin_visible is
-- created in cl_hat_onionskin_visibility.lua since it also gates entity SetNoDraw calls there;
-- these two only ever gate drawing done right here in Paint, so they're created here instead.
CreateClientConVar("hat_frozenbones_visible", "1", true, false, "Show HAT's frozen-bone lock icons")
CreateClientConVar("hat_dispname_visible", "1", true, false, "Show the selected prop's model name")

-- Forward-declared so PANEL:Init (defined above WorldEntitySelect's body further down) can close
-- over it when wiring it up as frameHolder.OnRightClickResolved.
local WorldEntitySelect

PANEL = {}
AccessorFunc(PANEL, "m_bStretchToFit", "StretchToFit")

--[[---------------------------------------------------------

-----------------------------------------------------------]]
function PANEL:Init()
	self:SetWorldClicker(true)
	self:SetDrawBackground(false)
	self:SetStretchToFit(true)

	self.SelectedPoser = 0

	-- Which bones (regular bone IDs, already translated from physbone indices server-side) the
	-- lock icon should draw over - synced via "hat_frozen_bones" since the selected entity may be
	-- a server-side-only ragdoll with no client physics objects to read frozen state from directly.
	self.FrozenBonesEnt = nil
	self.FrozenBoneIDs = {}

	local hatMenu = self

	-- The Tab Holder
	--self.propertySheet = vgui.Create("DPropertySheet", self)

	--menu:Open()

	-- Tutorial Panel
	self.tutorialBtn = vgui.Create("DButton", self)

	self.tutorialBtn:SetText("Video Tutorial")
	self.tutorialBtn.DoClick = function()
		gui.OpenURL("https://www.youtube.com/watch?v=pUBdpmK37-I")
	end

	-- Main Panel
	self.mainSheet = vgui.Create("DPanel", self)
	self.mainSheet.Paint = function(self, w, h)
		hatskin.drawFrame(0, 0, w, h)
	end

	-- Frames Holder
	self.frameHolder = vgui.Create("DFrameHolder", self.mainSheet)
	-- A plain right-click the frame holder doesn't consume itself (no frame/label context menu,
	-- no right-click-drag pan) resolves to selecting whatever's under the cursor in the world.
	self.frameHolder.OnRightClickResolved = function() WorldEntitySelect() end

	-- On/Off buttons, shown above a selected entity whose class is in HAT_TOGGLEABLE_ON_OFF
	-- (gmod_emitter, gmod_thruster - see hat_init.lua) - see PerformLayout/Paint below. Real
	-- DButtons (rather than a manual Paint+hit-test rect) so VGUI's own input handling consumes
	-- the click - otherwise SetWorldClicker(true) above lets it fall through to the game world
	-- and fire whatever's in the player's hands underneath the button.

	-- DHatButton paints no background of its own, so a framed backing panel sits behind the pair,
	-- using the same drawFrameBody 9-slice as the tool's other panels and the same 5px padding
	-- DFrameHolder uses around its own content (see dframeholder.lua:46, SetPadding(5)).
	self.ON_OFF_BUTTON_PADDING = 5

	self.onOffButtonFrame = vgui.Create("DPanel", self)
	self.onOffButtonFrame:SetVisible(false)
	self.onOffButtonFrame.Paint = function(self, w, h)
		hatskin.drawFrameBody(0, 0, w, h)
	end

	-- Both are toggle-style DHatButtons (like loopButton below) purely so their depressed look
	-- reflects state; DoClick is overridden so a click never flips m_Value itself - Paint below
	-- drives SetValue from the entity's real GetOn() every frame instead.
	self.onButton = vgui.Create("DHatButton", self)
	self.onButton:SetText("On")
	self.onButton:SetSize(50, 20)
	self.onButton:SetVisible(false)
	self.onButton:SetToggle(true)
	self.onButton:SetColor(Color(120, 120, 120))
	self.onButton.DoClick = function()
		if IsValid(self.SelectedEnt) then
			RunConsoleCommand("hat_entity_seton", self.SelectedEnt:EntIndex(), "1")
		end
	end

	self.offButton = vgui.Create("DHatButton", self)
	self.offButton:SetText("Off")
	self.offButton:SetSize(50, 20)
	self.offButton:SetVisible(false)
	self.offButton:SetToggle(true)
	self.offButton:SetColor(Color(120, 120, 120))
	self.offButton.DoClick = function()
		if IsValid(self.SelectedEnt) then
			RunConsoleCommand("hat_entity_seton", self.SelectedEnt:EntIndex(), "0")
		end
	end

	-- Toolbar
	self.toolbar = vgui.Create("DHatToolbar", self.mainSheet)
	self.toolbar:SetPaintBackground(false)

	-- Play Button
	self.playButton = self.toolbar:AddButton("DHatButton")
	self.playButton:SetText("Play")
	self.playButton:SetColor(Color(120, 120, 120))
	self.playButton.DoClick = function()
		RunConsoleCommand("hat_play")
	end

	-- Stop Button
	self.stopButton = self.toolbar:AddButton("DHatButton")
	self.stopButton:SetText("Stop")
	self.stopButton:SetColor(Color(120, 120, 120))
	self.stopButton.DoClick = function()
		RunConsoleCommand("hat_stop")
	end

	-- Loop Toggle Button (off by default; state is saved with the animation)
	self.loopButton = self.toolbar:AddButton("DHatButton")
	self.loopButton:SetText("Loop")
	self.loopButton:SetColor(Color(120, 120, 120))
	self.loopButton:SetToggle(true)
	self.loopButton.DoClick = function()
		RunConsoleCommand("hat_toggle_loop")
	end

	-- Divider between the playback controls (Play/Stop/Loop) and the frame-editing controls
	-- (New/Replace/Delete Frame, Easing).
	self.toolbarDivider = self.toolbar:AddButton("DPanel", 18)
	self.toolbarDivider:SetMouseInputEnabled(false)
	self.toolbarDivider.Paint = function(pnl, w, h)
		surface.SetDrawColor(0, 0, 0, 100)
		surface.DrawRect(w / 2 + 1, 8, 1, h - 20)
		surface.SetDrawColor(255, 255, 255, 10)
		surface.DrawRect(w / 2, 8, 1, h - 20)
	end

	-- New Frame Button (creates a new frame, snapshotted with the current pose)
	self.newButton = self.toolbar:AddButton("DHatButton")
	self.newButton:SetText("● New Frame")
	self.newButton:SetColor(Color(200, 0, 0))

	self.newButton.OlOnMousePressed = self.newButton.OnMousePressed
	self.newButton.OlOnMouseReleased = self.newButton.OnMouseReleased

	-- By this point, I might as well have created my own button.
	self.newButton.OnMousePressed = function(self)
		hatMenu:DragNewFrame()
		return self:OlOnMousePressed()
	end

	self.newButton.OnMouseReleased = function(self)
		hatMenu:FinishDragNewFrame(not self.Hovered)
		if self.Hovered then
			-- A plain click (no drag onto the strip) inserts right after the selected frame,
			-- rather than always appending to the end.
			local frameHolder = hatMenu.frameHolder
			local entData = frameHolder.Entities[frameHolder.CurEntity]
			local pos = entData and entData.SelectedFrame and (entData.SelectedFrame + 1)
			if pos then
				RunConsoleCommand("hat_frame_add", pos)
			else
				RunConsoleCommand("hat_frame_add")
			end
		end
		return self:OlOnMouseReleased()
	end

	-- Replace Frame Button (re-snapshots the current pose into the highlighted frame)
	self.recordButton = self.toolbar:AddButton("DHatButton")
	self.recordButton:SetText("Replace Frame")
	self.recordButton:SetColor(Color(120, 120, 120))
	self.recordButton.DoClick = function()
		-- Snapshot into whatever frame is actually highlighted, not the server's implicit
		-- "current frame" cursor (scrubbing moves the highlight without moving that cursor).
		local frameHolder = hatMenu.frameHolder
		local entData = frameHolder.Entities[frameHolder.CurEntity]
		local frame = entData and entData.SelectedFrame
		RunConsoleCommand("hat_frame_snapshot", frame)
	end

	-- Delete Frame Button (removes the currently highlighted frame)
	self.deleteButton = self.toolbar:AddButton("DHatButton")
	self.deleteButton:SetText("Delete Frame")
	self.deleteButton:SetColor(Color(120, 120, 120))
	self.deleteButton.DoClick = function()
		local frameHolder = hatMenu.frameHolder
		local entData = frameHolder.Entities[frameHolder.CurEntity]
		local frame = entData and entData.SelectedFrame
		if frame then
			RunConsoleCommand("hat_frame_remove", frame)
		end
	end

	-- Desc: the highlighted frame's easing/strength as shown on the Easing select box itself.
	local EASING_DISPLAY_NAMES = {
		stopmotion = "Stop Motion",
		linear = "Linear",
		easein = "Ease In",
		easeout = "Ease Out",
		easeinout = "Ease In and Out",
	}
	local STRENGTH_DISPLAY_NAMES = { weak = "Weak", normal = "Normal", strong = "Strong" }

	local function GetEasingDisplayName(easing, strength)
		local name = EASING_DISPLAY_NAMES[easing] or EASING_DISPLAY_NAMES.linear

		if easing == "easein" or easing == "easeout" or easing == "easeinout" then
			name = name .. " (" .. (STRENGTH_DISPLAY_NAMES[strength] or STRENGTH_DISPLAY_NAMES.normal) .. ")"
		end

		return name
	end

	-- Easing Select Box (opens a dropdown to set the highlighted frame's easing curve/strength;
	-- shows that frame's current easing as its value, like an inset textbox)
	self.easingButton = self.toolbar:AddButton("DHatSelectBox")
	self.easingButton:SetText("Easing")
	self.easingButton:SetColor(Color(120, 120, 120))

	-- Desc: keeps the select box's label in sync with whichever frame is currently highlighted.
	self.easingButton.Think = function(btn)
		local frameHolder = hatMenu.frameHolder
		local entData = frameHolder.Entities[frameHolder.CurEntity]
		local frame = entData and entData.SelectedFrame
		local frameData = frame and entData.Frames[frame]

		btn:SetText(frameData and GetEasingDisplayName(frameData.easing, frameData.easingStrength) or "Easing")
	end

	self.easingButton.DoClick = function(btn)
		local frameHolder = hatMenu.frameHolder
		local entData = frameHolder.Entities[frameHolder.CurEntity]
		local frame = entData and entData.SelectedFrame
		local frameData = frame and entData.Frames[frame]
		if not frameData then return end

		local menu = DermaMenu()
		frameHolder:BuildEasingMenu(menu, frame, frameData)

		-- 5px of bottom padding: the menu otherwise ends flush with its last option.
		local bottomPad = vgui.Create("DPanel", menu)
		bottomPad:SetTall(5)
		bottomPad.Paint = function() end
		menu:AddPanel(bottomPad)

		-- The toolbar sits at the bottom of the screen, so opening downward (DMenu's default)
		-- would overflow past ScrH() and get clamped back up in a way that clips/misplaces it.
		-- Measure the menu's real size up front and open it upward from the button instead.
		menu:InvalidateLayout(true)
		local bx, by = btn:LocalToScreen(0, 0)
		menu:Open(bx, by - menu:GetTall())
	end

	-- Menu Bar
	self.menuBar = vgui.Create("DMenuBar", self)

	local function MenuItemSelected()
		--RunConsoleCommand( "hat_new" )
	end

	self.fileMenu = self.menuBar:AddMenu("File")
	self.fileMenu:AddOption("New", function()
		self:Hide()

		local confirmation = vgui.Create("DFrame")
		confirmation:SetSize(250, 100)
		confirmation:SetTitle("New HAT Project")
		confirmation:Center()
		confirmation:SetVisible(true)
		confirmation:ShowCloseButton(true)
		confirmation:MakePopup()
		confirmation:SetDeleteOnClose(true)
		confirmation:SetDraggable(false)

		local label = vgui.Create("DLabel", confirmation)
		label:SetPos(10, 10)
		label:SetSize(230, 100)
		label:SetText("This will delete all user-created props\nand ragdolls on the map.\n\nAre you sure?")

		local ok = vgui.Create("DButton", confirmation)
		ok:SetPos(140, 70)
		ok:SetSize(50, 25)
		ok:SetText("Yes")
		ok.DoClick = function()
			RunConsoleCommand("hat_new")
			confirmation:Close()
		end

		local cancel = vgui.Create("DButton", confirmation)
		cancel:SetPos(195, 70)
		cancel:SetSize(50, 25)
		cancel:SetText("No")
		cancel.DoClick = function() confirmation:Close() end
	end)
	self.fileMenu:AddOption("Open...", function()
		self:Hide()

		local fileBrowser = vgui.Create("DFrame")
		fileBrowser:SetSize(400, 275)
		fileBrowser:SetTitle("Open HAT Project")
		fileBrowser:Center()
		fileBrowser:SetVisible(true)
		fileBrowser:ShowCloseButton(true)
		fileBrowser:MakePopup()
		fileBrowser:SetDeleteOnClose(true)
		fileBrowser:SetDraggable(false)

		local textEntry = vgui.Create("DTextEntry", fileBrowser)
		local fileList = vgui.Create("DFileList", fileBrowser)
		local openBtn = vgui.Create("DButton", fileBrowser)

		textEntry:SetSize(310, 20)
		textEntry:SetPos(10, 245)

		local function open()
			local file = fileList:GetCurrentDirectory() .. textEntry:GetText()
			local confirm = vgui.Create("DFrame")
			local label = vgui.Create("DLabel", confirm)
			local okayBtn = vgui.Create("DButton", confirm)
			local cancelBtn = vgui.Create("DButton", confirm)
			confirm:SetSize(300, 115)
			confirm:SetTitle("Are you sure?")
			confirm:Center()
			confirm:SetVisible(true)
			confirm:ShowCloseButton(true)
			confirm:MakePopup()
			confirm:SetDeleteOnClose(true)
			confirm:SetDraggable(false)

			label:SetText("Opening this file will remove all objects in this map.\nAre you sure you want to do this?")
			label:SetPos(10, 35);
			label:SetSize(380, 40)

			okayBtn:SetPos(10, 80)
			okayBtn:SetSize(65, 20)
			okayBtn:SetText("Okay")
			okayBtn.DoClick = function(self)
				RunConsoleCommand("hat_load", file)
				confirm:Close()
			end

			cancelBtn:SetPos(80, 80)
			cancelBtn:SetSize(65, 20)
			cancelBtn:SetText("Cancel")
			cancelBtn.DoClick = function(self)
				confirm:Close()
			end

			fileBrowser:Close()
		end

		textEntry.OnEnter = open

		fileList:SetPos(10, 35)
		fileList:SetSize(380, 200)
		fileList.LastClick = 0
		fileList.OnFileClick = function(self, fileName)
			if textEntry:GetText() == fileName and self.LastClick > RealTime() - 0.5 then
				open()
			end
			textEntry:SetText(fileName)
			self.LastClick = RealTime()
		end

		openBtn:SetPos(325, 245)
		openBtn:SetSize(65, 20)
		openBtn:SetText("Open")
		openBtn.DoClick = function(self, fileName)
			open()
		end
	end)
	self.fileMenu:AddOption("Save As...", function()
		self:Hide()

		local fileBrowser = vgui.Create("DFrame")
		fileBrowser:SetSize(400, 275)
		fileBrowser:SetTitle("Save HAT Project")
		fileBrowser:Center()
		fileBrowser:SetVisible(true)
		fileBrowser:ShowCloseButton(true)
		fileBrowser:MakePopup()
		fileBrowser:SetDeleteOnClose(true)
		fileBrowser:SetDraggable(false)

		local textEntry = vgui.Create("DTextEntry", fileBrowser)
		local fileList = vgui.Create("DFileList", fileBrowser)
		local saveBtn = vgui.Create("DButton", fileBrowser)

		textEntry:SetSize(310, 20)
		textEntry:SetPos(10, 245)

		local function save()
			-- Desc: row order is client-only display state (DFrameHolder.EntityOrder), so it has to be
			-- handed to the server explicitly here rather than read off HAT.objects. Ids are server
			-- keys (client id - 1, matching DFrameHolder:Load's offset) joined in display order.
			local orderIds = {}
			for _, id in ipairs(self.frameHolder:GetOrderedEntityIds()) do
				table.insert(orderIds, id - 1)
			end

			RunConsoleCommand("hat_save", fileList:GetCurrentDirectory() .. textEntry:GetText(), table.concat(orderIds, ","))
			fileBrowser:Close()
		end

		textEntry.OnEnter = save

		fileList:SetPos(10, 35)
		fileList:SetSize(380, 200)
		fileList.LastClick = 0
		fileList.OnFileClick = function(self, fileName)
			if textEntry:GetText() == fileName and self.LastClick > RealTime() - 0.5 then
				save()
			end
			textEntry:SetText(fileName)
			self.LastClick = RealTime()
		end

		saveBtn:SetPos(325, 245)
		saveBtn:SetSize(65, 20)
		saveBtn:SetText("Save")
		saveBtn.DoClick = function(self, fileName)
			save()
		end
	end)

	self.playOptions = vgui.Create("DFrame")
	self.playOptions:SetSize(310, 100)
	self.playOptions:SetTitle("Play Options")
	self.playOptions:Center()
	self.playOptions:SetVisible(true)
	self.playOptions:ShowCloseButton(true)
	self.playOptions:SetDraggable(false)
	self.playOptions:SetDeleteOnClose(false)
	local slider = vgui.Create("DNumSlider", self.playOptions)
	slider:SetPos(5, 25)
	slider:SetWide(300)
	slider:SetText("Play Rate")
	slider:SetMin(0)
	slider:SetMax(4)
	slider:SetDecimals(4)
	slider:SetConVar("hat_playrate")
	-- Snap to a 1/8 grid instead of letting the slider drag to any float; the raw
	-- 0-4 range with 4 decimals was too fine to reliably land on useful rates.
	local PLAYRATE_GRID = 1 / 8
	function slider:TranslateSliderValues(x, y)
		local raw = self.Scratch:GetMin() + (x * self.Scratch:GetRange())
		local snapped = math.Round(raw / PLAYRATE_GRID) * PLAYRATE_GRID
		self:SetValue(snapped)
		return self.Scratch:GetFraction(), y
	end
	-- Not check:SetConVar("hat_stopmotion"): hat_stopmotion is a server-only ConVar (see
	-- sv_hat_data.lua), so the client has no local copy for SetConVar's GetConVarNumber-based
	-- binding to read back - it kept resetting the checkbox to unchecked. Drive it manually
	-- with RunConsoleCommand instead, like every other client->server action in this addon.
	local check = vgui.Create("DCheckBoxLabel", self.playOptions)
	check:SetWide(300)
	check:SetPos(5, 55)
	check:SetText("Stop Motion")
	check:SetChecked(false)
	check.OnChange = function(self, val)
		RunConsoleCommand("hat_stopmotion", val and "1" or "0")
	end
	self.playOptions:SetVisible(false)
	-- DHATMenu is itself a screen-covering MakePopup()'d panel (see PANEL:Show below), so
	-- leaving it visible/popped while this dialog is open means a click meant to dismiss the
	-- dialog lands on DHATMenu instead and the engine promotes DHATMenu back above it. Hide
	-- DHATMenu while the dialog is up and restore it on close, same as the other dialogs below.
	self.playOptions.OnClose = function()
		hatMenu:Show()
	end

	-- View Menu - purely client-side display toggles, each just a checkable option bound straight
	-- to its own clientside convar (see the CreateClientConVar calls near the top of this file, and
	-- hat_onionskin_visible in cl_hat_onionskin_visibility.lua). Uses DMenuOption's own built-in
	-- checkable/checked rendering rather than a custom Paint override.
	self.viewMenu = self.menuBar:AddMenu("View")

	local function AddViewToggle(label, convarName)
		local option = self.viewMenu:AddOption(label, function() end)
		option:SetIsCheckable(true)
		option:SetChecked(GetConVar(convarName):GetBool())
		option.OnChecked = function(pnl, checked)
			RunConsoleCommand(convarName, checked and "1" or "0")
		end
	end

	AddViewToggle("Display Onion Skin", "hat_onionskin_visible")
	AddViewToggle("Display Frozen Bones", "hat_frozenbones_visible")
	AddViewToggle("Display Selected Prop Name", "hat_dispname_visible")

	self.optionsMenu = self.menuBar:AddMenu("Options")
	self.optionsMenu:AddOption("Play Options", function()
		self:Hide()
		self.playOptions:MakePopup()
		self.playOptions:SetVisible(true)
	end)
	self.optionsMenu:AddOption("Rebind HAT Menu Key", function()
		HAT.ShowKeyCapture(HAT.SetMenuKey, "Press any key to set it as the HAT menu button.", true)
	end)
	self.optionsMenu:AddOption("Rebind HAT Play Key", function()
		HAT.ShowKeyCapture(HAT.SetPlayKey, "Press any key to set it as the HAT play button.", false)
	end)

	--local submenu = self.menuBar:AddSubMenu( "Option Free" )
	--	submenu:AddOption( "Submenu 1", MenuItemSelected )
	--	submenu:AddOption( "Submenu 2", MenuItemSelected )
	--self.menuBar:AddOption( "Option For", MenuItemSelected )

	self:SetColor(Color(255, 255, 255, 255))
end

function PANEL:Show()
	self.menuBar:Show()
	self:MakePopup()
	self:SetVisible(true)
	self:SetMouseInputEnabled(true)
	self:SetKeyBoardInputEnabled(false)
	RestoreCursorPosition()
end

function PANEL:Hide()
	self.menuBar:Hide()
	self.fileMenu:Hide()
	RememberCursorPosition()
	self:SetVisible(false)
end

PANEL.SetIcon = PANEL.SetImage

function PANEL:Load(toLoad)
	self.frameHolder:Load(toLoad)
	self:SetLoop(toLoad.loop or false)
	timer.Simple(0.01, function()
		if toLoad.currentObjId and toLoad.objects[toLoad.currentObjId] then
			self.SelectedEnt = ents.GetByIndex(toLoad.objects[toLoad.currentObjId].ent)
		end
	end)
end

function PANEL:SetEntity(id, ent, posetype)
	self.frameHolder:SetEntity(tonumber(id) + 1, ent, posetype)
	self.SelectedEnt = ent
	self.SelectedPoseType = posetype
end

function PANEL:NewFrame(id, length, pos)
	self.frameHolder:NewFrame(id + 1, length or HAT_DEFAULT_LENGTH, pos)
end

function PANEL:RemoveFrame(id, pos)
	self.frameHolder:RemoveFrame(id + 1, pos)
end

function PANEL:MoveFrame(id, frameFrom, frameTo)
	self.frameHolder:MoveFrame(id + 1, frameFrom, frameTo)
end

function PANEL:SelectFrame(id, frame)
	self.frameHolder:SelectFrame(id + 1, frame)
end

function PANEL:SetFrameEasing(id, frame, easing, easingStrength)
	self.frameHolder:SetFrameEasing(id + 1, frame, easing, easingStrength)
end

function PANEL:DragNewFrame()
	self.frameHolder:DragNewFrame()
end

function PANEL:RemoveEntity(id)
	self.frameHolder:RemoveEntity(id + 1)
end

function PANEL:Play(start)
	self.frameHolder:Play(start)
end

function PANEL:Stop()
	self.frameHolder:Stop()
end

-- Desc: reflects the server's loop state (set on load, or synced live after a toggle) on the button.
function PANEL:SetLoop(loop)
	self.loopButton:SetValue(loop)
end

-- Desc: stores the locked bone IDs synced for ent by HAT.syncFrozenBones, for the lock icon in
-- Paint to draw over. Only ever relevant when ent is the currently selected entity - stored keyed
-- by ent anyway (rather than dropped when they don't match) since selection can change client-side
-- before the next sync catches up.
function PANEL:SetFrozenBones(ent, boneIDs)
	self.FrozenBonesEnt = ent
	self.FrozenBoneIDs = boneIDs
end

function PANEL:FinishDragNewFrame(shouldMakeNewFrame)
	self.frameHolder:FinishDragNewFrame(shouldMakeNewFrame)
end

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

--[[---------------------------------------------------------
	SizeToContents
-----------------------------------------------------------]]
function PANEL:SizeToContents()

end

-- Stolen from the finger stool.
local function GetHandPositions(pEntity)
	local LeftHand = pEntity:LookupBone("ValveBiped.Bip01_L_Hand")
	if (! LeftHand) then LeftHand = pEntity:LookupBone("bip_hand_L") end
	if (! LeftHand) then LeftHand = pEntity:LookupBone("Bip01_L_Hand") end

	local RightHand = pEntity:LookupBone("ValveBiped.Bip01_R_Hand")
	if (! RightHand) then RightHand = pEntity:LookupBone("bip_hand_R") end
	if (! RightHand) then RightHand = pEntity:LookupBone("Bip01_R_Hand") end

	if (! LeftHand || ! RightHand) then return false end

	local LeftHand = pEntity:GetBoneMatrix(LeftHand)
	local RightHand = pEntity:GetBoneMatrix(RightHand)
	if (! LeftHand || ! RightHand) then return false end

	return LeftHand, RightHand
end

-- Find out if we selected a head or hands.
local function CheckHeadAndHands(tr)
	if (! IsValid(tr.Entity)) then return 0 end
	if (tr.Entity:IsWorld()) then return 0 end

	local vEyePos = tr.Entity:EyePos()

	local eyeattachment = tr.Entity:LookupAttachment("eyes")
	if (eyeattachment ~= 0) then
		local attachment = tr.Entity:GetAttachment(eyeattachment)
		if attachment.Pos:Distance(tr.HitPos) < 7 then
			return HAT_SELECT_FACE
		end
	end

	local LeftHand, RightHand = GetHandPositions(tr.Entity)

	if LeftHand and RightHand then
		local LeftHand = (LeftHand:GetTranslation() - tr.HitPos):Length()
		local RightHand = (RightHand:GetTranslation() - tr.HitPos):Length()

		if LeftHand < RightHand and LeftHand < 7 then
			return HAT_SELECT_L_HAND
		elseif RightHand < LeftHand and RightHand < 7 then
			return HAT_SELECT_R_HAND
		end
	elseif LeftHand and not RightHand then
		return HAT_SELECT_L_HAND
	elseif RightHand and not LeftHand then
		return HAT_SELECT_R_HAND
	end


	return HAT_SELECT_ENTITY
end

function PANEL:SetPoser(poser)
	self.SelectedPoser = poser
end

-- Desc: traces from the player's eyes and hat_select's whatever's hit (head/hand-aware via
-- CheckHeadAndHands). Runs for a plain right-click that DFrameHolder didn't consume itself (a
-- frame/label context menu, or a right-click-drag pan) - see frameHolder.OnRightClickResolved
-- below and DFrameHolder:OnMouseReleased.
function WorldEntitySelect()
	local playerTrace = util.GetPlayerTrace(LocalPlayer())
	playerTrace.filter = { LocalPlayer() }
	for k, v in pairs(ents.GetAll()) do
		if v:GetNWBool("ignore") then
			table.insert(playerTrace.filter, v)
		end
	end
	local tr = util.TraceLine(playerTrace)
	if IsValid(tr.Entity) and not tr.Entity:GetNWBool("ignore") then
		RunConsoleCommand("hat_select", tr.Entity:EntIndex(), CheckHeadAndHands(tr))
	end
end

--[[---------------------------------------------------------
	OnMousePressed
-----------------------------------------------------------]]
-- Desc: forwards every press to frameHolder first. A right-click it doesn't land on a frame/label
-- is deferred there too (pending-click-or-pan - see DFrameHolder:OnMousePressed), resolving to
-- WorldEntitySelect on release rather than here, so frameHolder now always returns true for
-- MOUSE_RIGHT and there's nothing left for this function to do on a right-click itself.
function PANEL:OnMousePressed(mousecode)
	self.frameHolder:OnMousePressed(mousecode)
end

--[[---------------------------------------------------------
	OnMouseReleased
-----------------------------------------------------------]]
function PANEL:OnMouseReleased(mousecode)
	self.frameHolder:OnMouseReleased(mousecode)
	if mousecode == MOUSE_RIGHT then
	end
end

--[[---------------------------------------------------------

-----------------------------------------------------------]]
function PANEL:PerformLayout(width, height)
	self.tutorialBtn:SetPos(ScrW() - 105, ScrH() - 165)
	self.tutorialBtn:SetSize(100, 25)

	self:SetPos(0, 0)
	self:SetSize(ScrW(), ScrH())

	self.menuBar:SetPos(0, 0)
	self.menuBar:SetSize(ScrW(), 25)

	local mainSheetHeight = 200;
	self.mainSheet:SetPos(0, ScrH() - 200)
	self.mainSheet:SetSize(ScrW(), 200)

	self.frameHolder:SetPos(10, 36)
	self.frameHolder:SetSize(ScrW() - 24, 110)

	self.toolbar:SetPos(5, mainSheetHeight - 40 - 5)
	self.toolbar:SetSize(ScrW() - 10, 40)
end

function PANEL:Paint(w, h)
	local showOnOffButtons = IsValid(self.SelectedEnt) and HAT_TOGGLEABLE_ON_OFF[self.SelectedEnt:GetClass()] ~= nil
	self.onOffButtonFrame:SetVisible(showOnOffButtons)
	self.onButton:SetVisible(showOnOffButtons)
	self.offButton:SetVisible(showOnOffButtons)

	if IsValid(self.SelectedEnt) then
		local toScrDat = self.SelectedEnt:LocalToWorld(self.SelectedEnt:OBBCenter()):ToScreen()

		if GetConVar("hat_dispname_visible"):GetBool() then
			draw.SimpleText(self.SelectedEnt:GetModel(), "Trebuchet18", toScrDat.x, toScrDat.y, Color(255, 255, 255),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		if showOnOffButtons then
			local isOn = self.SelectedEnt:GetOn()
			local gap = 6
			local padding = self.ON_OFF_BUTTON_PADDING

			-- DHatButton auto-sizes itself to fit its label (see PerformLayout in dhatbutton.lua),
			-- so measure the real widths rather than assuming a fixed size.
			local onW, btnH = self.onButton:GetWide(), self.onButton:GetTall()
			local offW = self.offButton:GetWide()

			local frameW = onW + gap + offW + padding * 2
			local frameH = btnH + padding * 2

			local frameX = toScrDat.x - frameW / 2
			local frameY = toScrDat.y + 14

			self.onOffButtonFrame:SetPos(frameX, frameY)
			self.onOffButtonFrame:SetSize(frameW, frameH)

			self.onButton:SetPos(frameX + padding, frameY + padding)
			self.onButton:SetValue(isOn)
			self.onButton:SetColor(isOn and Color(60, 200, 60) or Color(120, 120, 120))

			self.offButton:SetPos(frameX + padding + onW + gap, frameY + padding)
			self.offButton:SetValue(not isOn)
			self.offButton:SetColor(not isOn and Color(200, 60, 60) or Color(120, 120, 120))
		end

		-- Lock icon over every bone locked in the currently displayed frame(s) - server-synced (see
		-- HAT.syncFrozenBones/"hat_frozen_bones") rather than read from the entity's own physics
		-- objects, since a server-side-only ragdoll has none client-side. Bone position still comes
		-- straight off the entity (GetBonePosition), which - unlike physics objects - is always
		-- networked for rendering, so it needs no syncing of its own.
		if self.FrozenBonesEnt == self.SelectedEnt and GetConVar("hat_frozenbones_visible"):GetBool() then
			local iconSize = 16
			surface.SetMaterial(FrozenIcon)
			surface.SetDrawColor(255, 255, 255, 255)

			for _, boneID in ipairs(self.FrozenBoneIDs) do
				local bonePos = self.SelectedEnt:GetBonePosition(boneID)
				if bonePos and bonePos ~= vector_origin then
					local boneScrPos = bonePos:ToScreen()
					if boneScrPos.visible then
						surface.DrawTexturedRect(boneScrPos.x - iconSize / 2, boneScrPos.y - iconSize / 2, iconSize, iconSize)
					end
				end
			end
		end
	end

	if (! IsValid(self.SelectedEnt)) then return end
	if (self.SelectedEnt:IsWorld()) then return end

	if self.SelectedPoser > HAT_SELECT_ENTITY then
		local scrpos
		local size

		if self.SelectedPoser == HAT_SELECT_FACE then
			local vEyePos = self.SelectedEnt:EyePos()

			local eyeattachment = self.SelectedEnt:LookupAttachment("eyes")
			if (eyeattachment == 0) then return end

			local attachment = self.SelectedEnt:GetAttachment(eyeattachment)
			scrpos = attachment.Pos:ToScreen()
			if (! scrpos.visible) then return end

			-- Work out the side distance to give a rough headsize box..
			local player_eyes = LocalPlayer():EyeAngles()
			local side = (attachment.Pos + player_eyes:Right() * 15):ToScreen()
			size = math.abs(side.x - scrpos.x)
		else
			local Bone = nil

			local lefthand, righthand = GetHandPositions(self.SelectedEnt)

			local BoneMatrix = lefthand
			if (self.SelectedPoser == HAT_SELECT_R_HAND) then BoneMatrix = righthand end
			if (! BoneMatrix) then return end

			local vPos = BoneMatrix:GetTranslation()

			scrpos = vPos:ToScreen()
			if (! scrpos.visible) then return end

			-- Work out the side distance to give a rough headsize box..
			local player_eyes = LocalPlayer():EyeAngles()
			local side = (vPos + player_eyes:Right() * 15):ToScreen()
			size = math.abs(side.x - scrpos.x)
		end

		surface.SetDrawColor(0, 255, 0, 255)
		surface.SetTexture(FacePoser)
		surface.DrawTexturedRect(scrpos.x - size, scrpos.y - size, size * 2, size * 2)
	end
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

derma.DefineControl("DHATMenu", "Henry's Animation Tool menu.", PANEL, "DPanel")
