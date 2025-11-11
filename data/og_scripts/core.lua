local version = {major = 1, minor = 20}
if not (Hyperspace.version and Hyperspace.version.major == version.major and Hyperspace.version.minor >= version.minor) then
	error("Incorrect Hyperspace version detected! The Outer Expansion requires Hyperspace "..version.major.."."..version.minor.."+")
end
mods.og = {}
local time_increment = mods.multiverse.time_increment

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

script.on_internal_event(Defines.InternalEvents.CALCULATE_STAT_POST, function(crewmem, stat, def, amount, value)
	local spaceManager = Hyperspace.App.world.space
	if pulsar_power[crewmem] and stat == Hyperspace.CrewStat.BONUS_POWER and (spaceManager.pulsarLevel or spaceManager.bStorm) then
		amount = amount + pulsar_power[crewmem]
	elseif pulsar_power[crewmem] and stat == Hyperspace.CrewStat.IS_TELEPATHIC and spaceManager.bNebula or spaceManager.bStorm then
		value = true
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
			damage.iDamage = math.floor(damage.iDamage * ship:GetAugmentationValue("OG_REFLECTIVE_PLATING"))
			if damage.iDamage == 0 then
				create_damage_message(ship.iShipId, damageMessages.NEGATED, location.x, location.y)
			end
		elseif damage.iDamage < 0 then
			damage.iDamage = math.ceil(damage.iDamage * ship:GetAugmentationValue("OG_REFLECTIVE_PLATING"))
		end
		if damage.iSystemDamage >= 0 then
			damage.iSystemDamage = math.floor(damage.iSystemDamage * ship:GetAugmentationValue("OG_REFLECTIVE_PLATING"))
		else
			damage.iSystemDamage = math.ceil(damage.iSystemDamage * ship:GetAugmentationValue("OG_REFLECTIVE_PLATING"))
		end
		if damage.iPersDamage >= 0 then
			damage.iPersDamage = math.floor(damage.iPersDamage * ship:GetAugmentationValue("OG_REFLECTIVE_PLATING"))
		else
			damage.iPersDamage = math.ceil(damage.iPersDamage * ship:GetAugmentationValue("OG_REFLECTIVE_PLATING"))
		end
		if damage.iIonDamage >= 0 then
			damage.iIonDamage = math.floor(damage.iIonDamage * ship:GetAugmentationValue("OG_REFLECTIVE_PLATING"))
		else
			damage.iIonDamage = math.ceil(damage.iIonDamage * ship:GetAugmentationValue("OG_REFLECTIVE_PLATING"))
		end
		damage.fireChance = math.floor(damage.fireChance * ship:GetAugmentationValue("OG_REFLECTIVE_PLATING"))
		damage.breachChance = math.floor(damage.breachChance * ship:GetAugmentationValue("OG_REFLECTIVE_PLATING"))
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
				power.temporaryPowerDuration.first = math.min(power.temporaryPowerDuration.first, power.temporaryPowerDuration.first + 1.25 * time_increment(true))
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