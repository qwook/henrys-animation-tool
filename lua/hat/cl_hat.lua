-- Client glue: creates the singleton DHATMenu panel, registers the +/-hat_menu concommands that
-- toggle it, and forwards server net broadcasts into hatMenu panel method calls.

local hatUI            = hatUI

HAT_DEFAULT_LENGTH     = 0.25
HAT_DEFAULT_FRAME_SIZE = 100

-- Remove HAT Menu if it already exists.
if (_G.hatMenu) then
	_G.hatMenu:Remove()
end

-- Create the HAT menu.
local hatMenu          = vgui.Create("DHATMenu")
hatMenu:SetVisible(false)

_G.hatMenu = hatMenu;

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

concommand.Add("set_frame_entity", function(pl, cmd, arg, count)
	hatMenu:SetEntity(arg[1])
end)

net.Receive("hat_select", function()
	hatMenu:SetEntity(net.ReadUInt(16), net.ReadEntity())
	hatMenu:SetPoser(net.ReadUInt(16))
end)

net.Receive("hat_frame_add", function()
	hatMenu:NewFrame(net.ReadUInt(16), HAT_DEFAULT_LENGTH, net.ReadUInt(32))
end)

net.Receive("hat_frame_remove", function()
	hatMenu:RemoveFrame(net.ReadUInt(16), net.ReadUInt(32))
end)

net.Receive("hat_frame_move", function()
	hatMenu:MoveFrame(net.ReadUInt(16), net.ReadUInt(32), net.ReadUInt(32))
end)

net.Receive("hat_frame_select", function()
	hatMenu:SelectFrame(net.ReadUInt(16), net.ReadUInt(32))
end)

net.Receive("hat_remove", function()
	hatMenu:RemoveEntity(net.ReadUInt(16))
end)

hook.Add("HUDPaint", "HATPaint", function()
end)

net.Receive("hat_stop", function()
	hatMenu:Stop()
end)

net.Receive("hat_play", function()
	hatMenu:Play(net.ReadFloat())
end)

net.Receive("hat_send_data", function()
	local toLoad = net.ReadTable()
	hatMenu:Load(toLoad)
end)

net.Receive("hat_loop", function()
	hatMenu:SetLoop(net.ReadBool())
end)

-- CLIENT
net.Receive("hat_error", function()
    local msg = net.ReadString()
    local duration = net.ReadFloat()
    notification.AddLegacy(msg, NOTIFY_ERROR, duration)
    surface.PlaySound("hl1/fvox/blip.wav") -- error sound
end)

-- While the menu is open, jumping toggles playback instead of making the player jump: play the
-- timeline, or stop it if it's already playing.
hook.Add("PlayerBindPress", "HATOverrideJump", function(pl, bind, pressed)
	if not pressed then return end
	if not hatMenu:IsVisible() then return end
	if bind ~= "+jump" then return end

	if hatMenu.frameHolder.StartTime then
		RunConsoleCommand("hat_stop")
	else
		RunConsoleCommand("hat_play")
	end

	return true
end)

