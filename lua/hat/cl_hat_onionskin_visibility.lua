-- Purely local toggle for the visibility of the server-side onion-skin ghosts spawned by
-- sv_hat_onionskin.lua. Doesn't touch the server or other players - just hides/shows the ghosts
-- on this client, using the same "ignore" NWBool those ghosts already set for physgun passthrough
-- to tell them apart from ordinary ragdolls/props.

CreateClientConVar("hat_onionskin_visible", "1", true, false, "Show HAT's onion-skin posing ghosts")

local function ApplyOnionVisibility(ent)
	if IsValid(ent) and ent:GetNWBool("ignore", false) then
		ent:SetNoDraw(not GetConVar("hat_onionskin_visible"):GetBool())
	end
end

hook.Add("OnEntityCreated", "HATOnionSkinVisibility", function(ent)
	if ent:GetClass() == "prop_ragdoll" or ent:GetClass() == "prop_dynamic" then
		-- The "ignore" NWBool isn't readable the instant the entity is created.
		timer.Simple(0, function() ApplyOnionVisibility(ent) end)
	end
end)

cvars.AddChangeCallback("hat_onionskin_visible", function()
	for _, ent in ipairs(ents.FindByClass("prop_ragdoll")) do
		ApplyOnionVisibility(ent)
	end
	for _, ent in ipairs(ents.FindByClass("prop_dynamic")) do
		ApplyOnionVisibility(ent)
	end
end, "HATOnionSkinVisibility")
