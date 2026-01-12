local version = {major = 1, minor = 20}
if not (Hyperspace.version and Hyperspace.version.major == version.major and Hyperspace.version.minor >= version.minor) then
	error("Incorrect Hyperspace version detected! The Outer Expansion requires Hyperspace "..version.major.."."..version.minor.."+")
end
mods.og = {}
local time_increment = mods.multiverse.time_increment
local vter = mods.multiverse.vter
function mods.og.get_room_at_location(shipManager, location, includeWalls)
	return Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId):GetSelectedRoom(location.x, location.y, includeWalls)
end
local get_room_at_location = mods.og.get_room_at_location

mods.multiverse.astrometricsSectors.og = {
	civilian = 0,
	neutral = 1,
	hostile = 0,
	hazard = 0
}

local repCombos = mods.multiverse.repCombos
repCombos.rep_comb_og_iron = {
	rep_og_iron = {buffer = 0},
	rep_pirate = {buffer = 2},
	rep_og_dawn = {buffer = 0, invert = true}
}
repCombos.rep_comb_all.rep_og_iron = {buffer = 0}

local pulsar_power = {}
pulsar_power["human_og_raider"] = 2

local crewStatName = {
	[0] = "MAX_HEALTH",
	"STUN_MULTIPLIER",
	"MOVE_SPEED_MULTIPLIER",
	"REPAIR_SPEED_MULTIPLIER",
	"DAMAGE_MULTIPLIER",
	"RANGED_DAMAGE_MULTIPLIER",
	"DOOR_DAMAGE_MULTIPLIER",
	"FIRE_REPAIR_MULTIPLIER",
	"SUFFOCATION_MODIFIER",
	"FIRE_DAMAGE_MULTIPLIER",
	"OXYGEN_CHANGE_SPEED",
	"DAMAGE_TAKEN_MULTIPLIER",
	"CLONE_SPEED_MULTIPLIER",
	"PASSIVE_HEAL_AMOUNT",
	"TRUE_PASSIVE_HEAL_AMOUNT",
	"TRUE_HEAL_AMOUNT",
	"PASSIVE_HEAL_DELAY",
	"ACTIVE_HEAL_AMOUNT",
	"SABOTAGE_SPEED_MULTIPLIER",
	"ALL_DAMAGE_TAKEN_MULTIPLIER",
	"HEAL_SPEED_MULTIPLIER",
	"HEAL_CREW_AMOUNT",
	"DAMAGE_ENEMIES_AMOUNT",
	"BONUS_POWER",
	"POWER_DRAIN",
	"ESSENTIAL",
	"CAN_FIGHT",
	"CAN_REPAIR",
	"CAN_SABOTAGE",
	"CAN_MAN",
	"CAN_TELEPORT",
	"CAN_SUFFOCATE",
	"CONTROLLABLE",
	"CAN_BURN",
	"IS_TELEPATHIC",
	"RESISTS_MIND_CONTROL",
	"IS_ANAEROBIC",
	"CAN_PHASE_THROUGH_DOORS",
	"DETECTS_LIFEFORMS",
	"CLONE_LOSE_SKILLS",
	"POWER_DRAIN_FRIENDLY",
	"DEFAULT_SKILL_LEVEL",
	"POWER_RECHARGE_MULTIPLIER",
	"HACK_DOORS",
	"NO_CLONE",
	"NO_SLOT",
	"NO_AI",
	"VALID_TARGET",
	"CAN_MOVE",
	"TELEPORT_MOVE",
	"TELEPORT_MOVE_OTHER_SHIP",
	"SILENCED",
	"LOW_HEALTH_THRESHOLD",
	"NO_WARNING",

	"CREW_SLOTS", 
	"ACTIVATE_WHEN_READY",
	"STAT_BOOST",
	"DEATH_EFFECT",
	"POWER_EFFECT",
	"POWER_MAX_CHARGES",
	"POWER_CHARGES_PER_JUMP",
	"POWER_COOLDOWN",
	"TRANSFORM_RACE"
}

script.on_internal_event(Defines.InternalEvents.CALCULATE_STAT_POST, function(crewmem, stat, def, amount, value)
	local spaceManager = Hyperspace.App.world.space
	--[[if pulsar_power[crewmem.type] then 
		print(stat.." "..Hyperspace.CrewStat[stat].." "..crewStatName[stat])
	end]]
	if pulsar_power[crewmem.type] and stat == Hyperspace.CrewStat.BONUS_POWER and (spaceManager.pulsarLevel or spaceManager.bStorm) then
		amount = amount + pulsar_power[crewmem.type]
	elseif pulsar_power[crewmem.type] and (stat == Hyperspace.CrewStat.IS_TELEPATHIC) and (spaceManager.bNebula or spaceManager.bStorm or Hyperspace.playerVariables.loc_environment_lightnebula >= 1) then
		value = true
	elseif pulsar_power[crewmem.type] and (stat == Hyperspace.CrewStat.DETECTS_LIFEFORMS or stat == Hyperspace.CrewStat.RESISTS_MIND_CONTROL) and (spaceManager.bNebula or spaceManager.bStorm or Hyperspace.playerVariables.loc_environment_lightnebula >= 1) then
		value = false
	end
	return Defines.Chain.CONTINUE, amount, value
end)

script.on_internal_event(Defines.InternalEvents.HAS_EQUIPMENT, function(shipManager, equipment, value)
	if equipment == "LIST_CREW_POWER" then
		local spaceManager = Hyperspace.App.world.space
		if spaceManager.pulsarLevel then
			for crewmem in vter(Hyperspace.ships.player.vCrewList) do
				if pulsar_power[crewmem.type] and crewmem.iShipId == shipManager.iShipId then
					value = value + 1
				end
			end
			for crewmem in vter(Hyperspace.ships.enemy.vCrewList) do
				if pulsar_power[crewmem.type] and crewmem.iShipId == shipManager.iShipId then
					value = value + 1
				end
			end
		end
	end
	return Defines.Chain.CONTINUE, value
end)

local create_damage_message = mods.multiverse.create_damage_message
local damageMessages = mods.multiverse.damageMessages
local function handle_reduction_armor(ship, projectile, location, damage, immediateDmgMsg)
	if ship:HasAugmentation("OG_REFLECTIVE_PLATING") > 0 then
		--print("REDUCE DAMAGE:"..tostring(damage.iDamage))
		-- Check if incoming damage is greater than the reduction amount
		if damage.iDamage > 0 then
			damage.iDamage = math.max(1, math.floor(damage.iDamage * ship:GetAugmentationValue("OG_REFLECTIVE_PLATING")))
		elseif damage.iDamage < 0 then
			damage.iDamage = math.min(-1, math.ceil(damage.iDamage * ship:GetAugmentationValue("OG_REFLECTIVE_PLATING")))
		end
		if damage.iSystemDamage > 0 then
			damage.iSystemDamage = math.max(1, math.floor(damage.iSystemDamage * ship:GetAugmentationValue("OG_REFLECTIVE_PLATING")))
		elseif damage.iSystemDamage < 0 then
			damage.iSystemDamage = math.min(-1, math.ceil(damage.iSystemDamage * ship:GetAugmentationValue("OG_REFLECTIVE_PLATING")))
		end
		if damage.iPersDamage > 0 then
			damage.iPersDamage = math.max(1, math.floor(damage.iPersDamage * ship:GetAugmentationValue("OG_REFLECTIVE_PLATING")))
		elseif damage.iPersDamage < 0 then
			damage.iPersDamage = math.min(-1, math.ceil(damage.iPersDamage * ship:GetAugmentationValue("OG_REFLECTIVE_PLATING")))
		end
		if damage.iIonDamage > 0 then
			damage.iIonDamage = math.max(1, math.floor(damage.iIonDamage * ship:GetAugmentationValue("OG_REFLECTIVE_PLATING")))
		elseif damage.iIonDamage < 0 then
			damage.iIonDamage = math.min(-1, math.ceil(damage.iIonDamage * ship:GetAugmentationValue("OG_REFLECTIVE_PLATING")))
		end
		damage.fireChance = math.max(1, math.floor(damage.fireChance * ship:GetAugmentationValue("OG_REFLECTIVE_PLATING")))
		damage.breachChance = math.max(1, math.floor(damage.breachChance * ship:GetAugmentationValue("OG_REFLECTIVE_PLATING")))
	end
end
script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(ship, projectile, location, damage, realNewTile, beamHitType)
	if beamHitType == Defines.BeamHit.NEW_ROOM then
		handle_reduction_armor(ship, projectile, location, damage, true)
	end
end)

script.on_internal_event(Defines.InternalEvents.POWER_ON_UPDATE, function(power)
	if power.temporaryPowerActive then
		local crewmem = power.crew
		if crewmem.type == "human_og_dawn" then
			if crewmem.bFighting then
				--power.temporaryPowerDuration.first = power.temporaryPowerDuration.first + time_increment(true)
			elseif crewmem:Repairing() then
				power.temporaryPowerDuration.first = power.temporaryPowerDuration.first + 0.25 * time_increment(true)
			elseif not crewmem:AtGoal() then
				power.temporaryPowerDuration.first = power.temporaryPowerDuration.first + 0.75 * time_increment(true)
			else
				power.temporaryPowerDuration.first = math.min(power.temporaryPowerDuration.second, power.temporaryPowerDuration.first + 1.25 * time_increment(true))
			end
		end
	end
	return Defines.Chain.CONTINUE
end)

local repToShow = {
	{id = "rep_comb_og_iron", name = "Iron Watch Reputation"},
	{id = "rep_og_dawn", name = "New Dawn Reputation", hidden = true},
}

local emptyReq = Hyperspace.ChoiceReq()
script.on_internal_event(Defines.InternalEvents.PRE_CREATE_CHOICEBOX, function(event)
	if event.eventName == "STORAGE_CHECK_STATUS_NOTORIETY" then
		local eventManager = Hyperspace.Event
		for _, rep in ipairs(repToShow) do
			if not rep.hidden or Hyperspace.playerVariables[rep.id] ~= 0 then
				local repVal = Hyperspace.playerVariables[rep.id]
				local s = rep.name.." ["..math.floor(repVal).."]"
				local invalidEvent = eventManager:CreateEvent("OPTION_INVALID", 0, false)
				event:AddChoice(invalidEvent, s, emptyReq, true)
			end
		end
	end
end)

local roomIconImageString = "effects/og_vunerable_icon"
local tileImageString = "effects/og_vunerable_back"
local wallImageString = "effects/og_vunerable"
local roomIconImage =  Hyperspace.Resources:CreateImagePrimitiveString( (roomIconImageString..".png") , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
local tileImage =  Hyperspace.Resources:CreateImagePrimitiveString( (tileImageString..".png") , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
local wallImage =  {
	up = Hyperspace.Resources:CreateImagePrimitiveString( (wallImageString.."_up.png") , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	right = Hyperspace.Resources:CreateImagePrimitiveString( (wallImageString.."_right.png") , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	down = Hyperspace.Resources:CreateImagePrimitiveString( (wallImageString.."_down.png") , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	left = Hyperspace.Resources:CreateImagePrimitiveString( (wallImageString.."_left.png") , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
}

function mods.og.render_vunerable(room)
	--print("render_vunerable:"..room.iRoomId)
	local opacity = 0.5
	local x = room.rect.x
	local y = room.rect.y
	local w = math.floor(room.rect.w/35)
	local h = math.floor(room.rect.h/35)
	local size = w * h
	--print("room:"..room.iRoomId.." gasLevel:"..gasLevel.." w:"..w.." h:"..h.." size:"..size)
	for i = 0, size - 1 do
		local xOff = x + (i%w) * 35
		local yOff = y + math.floor(i/w) * 35
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(xOff, yOff, 0)
		Graphics.CSurface.GL_RenderPrimitiveWithAlpha(tileImage, opacity)
		Graphics.CSurface.GL_PopMatrix()
	end
	opacity = 1
	-- top and bottom edge
	for i = 0, w - 1 do
		local xOff = x + i * 35
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(xOff, y, 0)
		Graphics.CSurface.GL_RenderPrimitiveWithAlpha(wallImage.up, opacity)
		Graphics.CSurface.GL_PopMatrix()

		local yOff = y + (h-1) * 35
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(xOff, yOff, 0)
		Graphics.CSurface.GL_RenderPrimitiveWithAlpha(wallImage.down, opacity)
		Graphics.CSurface.GL_PopMatrix()
	end
	-- left and right edge
	for i = 0, h - 1 do
		local yOff = y + i * 35
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(x, yOff, 0)
		Graphics.CSurface.GL_RenderPrimitiveWithAlpha(wallImage.left, opacity)
		Graphics.CSurface.GL_PopMatrix()

		local xOff = x + (w-1) * 35
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(xOff, yOff, 0)
		Graphics.CSurface.GL_RenderPrimitiveWithAlpha(wallImage.right, opacity)
		Graphics.CSurface.GL_PopMatrix()
	end
	Graphics.CSurface.GL_PushMatrix()
	Graphics.CSurface.GL_Translate(x, y, 0)
	Graphics.CSurface.GL_RenderPrimitive(roomIconImage)
	Graphics.CSurface.GL_PopMatrix()
end
local render_vunerable = mods.og.render_vunerable

mods.og.vunerable_weapons = {}
local vunerable_weapons = mods.og.vunerable_weapons
vunerable_weapons["OG_LASER_PROJECTILE_BASE_DAWN"] = 10
vunerable_weapons["OG_LASER_PROJECTILE_HEAVY_DAWN"] = 10
vunerable_weapons["OG_LASER_PROJECTILE_LIGHT_DAWN"] = 10
vunerable_weapons["OG_ION_PROJECTILE_BASE_DAWN"] = 10
vunerable_weapons["OG_MISSILE_PROJECTILE_HEAVY_DAWN"] = 10
vunerable_weapons["OG_FLAK_PROJECTILE_DAWN"] = 10
vunerable_weapons["OG_FOCUS_PROJECTILE_DAWN"] = 5
vunerable_weapons["OG_FOCUS_PROJECTILE_WEAK_DAWN"] = 5
vunerable_weapons["LOOT_OG_DAWN_1"] = 5

mods.og.vunerable_rooms = {[0] = {}, [1] = {}}
local vunerable_rooms = mods.og.vunerable_rooms
script.on_init(function()
	mods.og.vunerable_rooms = {[0] = {}, [1] = {}}
end)

script.on_internal_event(Defines.InternalEvents.JUMP_LEAVE, function(shipManager)
	mods.og.vunerable_rooms[1] = {}
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	for room in vter(shipManager.ship.vRoomList) do
		if vunerable_rooms[shipManager.iShipId][room.iRoomId] then
			--print("LOOP CORE:"..room.iRoomId)
			vunerable_rooms[shipManager.iShipId][room.iRoomId].time = vunerable_rooms[shipManager.iShipId][room.iRoomId].time - time_increment(true)
			if vunerable_rooms[shipManager.iShipId][room.iRoomId].time <= 0 then
				vunerable_rooms[shipManager.iShipId][room.iRoomId] = nil
			end
		end
	end
end)

script.on_render_event(Defines.RenderEvents.SHIP_FLOOR, function() end, function(ship) 
	local shipManager = Hyperspace.ships(ship.iShipId)
	for room in vter(shipManager.ship.vRoomList) do
		if vunerable_rooms[shipManager.iShipId][room.iRoomId] then
			render_vunerable(room)
		end
	end
end)

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA, function(shipManager, projectile, location, damage, forceHit, shipFriendlyFire)
	local room = get_room_at_location(shipManager, location, true)
	if vunerable_rooms[shipManager.iShipId][room] then
		if damage.iDamage + damage.iSystemDamage > 0 then
			damage.iSystemDamage = damage.iSystemDamage + 1
		end
	end
	return Defines.Chain.CONTINUE, forceHit, shipFriendlyFire
end)



script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(shipManager, projectile, location, damage, realNewTile, beamHitType)
	if beamHitType ~= Defines.BeamHit.NEW_ROOM then return Defines.Chain.CONTINUE, beamHitType end
	local room = get_room_at_location(shipManager, location, true)
	if vunerable_rooms[shipManager.iShipId][room] then
		if damage.iDamage + damage.iSystemDamage > 0 then
			damage.iSystemDamage = damage.iSystemDamage + 1
			vunerable_rooms[shipManager.iShipId][room].triggers = vunerable_rooms[shipManager.iShipId][room].triggers + 1
		end
	end
	if projectile and projectile.extend.name and vunerable_weapons[projectile.extend.name] then
		if vunerable_rooms[shipManager.iShipId][room] then
			vunerable_rooms[shipManager.iShipId][room].time = math.max(vunerable_rooms[shipManager.iShipId][room].time, vunerable_weapons[projectile.extend.name])
		else
			vunerable_rooms[shipManager.iShipId][room] = {time = vunerable_weapons[projectile.extend.name], triggers = 0}
		end
	end
	return Defines.Chain.CONTINUE, beamHitType
end)

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
	local room = get_room_at_location(shipManager, location, true)
	--if projectile and projectile.extend.name then print("attempt:"..projectile.extend.name) end
	if projectile and projectile.extend.name and vunerable_weapons[projectile.extend.name] then
		if vunerable_rooms[shipManager.iShipId][room] then
			vunerable_rooms[shipManager.iShipId][room].time = math.max(vunerable_rooms[shipManager.iShipId][room].time, vunerable_weapons[projectile.extend.name])
		else
			vunerable_rooms[shipManager.iShipId][room] = {time = vunerable_weapons[projectile.extend.name], triggers = 0}
		end
		--print("set:"..room.." t:"..tostring(vunerable_rooms[shipManager.iShipId][room]))
	end
	if vunerable_rooms[shipManager.iShipId][room] then
		if damage.iDamage + damage.iSystemDamage > 0 then
			vunerable_rooms[shipManager.iShipId][room].triggers = vunerable_rooms[shipManager.iShipId][room].triggers + 1
		end
	end
	return Defines.Chain.CONTINUE
end)