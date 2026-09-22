-- Menu-open/play keys: there's no way from Lua to set a console bind, so instead we store raw
-- keycodes in cookies and poll them every frame (see the Think hooks at the bottom).
-- ShowBindPrompt offers to set the menu key up, shown once per machine until a key is actually
-- set (run hat_remove_bind to reset it for testing); HAT.ShowKeyCapture is also used by the
-- "Rebind HAT Menu Key" / "Rebind HAT Play Key" options under Options (see dhatmenu.lua).

HAT = HAT or {}

local DEFAULT_KEY = KEY_X

-- Desc: keycode that currently toggles the HAT menu (defaults to X).
function HAT.GetMenuKey()
	return cookie.GetNumber("hat_menu_key", DEFAULT_KEY)
end

-- Desc: true once a menu key has actually been set (via the prompt or the rebind option),
-- distinct from GetMenuKey's fallback default, so the prompt only shows before that's happened.
function HAT.HasMenuKey()
	return cookie.GetNumber("hat_menu_key_set", 0) == 1
end

-- Desc: sets and persists the keycode that toggles the HAT menu.
function HAT.SetMenuKey(keycode)
	cookie.Set("hat_menu_key", keycode)
	cookie.Set("hat_menu_key_set", 1)
end

-- Desc: clears the stored menu key, so the bind prompt asks again next launch. Exposed as
-- hat_remove_bind for testing.
concommand.Add("hat_remove_bind", function()
	cookie.Delete("hat_menu_key")
	cookie.Delete("hat_menu_key_set")
end)

-- Desc: keycode that currently triggers Play, or nil if the (optional) play key hasn't been set.
function HAT.GetPlayKey()
	if cookie.GetNumber("hat_play_key_set", 0) ~= 1 then return nil end
	return cookie.GetNumber("hat_play_key", -1)
end

-- Desc: true once a play key has actually been set.
function HAT.HasPlayKey()
	return cookie.GetNumber("hat_play_key_set", 0) == 1
end

-- Desc: sets and persists the keycode that triggers Play.
function HAT.SetPlayKey(keycode)
	cookie.Set("hat_play_key", keycode)
	cookie.Set("hat_play_key_set", 1)
end

-- Desc: clears the stored play key. Exposed as hat_remove_play_bind for testing.
concommand.Add("hat_remove_play_bind", function()
	cookie.Delete("hat_play_key")
	cookie.Delete("hat_play_key_set")
end)

-- Desc: real engine binds ("bind x +hat_menu" / "bind x hat_toggle") conflict with our own raw
-- key-polling toggle above - if the engine already fires the menu off a bind, the console user
-- almost certainly doesn't also want our cookie-based key doing it. input.LookupBinding checks
-- the engine's actual bind list, which never includes our cookie key (that's just polled input,
-- never an engine bind), so there's nothing to exclude on our end - only console binds show up
-- here. Returns the console command and key name it's bound to, or nil if neither is bound.
function HAT.GetConflictingBind()
	for _, cmd in ipairs({ "+hat_menu", "hat_toggle" }) do
		local key = input.LookupBinding(cmd)
		if key then
			return cmd, key
		end
	end
end

-- Desc: full-screen fade-to-black overlay that captures the next keypress and stores it via
-- setKeyFunc (HAT.SetMenuKey or HAT.SetPlayKey). promptText is shown while capturing; checkConflict
-- gates it behind HAT.GetConflictingBind (only meaningful for the menu key, which the engine bind
-- would otherwise fight with).
function HAT.ShowKeyCapture(setKeyFunc, promptText, checkConflict)
	setKeyFunc = setKeyFunc or HAT.SetMenuKey
	promptText = promptText or "Press any key to set it as the HAT menu button."

	if checkConflict then
		local conflictCmd, conflictKey = HAT.GetConflictingBind()
		if conflictCmd then
			Derma_Message(
				"You already have \"" .. conflictCmd .. "\" bound to \"" .. conflictKey ..
				"\" in the console! Unbind this key in your console to use this menu.",
				"HAT", "OK")
			return
		end
	end

	local capture = vgui.Create("DPanel")
	capture:SetSize(ScrW(), ScrH())
	capture:SetPos(0, 0)
	capture:SetMouseInputEnabled(true)
	capture:SetKeyboardInputEnabled(true)
	capture.Alpha = 0

	capture.Paint = function(self, w, h)
		surface.SetDrawColor(0, 0, 0, self.Alpha)
		surface.DrawRect(0, 0, w, h)
		draw.SimpleText(promptText, "DermaLarge",
			w / 2, h / 2, Color(255, 255, 255, math.min(self.Alpha * 4, 255)), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	capture.Think = function(self)
		self.Alpha = math.min(self.Alpha + FrameTime() * 150, 255 * 0.25)
	end

	capture.OnKeyCodePressed = function(self, keycode)
		setKeyFunc(keycode)
		self:Remove()
	end

	capture:MakePopup()
end

-- Desc: the "want us to set a play key for you" dialog, shown right after the menu key is bound
-- (either via the prompt below or HAT.ShowKeyCapture). Optional, so "I don't want to, thanks."
-- just closes it without binding anything.
local function ShowPlayBindPrompt()
	local dialog = vgui.Create("DFrame")
	dialog:SetSize(340, 170)
	dialog:SetTitle("HAT")
	dialog:Center()
	dialog:MakePopup()
	dialog:SetDraggable(false)
	dialog:ShowCloseButton(true)
	dialog:SetDeleteOnClose(true)

	local label = vgui.Create("DLabel", dialog)
	label:SetPos(10, 30)
	label:SetSize(320, 60)
	label:SetWrap(true)
	label:SetAutoStretchVertical(true)
	label:SetText("Want to set a HAT Play key too? It does the same thing as the Play button in the HAT menu. This is optional.")

	local chooseBtn = vgui.Create("DButton", dialog)
	chooseBtn:SetPos(10, 135)
	chooseBtn:SetSize(140, 25)
	chooseBtn:SetText("Choose Key")
	chooseBtn.DoClick = function()
		dialog:Close()
		HAT.ShowKeyCapture(HAT.SetPlayKey, "Press any key to set it as the HAT play button.", false)
	end

	local noBtn = vgui.Create("DButton", dialog)
	noBtn:SetPos(160, 135)
	noBtn:SetSize(170, 25)
	noBtn:SetText("I don't want to, thanks.")
	noBtn.DoClick = function()
		dialog:Close()
	end
end

-- Desc: the "want us to set a key for you" dialog, shown until a menu key has been set.
local function ShowBindPrompt()
	local dialog = vgui.Create("DFrame")
	dialog:SetSize(340, 170)
	dialog:SetTitle("HAT")
	dialog:Center()
	dialog:MakePopup()
	dialog:SetDraggable(false)
	dialog:ShowCloseButton(true)
	dialog:SetDeleteOnClose(true)

	local label = vgui.Create("DLabel", dialog)
	label:SetPos(10, 30)
	label:SetSize(320, 60)
	label:SetWrap(true)
	label:SetAutoStretchVertical(true)
	label:SetText("Thanks for using HAT! Can we use the \"X\" key to open up the HAT menu?")

	local okayBtn = vgui.Create("DButton", dialog)
	okayBtn:SetPos(10, 135)
	okayBtn:SetSize(90, 25)
	okayBtn:SetText("Okay!")
	okayBtn.DoClick = function()
		HAT.SetMenuKey(DEFAULT_KEY)
		dialog:Close()
		if not HAT.HasPlayKey() then ShowPlayBindPrompt() end
	end

	local chooseBtn = vgui.Create("DButton", dialog)
	chooseBtn:SetPos(110, 135)
	chooseBtn:SetSize(140, 25)
	chooseBtn:SetText("Choose Different Key")
	chooseBtn.DoClick = function()
		dialog:Close()
		HAT.ShowKeyCapture(function(keycode)
			HAT.SetMenuKey(keycode)
			if not HAT.HasPlayKey() then ShowPlayBindPrompt() end
		end, "Press any key to set it as the HAT menu button.", true)
	end

	local noBtn = vgui.Create("DButton", dialog)
	noBtn:SetPos(260, 135)
	noBtn:SetSize(70, 25)
	noBtn:SetText("No, thanks.")
	noBtn.DoClick = function()
		dialog:Close()
	end
end

if not HAT.HasMenuKey() and not HAT.GetConflictingBind() then
	ShowBindPrompt()
end

-- Desc: polls the configured menu key every frame and toggles the menu on a fresh press. Raw
-- polling (rather than a bind) is what lets the key be set from Lua in the first place; skipped
-- while some other panel (e.g. chat, console) holds keyboard focus so typing "x" doesn't also
-- toggle the menu.
local wasKeyDown = false
hook.Add("Think", "HATMenuKeyToggle", function()
	if HAT.GetConflictingBind() then return end

	local isDown = not vgui.GetKeyboardFocus() and input.IsKeyDown(HAT.GetMenuKey())

	if isDown and not wasKeyDown then
		RunConsoleCommand("hat_toggle")
	end

	wasKeyDown = isDown
end)

-- Desc: polls the (optional) configured play key every frame and triggers Play on a fresh press,
-- same as the Play button in the HAT menu. No-op while unset.
local wasPlayKeyDown = false
hook.Add("Think", "HATPlayKeyToggle", function()
	local playKey = HAT.GetPlayKey()
	if not playKey then return end

	local isDown = not vgui.GetKeyboardFocus() and input.IsKeyDown(playKey)

	if isDown and not wasPlayKeyDown then
		RunConsoleCommand("hat_play")
	end

	wasPlayKeyDown = isDown
end)
