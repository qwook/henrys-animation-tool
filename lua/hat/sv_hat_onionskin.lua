-- Server-side onion-skin ghosts: semi-transparent duplicates of the posed entity. Multiple
-- independent, named ghosts can be shown at once - e.g. "prev" for the previous frame's pose
-- while editing the current one, and "current" for the current frame's own last-captured pose
-- (so posing drift after selecting a frame can be compared back against what's actually saved).
-- Split out of hat.lua.
-- (Separate from lua/hat/cl_hat_onionskin.lua, which is an unrelated clientside-model preview.)

HAT = HAT or {}
HAT.onionEntities = HAT.onionEntities or {}

-- Desc: (re)spawns the `slot` onion-skin ghost to match ent's model if needed, then poses its
-- bones from `bones`.
function HAT.playOnionSkin( slot, ent, bones, color )
	local onion = HAT.onionEntities[slot]

	if IsValid(onion) and ent:GetModel() ~= onion:GetModel() then
		onion:Remove()
		onion = nil
	end

	if not IsValid(onion) then
		if ent:GetClass() == "prop_ragdoll" then
			onion = gQuery.Create("prop_ragdoll")
		else
			onion = gQuery.Create("prop_dynamic")
		end

		onion
			:SetModel(ent:GetModel())
			:SetColor(color or Color(0, 255, 255, 125))
			:SetRenderMode(RENDERMODE_TRANSCOLOR)
			:SetCollisionGroup(COLLISION_GROUP_NONE)
			:SetNotSolid(true)
			:SetNWBool( "ignore", true )
			:Spawn()

		HAT.onionEntities[slot] = onion
	end

	onion
		:SetPos( ent:GetPos() )
		:SetAngles( ent:GetAngles() )

	for i,v in pairs( bones ) do
		local physObj = gQuery(onion:GetPhysicsObjectNum( i - 1 ))
			:SetPos(v.pos)
			:SetAngles(v.ang)
			:EnableMotion(false)
			:EnableCollisions(false)
			:Wake()
	end

end

-- Desc: removes the `slot` onion-skin ghost, or every ghost if `slot` is nil.
function HAT.clearOnionSkin( slot )
	if slot then
		if IsValid(HAT.onionEntities[slot]) then
			HAT.onionEntities[slot]:Remove()
		end
		HAT.onionEntities[slot] = nil
	else
		for _, onion in pairs(HAT.onionEntities) do
			if IsValid(onion) then onion:Remove() end
		end
		HAT.onionEntities = {}
	end
end

-- Desc: lets players physgun/reload through the onion-skin ghost instead of interacting with it.
-- Also doubles as the tag cl_hat_onionskin_visibility.lua uses to find onion ghosts to hide,
-- since only they set it.
local function onionPhysOverload( pl, ent )
	if IsValid(ent) and ent:GetNWBool( "ignore" ) then
		return false
	end
end
hook.Add("PhysgunPickup", "HATPhysgun", onionPhysOverload)
hook.Add("OnPhysgunReload", "HATPhysgun", function(_,pl) return onionPhysOverload(pl, pl:GetEyeTrace().Entity) end)
