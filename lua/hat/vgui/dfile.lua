local vgui = vgui

--[[   _                                
    ( )                               
   _| |   __   _ __   ___ ___     _ _ 
 /'_` | /'__`\( '__)/' _ ` _ `\ /'_` )
( (_| |(  ___/| |   | ( ) ( ) |( (_| |
`\__,_)`\____)(_)   (_) (_) (_)`\__,_) 

--]]

PANEL = {}
AccessorFunc( PANEL, "m_bBorder", 			"DrawBorder", 		FORCE_BOOL )
AccessorFunc( PANEL, "m_bDisabled", 		"Disabled", 		FORCE_BOOL )
AccessorFunc( PANEL, "m_FontName", 			"Font" )


local MatFolder = Material( "icon16/folder.png" )
local MatFile = Material( "icon16/page_white.png" )

--[[---------------------------------------------------------

-----------------------------------------------------------]]
function PANEL:Init()

	self:SetContentAlignment( 5 )
	
	--
	-- These are Lua side commands
	-- Defined above using AccessorFunc
	--
	self:SetDrawBorder( true )
	self:SetDrawBackground( true )
	
	--
	self:SetTall( 22 )
	self:SetMouseInputEnabled( true )
	self:SetKeyboardInputEnabled( true )

	self:SetCursor( "hand" )
	self:SetFont( "DermaDefault" )

	self.Text = ""
	self.Icon = 1

end

--[[---------------------------------------------------------
	IsDown
-----------------------------------------------------------]]
function PANEL:IsDown()

	return self.Depressed

end

function PANEL:SetText( text, icon )
	self.Text = text
	self.Icon = icon
end

function PANEL:GetText()
	return self.Text
end

--[[---------------------------------------------------------

-----------------------------------------------------------]]
function PANEL:Paint( w, h )

	-- derma.SkinHook( "Paint", "Button", self, w, h )

	if self.Hovered then
		draw.RoundedBox( 4, 0, 0, w, h, Color(100, 150, 255) )
		draw.RoundedBox( 4, 1, 1, w-2, h-2, Color(80, 130, 235) )
	end

	if self.Icon == 1 then
		surface.SetMaterial( MatFolder )
	elseif self.Icon == 2 then
		surface.SetMaterial( MatFile )
	end
	surface.SetDrawColor( Color( 255, 255, 255 ) )
	surface.DrawTexturedRect( 3, 3, 16, 16 )

	draw.SimpleText( self:GetText(), DermaDefault, 20, h/2, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )

end

--[[---------------------------------------------------------
	UpdateColours
-----------------------------------------------------------]]
function PANEL:UpdateColours( skin )

	if ( self:GetDisabled() )						then return self:SetTextStyleColor( skin.Colours.Button.Disabled ) end
	if ( self.Depressed || self.m_bSelected )		then return self:SetTextStyleColor( skin.Colours.Button.Down ) end
	if ( self.Hovered )								then return self:SetTextStyleColor( skin.Colours.Button.Hover ) end

	return self:SetTextStyleColor( skin.Colours.Button.Normal )

end

--[[---------------------------------------------------------
   Name: PerformLayout
-----------------------------------------------------------]]
function PANEL:PerformLayout()
		
	--
	-- If we have an image we have to place the image on the left
	-- and make the text align to the left, then set the inset
	-- so the text will be to the right of the icon.
	--
	if ( IsValid( self.m_Image ) ) then
			
		self.m_Image:SetPos( 4, (self:GetTall() - self.m_Image:GetTall()) * 0.5 )
		
		self:SetTextInset( self.m_Image:GetWide() + 16, 0 )
		
	end

	DLabel.PerformLayout( self )

end

--[[---------------------------------------------------------
	SetDisabled
-----------------------------------------------------------]]
function PANEL:SetDisabled( bDisabled )

	self.m_bDisabled = bDisabled	
	self:InvalidateLayout()

end

--[[---------------------------------------------------------
   Name: SetConsoleCommand
-----------------------------------------------------------]]
function PANEL:SetConsoleCommand( strName, strArgs )

	self.DoClick = function( self, val ) 
						RunConsoleCommand( strName, strArgs ) 
				   end

end

function PANEL:DoClick( val )
end

function PANEL:DoClickB()
end

function PANEL:OnDepressed()
	self:DoClickB()
end

function PANEL:OnReleased()
end

function PANEL:DoClickInternal()
end

--[[---------------------------------------------------------
	OnMousePressed
-----------------------------------------------------------]]
function PANEL:OnMousePressed( mousecode )

	return DLabel.OnMousePressed( self, mousecode )

end

--[[---------------------------------------------------------
	OnMouseReleased
-----------------------------------------------------------]]
function PANEL:OnMouseReleased( mousecode )

	return DLabel.OnMouseReleased( self, mousecode )

end

derma.DefineControl( "DFile", "Lists files.", PANEL, "DPanel" )