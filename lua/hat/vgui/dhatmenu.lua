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

PANEL = {}
AccessorFunc(PANEL, "m_bStretchToFit", "StretchToFit")

--[[---------------------------------------------------------

-----------------------------------------------------------]]
function PANEL:Init()
	self:SetWorldClicker(true)
	self:SetDrawBackground(false)
	self:SetStretchToFit(true)

	self.SelectedPoser = 0

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

	-- Toolbar
	self.toolbar = vgui.Create("DHatToolbar", self.mainSheet)
	self.toolbar:SetPaintBackground(false)

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
			RunConsoleCommand("hat_save", fileList:GetCurrentDirectory() .. textEntry:GetText())
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

	self.optionsMenu = self.menuBar:AddMenu("Options")
	self.optionsMenu:AddOption("Play Options", function()
		self.playOptions:MakePopup()
		self.playOptions:SetVisible(true)
	end)
	self.optionsMenu:AddOption("Rebind HAT Menu Key", function()
		HAT.ShowKeyCapture()
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
	self.frameHolder:SetEntity(tonumber(id) + 1, ent)
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

function PANEL:DragNewFrame()
	self.frameHolder:DragNewFrame()
end

function PANEL:RemoveEntity(id)
	self.frameHolder:RemoveEntity(id + 1)
	self.frameHolder:SetEntity(1)
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

--[[---------------------------------------------------------
	OnMousePressed
-----------------------------------------------------------]]
function PANEL:OnMousePressed(mousecode)
	self.frameHolder:OnMousePressed(mousecode)
	if mousecode == MOUSE_RIGHT then
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
	self.toolbar:SetSize(ScrW(), 40)
end

function PANEL:Paint(w, h)
	if IsValid(self.SelectedEnt) then
		local toScrDat = self.SelectedEnt:LocalToWorld(self.SelectedEnt:OBBCenter()):ToScreen()
		draw.SimpleText(self.SelectedEnt:GetModel(), "Trebuchet18", toScrDat.x, toScrDat.y, Color(255, 255, 255),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
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
