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

concommand.Add("hat_frame_setlength", function(pl, cmd, args)
	HAT.stop()
	if HAT.currentObjId and HAT.objects[HAT.currentObjId] then
		HAT.setFrameLength(HAT.currentObjId, tonumber(args[1]), tonumber(args[2]))
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

	local tempTrans = {}

	if toLoad.version == 2 then
		for k, v in pairs(toLoad.objects) do
			v.posetype = v.type
			v.type = nil
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
		if v.posetype and v.posetype ~= HAT_SELECT_ENTITY then
			v.ent = tempTrans[v.ent]
			v.cur = 1
			HAT.entityTrans[v.ent] = HAT.entityTrans[v.ent] or {}
			HAT.entityTrans[v.ent][v.posetype] = k
		end
	end

	HAT.currentObjId = toLoad.currentObjId
	HAT.objects = toLoad.objects
	HAT.loop = toLoad.loop or false

	local toSend = { currentObjId = HAT.currentObjId, objects = {}, loop = HAT.loop }
	for k, v in pairs(HAT.objects) do
		toSend.objects[k] = { frames = {}, ent = v.ent:EntIndex() }
		for _, v in ipairs(v.frames) do
			table.insert(toSend.objects[k].frames, v.length)
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

concommand.Add("hat_debugprint", function()
	PrintTable(HAT.objects)
end)
