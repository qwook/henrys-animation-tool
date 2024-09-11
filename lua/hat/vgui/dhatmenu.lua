local vgui = vgui

--[[   _                                
    ( )                               
   _| |   __   _ __   ___ ___     _ _ 
 /'_` | /'__`\( '__)/' _ ` _ `\ /'_` )
( (_| |(  ___/| |   | ( ) ( ) |( (_| |
`\__,_)`\____)(_)   (_) (_) (_)`\__,_) 

	DFrameHolder

--]]

local FacePoser	= surface.GetTextureID( "gui/faceposer_indicator" )

PANEL = {}
AccessorFunc( PANEL, "m_bStretchToFit", 			"StretchToFit" )

--[[---------------------------------------------------------

-----------------------------------------------------------]]
function PANEL:Init()

	self:SetWorldClicker( true )
	self:SetDrawBackground( false )
	self:SetStretchToFit( true )

	self.SelectedPoser = 0

	local hatMenu = self

	-- The Tab Holder
	--self.propertySheet = vgui.Create("DPropertySheet", self)

	--menu:Open()

	self.tutorialHTML = vgui.Create("DHTML", self)
	self.tutorialHTML:SetHTML(
	[[
		<html>
			<body style="padding: 0px; margin: 0px;">
				<iframe width="560" height="315" src="http://www.youtube.com/embed/Jg3DvQZFWwo?rel=0" frameborder="0" allowfullscreen></iframe>
			</body>
		</html>
	]]
	)
	self.tutorialHTML:SetVisible( false )

	-- Tutorial Panel
	self.tutorialBtn = vgui.Create("DButton", self)
	self.tutorialHideBtn = vgui.Create("DButton", self)

	self.tutorialBtn:SetText( "Video Tutorial" )
	self.tutorialBtn.DoClick = function()
		self.tutorialHTML:SetVisible( true )
		self.tutorialHideBtn:SetVisible( true )
		self.tutorialBtn:SetVisible( false )
	end

	-- Tutorial Panel
	self.tutorialHideBtn:SetText( "Hide" )
	self.tutorialHideBtn.DoClick = function()
		self.tutorialHTML:SetVisible( false )
		self.tutorialHideBtn:SetVisible( false )
		self.tutorialBtn:SetVisible( true )
	end
	self.tutorialHideBtn:SetVisible( false )

	-- Main Panel
	self.mainSheet = vgui.Create("DPanel", self)
	self.mainSheet.Paint = function(self, w, h)
		hatskin.drawFrame(0, 0, w, h)
		hatskin.drawFrameHolder( 4, 32, ScrW() - 8, 59 )
	end
	--self.propertySheet:AddSheet("Main", self.mainSheet)

		-- Frames Holder
		self.frameHolder = vgui.Create("DFrameHolder", self.mainSheet)

		-- Record Button
		self.recordButton = vgui.Create("DButton", self.mainSheet)
		self.recordButton:SetText("Snapshot")
		self.recordButton.Paint = function( self, w, h ) hatskin.drawButton( self.Depressed, self.Hovered, w, h ) end
		self.recordButton.PaintOver = function( self ) hatskin.drawRecordButton( self.Depressed, self.Hovered ) end
		self.recordButton.DoClick = function()
			RunConsoleCommand( "hat_frame_snapshot" )
		end

		-- Play Button
		self.playButton = vgui.Create("DButton", self.mainSheet)
		self.playButton:SetText("Play")
		self.playButton.Paint = function( self, w, h ) hatskin.drawButton( self.Depressed, self.Hovered, w, h ) end
		self.playButton.PaintOver = function( self ) hatskin.drawPlayButton( self.Depressed, self.Hovered ) end
		self.playButton.DoClick = function()
			RunConsoleCommand( "hat_play" )
		end

		-- Stop Button
		self.stopButton = vgui.Create("DButton", self.mainSheet)
		self.stopButton:SetText("Stop")
		self.stopButton.Paint = function( self, w, h ) hatskin.drawButton( self.Depressed, self.Hovered, w, h ) end
		self.stopButton.PaintOver = function( self ) hatskin.drawStopButton( self.Depressed, self.Hovered ) end
		self.stopButton.DoClick = function()
			RunConsoleCommand( "hat_stop" )
		end
	
		-- New Frame Button
		self.newButton = vgui.Create("DButton", self.mainSheet)
		self.newButton:SetText("New Frame")
		self.newButton.Paint = function( self, w, h ) hatskin.drawButton( self.Depressed, self.Hovered, w, h ) end
		self.newButton.PaintOver = function( self ) hatskin.drawNewButton( self.Depressed, self.Hovered ) end

			self.newButton.OlOnMousePressed = self.newButton.OnMousePressed
			self.newButton.OlOnMouseReleased = self.newButton.OnMouseReleased

			-- By this point, I might as well have created my own button.
			self.newButton.OnMousePressed = function( self )
				hatMenu:DragNewFrame()
				return self:OlOnMousePressed()
			end

			self.newButton.OnMouseReleased = function( self )
				hatMenu:FinishDragNewFrame( not self.Hovered )
				if self.Hovered then
					RunConsoleCommand( "hat_frame_add" )
				end
				return self:OlOnMouseReleased()
			end
	
	-- Menu Bar
	self.menuBar = vgui.Create("DMenuBar", self)

	local function MenuItemSelected()
		--RunConsoleCommand( "hat_new" )
	end

	self.fileMenu = self.menuBar:AddMenu( "File" )
		self.fileMenu:AddOption( "New", function()
		
			self:Hide()
		
			local confirmation = vgui.Create( "DFrame" )
			confirmation:SetSize( 250, 100 )
			confirmation:SetTitle( "New HAT Project" )
			confirmation:Center()
			confirmation:SetVisible( true )
			confirmation:ShowCloseButton( true )
			confirmation:MakePopup()
			confirmation:SetDeleteOnClose( true )
			confirmation:SetDraggable( false )
			
			local label = vgui.Create( "DLabel", confirmation )
			label:SetPos( 10, 10 )
			label:SetSize( 230, 100)
			label:SetText( "This will delete all user-created props\nand ragdolls on the map.\n\nAre you sure?" )
			
			local ok = vgui.Create( "DButton", confirmation )
			ok:SetPos( 140, 70 )
			ok:SetSize( 50, 25)
			ok:SetText( "Yes" )
			ok.DoClick = function() RunConsoleCommand( "hat_new" ) confirmation:Close() end
			
			local cancel = vgui.Create( "DButton", confirmation )
			cancel:SetPos( 195, 70 )
			cancel:SetSize( 50, 25)
			cancel:SetText( "No" )
			cancel.DoClick = function() confirmation:Close() end
			
		end	)
		self.fileMenu:AddOption( "Open...", function()
		
			self:Hide()
		
			local fileBrowser = vgui.Create( "DFrame" )
			fileBrowser:SetSize( 400, 275 )
			fileBrowser:SetTitle( "Open HAT Project" )
			fileBrowser:Center()
			fileBrowser:SetVisible( true )
			fileBrowser:ShowCloseButton( true )
			fileBrowser:MakePopup()
			fileBrowser:SetDeleteOnClose( true )
			fileBrowser:SetDraggable( false )
			
			local textEntry = vgui.Create( "DTextEntry", fileBrowser )
			local fileList = vgui.Create( "DFileList", fileBrowser )
			local openBtn = vgui.Create( "DButton", fileBrowser )
			
			textEntry:SetSize( 310, 20 )
			textEntry:SetPos( 10, 245 )
			
			local function open()
				RunConsoleCommand( "hat_load", fileList:GetCurrentDirectory() .. textEntry:GetText() )
				fileBrowser:Close()
			end
			
			textEntry.OnEnter = open
			
			fileList:SetPos( 10, 35 )
			fileList:SetSize( 380, 200 )
			fileList.LastClick = 0
			fileList.OnFileClick = function( self, fileName )
				if textEntry:GetText() == fileName and self.LastClick > RealTime() - 0.5 then
					open()
				end
				textEntry:SetText(fileName)
				self.LastClick = RealTime()
			end
			
			openBtn:SetPos( 325, 245 )
			openBtn:SetSize( 65, 20 )
			openBtn:SetText( "Open" )
			openBtn.DoClick = function( self, fileName )
				open()
			end
			
		end )
		self.fileMenu:AddOption( "Save As...", function()
		
			self:Hide()
		
			local fileBrowser = vgui.Create( "DFrame" )
			fileBrowser:SetSize( 400, 275 )
			fileBrowser:SetTitle( "Save HAT Project" )
			fileBrowser:Center()
			fileBrowser:SetVisible( true )
			fileBrowser:ShowCloseButton( true )
			fileBrowser:MakePopup()
			fileBrowser:SetDeleteOnClose( true )
			fileBrowser:SetDraggable( false )
			
			local textEntry = vgui.Create( "DTextEntry", fileBrowser )
			local fileList = vgui.Create( "DFileList", fileBrowser )
			local saveBtn = vgui.Create( "DButton", fileBrowser )
			
			textEntry:SetSize( 310, 20 )
			textEntry:SetPos( 10, 245 )
			
			local function save()
				RunConsoleCommand( "hat_save", fileList:GetCurrentDirectory() .. textEntry:GetText() )
				fileBrowser:Close()
			end
			
			textEntry.OnEnter = save
			
			fileList:SetPos( 10, 35 )
			fileList:SetSize( 380, 200 )
			fileList.LastClick = 0
			fileList.OnFileClick = function( self, fileName )
				if textEntry:GetText() == fileName and self.LastClick > RealTime() - 0.5 then
					save()
				end
				textEntry:SetText(fileName)
				self.LastClick = RealTime()
			end
			
			saveBtn:SetPos( 325, 245 )
			saveBtn:SetSize( 65, 20 )
			saveBtn:SetText( "Save" )
			saveBtn.DoClick = function( self, fileName )
				save()
			end
			
		end )

	self.playOptions = vgui.Create( "DFrame" )
		self.playOptions:SetSize( 310, 100 )
		self.playOptions:SetTitle( "Play Options" )
		self.playOptions:Center()
		self.playOptions:SetVisible( true )
		self.playOptions:ShowCloseButton( true )
		self.playOptions:SetDraggable( false )
		self.playOptions:SetDeleteOnClose( false )
			local slider = vgui.Create( "DNumSlider", self.playOptions )
			slider:SetPos( 5, 25 )
			slider:SetWide( 300 )
			slider:SetText( "Play Rate" )
			slider:SetMin( 0 )
			slider:SetMax( 4 )
			slider:SetDecimals( 4 )
			slider:SetConVar( "hat_playrate" )
			local check = vgui.Create( "DCheckBoxLabel", self.playOptions )
			check:SetWide( 300 )
			check:SetPos( 5, 55 )
			check:SetText( "Stop Motion" )
			check:SetConVar( "hat_stopmotion" )
		self.playOptions:SetVisible( false )

	self.optionsMenu = self.menuBar:AddMenu( "Options" )
		self.optionsMenu:AddOption( "Play Options", function()
			self.playOptions:MakePopup()
			self.playOptions:SetVisible( true )
	end )

	--local submenu = self.menuBar:AddSubMenu( "Option Free" )
	--	submenu:AddOption( "Submenu 1", MenuItemSelected )
	--	submenu:AddOption( "Submenu 2", MenuItemSelected )
	--self.menuBar:AddOption( "Option For", MenuItemSelected )

	self:SetColor( Color( 255, 255, 255, 255 ) )

end

function PANEL:Show()
	self.menuBar:Show()
	self:MakePopup()
	self:SetVisible(true)
	self:SetMouseInputEnabled( true )
	self:SetKeyBoardInputEnabled( false )
	RestoreCursorPosition()
end

function PANEL:Hide()
	self.menuBar:Hide()
	self.fileMenu:Hide()
	RememberCursorPosition()
	self:SetVisible(false)
end

PANEL.SetIcon = PANEL.SetImage

function PANEL:Load( toLoad )
	self.frameHolder:Load( toLoad )
	timer.Simple( 0.01, function()
		if toLoad.currentObjId and toLoad.objects[toLoad.currentObjId] then
			self.SelectedEnt = ents.GetByIndex(toLoad.objects[toLoad.currentObjId].ent)
		end
	end)
end

function PANEL:SetEntity( id, ent, posetype )
	self.frameHolder:SetEntity( tonumber( id ) + 1 )
	self.SelectedEnt = ent
	self.SelectedPoseType = posetype
end

function PANEL:NewFrame( id, length, pos )
	self.frameHolder:NewFrame( id + 1, length or HAT_DEFAULT_LENGTH, pos )
end

function PANEL:RemoveFrame( id, pos )
	self.frameHolder:RemoveFrame( id + 1, pos )
end

function PANEL:MoveFrame( id, frameFrom, frameTo )
	self.frameHolder:MoveFrame( id + 1, frameFrom, frameTo )
end

function PANEL:SelectFrame( id, frame )
	self.frameHolder:SelectFrame( id + 1, frame )
end

function PANEL:DragNewFrame()
	self.frameHolder:DragNewFrame()
end

function PANEL:RemoveEntity( id )
	self.frameHolder:RemoveEntity( id + 1 )
	self.frameHolder:SetEntity( 1 )
end

function PANEL:Play( start )
	self.frameHolder:Play( start )
end

function PANEL:Stop()
	self.frameHolder:Stop()
end

function PANEL:FinishDragNewFrame( shouldMakeNewFrame )
	self.frameHolder:FinishDragNewFrame( shouldMakeNewFrame )
end

--[[---------------------------------------------------------
	SetColor
-----------------------------------------------------------]]
function PANEL:SetColor( col )

end

--[[---------------------------------------------------------
	SetKeepAspect
-----------------------------------------------------------]]
function PANEL:SetKeepAspect( bKeep )

end

--[[---------------------------------------------------------
	SizeToContents
-----------------------------------------------------------]]
function PANEL:SizeToContents( )

end

-- Stolen from the finger stool.
local function GetHandPositions( pEntity )

	local LeftHand = pEntity:LookupBone( "ValveBiped.Bip01_L_Hand" )
	if (!LeftHand) then LeftHand = pEntity:LookupBone( "bip_hand_L" ) end
	if (!LeftHand) then LeftHand = pEntity:LookupBone( "Bip01_L_Hand" ) end
	
	local RightHand = pEntity:LookupBone( "ValveBiped.Bip01_R_Hand" )
	if (!RightHand) then RightHand = pEntity:LookupBone( "bip_hand_R" ) end
	if (!RightHand) then RightHand = pEntity:LookupBone( "Bip01_R_Hand" ) end
	
	if (!LeftHand || !RightHand) then return false end
	
	local LeftHand = pEntity:GetBoneMatrix( LeftHand )	
	local RightHand = pEntity:GetBoneMatrix( RightHand )
	if (!LeftHand || !RightHand) then return false end

	return LeftHand, RightHand
	
end

-- Find out if we selected a head or hands.
local function CheckHeadAndHands( tr )

		if ( !IsValid( tr.Entity ) ) then return 0 end
		if ( tr.Entity:IsWorld() ) then return 0 end
		
		local vEyePos = tr.Entity:EyePos()
		
		local eyeattachment = tr.Entity:LookupAttachment( "eyes" )
		if (eyeattachment ~= 0) then
		
			local attachment = tr.Entity:GetAttachment( eyeattachment )
			if attachment.Pos:Distance( tr.HitPos ) < 7 then
				return HAT_SELECT_FACE
			end

		end

		local LeftHand, RightHand = GetHandPositions( tr.Entity )

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

function PANEL:SetPoser( poser )
	self.SelectedPoser = poser
end

--[[---------------------------------------------------------
	OnMousePressed
-----------------------------------------------------------]]
function PANEL:OnMousePressed( mousecode )
	self.frameHolder:OnMousePressed( mousecode )
	if mousecode == MOUSE_RIGHT then
		local playerTrace = util.GetPlayerTrace( LocalPlayer() )
		playerTrace.filter = {LocalPlayer()}
		for k,v in pairs(ents.GetAll()) do
			if v:GetNWBool( "ignore" ) then
				table.insert( playerTrace.filter, v )
			end
		end
		local tr = util.TraceLine( playerTrace )
		if IsValid(tr.Entity) and not tr.Entity:GetNWBool("ignore") then
			RunConsoleCommand( "hat_select", tr.Entity:EntIndex(), CheckHeadAndHands( tr ) )
		end
	end
end

--[[---------------------------------------------------------
	OnMouseReleased
-----------------------------------------------------------]]
function PANEL:OnMouseReleased( mousecode )
	self.frameHolder:OnMouseReleased( mousecode )
	if mousecode == MOUSE_RIGHT then
	end
end

--[[---------------------------------------------------------

-----------------------------------------------------------]]
function PANEL:PerformLayout()

	self.tutorialBtn:SetPos( ScrW() - 105, ScrH() - 165 )
	self.tutorialBtn:SetSize( 100, 25 )

	self.tutorialHTML:SetPos( ScrW() - 565, ScrH() - 455 )
	self.tutorialHTML:SetSize( 560, 315 )

	self.tutorialHideBtn:SetPos( ScrW() - 85, ScrH() - 485 )
	self.tutorialHideBtn:SetSize( 80, 25 )

	self:SetPos( 0, 0 )
	self:SetSize(ScrW(), ScrH())

	self.menuBar:SetPos( 0, 0 )
	self.menuBar:SetSize(ScrW(), 25)

	self.mainSheet:SetPos( 0, ScrH() - 134 )
	self.mainSheet:SetSize(ScrW(), 134)

		self.frameHolder:SetPos(10, 36)
		self.frameHolder:SetSize(ScrW() - 24, 50)

		self.recordButton:SetPos(4, 93)
		self.recordButton:SetSize(97, 40)

		self.playButton:SetPos(101, 93)
		self.playButton:SetSize(42, 40)
		
		self.stopButton:SetPos(143, 93)
		self.stopButton:SetSize(45, 40)

		self.newButton:SetPos(188, 93)
		self.newButton:SetSize(87, 40)

end

function PANEL:Paint(w, h)
	if IsValid(self.SelectedEnt) then
		local toScrDat = self.SelectedEnt:LocalToWorld( self.SelectedEnt:OBBCenter() ):ToScreen()
		draw.SimpleText( self.SelectedEnt:GetModel(), "Trebuchet18", toScrDat.x, toScrDat.y, Color( 255, 255, 255 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
	end

	if ( !IsValid( self.SelectedEnt ) ) then return end
	if ( self.SelectedEnt:IsWorld() ) then return end

	if self.SelectedPoser > HAT_SELECT_ENTITY then
		local scrpos
		local size

		if self.SelectedPoser == HAT_SELECT_FACE then

			local vEyePos = self.SelectedEnt:EyePos()
			
			local eyeattachment = self.SelectedEnt:LookupAttachment( "eyes" )
			if (eyeattachment == 0) then return end
			
			local attachment = self.SelectedEnt:GetAttachment( eyeattachment )
			scrpos = attachment.Pos:ToScreen()
			if (!scrpos.visible) then return end

			-- Work out the side distance to give a rough headsize box..
			local player_eyes = LocalPlayer():EyeAngles()
			local side = (attachment.Pos + player_eyes:Right() * 15):ToScreen()
			size = math.abs( side.x - scrpos.x )
		else

			local Bone = nil
			
			local lefthand, righthand = GetHandPositions( self.SelectedEnt )
			
			local BoneMatrix = lefthand
			if ( self.SelectedPoser == HAT_SELECT_R_HAND ) then BoneMatrix = righthand end
			if (!BoneMatrix) then return end
			
			local vPos = BoneMatrix:GetTranslation()
			
			scrpos = vPos:ToScreen()
			if (!scrpos.visible) then return end
			
			-- Work out the side distance to give a rough headsize box..
			local player_eyes = LocalPlayer():EyeAngles()
			local side = (vPos + player_eyes:Right() * 15):ToScreen()
			size = math.abs( side.x - scrpos.x )
			
		end

		surface.SetDrawColor( 0, 255, 0, 255 )
		surface.SetTexture( FacePoser )
		surface.DrawTexturedRect( scrpos.x-size, scrpos.y-size, size*2, size*2 )
	end
end

--[[---------------------------------------------------------

-----------------------------------------------------------]]
function PANEL:SetDisabled( bDisabled )

	DButton.SetDisabled( self, bDisabled )

end

--[[---------------------------------------------------------

-----------------------------------------------------------]]
function PANEL:SetOnViewMaterial( MatName, Backup )


end

--[[---------------------------------------------------------
   Name: GenerateExample
-----------------------------------------------------------]]
function PANEL:GenerateExample( ClassName, PropertySheet, Width, Height )

end

derma.DefineControl( "DHATMenu", "Henry's Animation Tool menu.", PANEL, "DPanel" )