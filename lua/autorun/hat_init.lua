
-- This file loads before everything else and is supposed to be a debug wrapper for HAT
-- Just helps out with debugging and reloading HAT.

HAT_VERSION = 4

MsgN("Initiating Henry's Animation Tool ...")

if SERVER then

AddCSLuaFile("hat/vgui/dframeholder.lua")
AddCSLuaFile("hat/vgui/dhatmenu.lua")
AddCSLuaFile("hat/vgui/dfile.lua")
AddCSLuaFile("hat/vgui/dfilelist.lua")
AddCSLuaFile("hat/cl_hat.lua")
AddCSLuaFile("hat/cl_hat_onionskin.lua")
AddCSLuaFile("hat/hatskin.lua")
AddCSLuaFile("autorun/hat_init.lua")
AddCSLuaFile("gQuery.lua")

util.AddNetworkString( "hat_select" )
util.AddNetworkString( "hat_remove" )
util.AddNetworkString( "hat_play" )
util.AddNetworkString( "hat_stop" )
util.AddNetworkString( "hat_frame_select" )
util.AddNetworkString( "hat_frame_add" )
util.AddNetworkString( "hat_frame_remove" )
util.AddNetworkString( "hat_frame_move" )
util.AddNetworkString( "hat_send_data" )
util.AddNetworkString( "hat_onionskin" )

else

hatUI = Material("hat/hatui.png")

end

HAT_SELECT_ENTITY = 1
HAT_SELECT_FACE = 2
HAT_SELECT_L_HAND = 3
HAT_SELECT_R_HAND = 4

local hook = hook
local hookList = {}
local vgui = vgui
local vguiList = {}
local concommand = concommand
local concommandList = {}

local newHook = table.Copy( hook )

newHook.Add = function( name, hookName, func )
	table.insert(hookList, { name, hookName })
	return hook.Add( name, hookName, func )
end

local newConcommand = table.Copy( hook )

newConcommand.Add = function( name, func )
	table.insert(concommandList, name)
	return concommand.Add( name, func )
end

local newVGUI
if CLIENT then

	local rmX, rmY = 0, 0

	-- Global fix of RestoreCursorPosition for Mac OSX
	olRestoreCursorPosition = olRestoreCursorPosition or RestoreCursorPosition
	function RestoreCursorPosition()

		gui.SetMousePos(rmX, rmY + 252 - 252)

		--olRestoreCursorPosition() -- Try to restore it immediately.

		-- Mac OSX needs a bit of waiting time to restore the mouse position.
		timer.Create("Restore", 0, 2, function()
			gui.SetMousePos(rmX, rmY + 252 - 252)
			-- olRestoreCursorPosition()
		end)
	end

	function RememberCursorPosition()

		rmX = gui.MouseX()
		rmY = gui.MouseY()

	end

	newVGUI = table.Copy( vgui )

	-- Detect whenever a new vgui element is being created when HAT is running.
	-- Add it to our list of vgui elements.
	newVGUI.Create = function( className, parent, string )
		local vguiEle = vgui.Create(className, parent, string)
		table.insert(vguiList, vguiEle)
		return vguiEle
	end

end

-- Function to [re]load HAT.
local function loadHAT( cmd, args )

	MsgN("Loading HAT Core...")

	local olHook = hook
	local olVGUI = vgui
	local olConcommand = concommand
	if CLIENT then
		-- Overload the vgui table.
		_G.vgui = newVGUI

		-- Remove any existing hat vgui elements.
		for k,v in pairs(vguiList) do
			if v then
				v:Remove()
			end
		end
		vguiList = {}
	end

	_G.hook = newHook

	for k,v in pairs(hookList) do
		hook.Remove( v[1], v[2] )
	end

	hookList = {}

	_G.concommand = newConcommand

	for k,v in pairs(concommandList) do
		concommand.Remove( v )
	end

	concommandList = {}

	-- todo: Grab file list and dynamically include files.
	if CLIENT then
		include("hat/hatskin.lua")
		include("hat/vgui/dframeholder.lua")
		include("hat/vgui/dhatmenu.lua")
		include("hat/vgui/dfilelist.lua")
		include("hat/vgui/dfile.lua")
		include("hat/cl_hat.lua")
		include("hat/cl_hat_onionskin.lua")
		include("gQuery.lua")
	else
		include("hat/hat.lua")
		include("gQuery.lua")
	end

	_G.hook = olHook
	_G.concommand = olConcommand
	if CLIENT then
		-- Put the old vgui table back.
		_G.vgui = olVGUI
	end

	MsgN("Done Loading!")

end

if SERVER then
	loadHAT()
else
	if loadedHAT then
		loadHAT()
	else
		hook.Add( "InitPostEntity", "HATLoad", function() loadHAT() loadedHAT = true end )
	end
end

function unloadHAT( cmd, args )


	for k,v in pairs(hookList) do
		hook.Remove( v[1], v[2] )
	end

	hookList = {}

	for k,v in pairs(concommandList) do
		concommand.Remove( v )
	end

	concommandList = {}

	if CLIENT then
		-- Remove any existing hat vgui elements.
		for k,v in pairs(vguiList) do
			if v then
				v:Remove()
			end
		end
		vguiList = {}
	end

end

if CLIENT then

concommand.Add("reload_hat_cl", loadHAT)
concommand.Add("unload_hat_cl", unloadHAT)

else

concommand.Add("reload_hat", loadHAT)
concommand.Add("unload_hat", unloadHAT)

end

MsgN("Done Initializing!")
