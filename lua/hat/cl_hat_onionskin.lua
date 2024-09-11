
-- I need to develop some sort of pattern for writing this sort of stuff.

hatOS = {}

local model
local function getEntity( modelstr )
	if IsValid( model ) then
		model:SetModel( modelstr )
		return model
	else
		model = ClientsideModel( modelstr )
		return model
	end
end

local function drawEntity( entity, data )
	local model = getEntity( entity:GetModel() )
	model:SetPos( Vector(0,0,0) )
	model:SetPos( entity:GetPos() )
	model:SetAngles( Angle(0,0,0) )
	model:SetColor( Color( 255, 255, 255, 127 ) )
	model:SetSequence( model:LookupSequence("ragdoll") )
	model:SetParent( entity )
	--model:AddEffects( EF_BONEMERGE )
	for i,dat in pairs( data ) do
		local pos, ang = entity:GetBonePosition(i)
		--model:ManipulateBonePosition( i, pos )
		--model:ManipulateBoneAngles( i, ang )
		if dat.scale then model:ManipulateBoneScale( i, dat.scale ) end
		if dat.pos then model:ManipulateBonePosition( i, dat.pos ) end
		if dat.ang then model:ManipulateBoneAngles( i, dat.ang ) end
	end
end

local function clearEntity()
	if model then
		model:Remove()
		model = nil
	end
end


net.Receive( "hat_onionskin", function()

	if net.ReadBit() == 1 then
		local entity = net.ReadEntity()
		local data = net.ReadTable()
		drawEntity( entity, data )
	else
		clearEntity()
	end
end )

