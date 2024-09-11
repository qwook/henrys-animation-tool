--[[   _                                
    ( )                               
   _| |   __   _ __   ___ ___     _ _ 
 /'_` | /'__`\( '__)/' _ ` _ `\ /'_` )
( (_| |(  ___/| |   | ( ) ( ) |( (_| |
`\__,_)`\____)(_)   (_) (_) (_)`\__,_) 

	DFrameHolder - AKA CLUSTERFUCK OF FUNCTIONS OH GOD I NEED TO SPLIT THIS UP

--]]

HAT_PlayRate = GetConVar( "hat_playrate" )

PANEL = {}
AccessorFunc( PANEL, "m_bStretchToFit", 			"StretchToFit" )

--[[---------------------------------------------------------

-----------------------------------------------------------]]
function PANEL:Init()

	self.Enabled = true

	self:SetDrawBackground( false )
	self:SetStretchToFit( true )

	self.btnGrip = vgui.Create( "DScrollBarGrip", self )
	self.btnGrip:SetText("")
	self.btnGrip.Paint = function( self, w, h ) hatskin.drawScrollBar( 0, 0, w, h ) end

	self.Entities =
	{
		{
			Frames = {},
			ScrollRatio = 0,
			SelectedFrame = 1
		}
	}
	self.CurEntity = 1

	self.FramesSize = self:GetFramesSize()
	self.LastFramesSize = self.FramesSize

	self:SetColor( Color( 255, 255, 255, 255 ) )

	self.ScrollRatio = 0

	self.DraggingNewFrame = false
	self.HoldingFrame = false
	self.DraggingFrame = false

	self.DragFrameLength = nil
	self.DragFrameMouseX = 0
	self.DragFrameLengthO = 0
	
	self.Cursor = ""
	
	self:SetCursor( "arrow" )
end

local function newFrame( length )
	return {l=length, cA={0.5, 0.5}, cB={0.5, 0.5}, c=Color(math.random(180, 225),math.random(180, 225),math.random(180, 225))}
end

function PANEL:QueryCursor( cursor )
	if self.Cursor == cursor then return end
	
	self.Cursor = cursor
	self:SetCursor( cursor )
end

function PANEL:Load( toLoad )
	self.Entities =
	{
		{
			Frames = {},
			ScrollRatio = 0,
			SelectedFrame = 1
		}
	}
	for k,v in pairs(toLoad.objects) do
			self.Entities[k+1] = {
				Frames = {},
				ScrollRatio = 0,
				SelectedFrame = 1
			}
		for frame,v in ipairs(v.frames) do
			self.Entities[k+1].Frames[frame] = newFrame(v)
		end
	end
	self.CurEntity = ( toLoad.currentObjId or 0 ) + 1
end

function PANEL:SetEntity( id )
	self.CurEntity = id
	self.Entities[id] = self.Entities[id] or {Frames={newFrame(HAT_DEFAULT_LENGTH)},ScrollRatio=0,SelectedFrame=1}
	self.LastFramesSize = self:GetFramesSize()
	self:PerformLayout()
end

function PANEL:RemoveEntity( id )
	self.Entities[id] = nil
	--table.remove( self.Entities, id )
end

function PANEL:NewFrame( id, length, pos )
	if pos then
		table.insert( self.Entities[id].Frames, pos, newFrame(length) )
	else
		table.insert( self.Entities[id].Frames, newFrame(length) )
	end
	self:PerformLayout()
end

function PANEL:RemoveFrame( id, frame )
	table.remove( self.Entities[id].Frames, frame )
end

function PANEL:DragNewFrame()
	self.DraggingNewFrame = true
end

function PANEL:FinishDragNewFrame( shouldMakeNewFrame )
	local x, y = gui.MouseX(), gui.MouseY()
	local x, y = self:ScreenToLocal( x, y )

	self.DraggingNewFrame = false
	if shouldMakeNewFrame and y >= 0 and y <= 30 then
		local newFrame = self:GetNewFrame()
		RunConsoleCommand( "hat_frame_add", newFrame )
	end
end

function PANEL:SelectFrame( id, frame )
	self.Entities[id].SelectedFrame = frame
end

function PANEL:GetNewFrame()
	local x, y = gui.MouseX(), gui.MouseY()
	local x, y = self:ScreenToLocal( x, y )

	local scrollOffset = self.Entities[self.CurEntity].ScrollRatio * (self.FramesSize - self:GetWide())
	local offsetX = math.floor(-scrollOffset)

	local newFrameSpeculation
	local count = 0

	for i,val in pairs( self.Entities[self.CurEntity].Frames ) do
		local length = val.l
		local l, c, r = offsetX, offsetX + 1 + (HAT_DEFAULT_FRAME_SIZE * length + 2)/2, offsetX + 2 + (HAT_DEFAULT_FRAME_SIZE * length + 2)
		if x >= l and x <= c then
			newFrameSpeculation = i
		elseif x >= c and x <= r then
			newFrameSpeculation = i + 1
		end

		offsetX = offsetX + HAT_DEFAULT_FRAME_SIZE * length + 5
		count = i + 1
	end
	
	return newFrameSpeculation or count
end

function PANEL:MoveFrame( id, frameFrom, frameTo )

	local frame = self.Entities[ self.CurEntity ].Frames[frameFrom]
	self:RemoveFrame( self.CurEntity, frameFrom )
	table.insert( self.Entities[ self.CurEntity ].Frames, frameTo, frame )
	self:PerformLayout()
	
end

function PANEL:GetIncreaseLengthFrame()
	local x, y = gui.MouseX(), gui.MouseY()
	local x, y = self:ScreenToLocal( x, y )

	local scrollOffset = self.Entities[self.CurEntity].ScrollRatio * (self.FramesSize - self:GetWide())
	local offsetX = math.floor(-scrollOffset)

	local increaseFrameSpeculation

	for i,val in pairs( self.Entities[self.CurEntity].Frames ) do
		local length = val.l

		local l, r = offsetX, offsetX + 2 + (HAT_DEFAULT_FRAME_SIZE * length + 2)
		if x >= l and x >= r - 5 and x <= r then
			increaseFrameSpeculation = i
		end

		offsetX = offsetX + HAT_DEFAULT_FRAME_SIZE * length + 5
	end
	
	return increaseFrameSpeculation
end

function PANEL:GetFrameHovered()
	local x, y = gui.MouseX(), gui.MouseY()
	local x, y = self:ScreenToLocal( x, y )

	local scrollOffset = self.Entities[self.CurEntity].ScrollRatio * (self.FramesSize - self:GetWide())
	local offsetX = math.floor(-scrollOffset)

	for i,val in pairs( self.Entities[self.CurEntity].Frames ) do
		local length = val.l

		if (self.DragFrameLength and self.DragFrameLength == i) or ( not self.DragFrameLength and x >= offsetX and x <= offsetX + HAT_DEFAULT_FRAME_SIZE * length + 4 and y >= 0 and y <= 30 ) then
			return i
		end

		offsetX = offsetX + HAT_DEFAULT_FRAME_SIZE * length + 5
	end
end

function PANEL:Play( start )
	self.StartTime = start
	-- prep
	for _,obj in pairs( self.Entities ) do
		local length = 0
		for _,frame in pairs(obj.Frames) do
			frame.start = length
			length = length + frame.l
		end
	end
end

function PANEL:Stop()
	self.StartTime = nil
end

function PANEL:Think()

	if self.Dragging then

		local x, y = gui.MouseX(), 0
		local x, y = self.btnGrip:ScreenToLocal( x, y )

		local gX, gY = self.btnGrip:GetPos()
		local ratio = self:GetWide() / self.FramesSize
		local fullBarSize = (self:GetWide() - 30)

		if ratio <= 1 then
			self.Entities[self.CurEntity].ScrollRatio = self.Entities[self.CurEntity].ScrollRatio + ((x - self.HoldPos)/(fullBarSize - self.BarSize + 1))
		end

		self:PerformLayout()

		self.Entities[self.CurEntity].ScrollRatio = math.Clamp(self.Entities[self.CurEntity].ScrollRatio, 0, 1)

	end

	local x, y = gui.MouseX(), 0
	local x, y = self:ScreenToLocal( x, y )

	if self.DragFrameLength then

		self.Entities[self.CurEntity].Frames[self.DragFrameLength].l = math.max(self.DragFrameLengthO + (x - self.DragFrameMouseX)/ HAT_DEFAULT_FRAME_SIZE, 0)

	end

	if self.HoldingFrame and self.HoldingFrame ~= self:GetFrameHovered() then

		self.DraggingFrame = true

	end

end

local function drawLine( vecA, vecB )
	surface.DrawLine( vecA.x, vecA.y, vecB.x, vecB.y )
end

local function bezierCurve( t, tbl )
	local newTbl = {}
	for i = 1,#tbl-1 do
		table.insert( newTbl, LerpVector( t, tbl[i], tbl[i+1] ) )
	end
	if #newTbl == 1 then
		return newTbl[1]
	end
	return bezierCurve( t, newTbl )
end

function PANEL:Paint( w, h )

	local x, y = gui.MouseX(), gui.MouseY()
	local x, y = self:ScreenToLocal( x, y )

	-- Calculate offset caused by scrolling.
	local scrollOffset = self.Entities[self.CurEntity].ScrollRatio * (self.FramesSize - self:GetWide())
	local offsetX = math.floor(-scrollOffset)

	-- Initiate variables for calculating
	-- The green bar that shows up when you create a new frame
	-- Or move a frame.
	local newFrameSpeculation
	local newFrameSpeculationX

	local localTime = nil
	local drawTime = false
	if self.StartTime then
		drawTime = true
		localTime = CurTime() * HAT_PlayRate:GetFloat() - self.StartTime
	end
	
	local cursorChanged = false

	for i, val in pairs( self.Entities[self.CurEntity].Frames ) do
		local length = val.l

		-- Draw frame outline.
		if self.Entities[self.CurEntity].SelectedFrame == i then
			surface.SetDrawColor(Color(100, 100, 255))
		else
			surface.SetDrawColor(Color(100, 100, 100))
		end
		surface.DrawRect(offsetX, 0, HAT_DEFAULT_FRAME_SIZE * length + 4, 30)

		-- Draw the frame's unique color.
		surface.SetDrawColor(val.c)
		surface.DrawRect(offsetX + 1, 1, HAT_DEFAULT_FRAME_SIZE * length + 2, 28)

		-- See if this frame is selected
		if self.Entities[self.CurEntity].SelectedFrame == i then
			-- Set the color to signify we're selecting the frame.
			surface.SetDrawColor(Color(0, 0, 0, 100))
			surface.DrawRect(offsetX + 3, 3, HAT_DEFAULT_FRAME_SIZE * length-2, 24)
		-- Check to see if we're dragging the frame.
		elseif (self.DragFrameLength and self.DragFrameLength == i) or
			( not self.DragFrameLength and
				-- If not, check to see if the mouse is over the frame.
				x >= offsetX and x <= offsetX + HAT_DEFAULT_FRAME_SIZE * length + 4 and
				y >= 0 and y <= 30 ) then
			-- Set the color to signify we're highlighting the frame.
			surface.SetDrawColor(Color(225, 225, 225, 50))
			surface.DrawRect(offsetX + 1, 1, HAT_DEFAULT_FRAME_SIZE * length + 2, 28)
		end

		local dX = math.max( offsetX + 1, HAT_DEFAULT_FRAME_SIZE * length + offsetX - 2 )
		local dY = 1
		local dW = math.min( HAT_DEFAULT_FRAME_SIZE * length + 2, 5 )
		local dH = 28
		-- Draw the length dragger area.
		surface.SetDrawColor(Color(0, 0, 0, 50))
		surface.DrawRect(dX, dY, dW, dH)

		if (self.DragFrameLength and self.DragFrameLength == i) or (x > dX and x <= dX + dW and y >= dY and y <= dY + dH ) then
			self:QueryCursor( "sizewe" )
			cursorChanged = true
		end
		
		-- Check to see if this frame is where the player wants to put the new frame.
		local l, c, r = offsetX, offsetX + 1 + (HAT_DEFAULT_FRAME_SIZE * length + 2)/2, offsetX + 2 + (HAT_DEFAULT_FRAME_SIZE * length + 2)
		if (self.DraggingNewFrame or self.DraggingFrame) and y >= 0 and y <= 30 then
			if x >= l and x <= c then
				newFrameSpeculation = i
				newFrameSpeculationX = l-2
			elseif x >= c and x <= r then
				newFrameSpeculation = i + 1
				newFrameSpeculationX = r-1
			end
		end

		if drawTime then
			local delta = (localTime - val.start) / val.l
			if delta >= 0 and delta < 1 then
				surface.SetDrawColor(Color(0, 255, 0))
				surface.DrawRect( offsetX + (HAT_DEFAULT_FRAME_SIZE * length + 2) * delta, 0, 2, 30 )
				drawTime = false
			end
		end

		-- Calculate the offset.
		offsetX = offsetX + HAT_DEFAULT_FRAME_SIZE * length + 5
	end

	-- If we're dragging a new frame, draw the green line.
	if self.DraggingNewFrame or self.DraggingFrame then
		surface.SetDrawColor(Color(10, 150, 10))
		if newFrameSpeculationX then
			surface.DrawRect(newFrameSpeculationX, 0, 4, 30)
		else
			surface.DrawRect(offsetX - 2, 0, 4, 30)
		end
	end
	
	if not cursorChanged then
		self:QueryCursor( "arrow" )
	end

end

function PANEL:GetFramesSize()

	local accumLength = 0

	for i,val in pairs( self.Entities[self.CurEntity].Frames ) do
		local length = val.l
		accumLength = accumLength + HAT_DEFAULT_FRAME_SIZE * length + 5
	end

	return accumLength - 1

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

-- This makes it compatible with the older ImageButton
PANEL.SetMaterial = PANEL.SetImage


--[[---------------------------------------------------------
	SizeToContents
-----------------------------------------------------------]]
function PANEL:SizeToContents( )

end

--[[---------------------------------------------------------
	OnMousePressed
-----------------------------------------------------------]]
function PANEL:OnMousePressed( mousecode )

	self:MouseCapture( true )

	local x, y = gui.MouseX(), gui.MouseY()
	local x, y = self:ScreenToLocal( x, y )

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

	elseif mousecode == MOUSE_RIGHT then

		if frameHovered then
			RunConsoleCommand( "hat_frame_remove", frameHovered )
		end

	end

end

--[[---------------------------------------------------------
	OnMouseReleased
-----------------------------------------------------------]]
function PANEL:OnMouseReleased( mousecode )

	self.Dragging = false
	self.DraggingCanvas = nil
	self:MouseCapture( false )
	
	self.btnGrip.Depressed = false

	if mousecode == MOUSE_LEFT then
		if self.DragFrameLength and self.Entities[self.CurEntity].Frames[self.DragFrameLength].l ~= self.DragFrameLengthO then
			RunConsoleCommand( "hat_frame_setlength", self.DragFrameLength, self.Entities[self.CurEntity].Frames[self.DragFrameLength].l )
		else
			RunConsoleCommand( "hat_frame_select", self.HoldingFrame or self.DragFrameLength )
		end
		if self.DraggingFrame then
			local newFrame = self:GetNewFrame()
			if newFrame > self.HoldingFrame then
				newFrame = newFrame - 1
			end

			RunConsoleCommand( "hat_frame_move", self.HoldingFrame, newFrame )

			self.DraggingFrame = nil
		end
		self.HoldingFrame = nil
		self.DragFrameLength = nil
	end

	self:PerformLayout()
	
end


--[[---------------------------------------------------------

-----------------------------------------------------------]]
function PANEL:PerformLayout()

	self.FramesSize = self:GetFramesSize()
	local ratio = self:GetWide() / self.FramesSize

	if self.LastFramesSize != self.FramesSize then
		self.Entities[self.CurEntity].ScrollRatio = math.Clamp((self.Entities[self.CurEntity].ScrollRatio * ( self.LastFramesSize - self:GetWide() ) / ( self.FramesSize - self:GetWide() )), 0, 1)
	end

	if ratio > 1 then
		self.Entities[self.CurEntity].ScrollRatio = 0
		ratio = 1
	end

	local fullBarSize = (self:GetWide()--[[ - 30]])
	self.BarSize = fullBarSize * ratio

	self.btnGrip:SetPos(--[[15 +]] self.Entities[self.CurEntity].ScrollRatio * (fullBarSize - self.BarSize + 1),self:GetTall() - 12)
	self.btnGrip:SetSize(self.BarSize, 12)

	self.LastFramesSize = self.FramesSize

end

--[[---------------------------------------------------------
   Name: Grip
-----------------------------------------------------------]]
function PANEL:Grip()

	if ( !self.Enabled ) then return end
	if ( self.BarSize == 0 ) then return end

	self:MouseCapture( true )
	self.Dragging = true
	
	local x, y = gui.MouseX(), 0
	local x, y = self.btnGrip:ScreenToLocal( x, y )
	self.HoldPos = x
	
	self.btnGrip.Depressed = true
	
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

derma.DefineControl( "DFrameHolder", "Holds frames.", PANEL, "DPanel" )