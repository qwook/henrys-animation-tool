
local hatUI = hatUI

HAT_DEFAULT_LENGTH = 0.25
HAT_DEFAULT_FRAME_SIZE = 100

local -- Import global libraries.
	vgui,
	concommand,
	hook
	=
	vgui,
	concommand,
	hook

-- Create the HAT menu.
local hatMenu = vgui.Create("DHATMenu")
	hatMenu:SetVisible(false)

--[[local list = vgui.Create("DFileList")
--list:Open(".")
list:SetPos( 50, 100 )
list:SetSize( 250, 250 )
list:MakePopup()]]

concommand.Add("+hat_menu", function(cmd, arg)
	hatMenu:Show()
end)

concommand.Add("-hat_menu", function(cmd, arg)
	hatMenu:Hide()
end)

concommand.Add("hat_toggle", function(cmd, arg)
	if hatMenu:IsVisible() then
		hatMenu:Hide()
	else
		hatMenu:Show()
	end
end)

concommand.Add( "set_frame_entity", function( pl, cmd, arg, count )
	hatMenu:SetEntity( arg[1] )
end )

net.Receive( "hat_select", function()
	hatMenu:SetEntity( net.ReadUInt( 16 ), net.ReadEntity() )
	hatMenu:SetPoser( net.ReadUInt( 16 ) )
end )

net.Receive( "hat_frame_add", function()
	hatMenu:NewFrame( net.ReadUInt( 16 ), HAT_DEFAULT_LENGTH, net.ReadUInt( 32 ) )
end )

net.Receive( "hat_frame_remove", function()
	hatMenu:RemoveFrame( net.ReadUInt( 16 ), net.ReadUInt( 32 ) )
end )

net.Receive( "hat_frame_move", function()
	hatMenu:MoveFrame( net.ReadUInt( 16 ), net.ReadUInt( 32 ), net.ReadUInt( 32 ) )
end )

net.Receive( "hat_frame_select", function()
	hatMenu:SelectFrame( net.ReadUInt( 16 ), net.ReadUInt( 32 ) )
end )

net.Receive( "hat_remove", function()
	hatMenu:RemoveEntity( net.ReadUInt( 16 ) )
end )

hook.Add("HUDPaint", "HATPaint", function()
end)

net.Receive( "hat_stop", function()
	hatMenu:Stop()
end )

net.Receive( "hat_play", function()
	hatMenu:Play( net.ReadFloat() )
end )

net.Receive( "hat_send_data", function()
	local toLoad = net.ReadTable()
	hatMenu:Load( toLoad )
end )

--[[local lastAttack = false
hook.Add("CreateMove", "hat_select", function( cmd )
	MsgN(bit.band( cmd:GetButtons() ))
	if not hatMenu:IsVisible() then return end

	if bit.band( cmd:GetButtons(), IN_ATTACK ) > 0 then
		MsgN(":(")
		if lastAttack then
			local tr = LocalPlayer():GetEyeTrace()
			if IsValid(tr.Entity) then
				MsgN("Hi")
				RunConsoleCommand( "hat_select", tr.Entity:EntIndex() )
			end
		end
		lastAttack = true
		cmd:SetButtons( cmd:GetButtons() - IN_ATTACK )
	else
		lastAttack = false
	end
end)]]