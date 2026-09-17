-- Server-side onion-skin ghost: a semi-transparent duplicate of the posed entity, showing the
-- previous frame's pose while editing the current one. Split out of hat.lua.
-- (Separate from lua/hat/cl_hat_onionskin.lua, which is an unrelated clientside-model preview.)

HAT = HAT or {}

-- Desc: (re)spawns HAT.onionEntity to match ent's model if needed, then poses its bones from `bones`.
function HAT.playOnionSkin( ent, bones )

	if IsValid(HAT.onionEntity) and ent:GetModel() ~= HAT.onionEntity:GetModel() then
		HAT.onionEntity:Remove()
	end

	if not IsValid(HAT.onionEntity) then
		if ent:GetClass() == "prop_ragdoll" then
			HAT.onionEntity = gQuery.Create("prop_ragdoll")
		else
			HAT.onionEntity = gQuery.Create("prop_dynamic")
		end

		HAT.onionEntity
			:SetModel(ent:GetModel())
			:SetColor(Color(0, 255, 255, 125))
			:SetRenderMode(RENDERMODE_TRANSCOLOR)
			:SetCollisionGroup(COLLISION_GROUP_NONE)
			:SetNotSolid(true)
			:SetNWBool( "ignore", true )
			:Spawn()

	end

	HAT.onionEntity
		:SetPos( ent:GetPos() )
		:SetAngles( ent:GetAngles() )

	for i,v in pairs( bones ) do
		local physObj = gQuery(HAT.onionEntity:GetPhysicsObjectNum( i - 1 ))
			:SetPos(v.pos)
			:SetAngles(v.ang)
			:EnableMotion(false)
			:EnableCollisions(false)
			:Wake()
	end

end

-- Desc: removes the onion-skin ghost, if any.
function HAT.clearOnionSkin()
	if IsValid(HAT.onionEntity) then
		HAT.onionEntity:Remove()
	end
end

-- Desc: lets players physgun/reload through the onion-skin ghost instead of interacting with it.
local function onionPhysOverload( pl, ent )
	if IsValid(ent) and ent:GetNWBool( "ignore" ) then
		return false
	end
end
hook.Add("PhysgunPickup", "HATPhysgun", onionPhysOverload)
hook.Add("OnPhysgunReload", "HATPhysgun", function(_,pl) return onionPhysOverload(pl, pl:GetEyeTrace().Entity) end)
