-- Captures the current pose of an entity (physbones/flexes/hands) into a frame.
-- Split out of hat.lua.

HAT = HAT or {}

-- HAT stores/restores eye-aim as frame data (obj.frames[n].eye) rather than re-deriving it from
-- wherever the entity happens to be looking, so SetEyeTarget is patched to remember the last
-- position set (self.eyeTargetPos) and GetEyeTarget reads that back — the engine doesn't
-- expose a getter for the current eye-aim target itself. Was previously (oddly) defined in
-- gquery.lua; moved here since this is the only place that uses it.
local Entity = FindMetaTable("Entity")
Entity.SetEyeTargetEng = Entity.SetEyeTargetEng or Entity.SetEyeTarget
function Entity:SetEyeTarget( pos )
	self:SetEyeTargetEng( pos )
	self.eyeTargetPos = pos
end

function Entity:GetEyeTarget()
	return self.eyeTargetPos or Vector( 180, 0, 0 )
end

-- Desc: physics-object positions/angles/motion state, indexed by bone number + 1. `motionEnabled`
-- is phys:IsMotionEnabled() verbatim - true means free to move, false means frozen - fed straight
-- into EnableMotion() by HAT.restoreFreezeState.
function HAT.getPhysBones( ent )
	if not IsValid( ent ) then return end

	local bones = {}
	for i = 0, ent:GetPhysicsObjectCount() - 1 do
		local phys = ent:GetPhysicsObjectNum( i )
		if phys then
			bones[i+1] = { pos = phys:GetPos(), ang = phys:GetAngles(), motionEnabled = phys:IsMotionEnabled() }
		end
	end
	return bones
end

-- Desc: flexes that are driven by gesture/eye-tracking logic rather than manual posing, and
-- should be skipped when capturing/applying a face pose.
function HAT.IsUselessFaceFlex( strName )

	if ( strName == "gesture_rightleft" ) then return true end
	if ( strName == "gesture_updown" ) then return true end
	if ( strName == "head_forwardback" ) then return true end
	if ( strName == "chest_rightleft" ) then return true end
	if ( strName == "body_rightleft" ) then return true end
	if ( strName == "eyes_rightleft" ) then return true end
	if ( strName == "eyes_updown" ) then return true end
	if ( strName == "head_tilt" ) then return true end
	if ( strName == "head_updown" ) then return true end
	if ( strName == "head_rightleft" ) then return true end

	return false

end

-- Desc: flex weights + scale for an entity's face, excluding useless flexes.
function HAT.getFlexes( ent )
	if not IsValid( ent ) then return end

	local FlexNum = ent:GetFlexNum() - 1

	local flexes = { flexes = {}, scale = 1 }

	for i=0, FlexNum-1 do

		local Name = ent:GetFlexName( i )

		if ( not HAT.IsUselessFaceFlex(Name )  ) then

			flexes.flexes[i] = ent:GetFlexWeight( i )

		end

	end

	flexes.scale = ent:GetFlexScale()

	return flexes
end

-- Desc: captures the object's current pose (physbones/flexes/hand, depending on posetype) into a frame.
function HAT.snapShotFrame( objID, frame )
	HAT.stop()

	local obj = HAT.objects[objID]

	if not obj then return end

	if not HAT.isWholeNumber(frame) then frame = obj.cur end

	if obj.posetype == HAT_SELECT_ENTITY then
		local physbones = HAT.getPhysBones( obj.ent )
		obj.frames[frame].physbones = physbones

		-- getPhysBones above only records each physbone's *actual* motion state, so a leaf/root bone
		-- (fingertip, ponytail end, pelvis, etc.) that wasn't already physically frozen gets baked
		-- into the frame as unfrozen. Force it frozen here in the captured data itself when the
		-- setting is on, so every consumer of frame.physbones (restoreFreezeState, save/load) sees
		-- one consistent answer instead of only physics state reflecting it transiently.
		if HAT_AutoFreezeLeafBones:GetBool() then
			local extremityPhysBones = HAT.getLeafBones( obj.ent )
			for physBoneIndex in pairs( extremityPhysBones ) do
				local physbone = physbones[physBoneIndex + 1]
				if physbone then physbone.motionEnabled = false end
			end
		end

		if HAT.isToggleableEntity( obj.ent ) then
			obj.frames[frame].on = obj.ent:GetOn()
		end
	elseif obj.posetype == HAT_SELECT_FACE then
		obj.frames[frame].flexes = HAT.getFlexes( obj.ent )
		obj.frames[frame].eye = obj.ent:GetEyeTarget()
	elseif obj.posetype == HAT_SELECT_L_HAND then
		obj.frames[frame].lhand = hat_hands.getHand( obj.ent, 0 )
	elseif obj.posetype == HAT_SELECT_R_HAND then
		obj.frames[frame].rhand = hat_hands.getHand( obj.ent, 1 )
	end

end
