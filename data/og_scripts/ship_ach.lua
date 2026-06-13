----------------------
-- HELPER FUNCTIONS --
----------------------

local function vter(cvec)
	local i = -1
	local n = cvec:size()
	return function()
		i = i + 1
		if i < n then return cvec[i] end
	end
end
--local is_first_shot = mods.vertexutil.is_first_shot
local function userdata_table(userdata, tableName)
	if not userdata.table[tableName] then userdata.table[tableName] = {} end
	return userdata.table[tableName]
end

local function string_starts(str, start)
	return string.sub(str, 1, string.len(start)) == start
end

local function should_track_achievement(achievement, ship, shipClassName)
	return ship and
		   Hyperspace.App.world.bStartedGame and
		   Hyperspace.CustomAchievementTracker.instance:GetAchievementStatus(achievement) < Hyperspace.Settings.difficulty and
		   string_starts(ship.myBlueprint.blueprintName, shipClassName)
end

local function current_sector()
	return Hyperspace.App.world.starMap.worldLevel + 1
end

local function count_ship_achievements(achPrefix)
	local count = 0
	for i = 1, 3 do
		if Hyperspace.CustomAchievementTracker.instance:GetAchievementStatus(achPrefix.."_"..tostring(i)) > -1 then
			count = count + 1
		end
	end
	return count
end

-------------

local function ach_check_loop()
end

script.on_internal_event(Defines.InternalEvents.JUMP_LEAVE, ach_check_loop)


local function ach_check_raider_1()
	if should_track_achievement("SHIP_ACH_OG_RAIDER_1", Hyperspace.ships.player, "PLAYER_SHIP_OG_RAIDER") then
		Hyperspace.CustomAchievementTracker.instance:SetAchievement("SHIP_ACH_OG_RAIDER_1", false)
	end
end
script.on_game_event("OG_CRAFT_FINISH_ITEM", false, ach_check_raider_1)

local dawnShips = {}
for ship in vter(Hyperspace.Blueprints:GetBlueprintList("LIST_SHIPS_OG_DAWN_ALL")) do
	dawnShips[ship] = true
end
local function ach_check_raider_2()
	--local benchmark_start = os.clock()
	if Hyperspace.ships.enemy and dawnShips[Hyperspace.ships.enemy.myBlueprint.blueprintName] then
		local beenKilled = Hyperspace.ships.enemy.ship.hullIntegrity.first <= 0 and Hyperspace.ships.enemy._targetable.hostile
		if beenKilled and should_track_achievement("SHIP_ACH_OG_RAIDER_2", Hyperspace.ships.player, "PLAYER_SHIP_OG_RAIDER") then
			Hyperspace.CustomAchievementTracker.instance:SetAchievement("SHIP_ACH_OG_RAIDER_2", false)
		end
	end
	--local benchmark_end = os.clock()
	--print(string.format("ship_ach.lua ON_TICK 1: time: %.6f seconds", benchmark_end - benchmark_start))
end
script.on_internal_event(Defines.InternalEvents.ON_TICK, ach_check_raider_2)

local function check_no_shields_or_weapons_ach(ship)
 	local noWeapons = (not ship:HasSystem(3)) or (ship:GetSystem(3):GetMaxPower() <= ship.myBlueprint.systemInfo[3].powerLevel)
 	local noDrones = (not ship:HasSystem(4)) or (ship:GetSystem(4):GetMaxPower() <= ship.myBlueprint.systemInfo[4].powerLevel)
	return ship.iShipId == 0 and
		current_sector() >= 8 and
		noWeapons and
		noDrones and
		should_track_achievement("SHIP_ACH_OG_RAIDER_3", ship, "PLAYER_SHIP_OG_RAIDER")
end
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
	--local benchmark_start = os.clock()
	if check_no_shields_or_weapons_ach(ship) then
		Hyperspace.CustomAchievementTracker.instance:SetAchievement("SHIP_ACH_OG_RAIDER_3", false)
	end
	--local benchmark_end = os.clock()
	--print(string.format("ship_ach.lua SHIP_LOOP 1: time: %.6f seconds", benchmark_end - benchmark_start))
end)

local in_combat = false
local has_damage = false
local combat_check_events = {}
combat_check_events["COMBAT_CHECK"] = true
combat_check_events["COMBAT_CHECK_FAIL"] = true
script.on_internal_event(Defines.InternalEvents.PRE_CREATE_CHOICEBOX, function(event)
	local ship = Hyperspace.ships.player
	if combat_check_events[event.eventName] and should_track_achievement("SHIP_ACH_OG_EXECUTOR_2", ship, "PLAYER_SHIP_OG_EXECUTOR") and (not ship:HasSystem(0)) and (not ship:HasSystem(10)) then
		in_combat = true
		has_damage = false
	end
end)
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	--local benchmark_start = os.clock()
	if shipManager.iShipId == 1 or not in_combat then return end
	if (not Hyperspace.ships.enemy) or (not Hyperspace.ships.enemy._targetable.hostile) then
		in_combat = false
		if not has_damage then
			Hyperspace.CustomAchievementTracker.instance:SetAchievement("SHIP_ACH_OG_EXECUTOR_2", false)
		end
	end
	--local benchmark_end = os.clock()
	--print(string.format("ship_ach.lua SHIP_LOOP 2: time: %.6f seconds", benchmark_end - benchmark_start))
end)
script.on_internal_event(Defines.InternalEvents.JUMP_LEAVE, function(shipManager)
	if shipManager.iShipId == 0 and in_combat then
		in_combat = false
	end
end)
script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(shipManager, projectile, location, damage, realNewTile, beamHitType)
	if beamHitType ~= Defines.BeamHit.NEW_ROOM then return Defines.Chain.CONTINUE, beamHitType end
	if shipManager.iShipId == 0 and in_combat and damage.iDamage > 0 then
		has_damage = true
	end
	return Defines.Chain.CONTINUE, beamHitType
end)
script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
	if shipManager.iShipId == 0 and in_combat and damage.iDamage > 0 then
		has_damage = true
	end
	return Defines.Chain.CONTINUE
end)

local allowedSystems = {}
allowedSystems[Hyperspace.ShipSystem.NameToSystemId("og_turret")] = true
allowedSystems[Hyperspace.ShipSystem.NameToSystemId("og_turret_2")] = true
allowedSystems[Hyperspace.ShipSystem.NameToSystemId("og_turret_3")] = true
allowedSystems[Hyperspace.ShipSystem.NameToSystemId("og_turret_4")] = true
allowedSystems[Hyperspace.ShipSystem.NameToSystemId("og_turret_mini")] = true
allowedSystems[Hyperspace.ShipSystem.NameToSystemId("og_turret_mini_2")] = true
allowedSystems[Hyperspace.ShipSystem.NameToSystemId("og_turret_mini_3")] = true
allowedSystems[Hyperspace.ShipSystem.NameToSystemId("og_turret_mini_4")] = true
allowedSystems[0] = true
allowedSystems[1] = true
allowedSystems[2] = true
allowedSystems[10] = true
allowedSystems[5] = true
allowedSystems[13] = true
local function check_no_systems_ach(ship)
	if ship.iShipId == 1 or current_sector() < 8 then return false end
	local allowed = true
	for system in vter(ship.vSystemList) do
		if not (allowedSystems[system.iSystemType] or Hyperspace.ShipSystem.IsSubsystem(system.iSystemType)) then
			allowed = false
		end
	end
	return allowed and should_track_achievement("SHIP_ACH_OG_EXECUTOR_3", ship, "PLAYER_SHIP_OG_EXECUTOR")
end
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
	if check_no_systems_ach(ship) then
		Hyperspace.CustomAchievementTracker.instance:SetAchievement("SHIP_ACH_OG_EXECUTOR_3", false)
	end
end)

mods.og.defended_ach = 0
local function ach_check_dawn_spear_1()
	if should_track_achievement("SHIP_ACH_OG_DAWN_SPEAR_1", Hyperspace.ships.player, "PLAYER_SHIP_OG_DAWN_SPEAR") and mods.og.defended_ach >= 5 then
		Hyperspace.CustomAchievementTracker.instance:SetAchievement("SHIP_ACH_OG_DAWN_SPEAR_1", false)
	end
end

script.on_internal_event(Defines.InternalEvents.JUMP_LEAVE, function(shipManager)
	if shipManager.iShipId == 0 then
		ach_check_dawn_spear_1()
		mods.og.defended_ach = 0
	end
end)

local turrets = mods.og.turrets
local turretBlueprintsList = mods.og.turretBlueprintsList 
local function check_turret_projectile(projectile)
	--print("check:"..projectile.extend.name)
	local name = projectile.extend.name
	for _, id in ipairs(turretBlueprintsList) do
		local turret = turrets[id]
		--print("check:"..id.." blue:"..turret.blueprint)
		if turret.blueprint == name then
			--print("check return true")
			return true
		end
	end
	return false
end
script.on_internal_event(Defines.InternalEvents.PROJECTILE_COLLISION, function(projectile1, projectile2, damage, response)
	if not should_track_achievement("SHIP_ACH_OG_DAWN_SPEAR_1", Hyperspace.ships.player, "PLAYER_SHIP_OG_DAWN_SPEAR") then return Defines.Chain.CONTINUE end
	local turret_collision = false
	if projectile1 and projectile1.extend.name and projectile1.ownerId == 0 then
		turret_collision = turret_collision or check_turret_projectile(projectile1)
	end
	if projectile2 and projectile2.extend.name and projectile2.ownerId == 0 then
		turret_collision = turret_collision or check_turret_projectile(projectile2)
	end
	if turret_collision then
		mods.og.defended_ach = mods.og.defended_ach + 1
	end
	ach_check_dawn_spear_1()
	return Defines.Chain.CONTINUE
end)

local humanList = {}
for item in vter(Hyperspace.Blueprints:GetBlueprintList("LIST_CREW_HUMAN")) do
	humanList[item] = true
end
local function ach_spear_2_invalid_crew(crewmem)
	return crewmem.iShipId == 0 and not humanList[crewmem.type] and not (crewmem:IsDrone() or crewmem.bOutOfGame)
end
script.on_internal_event(Defines.InternalEvents.JUMP_LEAVE, function(shipManager)
	if shipManager.iShipId == 0 then
		for crewmem in vter(shipManager.vCrewList) do
			if ach_spear_2_invalid_crew(crewmem) then
				Hyperspace.playerVariables.og_ach_track_humans_only = 1
			end
		end
	end
end)
script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function(shipManager)
	if should_track_achievement("SHIP_ACH_OG_DAWN_SPEAR_2", Hyperspace.ships.player, "PLAYER_SHIP_OG_DAWN_SPEAR") and current_sector() >= 8 and Hyperspace.playerVariables.og_ach_track_humans_only == 0 then
		Hyperspace.CustomAchievementTracker.instance:SetAchievement("SHIP_ACH_OG_DAWN_SPEAR_2", false)
	end
end)
local achTexts = {
	valid = Hyperspace.Text:GetText("og_lua_turret_ach_valid"),
	crew = Hyperspace.Text:GetText("og_lua_turret_ach_crew"),
	invalid = Hyperspace.Text:GetText("og_lua_turret_ach_invalid"),
}
script.on_render_event(Defines.RenderEvents.MOUSE_CONTROL, function()
	if should_track_achievement("SHIP_ACH_OG_DAWN_SPEAR_2", Hyperspace.ships.player, "PLAYER_SHIP_OG_DAWN_SPEAR") then
		local jump_string = string.sub(Hyperspace.Text:GetText("jump_button"), 1, 20)
		--print("jump_string:"..jump_string)
		--print("mouse:"..Hyperspace.Mouse.tooltip)
		--print("mouse_start:"..string.sub(Hyperspace.Mouse.tooltip, 1, string.len(jump_string)))
		if string_starts(Hyperspace.Mouse.tooltip, jump_string) then
			Hyperspace.Mouse.bForceTooltip = true
			local validRun = true
			local invalidCrew = {}
			for crewmem in vter(Hyperspace.ships.player.vCrewList) do
				if ach_spear_2_invalid_crew(crewmem) then
					validRun = false
					table.insert(invalidCrew, crewmem:GetLongName())
				end
			end
			if Hyperspace.playerVariables.og_ach_track_humans_only == 0 and validRun then
				Hyperspace.Mouse.tooltip = Hyperspace.Mouse.tooltip..achTexts.valid
			elseif Hyperspace.playerVariables.og_ach_track_humans_only == 0 then
				local appendCrewString = ""
				for _, s in ipairs(invalidCrew) do
					appendCrewString = appendCrewString..", "..s
				end
				appendCrewString = string.sub(appendCrewString, 2)
				Hyperspace.Mouse.tooltip = Hyperspace.Mouse.tooltip..achTexts.crew..appendCrewString
			else
				Hyperspace.Mouse.tooltip = Hyperspace.Mouse.tooltip..achTexts.invalid
			end
		end
	end
end, function() end)

local vunerable_rooms = mods.og.vunerable_rooms
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	--print("shipManager:"..shipManager.iShipId.." should"..tostring(should_track_achievement("SHIP_ACH_OG_DAWN_SPEAR_3", Hyperspace.ships.player, "PLAYER_SHIP_OG_DAWN_SPEAR")))
	if shipManager.iShipId == 1 and should_track_achievement("SHIP_ACH_OG_DAWN_SPEAR_3", Hyperspace.ships.player, "PLAYER_SHIP_OG_DAWN_SPEAR") then
		for room in vter(shipManager.ship.vRoomList) do
			--print("room:"..room.iRoomId.." vunerable_rooms"..tostring(vunerable_rooms[shipManager.iShipId][room.iRoomId]))
			--if vunerable_rooms[shipManager.iShipId][room.iRoomId] then print("room:"..room.iRoomId.." triggers:"..vunerable_rooms[shipManager.iShipId][room.iRoomId].triggers) end
			if vunerable_rooms[shipManager.iShipId][room.iRoomId] and vunerable_rooms[shipManager.iShipId][room.iRoomId].triggers >= 6 then
				Hyperspace.CustomAchievementTracker.instance:SetAchievement("SHIP_ACH_OG_DAWN_SPEAR_3", false)
			end
		end
	end
end)

local systemBlueprintVarName = mods.og.systemBlueprintVarName
local systemNameList = mods.og.systemNameList
local turretBlueprintsList = mods.og.turretBlueprintsList 
local microTurrets = mods.og.microTurrets
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if shipManager.iShipId == 0 and should_track_achievement("SHIP_ACH_OG_DAWN_BIG_1", shipManager, "PLAYER_SHIP_OG_DAWN_BIG") then
		local crewCount = 0
		for crewmem in vter(Hyperspace.ships.player.vCrewList) do
			if crewmem.iShipId == 0 then
				local crewSlots = crewmem.extend:CalculateStat(Hyperspace.CrewStat.CREW_SLOTS)
				crewCount = crewCount + crewSlots
			end
		end
		if Hyperspace.ships.enemy then
			for crewmem in vter(Hyperspace.ships.enemy.vCrewList) do
				if crewmem.iShipId == 0 then
					local crewSlots = crewmem.extend:CalculateStat(Hyperspace.CrewStat.CREW_SLOTS)
					crewCount = crewCount + crewSlots
				end
			end
		end
		if crewCount >= 11 then
			Hyperspace.CustomAchievementTracker.instance:SetAchievement("SHIP_ACH_OG_DAWN_BIG_1", false)
		end
	end
	if shipManager.iShipId == 0 and should_track_achievement("SHIP_ACH_OG_DAWN_BIG_2", shipManager, "PLAYER_SHIP_OG_DAWN_BIG") then
		local lastTurret = nil
		local matchingTurrets = true
		for _, sysName in ipairs(systemNameList) do
			if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(sysName)) then
				local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(sysName))
				local currentTurretName = turretBlueprintsList[ Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemBlueprintVarName] ]
				if not lastTurret then
					lastTurret = currentTurretName
				elseif currentTurretName ~= lastTurret then
					matchingTurrets = false
				end
			end
		end
		if lastTurret and matchingTurrets then
			Hyperspace.CustomAchievementTracker.instance:SetAchievement("SHIP_ACH_OG_DAWN_BIG_2", false)
		end
	end
	if shipManager.iShipId == 0 and should_track_achievement("SHIP_ACH_OG_DAWN_BIG_3", shipManager, "PLAYER_SHIP_OG_DAWN_BIG") then
		local upgradedTurrets = true
		for _, sysName in ipairs(systemNameList) do
			if not microTurrets[sysName] and shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(sysName)) then
				local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(sysName))
				if system:GetMaxPower() < 5 then
					upgradedTurrets = false
				end
			end
		end
		if upgradedTurrets then
			Hyperspace.CustomAchievementTracker.instance:SetAchievement("SHIP_ACH_OG_DAWN_BIG_3", false)
		end
	end

	if shipManager.iShipId == 0 and should_track_achievement("SHIP_ACH_OG_EXECUTOR_1", shipManager, "PLAYER_SHIP_OG_EXECUTOR") then
		local upgradedTurrets = true
		for _, sysName in ipairs(systemNameList) do
			if microTurrets[sysName] and shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(sysName)) then
				local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(sysName))
				if system:GetMaxPower() < 3 then
					upgradedTurrets = false
				end
			end
		end
		if upgradedTurrets then
			Hyperspace.CustomAchievementTracker.instance:SetAchievement("SHIP_ACH_OG_EXECUTOR_1", false)
		end
	end

end)



local achLayoutUnlocks = {
	{
		achPrefix = "SHIP_ACH_OG_RAIDER",
		unlockShip = "PLAYER_SHIP_OG_RAIDER_3",
	},
	{
		achPrefix = "SHIP_ACH_OG_EXECUTOR",
		unlockShip = "PLAYER_SHIP_OG_EXECUTOR_3",
	},
	{
		achPrefix = "SHIP_ACH_OG_DAWN_SPEAR",
		unlockShip = "PLAYER_SHIP_OG_DAWN_SPEAR_3",
	},
	{
		achPrefix = "SHIP_ACH_OG_DAWN_BIG",
		unlockShip = "PLAYER_SHIP_OG_DAWN_BIG_3",
	},
}

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
	local unlockTracker = Hyperspace.CustomShipUnlocks.instance
	for _, unlockData in ipairs(achLayoutUnlocks) do
		--print("try:"..unlockData.unlockShip)
		--print("unlocked:"..tostring(not unlockTracker:GetCustomShipUnlocked(unlockData.unlockShip)))
		--print("unlocked:"..tostring(count_ship_achievements(unlockData.achPrefix)))
		if not unlockTracker:GetCustomShipUnlocked(unlockData.unlockShip) and count_ship_achievements(unlockData.achPrefix) >= 2 then
			unlockTracker:UnlockShip(unlockData.unlockShip, false)
		end
	end
end)
