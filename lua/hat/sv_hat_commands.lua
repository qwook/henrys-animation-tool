-- Console commands clients use to drive the HAT data model/playback (see sv_hat_data.lua,
-- sv_hat_playback.lua). Split out of hat.lua.

HAT = HAT or {}

-- Desc: selects an entity (and pose-type: body/face/l-hand/r-hand), creating its pose objects if new.
concommand.Add("hat_select", function(pl, cmd, args)
	HAT.stop()
	if not HAT.isWholeNumber(args[1]) then return end
	local ent = ents.GetByIndex(tonumber(args[1]))
	local posetype = tonumber(args[2]) or HAT_SELECT_ENTITY
	if IsValid(ent) and not ent:GetNWBool("ignore") then
		local entID
		if HAT.entityTrans[ent] then
			entID = HAT.entityTrans[ent][posetype]
			if not entID then
				-- we have an incompatible file version
				-- just fill up the blank spaces.
				entID = HAT.fill(HAT.entityTrans[ent], ent, posetype)
			end
		else
			HAT.newObject(ent)
			entID = HAT.entityTrans[ent][posetype]
		end
		HAT.currentObjId = entID

		local obj = HAT.objects[HAT.currentObjId]

		net.Start("hat_select")
		net.WriteUInt(entID, 16)
		net.WriteEntity(ent)
		net.WriteUInt(posetype, 16)
		net.Broadcast()
		MsgN("broadcasted")

		HAT.selectFrame(HAT.currentObjId, obj.cur or 1)
	end
end)

-- Desc: selects an already-existing pose object directly by its id (used when clicking a row
-- in the frame-strip timeline, which already knows which object/posetype that row is).
concommand.Add("hat_select_object", function(pl, cmd, args)
	HAT.stop()
	if not HAT.isWholeNumber(args[1]) then return end

	local objID = tonumber(args[1])
	local obj = HAT.objects[objID]
	if not obj or not IsValid(obj.ent) then return end

	HAT.currentObjId = objID

	net.Start("hat_select")
	net.WriteUInt(objID, 16)
	net.WriteEntity(obj.ent)
	net.WriteUInt(obj.posetype or HAT_SELECT_ENTITY, 16)
	net.Broadcast()

	HAT.selectFrame(objID, obj.cur or 1)
end)

-- Desc: "Stop Animating" from an entity label's right-click menu: deletes that pose object (and
-- all its frames) without touching the entity itself.
concommand.Add("hat_remove_entity", function(pl, cmd, args)
	if not HAT.isWholeNumber(args[1]) then return end
	HAT.removeObject(tonumber(args[1]))
end)

concommand.Add("hat_frame_select", function(pl, cmd, args)
	HAT.stop()
	if not HAT.isWholeNumber(args[1]) then return end

	local frame = tonumber(args[1])
	if HAT.currentObjId and HAT.objects[HAT.currentObjId] then
		HAT.selectFrame(HAT.currentObjId, frame)
	end
end)

concommand.Add("hat_frame_add", function(pl, cmd, args)
	HAT.stop()
	if HAT.currentObjId and HAT.objects[HAT.currentObjId] then
		HAT.addFrame(HAT.currentObjId, tonumber(args[1]))
	else
		net.Start("hat_error")
		net.WriteString("Select something to animate first. (Right Click)")
		net.WriteFloat(5)
		net.Send(pl)
	end
end)

concommand.Add("hat_frame_remove", function(pl, cmd, args)
	HAT.stop()
	if HAT.currentObjId and HAT.objects[HAT.currentObjId] then
		HAT.removeFrame(HAT.currentObjId, tonumber(args[1]))
	end
end)

concommand.Add("hat_frame_duplicate", function(pl, cmd, args)
	HAT.stop()
	if not HAT.isWholeNumber(args[1]) then return end
	if HAT.currentObjId and HAT.objects[HAT.currentObjId] then
		HAT.duplicateFrame(HAT.currentObjId, tonumber(args[1]))
	end
end)

concommand.Add("hat_frame_setlength", function(pl, cmd, args)
	HAT.stop()
	if HAT.currentObjId and HAT.objects[HAT.currentObjId] then
		HAT.setFrameLength(HAT.currentObjId, tonumber(args[1]), tonumber(args[2]))
	end
end)

concommand.Add("hat_frame_seteasing", function(pl, cmd, args)
	HAT.stop()
	if not HAT.isWholeNumber(args[1]) then return end
	if HAT.currentObjId and HAT.objects[HAT.currentObjId] then
		HAT.setFrameEasing(HAT.currentObjId, tonumber(args[1]), args[2], args[3])
	end
end)

concommand.Add("hat_frame_move", function(pl, cmd, args)
	HAT.stop()
	if not HAT.isWholeNumber(args[1]) then return end
	if not HAT.isWholeNumber(args[2]) then return end
	if HAT.currentObjId and HAT.objects[HAT.currentObjId] then
		HAT.moveFrame(HAT.currentObjId, tonumber(args[1]), tonumber(args[2]))
	end
end)

concommand.Add("hat_frame_snapshot", function(pl, cmd, args)
	HAT.stop()
	HAT.snapShotFrame(HAT.currentObjId, tonumber(args[1]))
end)

-- Desc: starts synchronized playback of every pose object from the shared scrubber position
-- (HAT.scrubTime, kept up to date by both scrubbing and clicking a frame), not from elapsed real
-- time, which would drift by however long the user waited before pressing Play.
concommand.Add("hat_play", function(pl, cmd, args)
	local offset = HAT.scrubTime

	-- If the scrubber is parked at (or past) the end of the timeline, play from the start
	-- instead of doing nothing.
	if offset >= HAT.getTotalTime() then
		offset = 0
	end

	HAT.clearOnionSkin()

	HAT.playOn = true
	HAT.playStart = CurTime() * HAT_PlayRate:GetFloat() - offset
	HAT.playLastFrame = HAT.playStart
	HAT.playObject = #HAT.objects

	for k, v in pairs(HAT.objects) do
		v.FrameStart = 0
		v.PlayFrame = 1
		v.Playing = true
	end

	-- Broadcast the timeline offset (seconds into playback), not the raw server-clock playStart:
	-- clients rebuild StartTime from their own CurTime(), so the scrubber doesn't depend on the
	-- server and client clocks lining up.
	net.Start("hat_play")
	net.WriteFloat(offset)
	net.Broadcast()
end)

-- Desc: stops playback if it's running; otherwise (already stopped) rewinds the scrubber to 0.
concommand.Add("hat_stop", function(pl, cmd, args)
	if HAT.playOn then
		HAT.stop()
	elseif HAT.currentObjId and HAT.objects[HAT.currentObjId] then
		HAT.selectFrame(HAT.currentObjId, 1)
	end
end)

-- Desc: scrubbing support: jumps every pose object's pose to timeline time args[1] (seconds)
-- without touching which frame is selected for editing.
concommand.Add("hat_seek", function(pl, cmd, args)
	HAT.seek( tonumber(args[1]) or 0 )
end)

-- Desc: flips whether playback loops after every object finishes, and syncs the new state to clients.
concommand.Add("hat_toggle_loop", function(pl, cmd, args)
	HAT.setLoop( not HAT.loop )
end)

-- Desc: serializes every pose object to a .hat.txt file under data/hat/.
concommand.Add("hat_save", function(pl, cmd, args)
	HAT.stop()

	local fileName = tostring(args[1] or "untitled")

	if fileName:sub(-4, -1):lower() ~= ".hat" then
		fileName = fileName .. ".hat"
	end

	local toSave = { objects = table.Copy(HAT.objects), currentObjId = HAT.currentObjId, version = HAT_VERSION, loop = HAT.loop }

	-- Desc: args[2] is the client's row display order (DHATMenu's save()), as comma-separated
	-- server-side object keys. Stamped onto each object as `order` so DFrameHolder:Load can restore
	-- row order; a save missing this (older client, or args[2] absent) just leaves `order` unset,
	-- which DFrameHolder:Load treats as "put it at the bottom" for backwards compatibility.
	MsgN(args[2])
	if args[2] and args[2] ~= "" then
		for i, key in ipairs(string.Explode(",", args[2])) do
			local obj = toSave.objects[tonumber(key)]
			if obj then obj.order = i end
		end
	end

	-- Desc: HAT.newObject/HAT.fill always create a Face/LHand/RHand pose object alongside the body
	-- one, whether or not the user ever poses it (see sv_hat_data.lua) - drop the ones that were
	-- never touched (no frames added) instead of writing dead rows to the file.
	for k, v in pairs(toSave.objects) do
		if v.posetype and v.posetype ~= HAT_SELECT_ENTITY and #v.frames == 0 then
			toSave.objects[k] = nil
		end
	end

	local tempTrans = {}

	for k, v in pairs(toSave.objects) do
		if not v.posetype or v.posetype == HAT_SELECT_ENTITY then
			tempTrans[v.ent] = k
			v.posetype = 1
			v.ent = duplicator.CopyEntTable(v.ent)
		end
	end

	for k, v in pairs(toSave.objects) do
		if v.posetype and v.posetype ~= HAT_SELECT_ENTITY then
			v.ent = tempTrans[v.ent]
		end
	end

	toSave = util.TableToJSON(toSave);

	if not file.IsDir("hat", "DATA") then
		file.CreateDir("hat")
	end
	file.Write(fileName .. ".txt", toSave)
end)

-- Desc: clears the current session and loads pose objects from a .hat.txt file, spawning their entities.
concommand.Add("hat_load", function(pl, cmd, args)
	HAT.stop()
	game.CleanUpMap()

	HAT.playOn = false
	HAT.playStart = 0
	HAT.playLastFrame = 0 -- to calculate delta time

	HAT.entityTrans = {}
	HAT.objects = {}
	HAT.currentObjId = nil

	local fileName = tostring(args[1] or "untitled")

	if fileName:sub(-4, -1):lower() ~= ".hat" then
		fileName = fileName .. ".hat"
	end

	local toLoad = file.Read(fileName .. ".txt", "DATA")
	toLoad = util.JSONToTable(toLoad)

	-- Desc: a sparse objects table (holes from dropped empty Face/LHand/RHand rows - see hat_save)
	-- encodes as a JSON object rather than an array, so util.JSONToTable hands back string keys
	-- ("5" instead of 5). HAT.objects = toLoad.objects below needs real numbers, since every other
	-- HAT.objects[objID] lookup in this file/sv_hat_data.lua indexes with numbers.
	do
		local renumbered = {}
		for k, v in pairs(toLoad.objects) do
			renumbered[tonumber(k)] = v
		end
		toLoad.objects = renumbered
	end

	local tempTrans = {}

	if toLoad.version == 2 then
		for k, v in pairs(toLoad.objects) do
			v.posetype = v.type
			v.type = nil
		end
	end

	-- Desc: drop untouched Face/LHand/RHand rows (no frames) - hat_save no longer writes these, but
	-- older files still have them.
	for k, v in pairs(toLoad.objects) do
		if v.posetype and v.posetype ~= HAT_SELECT_ENTITY and #v.frames == 0 then
			toLoad.objects[k] = nil
		end
	end

	for k, v in pairs(toLoad.objects) do
		if not v.posetype or v.posetype == HAT_SELECT_ENTITY then
			local ent = duplicator.CreateEntityFromTable(player.GetByID(1), v.ent)
			v.ent = ent
			v.cur = 1
			tempTrans[k] = ent
			HAT.entityTrans[v.ent] = HAT.entityTrans[v.ent] or {}
			HAT.entityTrans[v.ent][v.posetype or 1] = k
		end
	end

	for k, v in pairs(toLoad.objects) do
		-- A face/hand record with no matching body (HAT_SELECT_ENTITY) record above to resolve
		-- tempTrans[v.ent] is an orphan (e.g. an older save from before HAT.removeObject removed
		-- every pose-type slot together) - drop it instead of crashing on the nil entity index.
		if v.posetype and v.posetype ~= HAT_SELECT_ENTITY and tempTrans[v.ent] then
			v.ent = tempTrans[v.ent]
			v.cur = 1
			HAT.entityTrans[v.ent] = HAT.entityTrans[v.ent] or {}
			HAT.entityTrans[v.ent][v.posetype] = k
		elseif v.posetype and v.posetype ~= HAT_SELECT_ENTITY then
			toLoad.objects[k] = nil
		end
	end

	HAT.currentObjId = toLoad.currentObjId
	HAT.objects = toLoad.objects
	HAT.loop = toLoad.loop or false

	-- Legacy-save handling: saves from before physbone freeze state was tracked have no
	-- `physbones` table on any frame. Treat "no physbones data anywhere in the file" as "every
	-- physbone was frozen on every frame" (this addon's original behavior), rather than leaving
	-- bones unfrozen and having ragdolls go limp/flop on load.
	local anyPhysbones = false
	for _, v in pairs(HAT.objects) do
		if not v.posetype or v.posetype == HAT_SELECT_ENTITY then
			for _, frame in ipairs(v.frames) do
				if frame.physbones then
					anyPhysbones = true
					break
				end
			end
		end
		if anyPhysbones then break end
	end

	if not anyPhysbones then
		for _, v in pairs(HAT.objects) do
			if (not v.posetype or v.posetype == HAT_SELECT_ENTITY) and IsValid(v.ent) then
				for _, frame in ipairs(v.frames) do
					local bones = HAT.getPhysBones(v.ent)
					if bones then
						for _, bone in pairs(bones) do
							bone.frozen = false
						end
						frame.physbones = bones
					end
				end
			end
		end
	end

	local toSend = { currentObjId = HAT.currentObjId, objects = {}, loop = HAT.loop }
	for k, v in pairs(HAT.objects) do
		-- Desc: v.order (set on load from a save's stored row order) has to be forwarded here too -
		-- DFrameHolder:Load is the only place that reads it, and it only ever runs against this
		-- broadcast's payload, never the raw file.
		toSend.objects[k] = { frames = {}, ent = v.ent:EntIndex(), posetype = v.posetype, order = v.order }
		for _, v in ipairs(v.frames) do
			table.insert(toSend.objects[k].frames, { l = v.length, easing = v.easing, easingStrength = v.easingStrength })
		end
	end

	net.Start("hat_send_data")
	net.WriteTable(toSend)
	net.Broadcast()

	HAT.selectFrame(HAT.currentObjId, 1)
end)

-- Desc: clears the current session (all pose objects/entities), starting a blank project.
concommand.Add("hat_new", function(pl, cmd, args)
	HAT.stop()
	game.CleanUpMap()

	HAT.playOn = false
	HAT.playStart = 0
	HAT.playLastFrame = 0 -- to calculate delta time

	HAT.entityTrans = {}
	HAT.objects = {}
	HAT.currentObjId = nil
	HAT.loop = false

	net.Start("hat_send_data")
	net.WriteTable({ objects = {}, loop = HAT.loop })
	net.Broadcast()
end)

-- Desc: On/Off buttons drawn above a selected toggleable entity (gmod_emitter, gmod_thruster -
-- see HAT_TOGGLEABLE_ON_OFF in hat_init.lua and DHATMenu:Paint) toggle the live entity directly;
-- this is not itself an animation edit - the on/off state only enters the timeline via a snapshot
-- (HAT.snapShotFrame), same as physbones/flexes/hands.
concommand.Add("hat_entity_seton", function(pl, cmd, args)
	if not HAT.isWholeNumber(args[1]) then return end

	local ent = ents.GetByIndex(tonumber(args[1]))
	if not HAT.isToggleableEntity(ent) then return end

	HAT.setEntityOn(ent, args[2] == "1")
end)

concommand.Add("hat_debugprint", function()
	PrintTable(HAT.objects)
end)
