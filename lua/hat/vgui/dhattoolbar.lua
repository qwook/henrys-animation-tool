local vgui = vgui

--[[   _
    ( )
   _| |   __   _ __   ___ ___     _ _
 /'_` | /'__`\( '__)/' _ ` _ `\ /'_` )
( (_| |(  ___/| |   | ( ) ( ) |( (_| |
`\__,_)`\____)(_)   (_) (_) (_)`\__,_)

	DHatToolbar - lays out child panels in a horizontal row, left to right,
	each with a fixed width and a shared height, separated by a gap and
	inset by a padding. Add children with AddButton() rather than
	vgui.Create(..., toolbar) so the toolbar knows each panel's width.

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
-- configuring it (SetText, etc).
--
function PANEL:AddButton( panelType, width )

	local panel = vgui.Create( panelType, self )

	table.insert( self.Items, { panel = panel, w = width } )

	self:InvalidateLayout()

	return panel

end

function PANEL:PerformLayout( w, h )

	local x = self:GetPadding()
	local buttonTall = self:GetButtonTall()

	for _, item in ipairs( self.Items ) do
		local itemWidth = item.w

		if not itemWidth then
			item.panel:InvalidateLayout( true )
			itemWidth = item.panel:GetWide()
		end

		item.panel:SetPos( x, ( h - buttonTall ) * 0.5 )
		item.panel:SetSize( itemWidth, buttonTall )
		x = x + itemWidth + self:GetGap()
	end

end

derma.DefineControl( "DHatToolbar", "A horizontal row of fixed-width buttons with a gap and padding.", PANEL, "DPanel" )
