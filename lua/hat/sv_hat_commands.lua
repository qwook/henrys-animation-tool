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
		net.WriteString("Select something to animate first.")
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
	HAT.snapShotFrame(HAT.currentObjId)
end)

-- Desc: starts synchronized playback of every pose object from its current frame's timestamp.
concommand.Add("hat_play", function(pl, cmd, args)
	local offset = 0

	local obj = HAT.objects[HAT.currentObjId]

	if obj then
		offset = HAT.getTimeFromFrame(HAT.currentObjId, obj.cur)
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

	net.Start("hat_play")
	net.WriteFloat(HAT.playStart)
	net.Broadcast()
end)

concommand.Add("hat_stop", function(pl, cmd, args)
	HAT.stop()
end)

-- Desc: serializes every pose object to a .hat.txt file under data/hat/.
concommand.Add("hat_save", function(pl, cmd, args)
	HAT.stop()

	local fileName = tostring(args[1] or "untitled")

	if fileName:sub(-4, -1):lower() ~= ".hat" then
		fileName = fileName .. ".hat"
	end

	local toSave = { objects = table.Copy(HAT.objects), currentObjId = HAT.currentObjId, version = HAT_VERSION }

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

	local toSend = { currentObjId = HAT.currentObjId, objects = {} }
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

	net.Start("hat_send_data")
	net.WriteTable({ objects = {} })
	net.Broadcast()
end)

concommand.Add("hat_debugprint", function()
	PrintTable(HAT.objects)
end)
