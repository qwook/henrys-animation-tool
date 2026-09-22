local vgui = vgui

--[[   _
    ( )
   _| |   __   _ __   ___ ___     _ _
 /'_` | /'__`\( '__)/' _ ` _ `\ /'_` )
( (_| |(  ___/| |   | ( ) ( ) |( (_| |
`\__,_)`\____)(_)   (_) (_) (_)`\__,_)

	DHatToolbar - lays out child panels in a horizontal row, each with a fixed width and a shared
	height, separated by a gap and inset by a padding. Buttons added with align "left" (the
	default) are packed left to right from the left edge; buttons added with align "right" are
	packed left to right anchored to the right edge, after every left button is laid out. Add
	children with AddButton() rather than vgui.Create(..., toolbar) so the toolbar knows each
	panel's width and side.

--]]

PANEL = {}

AccessorFunc( PANEL, "m_iGap", "Gap" )
AccessorFunc( PANEL, "m_iPadding", "Padding" )
AccessorFunc( PANEL, "m_iButtonTall", "ButtonTall" )

function PANEL:Init()

	self.m_iGap = 2
	self.m_iPadding = 4
	self.m_iButtonTall = 40

	self.Items = {}

end

--
-- Creates a panel of panelType as a child of this toolbar and queues it
-- for layout at the given width. If width is omitted, the panel is left
-- to size itself (e.g. a DHatButton autosizing to its label) and its
-- width is read back at layout time, once the caller has finished
-- configuring it (SetText, etc). align is "left" (default) or "right".
--
function PANEL:AddButton( panelType, width, align )

	local panel = vgui.Create( panelType, self )

	table.insert( self.Items, { panel = panel, w = width, align = align } )

	self:InvalidateLayout()

	return panel

end

function PANEL:PerformLayout( w, h )

	local padding = self:GetPadding()
	local gap = self:GetGap()
	local buttonTall = self:GetButtonTall()

	-- Resolve auto-sized widths (and total them up) before laying anything out, since the right
	-- group's starting x depends on its total width.
	local rightWidth = 0

	for _, item in ipairs( self.Items ) do
		if not item.w then
			item.panel:InvalidateLayout( true )
			item.w = item.panel:GetWide()
		end

		if item.align == "right" then
			rightWidth = rightWidth + item.w + gap
		end
	end

	local x = padding
	local rightX = w - padding - math.max(rightWidth - gap, 0)

	for _, item in ipairs( self.Items ) do
		item.panel:SetSize( item.w, buttonTall )

		if item.align == "right" then
			item.panel:SetPos( rightX, ( h - buttonTall ) * 0.5 )
			rightX = rightX + item.w + gap
		else
			item.panel:SetPos( x, ( h - buttonTall ) * 0.5 )
			x = x + item.w + gap
		end
	end

end

derma.DefineControl( "DHatToolbar", "A horizontal row of fixed-width buttons with a gap and padding.", PANEL, "DPanel" )
