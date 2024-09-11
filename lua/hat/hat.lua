
include("hands.lua")
require("hon")

HAT_DEFAULT_LENGTH = 0.25

HAT_PlayRate = CreateConVar( "hat_playrate", 1, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_SERVER_CAN_EXECUTE} )
HAT_StopMotion = CreateConVar( "hat_stopmotion", 0, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_SERVER_CAN_EXECUTE} )

local playOn = false
local playStart = 0
local playLastFrame = 0 -- to calculate delta time
local playObject = 0

local entityTrans = {}
local objects = {}
local currentObjId

local function getTimeFromFrame( objID, frameID )
	local obj = objects[objID]

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

local function isWholeNumber( num )
	local num = tonumber(num)
	if not num then return end
	return math.ceil(num) == num
end

local function stop()
	if playOn then
		playOn = false
		net.Start( "hat_stop" )
		net.Broadcast()
		local obj = objects[objID]
		if obj then
			selectFrame( currentObjId, obj.cur or 1  )
		end
	end
end

local function getPhysBones( ent )
	if not IsValid( ent ) then return end

	local bones = {}
	for i = 0, ent:GetPhysicsObjectCount() - 1 do
		local phys = ent:GetPhysicsObjectNum( i )
		if phys then
			bones[i+1] = { pos = phys:GetPos(), ang = phys:GetAngles(), frozen = phys:IsMotionEnabled() }
		end
	end
	return bones
end

local function IsUselessFaceFlex( strName )

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

local function getFlexes( ent )
	if not IsValid( ent ) then return end

	local FlexNum = ent:GetFlexNum() - 1
	
	local flexes = { flexes = {}, scale = 1 }

	for i=0, FlexNum-1 do
	
		local Name = ent:GetFlexName( i )

		if ( not IsUselessFaceFlex(Name )  ) then
				
			flexes.flexes[i] = ent:GetFlexWeight( i )
		
		end
		
	end
	
	flexes.scale = ent:GetFlexScale()

	return flexes
end

-- Todo: design for modules
local function snapShotFrame( objID, frame )
	stop()

	local obj = objects[objID]

	if not obj then return end

	if not isWholeNumber(frame) then frame = obj.cur end

	if obj.posetype == HAT_SELECT_ENTITY then
		obj.frames[frame].physbones = getPhysBones( obj.ent )
	elseif obj.posetype == HAT_SELECT_FACE then
		obj.frames[frame].flexes = getFlexes( obj.ent )
		obj.frames[frame].eye = obj.ent:GetEyeTarget()
	elseif obj.posetype == HAT_SELECT_L_HAND then
		obj.frames[frame].lhand = hat_hands.getHand( obj.ent, 0 )
	elseif obj.posetype == HAT_SELECT_R_HAND then
		obj.frames[frame].rhand = hat_hands.getHand( obj.ent, 1 )
	end

end

local function blankFrame()
	return
	{
		length = HAT_DEFAULT_LENGTH;
	}
end

local function newObject( ent )
	stop()

	if not IsValid( ent ) then return end

	entityTrans[ent] = {
		table.insert(objects, {
			frames = {
				blankFrame();
			};
			ent = ent;
			cur = 1;
			posetype = HAT_SELECT_ENTITY;
		});
		table.insert(objects, {
			frames = {
				blankFrame();
			};
			ent = ent;
			cur = 1;
			posetype = HAT_SELECT_FACE;
		});
		table.insert(objects, {
			frames = {
				blankFrame();
			};
			ent = ent;
			cur = 1;
			posetype = HAT_SELECT_L_HAND;
		});
		table.insert(objects, {
			frames = {
				blankFrame();
			};
			ent = ent;
			cur = 1;
			posetype = HAT_SELECT_R_HAND;
		});
	};

	--[[for i = 1, 4 do
		snapShotFrame( entityTrans[ent][i] )
	end]]
	return entityTrans[ent]
end

local function fill( translate, ent, posetype )

	for i = 1, 4 do
		if not translate[i] then
			translate[i] = table.insert(objects, {
				frames = {
					blankFrame();
				};
				ent = ent;
				cur = 1;
				posetype = i;
			})
		end
	end

	return translate[posetype]

end

local function updateOtherObjects( objID, frame )
	local offset = getTimeFromFrame( objID, frame + 1 )
	local obj = objects[objID]

	for k,v in pairs(objects) do

		if not v then break end

		if v ~= obj and IsValid( v.ent ) then

			local FrameStart = 0
			local PlayFrame = 1

			local frame = v.frames[PlayFrame]

			while (frame and ( FrameStart + frame.length < offset ) ) do
				FrameStart = FrameStart + frame.length
				playFrame( v, PlayFrame, 1 )
				PlayFrame = PlayFrame + 1
				frame = v.frames[PlayFrame]
			end

			if frame then
				local delta = (offset - FrameStart) / frame.length
				playFrame( v, PlayFrame, delta )
			end

		end

	end
end

local function selectFrame( objID, frame )
	stop()

	local obj = objects[objID]

	if not obj then return end
	if not isWholeNumber( frame ) then return end
	if frame <= 0 or frame > #obj.frames then frame = #obj.frames end

	obj.cur = frame

	if obj.frames[obj.cur] then
		local physbones = obj.frames[obj.cur].physbones
		if physbones then
			for i,v in pairs( physbones ) do
				local physobj = g(obj.ent:GetPhysicsObjectNum( i - 1 ))
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

				if ( IsUselessFaceFlex(Name)  ) then
					
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

		playOnionSkin( obj.ent, bones )
	else
		clearOnionSkin()
	end

	updateOtherObjects( objID, frame )

	net.Start( "hat_frame_select" )
		net.WriteUInt( objID, 16 )
		net.WriteUInt( frame, 32 )
	net.Broadcast()
end

local function addFrame( objID, frame )
	stop()

	local obj = objects[objID]

	if not obj then return end

	if isWholeNumber( frame ) and frame > 0 and frame <= #obj.frames then
		table.insert( obj.frames, frame, blankFrame() )
	else
		frame = table.insert( obj.frames, blankFrame() )
	end

	net.Start( "hat_frame_add" )
		net.WriteUInt( objID, 16 )
		net.WriteUInt( frame, 32 )
	net.Broadcast()

	selectFrame( objID, frame )
end

local function removeFrame( objID, frame )
	stop()

	local obj = objects[objID]

	if not obj then return end

	if not ( isWholeNumber( frame ) and frame > 0 and frame <= #obj.frames ) then
		frame = #obj.frames
	end

	table.remove( obj.frames, frame )

	selectFrame( objID, frame )

	net.Start( "hat_frame_remove" )
		net.WriteUInt( objID, 16 )
		net.WriteUInt( frame, 32 )
	net.Broadcast()
end

local function moveFrame( objID, frameFrom, frameTo )
	stop()

	local obj = objects[objID]

	if not obj then return end
	if not isWholeNumber(frameFrom) then return end
	if not isWholeNumber(frameTo) then return end
	if frameFrom <= 0 or frameFrom > #obj.frames then return end

	local frame = obj.frames[ frameFrom ]
	table.remove( obj.frames, frameFrom )
	table.insert( obj.frames, frameTo, frame )

	net.Start( "hat_frame_move" )
		net.WriteUInt( objID, 16 )
		net.WriteUInt( frameFrom, 32 )
		net.WriteUInt( frameTo, 32 )
	net.Broadcast()

	selectFrame( objID, frameTo )
end

local function setFrameLength( objID, frame, frameLength )
	stop()

	local obj = objects[objID]

	if not obj then return end
	if not frameLength or frameLength < 0 then return end

	if isWholeNumber(frame) then
		obj.frames[frame].length = frameLength
	else
		obj.frames[obj.cur].length = frameLength
	end

	updateOtherObjects( objID, frame )
end

-- Select an entity.
concommand.Add( "hat_select", function( pl, cmd, args )
	stop()
	if not isWholeNumber( args[1] ) then return end
	local ent = ents.GetByIndex(tonumber(args[1]))
	local posetype = tonumber(args[2]) or HAT_SELECT_ENTITY
	if IsValid(ent) and not ent:GetNWBool("ignore") then
		local entID
		if entityTrans[ent] then
			entID = entityTrans[ent][posetype]
			if not entID then
				-- we have an incompatible file version
				-- just fill up the blank spaces.
				entID = fill( entityTrans[ent], ent, posetype )
			end
		else
			newObject( ent )
			entID = entityTrans[ent][posetype]
		end
		currentObjId = entID

		local obj = objects[currentObjId]

		net.Start( "hat_select" )
			net.WriteUInt( entID, 16 )
			net.WriteEntity( ent )
			net.WriteUInt( posetype, 16 )
		net.Broadcast()

		selectFrame( currentObjId, obj.cur or 1  )
	end
end)

concommand.Add( "hat_frame_select", function( pl, cmd, args )
	stop()
	if not isWholeNumber( args[1] ) then return end

	local frame = tonumber(args[1])
	if currentObjId and objects[currentObjId] then
		selectFrame( currentObjId, frame )
	end
end)

concommand.Add( "hat_frame_add", function( pl, cmd, args )
	stop()
	if currentObjId and objects[currentObjId] then
		addFrame( currentObjId, tonumber(args[1]) )
	end
end)

concommand.Add( "hat_frame_remove", function( pl, cmd, args )
	stop()
	if currentObjId and objects[currentObjId] then
		removeFrame( currentObjId, tonumber(args[1]) )
	end
end)

concommand.Add( "hat_frame_setlength", function( pl, cmd, args )
	stop()
	if currentObjId and objects[currentObjId] then
		setFrameLength( currentObjId, tonumber(args[1]), tonumber(args[2]) )
	end
end)

concommand.Add( "hat_frame_move", function( pl, cmd, args )
	stop()
	if not isWholeNumber( args[1] ) then return end
	if not isWholeNumber( args[2] ) then return end
	if currentObjId and objects[currentObjId] then
		moveFrame( currentObjId, tonumber(args[1]), tonumber(args[2]) )
	end
end)

concommand.Add( "hat_frame_snapshot", function( pl, cmd, args )
	stop()
	snapShotFrame( currentObjId )
end)

concommand.Add( "hat_play", function( pl, cmd, args )
	local offset = 0

	local obj = objects[currentObjId]

	if obj then
		offset = getTimeFromFrame(currentObjId, obj.cur)
	end

	clearOnionSkin()

	playOn = true
	playStart = CurTime() * HAT_PlayRate:GetFloat() - offset
	playLastFrame = playStart
	playObject = #objects

	for k,v in pairs(objects) do

		v.FrameStart = 0
		v.PlayFrame = 1
		v.Playing = true

	end

	net.Start( "hat_play" )
		net.WriteFloat( playStart )
	net.Broadcast()

end)

concommand.Add( "hat_stop", function( pl, cmd, args )
	stop()
end)

function playFrame( obj, frame, delta )

	local frameFrom = obj.frames[frame - 1]
	local frameTo = obj.frames[frame]

	if not frameFrom and frameTo then frameFrom = frameTo end
	if not frameFrom or not frameTo then return end

	local physbonesFrom = frameFrom.physbones
	local physbonesTo = frameTo.physbones

	if physbonesFrom and physbonesTo then
		for i,from in pairs( physbonesFrom ) do
			to = physbonesTo[i]

			local physobj = g(obj.ent:GetPhysicsObjectNum( i - 1 ))
			if physobj then
				physobj
					:SetPos( LerpVector(delta, from.pos, to.pos) )
					:SetAngles( LerpAngle(delta, from.ang, to.ang) )
					:Wake()
					:EnableMotion( false )
			end
		end
	end

	local flexesFrom = frameFrom.flexes
	local flexesTo = frameTo.flexes

	if flexesFrom and flexesTo then
		for i,from in pairs( flexesFrom.flexes ) do
			to = flexesTo.flexes[i]

			local FlexNum = obj.ent:GetFlexNum() - 1

			local Name = obj.ent:GetFlexName( i )

			if ( IsUselessFaceFlex(Name )  ) then
				
				obj.ent:SetFlexWeight( i, 0 )
					
			else
		
				obj.ent:SetFlexWeight( i, Lerp(delta, from, to) )
				
			end
		end
		obj.ent:SetFlexScale( Lerp(delta, flexesFrom.scale, flexesTo.scale) )
	end

	local lhandFrom = frameFrom.lhand
	local lhandTo = frameTo.lhand

	if lhandFrom and lhandTo then
		hat_hands.lerpHand(delta, obj.ent, lhandFrom, lhandTo, 0)
	end

	local rhandFrom = frameFrom.rhand
	local rhandTo = frameTo.rhand

	if rhandFrom and rhandTo then
		hat_hands.lerpHand(delta, obj.ent, rhandFrom, rhandTo, 1)
	end

	local eyeFrom = frameFrom.eye
	local eyeTo = frameTo.eye

	if eyeFrom and eyeTo then
		obj.ent:SetEyeTarget( LerpVector(delta, eyeFrom, eyeTo) )
	end

end

hook.Add("EntityRemoved", "HAT_Remove", function(entity)
	if entityTrans[entity] then
		for k, id in pairs( entityTrans[entity] ) do
			objects[id] = nil

			net.Start( "hat_remove" )
				net.WriteUInt( id, 16 )
			net.Broadcast()

		end
	end
end)

local function replay()

	playOn = true
	playStart = CurTime() * HAT_PlayRate:GetFloat()
	playLastFrame = 1
	playObject = #objects

	for k,v in pairs(objects) do

		v.FrameStart = 0
		v.PlayFrame = 1
		v.Playing = true

	end

	net.Start( "hat_play" )
		net.WriteFloat( playStart )
	net.Broadcast()

end

hook.Add("Think", "HAT_Play", function()
	if not playOn then return end

	local localTime = CurTime() * HAT_PlayRate:GetFloat() - playStart
	local deltaTime = CurTime() * HAT_PlayRate:GetFloat() - playLastFrame
	playLastFrame = CurTime() * HAT_PlayRate:GetFloat()

	for k,v in pairs(objects) do

		if not v then break end

		if IsValid( v.ent ) then

			local frame = v.frames[v.PlayFrame]

			-- Play fluidly. Take into account skipped frames.
			while (frame and ( v.FrameStart + frame.length < localTime ) ) do
				v.FrameStart = v.FrameStart + frame.length
				playFrame( v, v.PlayFrame, 1 )
				v.PlayFrame = v.PlayFrame + 1
				frame = v.frames[v.PlayFrame]
			end

			if frame then
				local delta = 1
				if not HAT_StopMotion:GetBool() then
					delta = (localTime - v.FrameStart) / frame.length
				end
				playFrame( v, v.PlayFrame, delta )
			elseif v.Playing then
				v.Playing = nil
				playObject = playObject - 1
			end

		end

	end

	if playObject == 0 then
		replay()
	end

end)

concommand.Add( "hat_save", function( pl, cmd, args )
	stop()

	local fileName = tostring( args[1] or "untitled" )
	
	if fileName:sub( -4, -1 ):lower() ~= ".hat" then
		fileName = fileName .. ".hat"
	end

	local toSave = {objects = table.Copy(objects), currentObjId = currentObjId, version = HAT_VERSION}

	local tempTrans = {}

	for k, v in pairs( toSave.objects ) do
		if not v.posetype or v.posetype == HAT_SELECT_ENTITY then
			tempTrans[v.ent] = k
			v.posetype = 1
			v.ent = duplicator.CopyEntTable(v.ent)
		end
	end

	for k, v in pairs( toSave.objects ) do
		if v.posetype and v.posetype ~= HAT_SELECT_ENTITY then
			v.ent = tempTrans[v.ent]
		end
	end

	toSave = honsolo.encode( toSave )

	if not file.IsDir("hat", "DATA") then
		file.CreateDir( "hat" )
	end
	file.Write(fileName .. ".txt", toSave)
end)

concommand.Add( "hat_load", function( pl, cmd, args )
	stop()
	game.CleanUpMap()

	playOn = false
	playStart = 0
	playLastFrame = 0 -- to calculate delta time

	entityTrans = {}
	objects = {}
	currentObjId = nil
	
	local fileName = tostring( args[1] or "untitled" )
	
	if fileName:sub( -4, -1 ):lower() ~= ".hat" then
		fileName = fileName .. ".hat"
	end

	toLoad = file.Read(fileName .. ".txt", "DATA")
	toLoad = honsolo.decode( toLoad )

	local tempTrans = {}

	if toLoad.version == 2 then
		for k,v in pairs( toLoad.objects ) do
			v.posetype = v.type
			v.type = nil
		end
	end

	for k,v in pairs( toLoad.objects ) do
		if not v.posetype or v.posetype == HAT_SELECT_ENTITY then
			local ent = duplicator.CreateEntityFromTable( player.GetByID(1), v.ent )
			v.ent = ent
			v.cur = 1
			tempTrans[k] = ent
			entityTrans[v.ent] = entityTrans[v.ent] or {}
			entityTrans[v.ent][v.posetype or 1] = k
		end
	end

	for k,v in pairs( toLoad.objects ) do
		if v.posetype and v.posetype ~= HAT_SELECT_ENTITY then
			v.ent = tempTrans[v.ent]
			v.cur = 1
			entityTrans[v.ent] = entityTrans[v.ent] or {}
			entityTrans[v.ent][v.posetype] = k
		end
	end

	currentObjId = toLoad.currentObjId
	objects = toLoad.objects

	local toSend = { currentObjId = currentObjId, objects = {} }
	for k,v in pairs( objects ) do
		toSend.objects[k] = {frames={}, ent=v.ent:EntIndex()}
		for _,v in ipairs( v.frames ) do
			table.insert( toSend.objects[k].frames, v.length )
		end
	end

	net.Start( "hat_send_data" )
		net.WriteTable( toSend )
	net.Broadcast()

	selectFrame( currentObjId, 1 )

end)

concommand.Add( "hat_new", function( pl, cmd, args )
	stop()
	game.CleanUpMap()

	playOn = false
	playStart = 0
	playLastFrame = 0 -- to calculate delta time

	entityTrans = {}
	objects = {}
	currentObjId = nil
	
	objects = {}

	net.Start( "hat_send_data" )
		net.WriteTable( {objects={}} )
	net.Broadcast()

end)

concommand.Add( "hat_debugprint", function()
	PrintTable( objects )
end )

function playOnionSkin( ent, bones )

	if IsValid(HAT_ONION) and IsValid(HAT_ONION) ~= HAT_ONION and ent:GetModel() ~= HAT_ONION:GetModel() then
		HAT_ONION:Remove()
	end

	if not IsValid(HAT_ONION) or IsValid(HAT_ONION) == HAT_ONION then
		if ent:GetClass() == "prop_ragdoll" then
			HAT_ONION = g.Create("prop_ragdoll")
		else
			HAT_ONION = g.Create("prop_dynamic")
		end

		HAT_ONION
			:SetModel(ent:GetModel())
			:SetColor(Color(0, 255, 255, 125))
			:SetRenderMode(RENDERMODE_TRANSCOLOR)
			:SetCollisionGroup(COLLISION_GROUP_NONE)
			:SetNotSolid(true)
			:SetNWBool( "ignore", true )
			:Spawn()

	end

	HAT_ONION
		:SetPos( ent:GetPos() )
		:SetAngles( ent:GetAngles() )

	for i,v in pairs( bones ) do
		local physObj = g(HAT_ONION:GetPhysicsObjectNum( i - 1 ))
			:SetPos(v.pos)
			:SetAngles(v.ang)
			:EnableMotion(false)
			:EnableCollisions(false)
			:Wake()
	end

end

function clearOnionSkin()
	if IsValid(HAT_ONION) and IsValid(HAT_ONION) ~= HAT_ONION then
		HAT_ONION:Remove()
	end
end

local function onionPhysOverload( pl, ent )
	if ent:GetNWBool( "ignore" ) then
		return false
	end
end
hook.Add("PhysgunPickup", "HATPhysgun", onionPhysOverload)
hook.Add("OnPhysgunReload", "HATPhysgun", function(_,pl) return onionPhysOverload(pl, pl:GetEyeTrace().Entity) end)
