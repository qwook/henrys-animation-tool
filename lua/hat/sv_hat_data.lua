-- HAT.objects / HAT.entityTrans data model: pose-object + frame CRUD.
-- Split out of hat.lua. Other sv_hat_*.lua files reach into this state via
-- the shared HAT table since include()'d files don't share Lua locals.

HAT = HAT or {}

HAT_DEFAULT_LENGTH = 0.25

-- FCVAR_REPLICATED so the client actually has a ConVar object to read: dframeholder.lua reads
-- HAT_PlayRate:GetFloat() directly (unlike hat_stopmotion's checkbox, which works around being
-- server-only via RunConsoleCommand - see the comment in dhatmenu.lua). Without this, GetConVar
-- returns nil client-side and pressing Play throws before the playhead ever starts advancing.
HAT_PlayRate = CreateConVar( "hat_playrate", 1, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_REPLICATED} )
HAT_StopMotion = CreateConVar( "hat_stopmotion", 0, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_SERVER_CAN_EXECUTE} )

HAT.entityTrans = {} -- Entity -> { [posetype] = objID }, the 4 pose-types per entity.
HAT.objects = {} -- objID -> { frames, ent, cur, posetype, FrameStart, PlayFrame, Playing }
HAT.currentObjId = nil

-- Desc: true if ent's class has a recordable/playable on/off state (see HAT_TOGGLEABLE_ON_OFF in
-- hat_init.lua).
function HAT.isToggleableEntity( ent )
	return IsValid( ent ) and HAT_TOGGLEABLE_ON_OFF[ent:GetClass()] ~= nil
end

-- Desc: flips a toggleable entity's on/off state via its class's own method (SetOn for
-- gmod_emitter, Switch for gmod_thruster - see HAT_TOGGLEABLE_ON_OFF), rather than assuming
-- SetOn works everywhere. No-ops for anything else.
function HAT.setEntityOn( ent, on )
	local setter = HAT.isToggleableEntity( ent ) and HAT_TOGGLEABLE_ON_OFF[ent:GetClass()]
	if not setter then return end

	ent[setter]( ent, on )
end

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

-- Desc: re-applies a frame's captured per-bone motion state to the live entity, undoing the
-- force-freeze HAT.applyPose uses while actively scrubbing/playing. Called whenever
-- playback/scrubbing comes to rest (Stop, frame select, a scrub) so the user isn't left holding a
-- fully frozen ragdoll just because playback touched it. This is also the single choke point every
-- caller (plain frame select, scrub interpolation) funnels through to reach a final per-bone
-- motionEnabled state, so it doubles as the place that syncs the lock icon's frozen-bone set to
-- the client - the entity may be a server-side-only ragdoll with no client physics objects to read
-- IsMotionEnabled() from directly (see dhatmenu.lua Paint), so the server has to tell it explicitly.
--
-- `frame` is the frame index to restore from - callers must pass it explicitly (obj.PlayFrame and
-- obj.cur track different things - the last-played/scrubbed frame vs. the last frame clicked in
-- the UI - and guessing between them left selectFrame restoring stale playback/scrub state).
--
-- `lerped`, when true, means the entity's live pose sits interpolated between `frame` and
-- `frame + 1` (playback/scrubbing stopped mid-tween) rather than resting exactly on `frame`'s own
-- captured pose (a plain frame click). In that case a bone is only left free to move if it was
-- unfrozen in *both* the source and target frame - frozen in either one wins - otherwise the still
-- half-interpolated bone would immediately fall/snap toward whichever frame it's unfrozen in.
function HAT.restoreFreezeState( obj, frame, lerped )
	if not obj or not IsValid( obj.ent ) then return end

	local frameFrom = obj.frames[frame]
	if not frameFrom or not frameFrom.physbones then return end

	local frameTo = lerped and obj.frames[frame + 1] or nil
	local physbonesTo = frameTo and frameTo.physbones or nil

	local lockedBoneIDs = {}

	local function apply( i, motionEnabled )
		local physobj = gQuery( obj.ent:GetPhysicsObjectNum( i - 1 ) )
		if not physobj then return end

		physobj:EnableMotion( motionEnabled )

		if not motionEnabled then
			local boneID = obj.ent:TranslatePhysBoneToBone( i - 1 )
			if boneID and boneID ~= -1 then
				table.insert( lockedBoneIDs, boneID )
			end
		end
	end

	for i, v in pairs( frameFrom.physbones ) do
		local motionEnabled = v.frozen
		local toV = physbonesTo and physbonesTo[i]
		if toV then motionEnabled = motionEnabled and toV.frozen end

		apply( i, motionEnabled )
	end

	-- A bone captured in the target frame but missing from the source frame's table (rare, but
	-- frame captures aren't guaranteed to cover identical bone sets) still needs restoring.
	if physbonesTo then
		for i, v in pairs( physbonesTo ) do
			if not frameFrom.physbones[i] then
				apply( i, v.frozen )
			end
		end
	end

	HAT.syncFrozenBones( obj, lockedBoneIDs )
end

-- Desc: broadcasts obj.ent's currently-locked bone IDs (already translated from physbone indices
-- by restoreFreezeState) for dhatmenu.lua's lock icon, since a server-side-only ragdoll has no
-- client physics objects to read frozen state from directly. Skipped when unchanged from the last
-- broadcast (restoreFreezeState runs every scrub tick while dragging) to avoid spamming net traffic.
function HAT.syncFrozenBones( obj, boneIDs )
	if not IsValid( obj.ent ) then return end

	table.sort( boneIDs )

	local key = table.concat( boneIDs, "," )
	if obj.lastSyncedFrozenBonesKey == key then return end
	obj.lastSyncedFrozenBonesKey = key

	net.Start( "hat_frozen_bones" )
		net.WriteEntity( obj.ent )
		net.WriteUInt( #boneIDs, 8 )
		for _, boneID in ipairs( boneIDs ) do
			net.WriteUInt( boneID, 16 )
		end
	net.Broadcast()
end

-- Desc: halts playback, leaving the shared scrubber at whatever timeline position playback had
-- reached, so a later Play resumes from here rather than from wherever it was last scrubbed to.
function HAT.stop()
	if HAT.playOn then
		HAT.playOn = false

		HAT.scrubTime = math.max( CurTime() * HAT_PlayRate:GetFloat() - HAT.playStart, 0 )
		HAT.playStart = CurTime() * HAT_PlayRate:GetFloat() - HAT.scrubTime
		HAT.playLastFrame = CurTime() * HAT_PlayRate:GetFloat()

		for _, obj in pairs( HAT.objects ) do
			if obj and obj.PlayFrame then
				HAT.restoreFreezeState( obj, obj.PlayFrame, true )
			end
		end

		net.Start( "hat_stop" )
		net.Broadcast()
	end
end

-- Desc: a fresh, empty frame using the default length. Optionally inherits the easing of the
-- frame it's being inserted after, so Stop Motion keeps applying to newly added frames.
function HAT.blankFrame( easing, easingStrength )
	return
	{
		length = HAT_DEFAULT_LENGTH;
		easing = easing or "linear";
		easingStrength = easingStrength or "normal";
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

		-- Removed objects leave a nil hole (see HAT.removeObject/EntityRemoved) rather than being
		-- compacted out of the array, so skip past them instead of aborting the whole loop.
		if v and v ~= obj and IsValid( v.ent ) then

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

			-- Restore this object's real per-bone motion state to whatever frame it landed on,
			-- undoing applyPose's force-freeze now that it's settled (see HAT.restoreFreezeState).
			v.PlayFrame = PlayFrame
			HAT.restoreFreezeState( v, PlayFrame, true )

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
					-- Force-freeze (and clear any leftover velocity) while teleporting, same as
					-- HAT.applyPose during playback/scrubbing - every physbone jumps to its target
					-- independently in one tick, so re-enabling motion immediately (EnableMotion(
					-- v.frozen)) let the constraint solver react to the resulting joint-position
					-- discontinuity with a violent corrective impulse ("slapping"). Real motion state
					-- is restored below via HAT.restoreFreezeState once the teleport has settled.
					physobj
						:SetPos( v.pos )
						:SetAngles( v.ang )
						:SetVelocity( vector_origin )
						:SetAngleVelocity( vector_origin )
						:Wake()
						:EnableMotion( false )
				end
			end

			local selectedFrame = obj.cur
			timer.Simple( 0, function()
				HAT.restoreFreezeState( obj, selectedFrame )
			end )
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

		local on = obj.frames[obj.cur].on

		if on ~= nil and obj.ent:GetOn() ~= on then
			HAT.setEntityOn( obj.ent, on )
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

		HAT.playOnionSkin( "prev", obj.ent, bones, Color(0, 255, 255, 125) )
	else
		HAT.clearOnionSkin( "prev" )
	end

	-- A second ghost showing the current frame's own last-captured pose (if it has one), so
	-- posing drift after selecting a frame can be compared back against what's actually saved
	-- before Replace Frame overwrites it.
	if obj.frames[obj.cur] and obj.frames[obj.cur].physbones then
		local physbones = obj.frames[obj.cur].physbones

		local bones = {}
		for i,v in pairs( physbones ) do
			bones[i] = {
				pos = v.pos,
				ang = v.ang
			}
		end

		HAT.playOnionSkin( "current", obj.ent, bones, Color(255, 0, 255, 125) )
	else
		HAT.clearOnionSkin( "current" )
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

	-- The new frame inherits Stop Motion easing from the frame it's inserted after, so a chain
	-- of stop-motion frames keeps snapping instead of silently reverting to linear.
	local prevFrame
	if HAT.isWholeNumber( frame ) and frame > 0 and frame <= #obj.frames then
		prevFrame = obj.frames[frame - 1]
		table.insert( obj.frames, frame, HAT.blankFrame( prevFrame and prevFrame.easing == "stopmotion" and prevFrame.easing, prevFrame and prevFrame.easingStrength ) )
	else
		prevFrame = obj.frames[#obj.frames]
		table.insert( obj.frames, HAT.blankFrame( prevFrame and prevFrame.easing == "stopmotion" and prevFrame.easing, prevFrame and prevFrame.easingStrength ) )
		frame = #obj.frames
	end

	HAT.snapShotFrame( objID, frame )

	local newEasing = obj.frames[frame].easing
	local newStrength = obj.frames[frame].easingStrength

	net.Start( "hat_frame_add" )
		net.WriteUInt( objID, 16 )
		net.WriteUInt( frame, 32 )
		net.WriteString( newEasing )
		net.WriteString( newStrength )
	net.Broadcast()

	HAT.selectFrame( objID, frame )
end

-- Desc: inserts a deep copy of a frame (pose data included) right after it, and selects the copy.
-- Unlike HAT.addFrame's "hat_frame_add" broadcast (which the client always reconstructs as a
-- blank default-length frame), the copy can have any length/easing, so this uses its own
-- "hat_frame_duplicate" message carrying that data explicitly.
function HAT.duplicateFrame( objID, frame )
	HAT.stop()

	local obj = HAT.objects[objID]

	if not obj then return end
	if not ( HAT.isWholeNumber( frame ) and frame > 0 and frame <= #obj.frames ) then return end

	local copy = table.Copy( obj.frames[frame] )
	local newFrame = frame + 1

	table.insert( obj.frames, newFrame, copy )

	net.Start( "hat_frame_duplicate" )
		net.WriteUInt( objID, 16 )
		net.WriteUInt( newFrame, 32 )
		net.WriteFloat( copy.length )
		net.WriteString( copy.easing or "linear" )
		net.WriteString( copy.easingStrength or "normal" )
	net.Broadcast()

	HAT.selectFrame( objID, newFrame )
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

-- Desc: sets a frame's playback duration and re-syncs other objects' playback offsets. Frames
-- can never be zero (or negative) length.
function HAT.setFrameLength( objID, frame, frameLength )
	HAT.stop()

	local obj = HAT.objects[objID]

	if not obj then return end
	if not frameLength or frameLength <= 0 then return end

	if HAT.isWholeNumber(frame) then
		obj.frames[frame].length = frameLength
	else
		obj.frames[obj.cur].length = frameLength
	end

	HAT.updateOtherObjects( objID, frame )
end

-- Desc: sets a frame's easing curve/strength (see HAT.Ease in sv_hat_playback.lua) and syncs it
-- to every client so the right-click Easing menu can show the current selection.
function HAT.setFrameEasing( objID, frame, easing, strength )
	local obj = HAT.objects[objID]

	if not obj then return end
	if not HAT.isWholeNumber(frame) or not obj.frames[frame] then return end

	obj.frames[frame].easing = easing
	obj.frames[frame].easingStrength = strength

	net.Start( "hat_frame_easing" )
		net.WriteUInt( objID, 16 )
		net.WriteUInt( frame, 32 )
		net.WriteString( easing )
		net.WriteString( strength )
	net.Broadcast()
end

-- Desc: manually deletes an entity's pose objects and all their frames without removing the
-- entity itself - the "Stop Animating" entity-label option. Removes every pose-type slot for the
-- entity (body/face/l-hand/r-hand), not just the row that was right-clicked: the load path
-- (hat_load, sv_hat_commands.lua) only re-creates an entity from a saved body (HAT_SELECT_ENTITY)
-- record, so leaving orphaned face/hand records with no matching body record around would crash
-- on the next load. Mirrors what the EntityRemoved hook below already does automatically when the
-- entity itself is removed from the world.
function HAT.removeObject( objID )
	local obj = HAT.objects[objID]

	if not obj then return end

	HAT.stop()

	local function removeSlot( id )
		HAT.objects[id] = nil

		if HAT.currentObjId == id then
			HAT.currentObjId = nil
		end

		net.Start( "hat_remove" )
			net.WriteUInt( id, 16 )
		net.Broadcast()
	end

	if IsValid(obj.ent) and HAT.entityTrans[obj.ent] then
		for _, id in pairs( HAT.entityTrans[obj.ent] ) do
			removeSlot( id )
		end
		HAT.entityTrans[obj.ent] = nil
	else
		removeSlot( objID )
	end
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
