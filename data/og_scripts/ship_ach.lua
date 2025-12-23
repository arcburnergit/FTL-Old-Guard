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
	if Hyperspace.ships.enemy and dawnShips[Hyperspace.ships.enemy.myBlueprint.blueprintName] then
		local beenKilled = Hyperspace.ships.enemy.ship.hullIntegrity.first <= 0 and Hyperspace.ships.enemy._targetable.hostile
		if beenKilled and should_track_achievement("SHIP_ACH_OG_RAIDER_2", Hyperspace.ships.player, "PLAYER_SHIP_OG_RAIDER") then
			Hyperspace.CustomAchievementTracker.instance:SetAchievement("SHIP_ACH_OG_RAIDER_2", false)
		end
	end
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
	if check_no_shields_or_weapons_ach(ship) then
		Hyperspace.CustomAchievementTracker.instance:SetAchievement("SHIP_ACH_OG_RAIDER_3", false)
	end
end)

local achLayoutUnlocks = {
	{
		achPrefix = "SHIP_ACH_OG_RAIDER",
		unlockShip = "PLAYER_SHIP_OG_RAIDER_3"
	}
}

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
	local unlockTracker = Hyperspace.CustomShipUnlocks.instance
	for _, unlockData in ipairs(achLayoutUnlocks) do
		if not unlockTracker:GetCustomShipUnlocked(unlockData.unlockShip) and count_ship_achievements(unlockData.achPrefix) >= 2 then
			unlockTracker:UnlockShip(unlockData.unlockShip, false)
		end
	end
end)
