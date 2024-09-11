local vgui = vgui

--[[   _                                
    ( )                               
   _| |   __   _ __   ___ ___     _ _ 
 /'_` | /'__`\( '__)/' _ ` _ `\ /'_` )
( (_| |(  ___/| |   | ( ) ( ) |( (_| |
`\__,_)`\____)(_)   (_) (_) (_)`\__,_) 

--]]

PANEL = {}
AccessorFunc( PANEL, "m_bStretchToFit", 			"StretchToFit" )

--[[---------------------------------------------------------

-----------------------------------------------------------]]
function PANEL:Init()

	self.PanelList = vgui.Create("PanelList", self)
	self.PanelList:EnableVerticalScrollbar( true )

	self.directory = {}

	self:LoadFiles()

end

function PANEL:GetCurrentDirectory()
	return table.concat(self.directory, "")
end

function PANEL:OnFileClick( file )
end

function PANEL:LoadFiles()

	self.PanelList:Clear()

	local a, b = file.Find( self:GetCurrentDirectory() .. "*", "DATA" )
	
	local all = table.Add( a, b )
	
	local files, directories = {}, {}

	for k,v in pairs( all ) do
		if file.IsDir( self:GetCurrentDirectory() .. v, "DATA" ) then
			table.insert( directories, v )
		else
			table.insert( files, v )
		end
	end

	if #self.directory > 0 then
		local function up( button )
			table.remove( self.directory, #self.directory )
			self:LoadFiles()
		end

		local button = vgui.Create("DFile")
		button:SetText( "..", 1 )
		button.DoClick = up

		self.PanelList:AddItem( button )
	end

	for k,v in pairs( directories ) do

		local function go( button )
			table.insert( self.directory, v .. "/" )
			self:LoadFiles()
		end

		local button = vgui.Create("DFile")
		button:SetText( v, 1 )
		button.DoClickB = go

		self.PanelList:AddItem( button )

	end

	for k,v in pairs( files ) do

		if v:sub(-8, -1) == ".hat.txt" then

			local button = vgui.Create("DFile")
			button:SetText( v:sub(0, -5), 2 )
			button.DoClickB = function() self:OnFileClick( v:sub(0, -5) ) end

			self.PanelList:AddItem( button )

		end

	end

end

function PANEL:Think()
end

function PANEL:Paint( w, h )

end

--[[---------------------------------------------------------

-----------------------------------------------------------]]
function PANEL:PerformLayout( w, h )

	self.PanelList:SetPos(0, 0)
	self.PanelList:SetSize(w, h)

end

--[[---------------------------------------------------------
	SizeToContents
-----------------------------------------------------------]]
function PANEL:SizeToContents( )

end

--[[---------------------------------------------------------

-----------------------------------------------------------]]
function PANEL:SetDisabled( bDisabled )

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

derma.DefineControl( "DFileList", "Lists files.", PANEL, "DPanel" )