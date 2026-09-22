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
local hatMenu = vgui.Create("DHATMenu")
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
	local id = net.ReadUInt(16)
	local ent = net.ReadEntity()
	local posetype = net.ReadUInt(16)
	hatMenu:SetEntity(id, ent, posetype)
	hatMenu:SetPoser(posetype)
end)

net.Receive("hat_frame_add", function()
	local objId = net.ReadUInt(16)
	local frame = net.ReadUInt(32)
	local easing = net.ReadString()
	local strength = net.ReadString()
	hatMenu:NewFrame(objId, HAT_DEFAULT_LENGTH, frame)
	hatMenu:SetFrameEasing(objId, frame, easing, strength)
end)

net.Receive("hat_frame_duplicate", function()
	local objId = net.ReadUInt(16)
	local frame = net.ReadUInt(32)
	local length = net.ReadFloat()
	local easing = net.ReadString()
	local strength = net.ReadString()
	hatMenu:NewFrame(objId, length, frame)
	hatMenu:SetFrameEasing(objId, frame, easing, strength)
end)

net.Receive("hat_frame_remove", function()
	hatMenu:RemoveFrame(net.ReadUInt(16), net.ReadUInt(32))
end)

net.Receive("hat_frame_move", function()
	hatMenu:MoveFrame(net.ReadUInt(16), net.ReadUInt(32), net.ReadUInt(32))
end)

net.Receive("hat_frame_easing", function()
	local objId = net.ReadUInt(16)
	local frame = net.ReadUInt(32)
	local easing = net.ReadString()
	local strength = net.ReadString()
	hatMenu:SetFrameEasing(objId, frame, easing, strength)
end)

net.Receive("hat_frame_select", function()
	hatMenu:SelectFrame(net.ReadUInt(16), net.ReadUInt(32))
end)

net.Receive("hat_remove", function()
	hatMenu:RemoveEntity(net.ReadUInt(16))
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

net.Receive("hat_frozen_bones", function()
	local ent = net.ReadEntity()
	local count = net.ReadUInt(8)
	local boneIDs = {}
	for i = 1, count do
		boneIDs[i] = net.ReadUInt(16)
	end
	hatMenu:SetFrozenBones(ent, boneIDs)
end)

-- CLIENT
net.Receive("hat_error", function()
	local msg = net.ReadString()
	local duration = net.ReadFloat()
	notification.AddLegacy(msg, NOTIFY_ERROR, duration)
	surface.PlaySound("hl1/fvox/blip.wav")   -- error sound
end)

-- While the HAT menu is open the mouse stays captured by the UI (see DHATMenu:Show), so cursor
-- movement never reaches the engine's normal mouselook. Middle-click-dragging over the game world
-- instead simulates aiming by reading the cursor's frame-to-frame delta ourselves and applying it
-- straight to the local player's eye angles. hatMenu itself is a screen-covering background panel
-- (see UpdateLayout: SetSize(ScrW(), ScrH())), and its mainSheet is likewise just a background
-- strip behind the toolbar/frameHolder, so hovering either of those bare backgrounds counts as
-- "not in the HAT gui" - only their real controls (frameHolder, toolbar, menu bar, tutorial
-- button, dialogs) should block the camera drag.
local camDragging = false
local camAngle
local lastMouseX, lastMouseY

local function IsOverHATBackground()
	local hovered = vgui.GetHoveredPanel()
	return not IsValid(hovered) or hovered == hatMenu or hovered == hatMenu.mainSheet
end

hook.Add("Think", "HATCameraDrag", function()
	if not hatMenu:IsVisible() then
		camDragging = false
		return
	end

	local down = input.IsMouseDown(MOUSE_MIDDLE)

	if down and not camDragging and IsOverHATBackground() then
		camDragging = true
		camAngle = LocalPlayer():EyeAngles()
		lastMouseX, lastMouseY = gui.MouseX(), gui.MouseY()
	elseif not down then
		camDragging = false
	end

	if camDragging then
		local mx, my = gui.MouseX(), gui.MouseY()
		local dx, dy = mx - lastMouseX, my - lastMouseY
		lastMouseX, lastMouseY = mx, my

		local sens = GetConVar("sensitivity"):GetFloat()
		local yawScale = sens * GetConVar("m_yaw"):GetFloat()
		local pitchScale = sens * GetConVar("m_pitch"):GetFloat()

		camAngle.y = camAngle.y - dx * yawScale
		camAngle.p = math.Clamp(camAngle.p + dy * pitchScale, -89, 89)

		LocalPlayer():SetEyeAngles(camAngle)
	end
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
