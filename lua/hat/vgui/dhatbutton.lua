local vgui = vgui

--[[   _
    ( )
   _| |   __   _ __   ___ ___     _ _
 /'_` | /'__`\( '__)/' _ ` _ `\ /'_` )
( (_| |(  ___/| |   | ( ) ( ) |( (_| |
`\__,_)`\____)(_)   (_) (_) (_)`\__,_)

	DHatButton - a DButton that paints itself with hatskin.drawGenericButton
	instead of the default derma skin, using its own label + color rather
	than the built-in DButton text drawing.

--]]

PANEL = {}

AccessorFunc( PANEL, "m_Color", "Color" )
AccessorFunc( PANEL, "m_Padding", "Padding" )

function PANEL:Init()

	self:SetText( "" )
	self.Label = ""
	self.m_Color = Color( 120, 120, 120 )
	self.m_Padding = 8

end

--
-- SetText overrides the label hatskin.drawGenericButton draws, while
-- self:SetText("") above keeps DButton from drawing its own default text.
--
function PANEL:SetText( text )

	self.Label = text or ""
	self:InvalidateLayout()

end

function PANEL:GetText()

	return self.Label

end

--
-- Sizes the button to fit its label plus Padding on each side, using the
-- same font hatskin.drawGenericButton uses to draw the label.
--
function PANEL:PerformLayout( w, h )

	surface.SetFont( "Arial18" )
	local textWidth, textHeight = surface.GetTextSize( self.Label )
	local padding = self:GetPadding()

	self:SetSize( textWidth + padding * 2, textHeight + padding * 2 )

end

function PANEL:Paint( w, h )

	hatskin.drawGenericButton( self.Label, w, h, self:GetColor(), self.Depressed, self.Hovered )

	return true

end

derma.DefineControl( "DHatButton", "A button skinned with hatskin.drawGenericButton.", PANEL, "DButton" )
