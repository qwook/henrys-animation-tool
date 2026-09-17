-- HAT.objects / HAT.entityTrans data model: pose-object + frame CRUD.
-- Split out of hat.lua. Other sv_hat_*.lua files reach into this state via
-- the shared HAT table since include()'d files don't share Lua locals.

HAT = HAT or {}

HAT_DEFAULT_LENGTH = 0.25

HAT_PlayRate = CreateConVar( "hat_playrate", 1, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_SERVER_CAN_EXECUTE} )
HAT_StopMotion = CreateConVar( "hat_stopmotion", 0, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_SERVER_CAN_EXECUTE} )

HAT.entityTrans = {} -- Entity -> { [posetype] = objID }, the 4 pose-types per entity.
HAT.objects = {} -- objID -> { frames, ent, cur, posetype, FrameStart, PlayFrame, Playing }
HAT.currentObjId = nil

-- Desc: sums frame lengths before frameID to get its start time within the object's timeline.
function HAT.getTimeFromFrame( objID, frameID )
	local obj = HAT.objects[objID]

	if not obj then return end

	local length = 0
	for i = 1, frameID - 1 do
		local frame = obj.frames[i]
		if frame and frame.length then
			length = length + frame.length
		end
	end

	return length
end

-- Desc: total timeline length (seconds), the longest of every object's summed frame lengths.
function HAT.getTotalTime()
	local total = 0

	for _, obj in pairs(HAT.objects) do
		local length = 0
		for _, frame in pairs(obj.frames) do
			if frame and frame.length then
				length = length + frame.length
			end
		end
		total = math.max(total, length)
	end

	return total
end

-- Desc: true if num is an integer (frame indices must be whole numbers).
function HAT.isWholeNumber( num )
	local num = tonumber(num)
	if not num then return end
	return math.ceil(num) == num
end

-- Desc: halts playback, leaving the shared scrubber at whatever timeline position playback had
-- reached, so a later Play resumes from here rather than from wherever it was last scrubbed to.
function HAT.stop()
	if HAT.playOn then
		HAT.playOn = false

		HAT.scrubTime = math.max( CurTime() * HAT_PlayRate:GetFloat() - HAT.playStart, 0 )
		HAT.playStart = CurTime() * HAT_PlayRate:GetFloat() - HAT.scrubTime
		HAT.playLastFrame = CurTime() * HAT_PlayRate:GetFloat()

		net.Start( "hat_stop" )
		net.Broadcast()
	end
end

-- Desc: a fresh, empty frame using the default length.
function HAT.blankFrame()
	return
	{
		length = HAT_DEFAULT_LENGTH;
	}
end

-- Desc: creates the 4 pose objects (entity/face/left hand/right hand) for a newly selected entity.
function HAT.newObject( ent )
	HAT.stop()

	if not IsValid( ent ) then return end

	HAT.entityTrans[ent] = {
		table.insert(HAT.objects, {
			frames = {};
			ent = ent;
			cur = 1;
			posetype = HAT_SELECT_ENTITY;
		});
		table.insert(HAT.objects, {
			frames = {};
			ent = ent;
			cur = 1;
			posetype = HAT_SELECT_FACE;
		});
		table.insert(HAT.objects, {
			frames = {};
			ent = ent;
			cur = 1;
			posetype = HAT_SELECT_L_HAND;
		});
		table.insert(HAT.objects, {
			frames = {};
			ent = ent;
			cur = 1;
			posetype = HAT_SELECT_R_HAND;
		});
	};

	return HAT.entityTrans[ent]
end

-- Desc: fills in any missing pose-type slots for an entity loaded from an older/incompatible save.
function HAT.fill( translate, ent, posetype )

	for i = 1, 4 do
		if not translate[i] then
			translate[i] = table.insert(HAT.objects, {
				frames = {
					HAT.blankFrame();
				};
				ent = ent;
				cur = 1;
				posetype = i;
			})
		end
	end

	return translate[posetype]

end

-- Desc: fast-forwards every other object's playback state to match the timestamp of objID's given frame.
function HAT.updateOtherObjects( objID, frame )
	local offset = HAT.getTimeFromFrame( objID, frame + 1 )
	local obj = HAT.objects[objID]

	for k,v in pairs(HAT.objects) do

		if not v then break end

		if v ~= obj and IsValid( v.ent ) then

			local FrameStart = 0
			local PlayFrame = 1

			local frame = v.frames[PlayFrame]

			while (frame and ( FrameStart + frame.length < offset ) ) do
				FrameStart = FrameStart + frame.length
				HAT.applyPose( v, PlayFrame, 1 )
				PlayFrame = PlayFrame + 1
				frame = v.frames[PlayFrame]
			end

			if frame then
				local delta = (offset - FrameStart) / frame.length
				HAT.applyPose( v, PlayFrame, delta )
			end

		end

	end
end

-- Desc: applies a frame's pose to its entity, updates onion-skin, and broadcasts the selection.
function HAT.selectFrame( objID, frame )
	HAT.stop()

	local obj = HAT.objects[objID]

	if not obj then return end
	if not HAT.isWholeNumber( frame ) then return end
	if frame <= 0 or frame > #obj.frames then frame = #obj.frames end

	obj.cur = frame

	if obj.frames[obj.cur] then
		local physbones = obj.frames[obj.cur].physbones
		if physbones then
			for i,v in pairs( physbones ) do
				local physobj = gQuery(obj.ent:GetPhysicsObjectNum( i - 1 ))
				if physobj then
					physobj
						:SetPos( v.pos )
						:SetAngles( v.ang )
						:Wake()
						:EnableMotion( v.frozen )
				end
			end
		end

		local flexes = obj.frames[obj.cur].flexes

		if flexes then
			for i,v in pairs( flexes.flexes ) do
				local Name = obj.ent:GetFlexName( i )

				if ( HAT.IsUselessFaceFlex(Name)  ) then

					obj.ent:SetFlexWeight( i, 0 )

				else

					obj.ent:SetFlexWeight( i, v )

				end
			end

			obj.ent:SetFlexScale( flexes.scale )
		end

		local lhand = obj.frames[obj.cur].lhand

		if lhand then
			hat_hands.setHand( obj.ent, lhand, 0 )
		end

		local rhand = obj.frames[obj.cur].rhand

		if rhand then
			hat_hands.setHand( obj.ent, rhand, 1 )
		end

		local eye = obj.frames[obj.cur].eye

		if eye then
			obj.ent:SetEyeTarget( eye )
		end

	end

	if obj.frames[obj.cur-1] and obj.frames[obj.cur-1].physbones then
		local physbones = obj.frames[obj.cur-1].physbones

		local bones = {}
		for i,v in pairs( physbones ) do
			bones[i] = {
				pos = v.pos,
				ang = v.ang
			}
		end

		HAT.playOnionSkin( obj.ent, bones )
	else
		HAT.clearOnionSkin()
	end

	HAT.updateOtherObjects( objID, frame )

	-- Move the shared scrubber to this frame's start time, so Play resumes from here and the
	-- client's timeline playhead follows the selection.
	HAT.scrubTime = HAT.getTimeFromFrame( objID, frame )
	HAT.playStart = CurTime() * HAT_PlayRate:GetFloat() - HAT.scrubTime
	HAT.playLastFrame = CurTime() * HAT_PlayRate:GetFloat()

	net.Start( "hat_frame_select" )
		net.WriteUInt( objID, 16 )
		net.WriteUInt( frame, 32 )
	net.Broadcast()
end

-- Desc: inserts a blank frame (at a position, or appended), snapshots the object's current
-- pose into it, and selects it.
function HAT.addFrame( objID, frame )
	HAT.stop()

	local obj = HAT.objects[objID]

	if not obj then return end

	if HAT.isWholeNumber( frame ) and frame > 0 and frame <= #obj.frames then
		table.insert( obj.frames, frame, HAT.blankFrame() )
	else
		table.insert( obj.frames, HAT.blankFrame() )
		frame = #obj.frames
	end

	HAT.snapShotFrame( objID, frame )

	net.Start( "hat_frame_add" )
		net.WriteUInt( objID, 16 )
		net.WriteUInt( frame, 32 )
	net.Broadcast()

	HAT.selectFrame( objID, frame )
end

-- Desc: removes a frame (or the last one) and selects the frame that takes its place.
function HAT.removeFrame( objID, frame )
	HAT.stop()

	local obj = HAT.objects[objID]

	if not obj then return end

	if not ( HAT.isWholeNumber( frame ) and frame > 0 and frame <= #obj.frames ) then
		frame = #obj.frames
	end

	table.remove( obj.frames, frame )

	HAT.selectFrame( objID, frame )

	net.Start( "hat_frame_remove" )
		net.WriteUInt( objID, 16 )
		net.WriteUInt( frame, 32 )
	net.Broadcast()
end

-- Desc: relocates a frame within the timeline and selects it at its new position.
function HAT.moveFrame( objID, frameFrom, frameTo )
	HAT.stop()

	local obj = HAT.objects[objID]

	if not obj then return end
	if not HAT.isWholeNumber(frameFrom) then return end
	if not HAT.isWholeNumber(frameTo) then return end
	if frameFrom <= 0 or frameFrom > #obj.frames then return end

	local frame = obj.frames[ frameFrom ]
	table.remove( obj.frames, frameFrom )
	table.insert( obj.frames, frameTo, frame )

	net.Start( "hat_frame_move" )
		net.WriteUInt( objID, 16 )
		net.WriteUInt( frameFrom, 32 )
		net.WriteUInt( frameTo, 32 )
	net.Broadcast()

	HAT.selectFrame( objID, frameTo )
end

-- Desc: sets a frame's playback duration and re-syncs other objects' playback offsets.
function HAT.setFrameLength( objID, frame, frameLength )
	HAT.stop()

	local obj = HAT.objects[objID]

	if not obj then return end
	if not frameLength or frameLength < 0 then return end

	if HAT.isWholeNumber(frame) then
		obj.frames[frame].length = frameLength
	else
		obj.frames[obj.cur].length = frameLength
	end

	HAT.updateOtherObjects( objID, frame )
end

hook.Add("EntityRemoved", "HAT_Remove", function(entity)
	if HAT.entityTrans[entity] then
		for k, id in pairs( HAT.entityTrans[entity] ) do
			HAT.objects[id] = nil

			net.Start( "hat_remove" )
				net.WriteUInt( id, 16 )
			net.Broadcast()

		end
	end
end)
