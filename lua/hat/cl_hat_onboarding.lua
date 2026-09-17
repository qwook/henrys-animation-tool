-- Menu-open key: there's no way from Lua to set a console bind, so instead we store a raw
-- keycode in a cookie and poll it every frame to toggle the menu (see the Think hook at the
-- bottom). ShowBindPrompt offers to set this up, shown once per machine until a key is actually
-- set (run hat_remove_bind to reset it for testing); HAT.ShowKeyCapture is also used by the
-- "Rebind HAT Menu Key" option under Options (see dhatmenu.lua).

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

-- Desc: full-screen fade-to-black overlay that captures the next keypress and stores it as the
-- HAT menu toggle key.
function HAT.ShowKeyCapture()
	local capture = vgui.Create("DPanel")
	capture:SetSize(ScrW(), ScrH())
	capture:SetPos(0, 0)
	capture:SetMouseInputEnabled(true)
	capture:SetKeyboardInputEnabled(true)
	capture.Alpha = 0

	capture.Paint = function(self, w, h)
		surface.SetDrawColor(0, 0, 0, self.Alpha)
		surface.DrawRect(0, 0, w, h)
		draw.SimpleText("Press any key to set it as the HAT menu button.", "DermaLarge",
			w / 2, h / 2, Color(255, 255, 255, math.min(self.Alpha * 4, 255)), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	capture.Think = function(self)
		self.Alpha = math.min(self.Alpha + FrameTime() * 150, 255 * 0.25)
	end

	capture.OnKeyCodePressed = function(self, keycode)
		HAT.SetMenuKey(keycode)
		self:Remove()
	end

	capture:MakePopup()
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
	end

	local chooseBtn = vgui.Create("DButton", dialog)
	chooseBtn:SetPos(110, 135)
	chooseBtn:SetSize(140, 25)
	chooseBtn:SetText("Choose Different Key")
	chooseBtn.DoClick = function()
		dialog:Close()
		HAT.ShowKeyCapture()
	end

	local noBtn = vgui.Create("DButton", dialog)
	noBtn:SetPos(260, 135)
	noBtn:SetSize(70, 25)
	noBtn:SetText("No, thanks.")
	noBtn.DoClick = function()
		dialog:Close()
	end
end

if not HAT.HasMenuKey() then
	ShowBindPrompt()
end

-- Desc: polls the configured menu key every frame and toggles the menu on a fresh press. Raw
-- polling (rather than a bind) is what lets the key be set from Lua in the first place; skipped
-- while some other panel (e.g. chat, console) holds keyboard focus so typing "x" doesn't also
-- toggle the menu.
local wasKeyDown = false
hook.Add("Think", "HATMenuKeyToggle", function()
	local isDown = not vgui.GetKeyboardFocus() and input.IsKeyDown(HAT.GetMenuKey())

	if isDown and not wasKeyDown then
		RunConsoleCommand("hat_toggle")
	end

	wasKeyDown = isDown
end)
