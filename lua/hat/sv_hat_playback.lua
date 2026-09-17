-- Frame-to-frame interpolation and the Think hook that drives playback. Split out of hat.lua.

HAT = HAT or {}

HAT.playOn = false
HAT.playStart = 0
HAT.playLastFrame = 0 -- to calculate delta time
HAT.playObject = 0

-- Desc: lerps obj's pose between frame-1 and frame by delta (0-1) and applies it.
function HAT.applyPose( obj, frame, delta )

	local frameFrom = obj.frames[frame - 1]
	local frameTo = obj.frames[frame]

	if not frameFrom and frameTo then frameFrom = frameTo end
	if not frameFrom or not frameTo then return end

	local physbonesFrom = frameFrom.physbones
	local physbonesTo = frameTo.physbones

	if physbonesFrom and physbonesTo then
		for i,from in pairs( physbonesFrom ) do
			to = physbonesTo[i]

			local physobj = gQuery(obj.ent:GetPhysicsObjectNum( i - 1 ))
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

			if ( HAT.IsUselessFaceFlex(Name )  ) then

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

-- Desc: jumps every object's pose to timeline time t (seconds), independent of playOn state.
function HAT.seek( t )

	t = math.max( t, 0 )

	for k,v in pairs(HAT.objects) do

		if not v then break end

		local FrameStart = 0
		local PlayFrame = 1
		local frame = v.frames[PlayFrame]

		while (frame and ( FrameStart + frame.length < t ) ) do
			FrameStart = FrameStart + frame.length
			PlayFrame = PlayFrame + 1
			frame = v.frames[PlayFrame]
		end

		v.FrameStart = FrameStart
		v.PlayFrame = PlayFrame

		if frame and IsValid( v.ent ) then
			local delta = 1
			if not HAT_StopMotion:GetBool() then
				delta = (t - FrameStart) / frame.length
			end
			HAT.applyPose( v, PlayFrame, delta )
		end

	end

	-- Keep the Think hook's localTime lined up with t so playback resumes from here if playOn.
	HAT.playStart = CurTime() * HAT_PlayRate:GetFloat() - t
	HAT.playLastFrame = CurTime() * HAT_PlayRate:GetFloat()

end

-- Desc: restarts playback from frame 1 for every object (loops after all objects finish playing).
function HAT.replay()

	HAT.playOn = true
	HAT.playStart = CurTime() * HAT_PlayRate:GetFloat()
	HAT.playLastFrame = 1
	HAT.playObject = #HAT.objects

	for k,v in pairs(HAT.objects) do

		v.FrameStart = 0
		v.PlayFrame = 1
		v.Playing = true

	end

	net.Start( "hat_play" )
		net.WriteFloat( HAT.playStart )
	net.Broadcast()

end

hook.Add("Think", "HAT_Play", function()
	if not HAT.playOn then return end

	local localTime = CurTime() * HAT_PlayRate:GetFloat() - HAT.playStart
	local deltaTime = CurTime() * HAT_PlayRate:GetFloat() - HAT.playLastFrame
	HAT.playLastFrame = CurTime() * HAT_PlayRate:GetFloat()

	for k,v in pairs(HAT.objects) do

		if not v then break end

		if IsValid( v.ent ) then

			local frame = v.frames[v.PlayFrame]

			-- Play fluidly. Take into account skipped frames.
			while (frame and ( v.FrameStart + frame.length < localTime ) ) do
				v.FrameStart = v.FrameStart + frame.length
				HAT.applyPose( v, v.PlayFrame, 1 )
				v.PlayFrame = v.PlayFrame + 1
				frame = v.frames[v.PlayFrame]
			end

			if frame then
				local delta = 1
				if not HAT_StopMotion:GetBool() then
					delta = (localTime - v.FrameStart) / frame.length
				end
				HAT.applyPose( v, v.PlayFrame, delta )
			elseif v.Playing then
				v.Playing = nil
				HAT.playObject = HAT.playObject - 1
			end

		end

	end

	if HAT.playObject == 0 then
		HAT.replay()
	end

end)
