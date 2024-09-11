
hat_hands = {}


local VarsOnHand = 5 * 3
local FingerVars = VarsOnHand * 2


--[[------------------------------------------------------------
	Name: HasTF2Hands
	Desc: Returns true if it has TF2 hands
--------------------------------------------------------------]] 
local function HasTF2Hands( pEntity )
	return pEntity:LookupBone( "bip_hand_L" ) != nil
end

--[[------------------------------------------------------------
	Name: HasZenoHands
	Desc: Returns true if it has Zeno Clash hands
--------------------------------------------------------------]] 
local function HasZenoHands( pEntity )
	return pEntity:LookupBone( "Bip01_L_Hand" ) != nil
end

local TranslateTable_TF2 = {}
	TranslateTable_TF2[ "ValveBiped.Bip01_L_Finger0" ] = "bip_thumb_0_L"
	TranslateTable_TF2[ "ValveBiped.Bip01_L_Finger01" ] = "bip_thumb_1_L"
	TranslateTable_TF2[ "ValveBiped.Bip01_L_Finger02" ] = "bip_thumb_2_L"
	TranslateTable_TF2[ "ValveBiped.Bip01_L_Finger1" ] = "bip_index_0_L"
	TranslateTable_TF2[ "ValveBiped.Bip01_L_Finger11" ] = "bip_index_1_L"
	TranslateTable_TF2[ "ValveBiped.Bip01_L_Finger12" ] = "bip_index_2_L"
	TranslateTable_TF2[ "ValveBiped.Bip01_L_Finger2" ] = "bip_middle_0_L"
	TranslateTable_TF2[ "ValveBiped.Bip01_L_Finger21" ] = "bip_middle_1_L"
	TranslateTable_TF2[ "ValveBiped.Bip01_L_Finger22" ] = "bip_middle_2_L"
	TranslateTable_TF2[ "ValveBiped.Bip01_L_Finger3" ] = "bip_ring_0_L"
	TranslateTable_TF2[ "ValveBiped.Bip01_L_Finger31" ] = "bip_ring_1_L"
	TranslateTable_TF2[ "ValveBiped.Bip01_L_Finger32" ] = "bip_ring_2_L"
	TranslateTable_TF2[ "ValveBiped.Bip01_L_Finger4" ] = "bip_pinky_0_L"
	TranslateTable_TF2[ "ValveBiped.Bip01_L_Finger41" ] = "bip_pinky_1_L"
	TranslateTable_TF2[ "ValveBiped.Bip01_L_Finger42" ] = "bip_pinky_2_L"
	TranslateTable_TF2[ "ValveBiped.Bip01_R_Finger0" ] = "bip_thumb_0_R"
	TranslateTable_TF2[ "ValveBiped.Bip01_R_Finger01" ] = "bip_thumb_1_R"
	TranslateTable_TF2[ "ValveBiped.Bip01_R_Finger02" ] = "bip_thumb_2_R"
	TranslateTable_TF2[ "ValveBiped.Bip01_R_Finger1" ] = "bip_index_0_R"
	TranslateTable_TF2[ "ValveBiped.Bip01_R_Finger11" ] = "bip_index_1_R"
	TranslateTable_TF2[ "ValveBiped.Bip01_R_Finger12" ] = "bip_index_2_R"
	TranslateTable_TF2[ "ValveBiped.Bip01_R_Finger2" ] = "bip_middle_0_R"
	TranslateTable_TF2[ "ValveBiped.Bip01_R_Finger21" ] = "bip_middle_1_R"
	TranslateTable_TF2[ "ValveBiped.Bip01_R_Finger22" ] = "bip_middle_2_R"
	TranslateTable_TF2[ "ValveBiped.Bip01_R_Finger3" ] = "bip_ring_0_R"
	TranslateTable_TF2[ "ValveBiped.Bip01_R_Finger31" ] = "bip_ring_1_R"
	TranslateTable_TF2[ "ValveBiped.Bip01_R_Finger32" ] = "bip_ring_2_R"
	TranslateTable_TF2[ "ValveBiped.Bip01_R_Finger4" ] = "bip_pinky_0_R"
	TranslateTable_TF2[ "ValveBiped.Bip01_R_Finger41" ] = "bip_pinky_1_R"
	TranslateTable_TF2[ "ValveBiped.Bip01_R_Finger42" ] = "bip_pinky_2_R"
	
local TranslateTable_Zeno = {}
	TranslateTable_Zeno[ "ValveBiped.Bip01_L_Finger0" ] = "Bip01_L_Finger0"
	TranslateTable_Zeno[ "ValveBiped.Bip01_L_Finger01" ] = "Bip01_L_Finger01"
	TranslateTable_Zeno[ "ValveBiped.Bip01_L_Finger02" ] = "Bip01_L_Finger02"
	TranslateTable_Zeno[ "ValveBiped.Bip01_L_Finger1" ] = "Bip01_L_Finger1"
	TranslateTable_Zeno[ "ValveBiped.Bip01_L_Finger11" ] = "Bip01_L_Finger11"
	TranslateTable_Zeno[ "ValveBiped.Bip01_L_Finger12" ] = "Bip01_L_Finger12"
	TranslateTable_Zeno[ "ValveBiped.Bip01_L_Finger2" ] = "Bip01_L_Finger2"
	TranslateTable_Zeno[ "ValveBiped.Bip01_L_Finger21" ] = "Bip01_L_Finger21"
	TranslateTable_Zeno[ "ValveBiped.Bip01_L_Finger22" ] = "Bip01_L_Finger22"
	TranslateTable_Zeno[ "ValveBiped.Bip01_L_Finger3" ] = "Bip01_L_Finger3"
	TranslateTable_Zeno[ "ValveBiped.Bip01_L_Finger31" ] = "Bip01_L_Finger31"
	TranslateTable_Zeno[ "ValveBiped.Bip01_L_Finger32" ] = "Bip01_L_Finger32"
	TranslateTable_Zeno[ "ValveBiped.Bip01_L_Finger4" ] = "Bip01_L_Finger4"
	TranslateTable_Zeno[ "ValveBiped.Bip01_L_Finger41" ] = "Bip01_L_Finger41"
	TranslateTable_Zeno[ "ValveBiped.Bip01_L_Finger42" ] = "Bip01_L_Finger42"
	TranslateTable_Zeno[ "ValveBiped.Bip01_R_Finger0" ] = "Bip01_R_Finger0"
	TranslateTable_Zeno[ "ValveBiped.Bip01_R_Finger01" ] = "Bip01_R_Finger01"
	TranslateTable_Zeno[ "ValveBiped.Bip01_R_Finger02" ] = "Bip01_R_Finger02"
	TranslateTable_Zeno[ "ValveBiped.Bip01_R_Finger1" ] = "Bip01_R_Finger1"
	TranslateTable_Zeno[ "ValveBiped.Bip01_R_Finger11" ] = "Bip01_R_Finger11"
	TranslateTable_Zeno[ "ValveBiped.Bip01_R_Finger12" ] = "Bip01_R_Finger12"
	TranslateTable_Zeno[ "ValveBiped.Bip01_R_Finger2" ] = "Bip01_R_Finger2"
	TranslateTable_Zeno[ "ValveBiped.Bip01_R_Finger21" ] = "Bip01_R_Finger21"
	TranslateTable_Zeno[ "ValveBiped.Bip01_R_Finger22" ] = "Bip01_R_Finger22"
	TranslateTable_Zeno[ "ValveBiped.Bip01_R_Finger3" ] = "Bip01_R_Finger3"
	TranslateTable_Zeno[ "ValveBiped.Bip01_R_Finger31" ] = "Bip01_R_Finger31"
	TranslateTable_Zeno[ "ValveBiped.Bip01_R_Finger32" ] = "Bip01_R_Finger32"
	TranslateTable_Zeno[ "ValveBiped.Bip01_R_Finger4" ] = "Bip01_R_Finger4"
	TranslateTable_Zeno[ "ValveBiped.Bip01_R_Finger41" ] = "Bip01_R_Finger41"
	TranslateTable_Zeno[ "ValveBiped.Bip01_R_Finger42" ] = "Bip01_R_Finger42"

--[[------------------------------------------------------------
	Name: GetFingerBone
	Desc: Translate the fingernum, part and hand into an real bone number
--------------------------------------------------------------]] 
local function GetFingerBone( self, fingernum, part, hand )

	---- START HL2 BONE LOOKUP ----------------------------------
	local Name = "ValveBiped.Bip01_L_Finger"..fingernum
	if ( hand == 1 ) then Name = "ValveBiped.Bip01_R_Finger"..fingernum end
	if ( part != 0 ) then Name = Name .. part end

	local bone = self:LookupBone( Name )
	if ( bone ) then return bone end
	---- END HL2 BONE LOOKUP ----------------------------------
	
	
	---- START TF BONE LOOKUP ----------------------------------
	local TranslatedName = TranslateTable_TF2[ Name ]
	if ( TranslatedName ) then 
		local bone = self:LookupBone( TranslatedName )
		if ( bone ) then return bone end
	end
	---- END TF BONE LOOKUP ----------------------------------
	
	---- START Zeno BONE LOOKUP ----------------------------------
	local TranslatedName = TranslateTable_Zeno[ Name ]
	if ( TranslatedName ) then 
		local bone = self:LookupBone( TranslatedName )
		if ( bone ) then return bone end
	end
	---- END Zeno BONE LOOKUP ----------------------------------

end

--[[------------------------------------------------------------
	Name: SetupFingers
	Desc: Cache the finger bone numbers for faster access
--------------------------------------------------------------]] 
local function SetupFingers( self )

	if ( self.FingerIndex ) then return end
		
	self.FingerIndex = {}

	local i = 1
	
	for hand = 0, 1 do
		for finger = 0, 4 do
			for part = 0, 2 do
				
				self.FingerIndex[ i ] = GetFingerBone( self, finger, part, hand )
				
				i = i + 1
			
			end
		end
	end

end

function hat_hands.getHand( entity, hand )

	SetupFingers( entity )

	local handData = {}

	for i=0, VarsOnHand-1 do
	
		local bone = entity.FingerIndex[ i + hand*VarsOnHand + 1 ] 
		if ( bone ) then
			local Var = player.GetByID(1):GetInfo( "finger_"..i )
			local VecComp = string.Explode( " ", Var )

			local Ang = nil;

			if ( bTF2 ) then
					
				if ( i < 3 ) then
					Ang = Angle( 0, tonumber(VecComp[2]), tonumber(VecComp[1]) )
				else
					Ang = Angle( 0, tonumber(VecComp[1]), -tonumber(VecComp[2]) )
				end

			else
				if ( i < 3 ) then
					Ang = Angle( tonumber(VecComp[2]), tonumber(VecComp[1]), 0 )		
				else
					Ang = Angle( tonumber(VecComp[1]), tonumber(VecComp[2]), 0 )
				end
			end

			handData[i] = Ang
		end
	end

	return handData
end

function hat_hands.setHand( entity, handData, hand )

	SetupFingers( entity )

	for i=0, VarsOnHand-1 do
	
		local Ang = nil

		local bone = entity.FingerIndex[ i + hand*VarsOnHand + 1 ] 
		if ( bone ) then
			entity:ManipulateBoneAngles( bone, handData[i] )
		end
		
	end

end

function hat_hands.lerpHand( delta, entity, handDataFrom, handDataTo, hand )

	SetupFingers( entity )

	for i=0, VarsOnHand-1 do
	
		local Ang = nil

		local bone = entity.FingerIndex[ i + hand*VarsOnHand + 1 ] 
		if ( bone ) then
			entity:ManipulateBoneAngles( bone, LerpAngle( delta, handDataFrom[i], handDataTo[i] ) )
		end
		
	end

end
