local vgui = vgui

--[[   _
    ( )
   _| |   __   _ __   ___ ___     _ _
 /'_` | /'__`\( '__)/' _ ` _ `\ /'_` )
( (_| |(  ___/| |   | ( ) ( ) |( (_| |
`\__,_)`\____)(_)   (_) (_) (_)`\__,_)

	DHatSelectBox - a DButton that paints itself with hatskin.drawSelectBox, looking like an
	inset textbox showing a current value rather than a raised button. Meant for buttons that
	open a dropdown menu of choices (see the Easing button in dhatmenu.lua).

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
-- SetText overrides the label hatskin.drawSelectBox draws, while self:SetText("") above keeps
-- DButton from drawing its own default text.
--
function PANEL:SetText( text )

	self.Label = text or ""
	self:InvalidateLayout()

end

function PANEL:GetText()

	return self.Label

end

--
-- Sizes the box to fit its label plus Padding on each side, using the same font
-- hatskin.drawSelectBox uses to draw the label.
--
function PANEL:PerformLayout( w, h )

	surface.SetFont( "Arial18" )
	local textWidth, textHeight = surface.GetTextSize( self.Label )
	local padding = self:GetPadding()

	self:SetSize( textWidth + padding * 2, textHeight + padding * 2 )

end

function PANEL:Paint( w, h )

	hatskin.drawSelectBox( self.Label, w, h, self:GetColor(), self.Hovered )

	return true

end

derma.DefineControl( "DHatSelectBox", "A button skinned with hatskin.drawSelectBox, looking like an inset textbox.", PANEL, "DButton" )
