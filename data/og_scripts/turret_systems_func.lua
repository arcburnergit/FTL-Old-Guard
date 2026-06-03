-- MV CORE
local vter = mods.multiverse.vter
local time_increment = mods.multiverse.time_increment
local userdata_table = mods.multiverse.userdata_table
local node_child_iter = mods.multiverse.node_child_iter
local node_get_number_default = mods.multiverse.node_get_number_default

--OG CORE
local get_room_at_location = mods.og.get_room_at_location
local xor = mods.og.xor
local isPointInEllipse = mods.og.isPointInEllipse
local worldToPlayerLocation = mods.og.worldToPlayerLocation
local worldToEnemyLocation = mods.og.worldToEnemyLocation
local get_distance = mods.og.get_distance
local offset_point_in_direction = mods.og.offset_point_in_direction
local get_random_point_in_radius = mods.og.get_random_point_in_radius
local normalize_angle = mods.og.normalize_angle
local angle_diff = mods.og.angle_diff
local move_angle_to = mods.og.move_angle_to
local get_angle_between_points = mods.og.get_angle_between_points
local find_intercept_angle = mods.og.find_intercept_angle
local find_closest_slot = mods.og.find_closest_slot

local vunerable_weapons = mods.og.vunerable_weapons
--TURRET DEFINITIONS
local systemName = "og_turret"

mods.og.microTurrets = {
["og_turret_mini"] = true, ["og_turret_mini_2"] = true, 
["og_turret_mini_3"] = true, ["og_turret_mini_4"] = true
}
local microTurrets = mods.og.microTurrets

mods.og.systemNameList = {
systemName, 
systemName.."_2", 
systemName.."_3", 
systemName.."_4", 
systemName.."_mini", 
systemName.."_mini_2", 
systemName.."_mini_3", 
systemName.."_mini_4", 
systemName.."_adaptive"
}
local systemNameList = mods.og.systemNameList

for _, sysName in ipairs(systemNameList) do
	mods.multiverse.systemIcons[Hyperspace.ShipSystem.NameToSystemId(sysName)] = mods.multiverse.register_system_icon(sysName)
end

mods.og.systemCacheList = {[0] = {}, [1] = {}}
local systemCacheList = mods.og.systemCacheList

local systemNameCheck = {}
for _, sysName in ipairs(systemNameList) do
	systemNameCheck[sysName] = true
end

mods.og.scrambler_radius = 32
local scrambler_radius = mods.og.scrambler_radius

mods.og.turret_autofire_setting = 0

--TURRET ENUMS
mods.og.turret_directions = {
	up = -1,
	right = 0,
	down = 1,
	left = -2,
	upright = -0.5,
	downright = 0.5,
	upleft = -1.5,
	downleft = 1.5,
}
local turret_directions = mods.og.turret_directions

--1 = MISSILES, 2 = FLAK, 3 = DRONES, 4 = PROJECTILES, 5 = HACKING 
mods.og.defence_types = {
	DRONES = {[3] = true, [7] = true, name = Hyperspace.Text:GetText("og_lua_turret_type_drones")},
	MISSILES = {[1] = true, [2] = true, [7] = true, name = Hyperspace.Text:GetText("og_lua_turret_type_missiles")},
	DRONES_MISSILES = {[1] = true, [2] = true, [3] = true, [7] = true, name = Hyperspace.Text:GetText("og_lua_turret_type_drones_missiles")},
	PROJECTILES = {[4] = true, name = Hyperspace.Text:GetText("og_lua_turret_type_projectiles")},
	DRONES_PROJECTILES = {[3] = true, [4] = true, [7] = true, name = Hyperspace.Text:GetText("og_lua_turret_type_drones_projectiles")},
	PROJECTILES_MISSILES = {[1] = true, [2] = true, [4] = true, [7] = true, name = Hyperspace.Text:GetText("og_lua_turret_type_projectiles_missiles")},
	ALL = {[1] = true, [2] = true, [3] = true, [4] = true, [7] = true, name = Hyperspace.Text:GetText("og_lua_turret_type_all")},
}
local defence_types = mods.og.defence_types

mods.og.chain_types = {
	cooldown = 1,
}
local chain_types = mods.og.chain_types

mods.og.turret_states = {
	defence = 0,
	offence = 1,
}
local turret_states = mods.og.turret_states

--STORE GENERATED INFO
mods.og.turret_location = {}
mods.og.starting_turrets = {}
local turret_location = mods.og.turret_location
local starting_turrets = mods.og.starting_turrets
do
	local blueprintFiles = {
		"data/blueprints.xml",
		"data/dlcBlueprints.xml",
		"data/autoBlueprints.xml",
	}
	local xmlFilesToCheck = {}
	for _, file in ipairs(blueprintFiles) do
		--print("check file:"..file)
		local doc = RapidXML.xml_document(file)
		for node in node_child_iter(doc:first_node("FTL") or doc) do
			if node:name() == "shipBlueprint" then
				local shipClass = node:first_attribute("name"):value()
				if shipClass then
					starting_turrets[shipClass] = {}
					local xmlFile = node:first_attribute("layout"):value()
					local imgFile = node:first_attribute("img"):value()
					table.insert(xmlFilesToCheck, {xml=xmlFile, img=imgFile})
					for systemListNode in node_child_iter(node) do
						if systemListNode:name() == "systemList" then
							for systemNode in node_child_iter(systemListNode) do
								if systemNameCheck[systemNode:name()] then
									--print(shipClass.." "..systemNode:name().." "..systemNode:first_attribute("turret"):value())
									starting_turrets[shipClass][systemNode:name()] = systemNode:first_attribute("turret"):value() or "OG_TURRET_LASER_RUSTY_MINI_1"
								end
							end
						end
					end
				end
			end
		end
		doc:clear()
	end

	for _, fileTable in ipairs(xmlFilesToCheck) do
		turret_location[fileTable.xml] = {}
		local doc = RapidXML.xml_document("data/"..fileTable.xml..".xml")
		for node in node_child_iter(doc:first_node("FTL") or doc) do
			if node:name() == "ogTurretMounts" then
				for turretNode in node_child_iter(node) do
					--print(fileTable.xml)
					local t_x = node_get_number_default(turretNode:first_attribute("x"), 0)
					local t_y = node_get_number_default(turretNode:first_attribute("y"), 0)
					local t_direction = turret_directions[turretNode:first_attribute("direction"):value()]
					--print(fileTable.xml.." "..turretNode:name().." x:"..tostring(t_x).." y:"..tostring(t_y).." direction:"..tostring(t_direction))
					turret_location[fileTable.xml][turretNode:name()] = {x = t_x, y = t_y, direction = t_direction}
				end
			end
		end
		turret_location[fileTable.xml]["og_turret_adaptive"] = {x = 0, y = 0, direction = turret_directions.right}
	end
end

--Generated in turret_systems_stats.lua
mods.og.turretBlueprintsList = {}
local turretBlueprintsList = mods.og.turretBlueprintsList 

mods.og.turrets = {}
local turrets = mods.og.turrets

--GENERATE TURRET STATS TEXT
local statsText = {
	time = Hyperspace.Text:GetText("og_lua_turret_stats_time"),
	charges = Hyperspace.Text:GetText("og_lua_turret_stats_charges"),
	amount = Hyperspace.Text:GetText("og_lua_turret_stats_amount"),
	ammo = Hyperspace.Text:GetText("og_lua_turret_stats_ammo"),
	chain = Hyperspace.Text:GetText("og_lua_turret_stats_chain"),
	chainCap = Hyperspace.Text:GetText("og_lua_turret_stats_chainCap"),
	rotation = Hyperspace.Text:GetText("og_lua_turret_stats_rotation"),
	radius = Hyperspace.Text:GetText("og_lua_turret_stats_radius"),
	rate = Hyperspace.Text:GetText("og_lua_turret_stats_rate"),
	target = Hyperspace.Text:GetText("og_lua_turret_stats_target"),

	damage = Hyperspace.Text:GetText("og_lua_turret_stats_damage"),
	sysDamage = Hyperspace.Text:GetText("og_lua_turret_stats_sysDamage"),
	persDamage = Hyperspace.Text:GetText("og_lua_turret_stats_persDamage"),
	ionDamage = Hyperspace.Text:GetText("og_lua_turret_stats_ionDamage"),
	pierce = Hyperspace.Text:GetText("og_lua_turret_stats_pierce"),
	hullBust = Hyperspace.Text:GetText("og_lua_turret_stats_hullBust"),
	lockdown = Hyperspace.Text:GetText("og_lua_turret_stats_lockdown"),

	fireChance = Hyperspace.Text:GetText("og_lua_turret_stats_fireChance"),
	breachChance = Hyperspace.Text:GetText("og_lua_turret_stats_breachChance"),
	stunChance = Hyperspace.Text:GetText("og_lua_turret_stats_stunChance"),
	effect = Hyperspace.Text:GetText("og_lua_turret_stats_effect"),
	stealth = Hyperspace.Text:GetText("stat_stealth"),

	price = Hyperspace.Text:GetText("og_lua_turret_stats_price"),
}
local function add_stat_text(desc, currentTurret, chargeMax)
	desc = desc..statsText.time
	for i, t in ipairs(currentTurret.charge_time) do
		if i <= chargeMax then
			desc = desc..math.floor(t*10)/10
		end
		if i < #currentTurret.charge_time and i < chargeMax then
			desc = desc.."/"
		end
	end
	desc = desc..string.format(statsText.charges, math.floor(currentTurret.charges))
	desc = desc..string.format(statsText.amount, math.floor(currentTurret.charges_per_charge))
	if currentTurret.ammo_consumption then
		desc = desc..string.format(statsText.ammo, currentTurret.ammo_consumption)
	end
	if currentTurret.chain and currentTurret.chain.type == chain_types.cooldown then
		local chain_amount = math.floor(currentTurret.chain.amount * 100)
		desc = desc..string.format(statsText.chain, chain_amount)
		local chain_count = math.floor(currentTurret.chain.count)
		local chain_max_effect = math.floor(currentTurret.chain.amount * currentTurret.chain.count * 100)
		desc = desc..string.format(statsText.chainCap, chain_max_effect, chain_count)
	end
	desc = desc..string.format(statsText.rotation, math.floor(currentTurret.rotation_speed))
	if currentTurret.shot_radius then
		desc = desc..string.format(statsText.radius, math.floor(currentTurret.shot_radius))
	end
	desc = desc..statsText.rate
	for i, t in ipairs(currentTurret.fire_points) do
		desc = desc..t.fire_delay
		if i < #currentTurret.fire_points then
			desc = desc.."/"
		end
	end
	desc = desc..string.format(statsText.target, currentTurret.defence_type.name)
	local shotBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint(currentTurret.blueprint)
	local damage = shotBlueprint.damage
	desc = desc.."\n"
	local tempDamage = {iDamage = damage.iDamage, iSystemDamage = damage.iSystemDamage, iPersDamage = damage.iPersDamage, iIonDamage = damage.iIonDamage}
	if currentTurret.fake_damage then
		if currentTurret.fake_damage.iDamage then tempDamage.iDamage = tempDamage.iDamage + currentTurret.fake_damage.iDamage end
		if currentTurret.fake_damage.iSystemDamage then tempDamage.iSystemDamage = tempDamage.iSystemDamage + currentTurret.fake_damage.iSystemDamage end
		if currentTurret.fake_damage.iPersDamage then tempDamage.iPersDamage = tempDamage.iPersDamage + currentTurret.fake_damage.iPersDamage end
		if currentTurret.fake_damage.iIonDamage then tempDamage.iIonDamage = tempDamage.iIonDamage + currentTurret.fake_damage.iIonDamage end
	end
	if tempDamage.iDamage > 0 then
		desc = desc..string.format(statsText.damage, math.floor(tempDamage.iDamage))
	end
	if tempDamage.iSystemDamage + tempDamage.iDamage > 0 then
		desc = desc..string.format(statsText.sysDamage, math.floor(tempDamage.iDamage + tempDamage.iSystemDamage))
	end
	if tempDamage.iPersDamage + tempDamage.iDamage > 0 then
		desc = desc..string.format(statsText.persDamage, math.floor((tempDamage.iDamage + tempDamage.iPersDamage) * 15))
	end
	if tempDamage.iIonDamage > 0 then
		desc = desc..string.format(statsText.ionDamage, math.floor(tempDamage.iIonDamage))
	end
	if damage.iShieldPiercing ~= 0 then
		local tempPiercing = damage.iShieldPiercing
		if currentTurret.blueprint_type == 3 then 
			tempPiercing = tempPiercing - 1 
			if currentTurret.fake_damage and currentTurret.fake_damage.iDamage then
				tempPiercing = tempPiercing - currentTurret.fake_damage.iDamage
			end
		end
		desc = desc..string.format(statsText.pierce, math.floor(tempPiercing))
	end
	if damage.bHullBuster then
		desc = desc..statsText.hullBust
	end
	desc = desc.."\n"
	if damage.bLockdown then
		desc = desc..statsText.lockdown
	end
	if damage.fireChance > 0 then
		desc = desc..string.format(statsText.fireChance, math.floor(damage.fireChance * 10))
	end
	if damage.breachChance > 0 then
		desc = desc..string.format(statsText.breachChance, math.floor(damage.breachChance * 10), math.floor((100 - 10 * damage.fireChance) * (damage.breachChance/10)))
	end
	if damage.stunChance > 0 then
		desc = desc..string.format(statsText.fireChance, math.floor(damage.stunChance * 10), math.floor((damage.iStun > 0 and damage.iStun) or 3))
	end
	if vunerable_weapons[currentTurret.blueprint] then
		desc = desc..string.format(statsText.effect, math.floor(vunerable_weapons[currentTurret.blueprint]))
	end
	if currentTurret.stealth then
		desc = desc.."\n\n"..statsText.stealth
	end
	return desc
end

script.on_internal_event(Defines.InternalEvents.WEAPON_DESCBOX, function(blueprint, desc)
	if turrets[blueprint.name] then
		local currentTurret = turrets[blueprint.name]
		desc = add_stat_text((blueprint.desc.description:GetText().."\n\n"), currentTurret, 8)
		desc = desc..string.format(statsText.price, math.floor(blueprint.desc.cost), math.floor(blueprint.desc.cost/2))
	end
	return Defines.Chain.CONTINUE, desc
end)

script.on_internal_event(Defines.InternalEvents.WEAPON_STATBOX, function(blueprint, stats)
	return Defines.Chain.CONTINUE, stats
end)

-- TURRET HELPER FUNCTIONS

local cursorValid = Hyperspace.Resources:GetImageId("mouse/mouse_og_turret_valid.png")
local cursorValid2 = Hyperspace.Resources:GetImageId("mouse/mouse_og_turret_valid2.png")
local cursorDefault = Hyperspace.Resources:GetImageId("mouse/pointerValid.png")
local cursorDefault2 = Hyperspace.Resources:GetImageId("mouse/pointerInvalid.png")

mods.og.systemBlueprintVarName = "_blueprint"
mods.og.systemStateVarName = "_state"
mods.og.systemChargesVarName = "_charges"
mods.og.systemChainVarName = "_chain"
mods.og.systemTimeVarName = "_time"

local systemBlueprintVarName = mods.og.systemBlueprintVarName
local systemStateVarName = mods.og.systemStateVarName
local systemChargesVarName = mods.og.systemChargesVarName
local systemChainVarName = mods.og.systemChainVarName
local systemTimeVarName = mods.og.systemTimeVarName
local timeSaveFactor = 100000

function mods.og.saveTurretDefaults(shipManager, system, sysName, id)
	--log("save:"..sysName)
	local shipId = math.floor(shipManager.iShipId)
	for i, name in ipairs(turretBlueprintsList) do
		if name == id then
			Hyperspace.playerVariables[shipId..sysName..systemBlueprintVarName] = i
			--log("save blueprint:"..system.table.blueprint.." var:"..tostring(Hyperspace.playerVariables[shipId..sysName..systemBlueprintVarName]))
			goto SAVE_STATE
		end
	end
	::SAVE_STATE::
	Hyperspace.playerVariables[shipId..sysName..systemStateVarName] = 0
	--log("save state:"..system.table.state.." var:"..Hyperspace.playerVariables[shipId..sysName..systemStateVarName])

	Hyperspace.playerVariables[shipId..sysName..systemChargesVarName] = 0
	--log("save charges:"..system.table.charges.." var:"..Hyperspace.playerVariables[shipId..sysName..systemChargesVarName])

	Hyperspace.playerVariables[shipId..sysName..systemChainVarName] = 0
	--log("save chain_level:"..system.table.chain_level.." var:"..Hyperspace.playerVariables[shipId..sysName..systemChainVarName])

	Hyperspace.playerVariables[shipId..sysName..systemTimeVarName] = 0
	--log("save time:"..system.table.time.." factor:"..(system.table.time * timeSaveFactor).." var:"..Hyperspace.playerVariables[shipId..sysName..systemTimeVarName])
end
local saveTurretDefaults = mods.og.saveTurretDefaults

function mods.og.saveTurret(shipManager, system, sysName)
	if Hyperspace.App.menu.shipBuilder.bOpen then return end
	--log("save:"..sysName)
	local shipId = math.floor(shipManager.iShipId)

	if system.table.blueprint == "" then
		--log("save empty blueprint")
        Hyperspace.playerVariables[shipId..sysName..systemBlueprintVarName] = -1
        Hyperspace.playerVariables[shipId..sysName..systemStateVarName] = 0
        Hyperspace.playerVariables[shipId..sysName..systemChargesVarName] = 0
        Hyperspace.playerVariables[shipId..sysName..systemChainVarName] = 0
        Hyperspace.playerVariables[shipId..sysName..systemTimeVarName] = 0
        return
    end

	for i, name in ipairs(turretBlueprintsList) do
		if name == system.table.blueprint then
			Hyperspace.playerVariables[shipId..sysName..systemBlueprintVarName] = i
			--log("save blueprint:"..system.table.blueprint.." var:"..tostring(Hyperspace.playerVariables[shipId..sysName..systemBlueprintVarName]))
			goto SAVE_STATE
		end
	end
	::SAVE_STATE::
	Hyperspace.playerVariables[shipId..sysName..systemStateVarName] = system.table.state
	--log("save state:"..system.table.state.." var:"..Hyperspace.playerVariables[shipId..sysName..systemStateVarName])

	Hyperspace.playerVariables[shipId..sysName..systemChargesVarName] = system.table.charges
	--log("save charges:"..system.table.charges.." var:"..Hyperspace.playerVariables[shipId..sysName..systemChargesVarName])

	Hyperspace.playerVariables[shipId..sysName..systemChainVarName] = system.table.chain_level
	--log("save chain_level:"..system.table.chain_level.." var:"..Hyperspace.playerVariables[shipId..sysName..systemChainVarName])

	Hyperspace.playerVariables[shipId..sysName..systemTimeVarName] = system.table.time * timeSaveFactor
	--log("save time:"..system.table.time.." factor:"..(system.table.time * timeSaveFactor).." var:"..Hyperspace.playerVariables[shipId..sysName..systemTimeVarName])
end
local saveTurret = mods.og.saveTurret

function mods.og.loadTurret(shipManager, system, sysName)
	--log("load:"..sysName)
	local shipId = math.floor(shipManager.iShipId)

	if Hyperspace.playerVariables[shipId..sysName..systemBlueprintVarName] == -1 then
		--log("load empty blueprint")
        system.table.blueprint = ""
        system.table.state = 0
        system.table.charges = 0
        system.table.chain_level = 0
        system.table.time = 0
        return
    end

	for i, name in ipairs(turretBlueprintsList) do
		if i == Hyperspace.playerVariables[shipId..sysName..systemBlueprintVarName] then
			system.table.blueprint = name
			--log("load blueprint:"..system.table.blueprint.." var:"..tostring(Hyperspace.playerVariables[shipId..sysName..systemBlueprintVarName]))
			goto LOAD_STATE
		end
	end
	::LOAD_STATE::
	system.table.state = Hyperspace.playerVariables[shipId..sysName..systemStateVarName]
	--log("load state:"..system.table.state.." var:"..Hyperspace.playerVariables[shipId..sysName..systemStateVarName])

	system.table.charges = Hyperspace.playerVariables[shipId..sysName..systemChargesVarName]
	--log("load charges:"..system.table.charges.." var:"..Hyperspace.playerVariables[shipId..sysName..systemChargesVarName])

	system.table.chain_level = Hyperspace.playerVariables[shipId..sysName..systemChainVarName]
	--log("load chain_level:"..system.table.chain_level.." var:"..Hyperspace.playerVariables[shipId..sysName..systemChainVarName])

	system.table.time = Hyperspace.playerVariables[shipId..sysName..systemTimeVarName] / timeSaveFactor
	--log("load time:"..system.table.time.." factor:"..(system.table.time * timeSaveFactor).." var:"..Hyperspace.playerVariables[shipId..sysName..systemTimeVarName])
end
local loadTurret = mods.og.loadTurret

local counter = {[0] = 0, [1] = 0}
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
	for i = 0, 1 do
		counter[i] = counter[i] + time_increment(false)
		if counter[i] >= 1 then
			local shipManager = Hyperspace.ships(i)
			if shipManager then
				counter[shipManager.iShipId] = 0
				for _, sysName in ipairs(systemNameList) do
					if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(sysName)) then
						systemCacheList[shipManager.iShipId][sysName] = true
						local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(sysName))
						saveTurret(shipManager, system, sysName)
					else
						systemCacheList[shipManager.iShipId][sysName] = false
					end
				end
			else
				systemCacheList[i] = {}
			end
		end
	end
end)

function mods.og.findStartingTurret(shipManager, sysName)
	local shipName = shipManager.myBlueprint.blueprintName
	if starting_turrets[shipName] and starting_turrets[shipName][sysName] then
		local weapon_id = starting_turrets[shipName][sysName]
		if Hyperspace.Blueprints:GetBlueprintList(weapon_id):size() > 0 then
			local list = Hyperspace.Blueprints:GetBlueprintList(weapon_id)
			local r = math.random(list:size()) - 1
			weapon_id = list[r]
		end
		for i, id in ipairs(turretBlueprintsList) do
			if weapon_id == id then
				return id, i
			end
		end
		print("Failed to find starting turret")
	end
	return "", -1
end
local findStartingTurret = mods.og.findStartingTurret

local initialFiringTime = 0.1

local function resetTurrets(shipManager)
	for _, sysName in ipairs(systemNameList) do
		if systemCacheList[shipManager.iShipId][sysName] then
			local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(sysName))

			system.table.time = 0
			local currentTurret = turrets[ system.table.blueprint ]
			if shipManager:HasAugmentation("OG_TURRET_PREIGNITE") > 0 and currentTurret then
				system.table.charges = currentTurret.charges
			elseif shipManager:HasAugmentation("OG_TURRET_PREIGNITE_WEAK") > 0 and currentTurret then
				if shipManager.iShipId == 0 then
					system.table.charges = math.ceil(currentTurret.charges/2)
				else
					system.table.charges = math.floor(currentTurret.charges/2)
				end
			else
				system.table.charges = 0
			end
			if currentTurret.chain then
				system.table.chain_level = math.min(currentTurret.chain.count, system.table.charges)
			else
				system.table.chain_level = 0
			end
			--system.table.state = turret_states.defence
			system.table.firingTime = initialFiringTime

			system.table.ammo_consumed = 0

			--Tracking vars
			--system.table.currentAimingAngle = 0
			system.table.entryAngle = math.random(360)

			--User Interaction settings
			system.table.currentlyTargetting = false
			system.table.currentlyTargetted = false

			system.table.currentTarget = nil
			system.table.currentTargetTemp = nil

			system.table.autoFireInvert = false
		end
	end
end

function mods.og.select_turret(system, shift)
	local shipManager = Hyperspace.ships.player
	system.table.currentTarget = nil
	system.table.autoFireInvert = shift 
	system.table.currentTargetTemp = nil
	system.table.currentlyTargetted = false
	system.table.currentlyTargetting = true
	Hyperspace.Mouse.validPointer = cursorValid
	Hyperspace.Mouse.invalidPointer = cursorValid2
end
local select_turret = mods.og.select_turret

function mods.og.checkValidTarget(targetable, defence_type, shipManager)
	if not targetable then return false end
	local isDying = targetable.GetIsDying and targetable:GetIsDying()
	local ownerId = targetable.GetOwnerId and targetable:GetOwnerId()
	local space = targetable.GetSpaceId and targetable:GetSpaceId()
	local valid = targetable.ValidTarget and targetable:ValidTarget()
	--local hostile = targetable.hostile -- bool
	local type = targetable.type -- int
	--local targeted = targetable.targeted -- bool
	local otherManager = Hyperspace.ships(1 - shipManager.iShipId)
	local hasHackingDrone = otherManager and otherManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId("hacking")) and otherManager.hackingSystem.drone
	local hackingDrone = hasHackingDrone and otherManager.hackingSystem.drone._targetable:GetSelfId() == targetable:GetSelfId() and not otherManager.hackingSystem.drone.arrived 
	--if ppp then
	--print("target: isDying"..tostring(isDying).." ownerId"..tostring(ownerId).." space"..tostring(space).." valid"..tostring(valid)--[[.." hostile"..tostring(hostile)]].." type"..tostring(type).." validType"..tostring(defence_type[type]).." hackingdrone:"..tostring((defence_type[6] and hackingDrone)).." defence_type"..tostring(defence_type.name))
	--end
	if (not isDying) and (ownerId ~= shipManager.iShipId) and valid and (defence_type[type] or (defence_type[7] and hackingDrone)) then
		return true
	end
	return false
end
local checkValidTarget = mods.og.checkValidTarget

function mods.og.get_charge_time(currentTurret, system)
	local systemNameTemp = Hyperspace.ShipSystem.SystemIdToName(system.iSystemType)
	local shipId = math.floor(system._shipObj.iShipId)
	local shipManager = Hyperspace.ships(shipId)

	local hasMannedBonus = (system.iActiveManned > 0 and 0.05) or 0
	local chargeTime = currentTurret.charge_time[system:GetEffectivePower()]
	if currentTurret.enemy_charge_time and shipId == 1 then
		chargeTime = currentTurret.enemy_charge_time[system:GetEffectivePower()]
	end
	local chargeTimeReduction = 0
	local chainAmount = system.table.chain_level
	if currentTurret.chain and currentTurret.chain.type == chain_types.cooldown then
		for i = 1, chainAmount do
			chargeTimeReduction = chargeTimeReduction + chargeTime * currentTurret.chain.amount
		end
	end
	chargeTime = chargeTime - chargeTimeReduction
	chargeTime = (chargeTime * (1 - (hasMannedBonus + system.iActiveManned * 0.05)))/(1 + shipManager:GetAugmentationValue("AUTO_COOLDOWN")/2)
	return chargeTime
end
local get_charge_time = mods.og.get_charge_time

--SYSTEM FUNCTIONALITY

--SYSTEM CHECK
function mods.og.is_system(systemBox)
	local systemId = Hyperspace.ShipSystem.SystemIdToName(systemBox.pSystem.iSystemType)
	local isSystemName = false
	for _, sysName in ipairs(systemNameList) do
		if systemId == sysName then
			isSystemName = true
		end
	end
	return isSystemName and systemBox.bPlayerUI
end
function mods.og.is_system_enemy(systemBox)
	local systemId = Hyperspace.ShipSystem.SystemIdToName(systemBox.pSystem.iSystemType)
	local isSystemName = false
	for _, sysName in ipairs(systemNameList) do
		if systemId == sysName then
			isSystemName = true
		end
	end
	return isSystemName and not systemBox.bPlayerUI
end
local is_system = mods.og.is_system
local is_system_enemy = mods.og.is_system_enemy

--SYSTEM READY
function mods.og.system_ready(shipSystem)
	return --[[not shipSystem:GetLocked() and]] shipSystem:Functioning() and shipSystem.iHackEffect <= 1
end
local system_ready = mods.og.system_ready

--LEVEL DESCRIPTION
local text_power_increase = Hyperspace.Text:GetText("og_lua_turret_power_increase")
local function get_level_description_system(currentId, level, tooltip)
	for _, sysName in ipairs(systemNameList) do
		if currentId == Hyperspace.ShipSystem.NameToSystemId(sysName) then
			return string.format(text_power_increase)
		end
	end
end
script.on_internal_event(Defines.InternalEvents.GET_LEVEL_DESCRIPTION, get_level_description_system)

--SYSTEM CONSTRUCTION
mods.og.UIOffset_x = 32
mods.og.UIOffset_y = -44

mods.og.autoFireX = 63
mods.og.autoFireY = 61

local UIOffset_x = mods.og.UIOffset_x
local UIOffset_y = mods.og.UIOffset_y

local autoFireX = mods.og.autoFireX
local autoFireY = mods.og.autoFireY
mods.og.autoFireOffButton = Hyperspace.Button()
mods.og.autoFireOnButton = Hyperspace.Button()
local autoFireOffButton= mods.og.autoFireOffButton
local autoFireOnButton= mods.og.autoFireOnButton
--setup autofire buttons
do
	autoFireOffButton:OnInit("button_small_autofireOff", Hyperspace.Point(UIOffset_x + autoFireX, UIOffset_y + autoFireY))
	autoFireOffButton.hitbox.x = 9
	autoFireOffButton.hitbox.y = 2
	autoFireOffButton.hitbox.w = 22
	autoFireOffButton.hitbox.h = 24

	autoFireOnButton:OnInit("button_small_autofireOn", Hyperspace.Point(UIOffset_x + autoFireX, UIOffset_y + autoFireY))
	autoFireOnButton.hitbox.x = 9
	autoFireOnButton.hitbox.y = 2
	autoFireOnButton.hitbox.w = 22
	autoFireOnButton.hitbox.h = 24
end

local function setup_system_buttons(systemBox)
	local targetButton = Hyperspace.Button()
	targetButton:OnInit("systemUI/button_og_turret_target", Hyperspace.Point(UIOffset_x, UIOffset_y))
	targetButton.hitbox.x = 16
	targetButton.hitbox.y = 16
	targetButton.hitbox.w = 75
	targetButton.hitbox.h = 39
	systemBox.table.targetButton = targetButton
	local offenceButton = Hyperspace.Button()
	offenceButton:OnInit("systemUI/button_og_turret_toggle_o", Hyperspace.Point(UIOffset_x, UIOffset_y))
	offenceButton.hitbox.x = 74
	offenceButton.hitbox.y = 37
	offenceButton.hitbox.w = 17
	offenceButton.hitbox.h = 18
	systemBox.table.offenceButton = offenceButton
	local defenceButton = Hyperspace.Button()
	defenceButton:OnInit("systemUI/button_og_turret_toggle_d", Hyperspace.Point(UIOffset_x, UIOffset_y))
	defenceButton.hitbox.x = 74
	defenceButton.hitbox.y = 37
	defenceButton.hitbox.w = 17
	defenceButton.hitbox.h = 18
	systemBox.table.defenceButton = defenceButton
end

local function setup_adaptive_system(systemBox, systemId)
	systemBox.pSystem.table.micro = true
	microTurrets[systemId] = true
	if Hyperspace.playerVariables.og_turret_adaptive_saved_x > 0 then
		local shipManager = Hyperspace.ships.player
		turret_location[shipManager.ship.shipName]["og_turret_adaptive"].x = Hyperspace.playerVariables.og_turret_adaptive_saved_x
		turret_location[shipManager.ship.shipName]["og_turret_adaptive"].y = Hyperspace.playerVariables.og_turret_adaptive_saved_y
		turret_location[shipManager.ship.shipName]["og_turret_adaptive"].direction = Hyperspace.playerVariables.og_turret_adaptive_saved_direction/2
	else
		local roomId = systemBox.pSystem.roomId
		local shipManager = Hyperspace.ships.player
		local pos = shipManager:GetRoomCenter(roomId)

		local ship = shipManager.ship
		local shipGraph = Hyperspace.ShipGraph.GetShipInfo(0)
		local shipCorner = {x = ship.shipImage.x + shipGraph.shipBox.x, y = ship.shipImage.y + shipGraph.shipBox.y}
		local posRelative = {x = pos.x - shipCorner.x, y = pos.y - shipCorner.y}

		turret_location[shipManager.ship.shipName]["og_turret_adaptive"].x = posRelative.x
		turret_location[shipManager.ship.shipName]["og_turret_adaptive"].y = posRelative.y
	end
end

local function system_construct_system_box(systemBox)
	if is_system(systemBox) then

		systemBox.extend.xOffset = 113
		setup_system_buttons(systemBox)

		local systemId = Hyperspace.ShipSystem.SystemIdToName(systemBox.pSystem.iSystemType)
		--print("construct player turret system "..systemId)
		if systemId == "og_turret_adaptive" then
			setup_adaptive_system(systemBox, systemId)
		elseif microTurrets[systemId] then
			systemBox.pSystem.table.micro = true
			systemBox.pSystem.bBoostable = false
		end

		systemBox.pSystem.table.index = -1
		local shipManager = Hyperspace.ships(systemBox.pSystem._shipObj.iShipId)
		if shipManager and ((not systemBox.pSystem.table.blueprint) or systemBox.pSystem.table.blueprint == "OG_EMPTY_TURRET") then
			local id, i = findStartingTurret(shipManager, systemId)
			systemBox.pSystem.table.blueprint = id
		end

		systemBox.pSystem.table.time = 0
		systemBox.pSystem.table.charges = 0
		systemBox.pSystem.table.chain_level = 0
		systemBox.pSystem.table.state = turret_states.defence
		systemBox.pSystem.table.firingTime = initialFiringTime

		systemBox.pSystem.table.ammo_consumed = 0

		--Tracking vars
		systemBox.pSystem.table.currentAimingAngle = 0
		systemBox.pSystem.table.entryAngle = math.random(360)

		--User Interaction settings
		systemBox.pSystem.table.currentlyTargetting = false
		systemBox.pSystem.table.currentlyTargetted = false

		systemBox.pSystem.table.currentTarget = nil
		systemBox.pSystem.table.currentTargetTemp = nil

		systemBox.pSystem.table.autoFireInvert = false
	elseif is_system_enemy(systemBox) then

		local systemId = Hyperspace.ShipSystem.SystemIdToName(systemBox.pSystem.iSystemType)
		if microTurrets[systemId] then
			systemBox.pSystem.table.micro = true
			--systemBox.pSystem.bBoostable = false
		end
		if not systemBox.pSystem.table.blueprint then
			systemBox.pSystem.table.blueprint = "OG_EMPTY_TURRET"
		end

		systemBox.pSystem.table.time = 0
		systemBox.pSystem.table.charges = 0
		systemBox.pSystem.table.chain_level = 0
		systemBox.pSystem.table.state = turret_states.defence
		systemBox.pSystem.table.firingTime = initialFiringTime

		systemBox.pSystem.table.ammo_consumed = 0

		--Tracking vars
		systemBox.pSystem.table.currentAimingAngle = -90
		systemBox.pSystem.table.entryAngle = math.random(360)

		--Auto Interaction settings
		systemBox.pSystem.table.currentlyTargetting = false
		systemBox.pSystem.table.currentlyTargetted = false

		systemBox.pSystem.table.currentTarget = nil
	end
end
script.on_internal_event(Defines.InternalEvents.CONSTRUCT_SYSTEM_BOX, system_construct_system_box)

--MOUSE MOVE
local hoverBox = {
	x = 8,
	y = 85,
	w = 24,
	h = 14,
}
local tooltip_hover = {
	none = -1,
	target_button = 0,
	offence_button = 1,
	defence_button = 2,
	autofire_off = 3,
	autofire_on = 4,
}
local function system_mouse_move(systemBox, x, y)
	if is_system(systemBox) then
		local systemId = Hyperspace.ShipSystem.SystemIdToName(systemBox.pSystem.iSystemType)
		local targetButton = systemBox.table.targetButton
		targetButton:MouseMove(x - (UIOffset_x), y - (UIOffset_y), false)
		local offenceButton = systemBox.table.offenceButton
		offenceButton:MouseMove(x - (UIOffset_x), y - (UIOffset_y), false)
		local defenceButton = systemBox.table.defenceButton
		defenceButton:MouseMove(x - (UIOffset_x), y - (UIOffset_y), false)

		--Tooltips
		local shipId = (systemBox.bPlayerUI and 0) or 1
		if offenceButton.bHover and systemBox.pSystem.table.state == turret_states.offence then
			systemBox.pSystem.table.tooltip_type = tooltip_hover.offence_button
		elseif defenceButton.bHover and systemBox.pSystem.table.state == turret_states.defence then
			systemBox.pSystem.table.tooltip_type = tooltip_hover.defence_button
		elseif targetButton.bHover then
			systemBox.pSystem.table.tooltip_type = tooltip_hover.target_button
		else
			systemBox.pSystem.table.tooltip_type = tooltip_hover.none
		end

		if systemBox.pSystem.table.index == Hyperspace.playerVariables.og_turret_count then
			if mods.og.turret_autofire_setting == 0 then
				autoFireOffButton:MouseMove(x - (UIOffset_x + autoFireX), y - (UIOffset_y + autoFireY), false)
				if autoFireOffButton.bHover then
					systemBox.pSystem.table.tooltip_type = tooltip_hover.autofire_off
				end
			else
				autoFireOnButton:MouseMove(x - (UIOffset_x + autoFireX), y - (UIOffset_y + autoFireY), false)
				if autoFireOnButton.bHover then
					systemBox.pSystem.table.tooltip_type = tooltip_hover.autofire_on
				end
			end
		end
	end
	return Defines.Chain.CONTINUE
end
script.on_internal_event(Defines.InternalEvents.SYSTEM_BOX_MOUSE_MOVE, system_mouse_move)

--SET TOOLTIP TEXT
local buttonHover_text = {
	offence = Hyperspace.Text:GetText("og_lua_turret_button_offence"),
	defence = Hyperspace.Text:GetText("og_lua_turret_button_defence"),
	autoFire = Hyperspace.Text:GetText("og_lua_turret_button_autoFire"),
}

local function system_tooltip()
	local shipManager = Hyperspace.ships.player
	if not shipManager then return end
	for _, sysName in ipairs(systemNameList) do
		if systemCacheList[shipManager.iShipId][sysName] then
			local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(sysName))
			if system then
				local shipId = 0
				if system.table.tooltip_type == tooltip_hover.offence_button then
					Hyperspace.Mouse.bForceTooltip = true
					Hyperspace.Mouse.tooltip = buttonHover_text.offence
				elseif system.table.tooltip_type == tooltip_hover.defence_button then
					Hyperspace.Mouse.bForceTooltip = true
					Hyperspace.Mouse.tooltip = buttonHover_text.defence
				elseif system.table.tooltip_type == tooltip_hover.target_button then
					if system.table.blueprint ~= "" then
						Hyperspace.Mouse.bForceTooltip = true
						local currentTurret = turrets[ system.table.blueprint ]
						Hyperspace.Mouse.tooltip = add_stat_text("", currentTurret, system:GetMaxPower())
					end
				elseif system.table.tooltip_type == tooltip_hover.autofire_off or system.table.tooltip_type == tooltip_hover.autofire_on then
					Hyperspace.Mouse.bForceTooltip = true
					Hyperspace.Mouse.tooltip = buttonHover_text.autoFire
				end
			end
		end
	end
end
script.on_internal_event(Defines.InternalEvents.ON_TICK, system_tooltip)

--KEY CLICK
local key_names = mods.og.key_names

local hotkeys = {
	"prof_hotkey_og_turret_1",
	"prof_hotkey_og_turret_2",
	"prof_hotkey_og_turret_3",
	"prof_hotkey_og_turret_4",
	"prof_hotkey_og_turret_5",
	"prof_hotkey_og_turret_6",
	"prof_hotkey_og_turret_7",
	"prof_hotkey_og_turret_8",
}
-- Initialize hotkeys
script.on_init(function()
	for _, var in ipairs(hotkeys) do
		if Hyperspace.metaVariables[var] == 0 then Hyperspace.metaVariables[var] = -1 end
	end
end)

mods.og.ctrl_held = false

-- Track when the hotkeys are being configured
local settingTurret = nil
script.on_game_event("COMBAT_CHECK_HOTKEYS_OG_TURRET_1_START", false, function() settingTurret = 1 end)
script.on_game_event("COMBAT_CHECK_HOTKEYS_OG_TURRET_2_START", false, function() settingTurret = 2 end)
script.on_game_event("COMBAT_CHECK_HOTKEYS_OG_TURRET_3_START", false, function() settingTurret = 3 end)
script.on_game_event("COMBAT_CHECK_HOTKEYS_OG_TURRET_4_START", false, function() settingTurret = 4 end)
script.on_game_event("COMBAT_CHECK_HOTKEYS_OG_TURRET_5_START", false, function() settingTurret = 5 end)
script.on_game_event("COMBAT_CHECK_HOTKEYS_OG_TURRET_6_START", false, function() settingTurret = 6 end)
script.on_game_event("COMBAT_CHECK_HOTKEYS_OG_TURRET_7_START", false, function() settingTurret = 7 end)
script.on_game_event("COMBAT_CHECK_HOTKEYS_OG_TURRET_8_START", false, function() settingTurret = 8 end)
script.on_game_event("COMBAT_CHECK_HOTKEYS", false, function() settingTurret = nil end)

local emptyReq = Hyperspace.ChoiceReq()
local hotkey_events = {}
hotkey_events["COMBAT_CHECK_HOTKEYS_OG_TURRET_1_START"] = true
hotkey_events["COMBAT_CHECK_HOTKEYS_OG_TURRET_2_START"] = true
hotkey_events["COMBAT_CHECK_HOTKEYS_OG_TURRET_3_START"] = true
hotkey_events["COMBAT_CHECK_HOTKEYS_OG_TURRET_4_START"] = true
hotkey_events["COMBAT_CHECK_HOTKEYS_OG_TURRET_5_START"] = true
hotkey_events["COMBAT_CHECK_HOTKEYS_OG_TURRET_6_START"] = true
hotkey_events["COMBAT_CHECK_HOTKEYS_OG_TURRET_7_START"] = true
hotkey_events["COMBAT_CHECK_HOTKEYS_OG_TURRET_8_START"] = true
script.on_internal_event(Defines.InternalEvents.PRE_CREATE_CHOICEBOX, function(event)
	if hotkey_events[event.eventName] then
		event.choices:clear()
		--print(Hyperspace.metaVariables[hotkeys[settingTurret]].." "..hotkeys[settingTurret].." "..settingTurret)
		local key = Hyperspace.metaVariables[hotkeys[settingTurret]]
		local s = ""
		for _, key_table in pairs(key_names) do
			--print(key_table.name.." i:"..key_table.index)
			if key == key_table.index then
				s = key_table.name
			end
		end
		if key == -1 then
			s = "Unset"
		end
		event:AddChoice(event, "Current key: "..s, emptyReq, false)
	end
end)

local auto_key = 306

script.on_internal_event(Defines.InternalEvents.ON_KEY_UP, function(key)
	if key == auto_key then
		mods.og.ctrl_held = false
	end
	return Defines.Chain.CONTINUE
end)

script.on_internal_event(Defines.InternalEvents.ON_KEY_DOWN, function(key)
	if key == auto_key then
		mods.og.ctrl_held = true
	end
	-- Allow player to reconfigure the hotkeys
	if settingTurret then
		if key == key_names.SDLK_ESCAPE.index then
			Hyperspace.metaVariables[hotkeys[settingTurret]] = -1
		else
			Hyperspace.metaVariables[hotkeys[settingTurret]] = key
		end
		local world = Hyperspace.App.world
		Hyperspace.CustomEventsParser.GetInstance():LoadEvent(world, "COMBAT_CHECK_HOTKEYS", false, -1)
		return Defines.Chain.PREEMPT
	end
	
	-- Do stuff if a hotkey is pressed
	local cmdGui = Hyperspace.App.gui
	if Hyperspace.ships.player and not (Hyperspace.ships.player.bJumping or cmdGui.event_pause or cmdGui.menu_pause) then
		for i, var in ipairs(hotkeys) do
			if key == Hyperspace.metaVariables[var] then
				local shipManager = Hyperspace.ships.player
				for _, sysName in ipairs(systemNameList) do
					if systemCacheList[shipManager.iShipId][sysName] then
						local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(sysName))
						if system.table.index == i then
							select_turret(system, mods.og.ctrl_held) -- enables targetting for a turret
						elseif system.table.currentlyTargetting then
							system.table.currentlyTargetting = false -- disables targetting for other turrets if its active
						end
					end
				end
			end
		end
	end
	return Defines.Chain.CONTINUE
end)

script.on_internal_event(Defines.InternalEvents.POST_CREATE_CHOICEBOX, function(choiceBox, event)
	if event.eventName == "COMBAT_CHECK_HOTKEYS" then
		for choice in vter(choiceBox:GetChoices()) do
			if string.sub(choice.text, 1, 2) == "OG" then
				local i = tonumber(string.sub(choice.text, -1))
				local key = Hyperspace.metaVariables[hotkeys[i]]
				local s = ""
				for _, key_table in pairs(key_names) do
					if key == key_table.index then
						s = key_table.name
					end
				end
				if key == -1 then
					s = "Unset"
				end
				choice.text = choice.text.." (currently is the \""..s.."\" key)"
			end
		end
	end
end)

-- Initialize hotkeys
script.on_init(function()
	for _, var in ipairs(hotkeys) do
		if Hyperspace.metaVariables[var] == 0 then Hyperspace.metaVariables[var] = -1 end
	end
end)

--MOUSE CLICK
local function target_enemy_room_temp(systemBox, combatControl)
	local targetShipGraph = Hyperspace.ShipGraph.GetShipInfo(1)
	local roomShape = targetShipGraph:GetRoomShape(combatControl.selectedRoom)
	local mousePosEnemy = worldToEnemyLocation(Hyperspace.Mouse.position)
	local slotId = find_closest_slot(roomShape, mousePosEnemy)
	systemBox.pSystem.table.currentTargetTemp = {roomId = combatControl.selectedRoom, slotId = slotId}
end

local distance_cutoff = 20
local function target_enemy_projectile(currentTurret, mousePosPlayer, mousePosEnemy, spaceManager)
	local currentClosest = nil
	for projectile in vter(spaceManager.projectiles) do
		local blueprint = Hyperspace.Blueprints:GetWeaponBlueprint(projectile.extend.name)
		if checkValidTarget(projectile._targetable, currentTurret.defence_type, Hyperspace.ships.player) and not projectile.missed and not projectile.passedTarget and blueprint.typeName ~= "BEAM" then
			local targetPos = projectile._targetable:GetRandomTargettingPoint(true)
			local dist
			if projectile._targetable:GetSpaceId() == 0 then
				dist = get_distance(mousePosPlayer, targetPos)
			else
				dist = get_distance(mousePosEnemy, targetPos)
			end
			if (not currentClosest and dist < distance_cutoff) or (currentClosest and dist < distance_cutoff and dist < currentClosest.dist) then
				currentClosest = {target = projectile, dist = dist}
			end
		end
	end
	return currentClosest
end
local function target_enemy_drone(currentTurret, mousePosPlayer, mousePosEnemy, spaceManager, currentClosest)
	for drone in vter(spaceManager.drones) do
		if checkValidTarget(drone._targetable, currentTurret.defence_type, Hyperspace.ships.player) and not drone.bDead then
			local targetPos = drone._targetable:GetRandomTargettingPoint(true)
			local dist
			if drone._targetable:GetSpaceId() == 0 then
				dist = get_distance(mousePosPlayer, targetPos)
			else
				dist = 500
			end
			if (not currentClosest and dist < 20) or (currentClosest and dist < 20 and dist < currentClosest.dist) then
				currentClosest = {target = drone, dist = dist}
			end
		end
	end
	return currentClosest
end

local function click_finish_targetting(systemBox, shipManager, targetButton)
	systemBox.pSystem.table.currentlyTargetting = false
	Hyperspace.Mouse.validPointer = cursorDefault
	Hyperspace.Mouse.invalidPointer = cursorDefault2
	local combatControl = Hyperspace.App.gui.combatControl
	if combatControl.selectedRoom >= 0 then
		target_enemy_room_temp(systemBox, combatControl)
	else
		local shipId = (systemBox.bPlayerUI and 0) or 1
		local currentTurret = turrets[ systemBox.pSystem.table.blueprint ]
		local mousePosPlayer = worldToPlayerLocation(Hyperspace.Mouse.position)
		local mousePosEnemy = worldToEnemyLocation(Hyperspace.Mouse.position)
		local spaceManager = Hyperspace.App.world.space
		local currentClosest = target_enemy_projectile(currentTurret, mousePosPlayer, mousePosEnemy, spaceManager)
		currentClosest = target_enemy_drone(currentTurret, mousePosPlayer, mousePosEnemy, spaceManager, currentClosest)
		if currentClosest then
			systemBox.pSystem.table.currentlyTargetted = true
			systemBox.pSystem.table.currentTargetTemp = currentClosest.target
		end
	end
end

local function system_click(systemBox, shift)
	local systemId = Hyperspace.ShipSystem.SystemIdToName(systemBox.pSystem.iSystemType)
	local shipId = (systemBox.bPlayerUI and 0) or 1
	if is_system(systemBox) then
		local targetButton = systemBox.table.targetButton
		local shipManager = Hyperspace.ships.player
		if Hyperspace.App.world.bStartedGame and systemBox.pSystem.table.currentlyTargetting then
			click_finish_targetting(systemBox, shipManager, targetButton)
		end

		local offenceButton = systemBox.table.offenceButton
		local defenceButton = systemBox.table.defenceButton
		if offenceButton.bHover and offenceButton.bActive then
			local shipManager = Hyperspace.ships.player
			systemBox.pSystem.table.currentTarget = nil
			systemBox.pSystem.table.currentlyTargetted = false
			systemBox.pSystem.table.currentTargetTemp = nil
			systemBox.pSystem.table.state = turret_states.defence
		elseif defenceButton.bHover and defenceButton.bActive then
			local shipManager = Hyperspace.ships.player
			systemBox.pSystem.table.currentTarget = nil
			systemBox.pSystem.table.currentlyTargetted = false
			systemBox.pSystem.table.currentTargetTemp = nil
			systemBox.pSystem.table.state = turret_states.offence
		elseif targetButton.bHover and targetButton.bActive then
			select_turret(systemBox.pSystem, mods.og.ctrl_held)
		end

		if systemBox.pSystem.table.index == Hyperspace.playerVariables.og_turret_count then
			if mods.og.turret_autofire_setting == 0 and autoFireOffButton.bHover and autoFireOffButton.bActive then
				mods.og.turret_autofire_setting = 1
			elseif mods.og.turret_autofire_setting == 1 and autoFireOnButton.bHover and autoFireOnButton.bActive then
				mods.og.turret_autofire_setting = 0
			end
		end
	end
	return Defines.Chain.CONTINUE
end
script.on_internal_event(Defines.InternalEvents.SYSTEM_BOX_MOUSE_CLICK, system_click)

script.on_internal_event(Defines.InternalEvents.ON_MOUSE_R_BUTTON_DOWN, function(x,y) 
	local shipManager = Hyperspace.ships.player
	if shipManager then
		for _, sysName in ipairs(systemNameList) do
			if systemCacheList[shipManager.iShipId][sysName] then
				local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(sysName))
				if system.table.currentlyTargetting then
					system.table.currentlyTargetting = false
					Hyperspace.Mouse.validPointer = cursorDefault
					Hyperspace.Mouse.invalidPointer = cursorDefault2
				end
			end
		end
	end
	return Defines.Chain.CONTINUE
end)

--RESET AND SAVE/LOAD FUNCTIONALITY

script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, resetTurrets)
script.on_internal_event(Defines.InternalEvents.ON_WAIT, resetTurrets)

--[[script.on_internal_event(Defines.InternalEvents.JUMP_LEAVE, function(shipManager)
	if shipManager.iShipId == 1 then
		for _, sysName in ipairs(systemNameList) do
			Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemTimeVarName] = 0
		end
	end
end)]]


script.on_game_event("STORAGE_CHECK_OG_TURRET", false, function()
	local shipManager = Hyperspace.ships.player
	resetTurrets(shipManager)
end)

local needSetValues = false
local needSetValuesEnemy = false
script.on_init(function(newGame)
	if newGame then
		local shipManager = Hyperspace.ships.player
		for _, sysName in ipairs(systemNameList) do
			if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(sysName)) then
				local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(sysName))
				--system.table.blueprint = id
				local id, i = findStartingTurret(shipManager, sysName)
				saveTurretDefaults(shipManager, system, sysName, id)
				--print("set starting "..sysName..": "..id)
			end
		end

	else
		needSetValues = true
		needSetValuesEnemy = true
	end
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if shipManager.iShipId == 0 and needSetValues and Hyperspace.playerVariables.og_test_variable == 1 then
		needSetValues = false
		for _, sysName in ipairs(systemNameList) do
			if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(sysName)) then
				local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(sysName))
				loadTurret(shipManager, system, sysName)
			end
		end
	elseif shipManager.iShipId == 1 and needSetValuesEnemy and Hyperspace.playerVariables.og_test_variable == 1 then
		needSetValuesEnemy = false
		for _, sysName in ipairs(systemNameList) do
			if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(sysName)) then
				local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(sysName))
				loadTurret(shipManager, system, sysName)
			end
		end
	end
end)
script.on_internal_event(Defines.InternalEvents.JUMP_LEAVE, function()
	if needSetValuesEnemy then needSetValuesEnemy = false end
end)

script.on_internal_event(Defines.InternalEvents.GENERATOR_CREATE_SHIP_POST, function(name, sector, event, bp, shipManager)
	--print(shipManager.myBlueprint.blueprintName)
	for _, sysName in ipairs(systemNameList) do
		if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(sysName)) then
			local id, i = findStartingTurret(shipManager, sysName)
			--print(sysName.." "..tostring(id).." "..tostring(i))
			local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(sysName))
			system.table.blueprint = id
			system.table.currentAimingAngle = -90
		end
	end
	resetTurrets(shipManager)
	return Defines.Chain.CONTINUE
end)


--TURRET FIRING
local function findFiringPosition(targetPosition, shipManager, otherManager, pos, currentTurret, offensive)
	local firingPosition = targetPosition
	local beamMiss = false
	if offensive and shipManager.iShipId == 0 then
		firingPosition = Hyperspace.Pointf(10000, pos.y)
	elseif offensive and shipManager.iShipId == 1 then
		firingPosition = Hyperspace.Pointf(pos.x, -10000)
	elseif currentTurret.shot_radius or (otherManager and otherManager:HasAugmentation("DEFENSE_SCRAMBLER") > 0) then
		local rad = (currentTurret.shot_radius or 0)
		rad = rad/2
		if otherManager and otherManager:HasAugmentation("DEFENSE_SCRAMBLER") > 0 then
			rad = rad + scrambler_radius
		end
		local newFiringPosition = get_random_point_in_radius(firingPosition, rad)
		if get_distance(newFiringPosition, firingPosition) > 10 then beamMiss = true end
		firingPosition = newFiringPosition
	end
	return firingPosition, beamMiss
end
local function handleTurretBeams(system, blueprint, firingPos, beamMiss, shipManager, offensive, projectile, targetPosition)
	local spaceManager = Hyperspace.App.world.space
	if offensive then
		projectile.speed_magnitude = projectile.speed_magnitude * 0.25
		local projectile2 = spaceManager:CreateBeam(
			blueprint,
			firingPos,
			shipManager.iShipId,
			shipManager.iShipId,
			targetPosition,
			Hyperspace.Pointf(targetPosition.x, targetPosition.y + 1),
			1-shipManager.iShipId,
			1,
			math.rad(system.table.currentAimingAngle)
			)
		projectile2:ComputeHeading()
		projectile2.speed_magnitude = projectile2.speed_magnitude * 0.25
		projectile2.entryAngle = system.table.entryAngle
	elseif system.table.currentTarget.death_animation and not beamMiss then
		system.table.currentTarget.death_animation:Start(true)
		if mods.og.defended_ach and shipManager.iShipId == 0 then
			mods.og.defended_ach = mods.og.defended_ach + 1
		end
	elseif system.table.currentTarget.BlowUp and not beamMiss then
		system.table.currentTarget:BlowUp(false)
		if mods.og.defended_ach and shipManager.iShipId == 0 then
			mods.og.defended_ach = mods.og.defended_ach + 1
		end
	end
end
local function createTurretProjectile(currentTurret, system, blueprint, spawnPos, firingPos, shipManager, offensive)
	local spaceManager = Hyperspace.App.world.space
	if currentTurret.blueprint_type == 1 then
		local projectile = spaceManager:CreateLaserBlast(
			blueprint,
			spawnPos,
			shipManager.iShipId,
			shipManager.iShipId,
			((currentTurret.homing and (not offensive) and offset_point_in_direction(spawnPos, system.table.currentAimingAngle, 0, -50)) or firingPos),
			shipManager.iShipId,
			math.rad(system.table.currentAimingAngle)
			)
		projectile:ComputeHeading()
		return projectile
	elseif currentTurret.blueprint_type == 2 then
		local projectile = spaceManager:CreateMissile(
			blueprint,
			spawnPos,
			shipManager.iShipId,
			shipManager.iShipId,
			((currentTurret.homing and (not offensive) and offset_point_in_direction(spawnPos, system.table.currentAimingAngle, 0, -50)) or firingPos),
			shipManager.iShipId,
			math.rad(system.table.currentAimingAngle)
			)
		projectile:ComputeHeading()
		return projectile
	elseif currentTurret.blueprint_type == 3 then
		local projectile = spaceManager:CreateBeam(
			Hyperspace.Blueprints:GetWeaponBlueprint(currentTurret.blueprint_fake) ,
			spawnPos,
			shipManager.iShipId,
			1-shipManager.iShipId,
			firingPos,
			Hyperspace.Pointf(firingPos.x, firingPos.y + 1),
			shipManager.iShipId,
			1,
			math.rad(system.table.currentAimingAngle)
			)
		projectile:ComputeHeading()
		return projectile
	end
end

local function fireTurret(system, currentTurret, shipManager, otherManager, sysName, blueprint, pos, offensive, targetPosition, manningCrew)

	local currentShotNumber =(system.table.charges - 1) % #currentTurret.fire_points + 1
	local currentShot = currentTurret.fire_points[currentShotNumber]

	local firingPos, beamMiss = findFiringPosition(targetPosition, shipManager, otherManager, pos, currentTurret, offensive)
	local spawnPos = offset_point_in_direction(pos, system.table.currentAimingAngle, currentShot.x, currentShot.y)

	local projectile = createTurretProjectile(currentTurret, system, blueprint, spawnPos, firingPos, shipManager, offensive)
	if currentTurret.blueprint_type == 3 then
		handleTurretBeams(system, blueprint, firingPos, beamMiss, shipManager, offensive, projectile, targetPosition)
	end
	--handle missile consumption
	if currentTurret.ammo_consumption then
		system.table.ammo_consumed = system.table.ammo_consumed + currentTurret.ammo_consumption
		if system.table.ammo_consumed >= 1 then 
			shipManager:ModifyMissileCount(-1 * math.floor(system.table.ammo_consumed))
			system.table.ammo_consumed = system.table.ammo_consumed - math.floor(system.table.ammo_consumed)
		end
	end

	--handle sounds
	if blueprint.effects.launchSounds:size() > 0 then
		local randomSound = math.random(blueprint.effects.launchSounds:size()) - 1
		Hyperspace.Sounds:PlaySoundMix(blueprint.effects.launchSounds[randomSound], -1, false)
	end

	--manning crew
	if manningCrew and otherManager and otherManager._targetable.hostile then
		manningCrew:IncreaseSkill(3)
	end

	--clone cannon
	if blueprint.name == "OG_MISSILE_PROJECTILE_CLONE" then
		local race = "human"
		if manningCrew then
			race = manningCrew.type
			projectile.flight_animation = Hyperspace.Animations:GetAnimation(race.."_walk_up")
			projectile.flight_animation:Start(true)
		end
		userdata_table(projectile, "mods.og").clone_cannon = race
	end

	--cloak timer
	if offensive and shipManager.ship.bCloaked and shipManager.cloakSystem and shipManager:GetAugmentationValue("CLOAK_FIRE") < 1 and not currentTurret.stealth then
		local timer = shipManager.cloakSystem.timer
		timer.currTime = timer.currTime + timer.currGoal/5
		--shipManager.cloakSystem.timer.currTime = math.min(shipManager.cloakSystem.timer.currTime + (shipManager.cloakSystem.timer.maxTime/5), shipManager.cloakSystem.timer.maxTime)
	end

	--handle targetting
	if offensive and currentTurret.blueprint_type ~= 3 then
		if currentTurret.shot_radius then
			targetPosition = get_random_point_in_radius(targetPosition, currentTurret.shot_radius)
			projectile.bBroadcastTarget = true
		end
		projectile.entryAngle = system.table.entryAngle
		userdata_table(projectile, "mods.og").turret_projectile = {target = targetPosition, destination_space = otherManager.iShipId}
	elseif not offensive and currentTurret.blueprint_type ~= 3 then
		userdata_table(projectile, "mods.og").targeted = system.table.currentTarget
		if system.table.currentTarget and system.table.currentTarget.table then
			system.table.currentTarget.table.og_targeted = (system.table.currentTarget.table.og_targeted or 0) + 1
		end
	end

	--handle homing
	if not offensive and currentTurret.homing then
		local home_rate = currentTurret.homing
		if shipManager:HasAugmentation("UPG_OG_TURRET_SPEED") > 0 then
			home_rate = home_rate * (1.5 ^ shipManager:GetAugmentationValue("UPG_OG_TURRET_SPEED"))
		end
		userdata_table(projectile, "mods.og").homing = {target = system.table.currentTarget, turn_rate = home_rate}
	end

	--handle speed increase
	if shipManager:HasAugmentation("UPG_OG_TURRET_SPEED") > 0 then
		projectile.speed_magnitude = projectile.speed_magnitude * (1.5 ^ shipManager:GetAugmentationValue("UPG_OG_TURRET_SPEED"))
	end

	--reset turret target in defence mode
	if (not offensive) and ((not currentShot.auto_burst) or system.table.charges == 1) then
		system.table.currentTarget = nil
		system.table.currentlyTargetted = false
	end

	--reset turret target in offence mode
	local cApp = Hyperspace.App
	local combatControl = cApp.gui.combatControl
	local weapControl = combatControl.weapControl
	if offensive and xor(mods.og.turret_autofire_setting == 0, system.table.autoFireInvert) and ((not currentShot.auto_burst) or system.table.charges == 1) then
		system.table.currentTarget = nil
		system.table.currentlyTargetted = false
	end

	--turret animation
	currentTurret.image:Start(true)
	if currentTurret.image.info.numFrames > 1 then
		if currentTurret.multi_anim then
			currentTurret.image:SetCurrentFrame(1 + currentTurret.multi_anim.frames * (system.table.charges - 1))
		else
			currentTurret.image:SetCurrentFrame(1)
		end
	end
	
	--update turret values
	system.table.firingTime = currentShot.fire_delay
	system.table.charges = system.table.charges - 1
end

local function findTurretTarget(system, currentTurret, shipManager, pos, speed)
	local spaceManager = Hyperspace.App.world.space
	local targetList = {}
	local otherManager = Hyperspace.ships(1 - shipManager.iShipId)
	if otherManager and otherManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId("drones")) then 
		local deadDrones = {}
		for drone in vter(otherManager.droneSystem.drones) do
			if drone.bDead then
				deadDrones[drone.selfId] = true
			end
		end
		for drone in vter(spaceManager.drones) do
			if deadDrones[drone.selfId] and drone.table.og_targeted then
				drone.table.og_targeted = nil
			end
		end
	end
	for projectile in vter(spaceManager.projectiles) do
		--print(projectile.extend.name.." type:"..tostring(projectile:GetType()))
		local blueprint = Hyperspace.Blueprints:GetWeaponBlueprint(projectile.extend.name)
		local validTarget = checkValidTarget(projectile._targetable, currentTurret.defence_type, shipManager)
		local notTargeted = (not projectile.table.og_targeted) or (projectile.table.og_targeted < 2 and (currentTurret.multifire_homing or not currentTurret.homing)) or projectile.table.og_targeted < 1
		local projectileActive = not (projectile.missed or projectile.passedTarget or projectile.death_animation.tracker.running)
		if validTarget and notTargeted and projectileActive then
			local targetPos = projectile._targetable:GetRandomTargettingPoint(true)
			local targetVelocity = projectile._targetable:GetSpeed()
			targetVelocity = Hyperspace.Pointf(targetVelocity.x/(18.333*time_increment(true)), targetVelocity.y/(18.333*time_increment(true)))
			local target_angle, int_point, t = find_intercept_angle(pos, speed, targetPos, targetVelocity)
			if not target_angle then 
				target_angle = get_angle_between_points(pos, targetPos)
				int_point = targetPos
				t = 1
			end
			table.insert(targetList, {target = projectile, angle = target_angle})
		end
	end
	--print("drones")
	for drone in vter(spaceManager.drones) do
		local validTarget = checkValidTarget(drone._targetable, currentTurret.defence_type, shipManager)
		local notTargeted = (not drone.table.og_targeted) or (drone.table.og_targeted < 2 and not currentTurret.homing) or drone.table.og_targeted < 1
		local droneActive = not (drone.bDead or drone.arrived or drone.explosion.tracker.running)
		if validTarget and notTargeted and droneActive then
			local targetPos = drone._targetable:GetRandomTargettingPoint(true)
			local targetVelocity = drone._targetable:GetSpeed()
			targetVelocity = Hyperspace.Pointf(targetVelocity.x/(18.333*time_increment(true)), targetVelocity.y/(18.333*time_increment(true)))
			local target_angle, int_point, t = find_intercept_angle(pos, speed, targetPos, targetVelocity)
			if not target_angle then 
				target_angle = get_angle_between_points(pos, targetPos)
				int_point = targetPos
				t = 1
			end
			table.insert(targetList, {target = drone, angle = target_angle})
		elseif drone.bDead and drone.table.og_targeted then
			drone.table.og_targeted = nil
		end
	end
	if #targetList > 0 then
		local currentLowest = targetList[1]
		for i, targetTable in ipairs(targetList) do
			local diffCurrent = targetTable.angle - system.table.currentAimingAngle
			if diffCurrent > 180 then
				diffCurrent = diffCurrent - 360
			elseif diffCurrent <= -180 then
				diffCurrent = diffCurrent + 360
			end
			local diffLowest = currentLowest.angle - system.table.currentAimingAngle
			if diffLowest > 180 then
				diffLowest = diffLowest - 360
			elseif diffLowest <= -180 then
				diffLowest = diffLowest + 360
			end
			if math.abs(diffCurrent) < math.abs(diffLowest) then
				currentLowest = targetTable
			end
		end
		return currentLowest.target
	end
	return nil
end

--MAIN SYSTEM LOOP
local function getTurretRotationSpeed(currentTurret, shipManager, system)
	local currentMaxRotationSpeed = currentTurret.rotation_speed * (1 + shipManager:GetAugmentationValue("UPG_OG_TURRET_ROTATION"))
	if (system.table.currentlyTargetted or system.table.currentlyTargetting) and shipManager:HasAugmentation("UPG_OG_TURRET_MANUAL") > 0 then
		currentMaxRotationSpeed = currentMaxRotationSpeed + shipManager:GetAugmentationValue("UPG_OG_TURRET_MANUAL")
	end
	if currentTurret.hold_time and system.table.firingTime > currentTurret.hold_time then
		currentMaxRotationSpeed = 0
	elseif currentTurret.speed_reduction and system.table.firingTime > 0 then
		currentMaxRotationSpeed = currentMaxRotationSpeed * currentTurret.speed_reduction
	end
	return currentMaxRotationSpeed
end
local function findTurretManning(system, shipManager)
	if system.bBoostable then
		for crew in vter(shipManager.vCrewList) do
			if crew.bActiveManning and crew.currentSystem == system then
				system.iActiveManned = crew:GetSkillLevel(3)
				return crew
			end
		end
	end
	return nil
end
local function updateTurretCharge(currentTurret, system, shipManager, otherManager, chargeTime)
	if system.table.charges > currentTurret.charges then
		system.table.charges = currentTurret.charges
	else
		local validAmmo = not currentTurret.ammo_consumption or shipManager:GetMissileCount() > system.table.ammo_consumed + currentTurret.ammo_consumption * system.table.charges
		if system_ready(system) and system.table.charges < currentTurret.charges and validAmmo then
			local otherShipCloaking = otherManager and otherManager.ship.bCloaked
			local cloak_mult = (otherShipCloaking and 0.5) or 1
			system.table.time = system.table.time + cloak_mult * time_increment(true)/chargeTime
			if system.table.time >= 1 then
				local maxWithAmmo = ((not currentTurret.ammo_consumption) and math.huge) or ((shipManager:GetMissileCount() - system.table.ammo_consumed - currentTurret.ammo_consumption * system.table.charges)/currentTurret.ammo_consumption) 
				system.table.charges = math.min(system.table.charges + maxWithAmmo , currentTurret.charges, system.table.charges + currentTurret.charges_per_charge)
				if currentTurret.chain then
					system.table.chain_level = math.min(currentTurret.chain.count, system.table.chain_level + 1)
				end
				system.table.time = 0
			end
		elseif currentTurret.ammo_consumption and system.table.charges > 0 and shipManager:GetMissileCount() < system.table.ammo_consumed + currentTurret.ammo_consumption * system.table.charges then
			local amountOver = math.ceil((system.table.ammo_consumed + currentTurret.ammo_consumption * system.table.charges - shipManager:GetMissileCount())/2)
			system.table.charges = math.max(0, system.table.charges - amountOver)
		elseif not system_ready(system) then
			system.table.time = math.max(0, system.table.time - 6 * time_increment(true)/chargeTime)
			if system.table.time <= 0 and system.table.charges > 0 then
				system.table.charges = math.max(0, system.table.charges - currentTurret.charges_per_charge)
				if currentTurret.chain then
					system.table.chain_level = math.max(0, system.table.chain_level - 1)
				end
				system.table.time = 1
			elseif system.table.time <= 0 and system.table.chain_level >= 1 then
				system.table.chain_level = math.max(0, system.table.chain_level - 1)
				system.table.time = 1
			end
		end
	end
end

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if Hyperspace.App.menu.shipBuilder.bOpen or (shipManager.bJumping and shipManager.iShipId == 1) or shipManager.ship.hullIntegrity.first <= 0 then return end
	local shipGraph = Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId)
	local shipCorner = {x = shipManager.ship.shipImage.x + shipGraph.shipBox.x, y = shipManager.ship.shipImage.y + shipGraph.shipBox.y}
	local otherManager = Hyperspace.ships(1 - shipManager.iShipId)
	for _, sysName in ipairs(systemNameList) do
		if sysName == "og_turret_adaptive" and shipManager:HasAugmentation("UPG_OG_TURRET_ADAPTIVE_LARGE") > 0 then
			microTurrets["og_turret_adaptive"] = false
		elseif sysName == "og_turret_adaptive" then
			microTurrets["og_turret_adaptive"] = true
		end
		if systemCacheList[shipManager.iShipId][sysName] then
			local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(sysName))
			if system.table.blueprint == "" or not system.table.firingTime then 
				--[[print(tostring(system.table.blueprint == ""))
				print(tostring(not system.table.firingTime))
				print("skip"..sysName)]]
				goto END_SYSTEM_LOOP 
			end
			
			local turretLoc = turret_location[shipManager.ship.shipName] and turret_location[shipManager.ship.shipName][sysName] or {x = 0, y = 0, direction = turret_directions.right}
			local turretRestAngle = 90 * (turretLoc.direction or 0)
			if otherManager and otherManager:HasAugmentation("DEFENSE_SCRAMBLER") > 0 then
				turretRestAngle = normalize_angle(turretRestAngle + math.random(-135, 135))
			end
			local pos = {x = shipCorner.x + turretLoc.x, y = shipCorner.y + turretLoc.y}

			local currentTurret = turrets[ system.table.blueprint ]
			local currentMaxRotationSpeed = getTurretRotationSpeed(currentTurret, shipManager, system)
			
			local manningCrew = findTurretManning(system, shipManager)

			local chargeTime = get_charge_time(currentTurret, system)
			
			system.table.firingTime = system.table.firingTime - time_increment(true)
			updateTurretCharge(currentTurret, system, shipManager, otherManager, chargeTime)

			local blueprint = Hyperspace.Blueprints:GetWeaponBlueprint(currentTurret.blueprint)
			local speed = blueprint.speed
			if speed == 0 then
				local pType = blueprint.typeName
				if pType == "MISSILES" then
					speed = 35
				else
					speed = 60
				end
			end
			if shipManager:HasAugmentation("UPG_OG_TURRET_SPEED") > 0 then
				speed = speed * (1.5 ^ shipManager:GetAugmentationValue("UPG_OG_TURRET_SPEED"))
			end

			if not system_ready(system) then
				currentTurret.image.tracker:Stop(true)
				currentTurret.image:SetCurrentFrame(0)
				system.table.currentTarget = nil
				goto END_SYSTEM_LOOP
			elseif system.table.currentlyTargetting then 
				local mousePosPlayer = worldToPlayerLocation(Hyperspace.Mouse.position)
				local target_angle = get_angle_between_points(pos, mousePosPlayer)
				if math.abs(angle_diff(system.table.currentAimingAngle, target_angle)) > 0.01 then
					system.table.currentAimingAngle = move_angle_to(system.table.currentAimingAngle, target_angle, currentMaxRotationSpeed * time_increment(true))
				end
			elseif system.table.state == turret_states.defence and not system.table.currentlyTargetted then
				
				if system.table.currentTargetTemp then
					system.table.currentTarget = system.table.currentTargetTemp
					system.table.entryAngle = math.random(360)
					system.table.currentTargetTemp = nil
					system.table.currentlyTargetted = false
				end

				if shipManager.iShipId == 0 and system.table.currentTarget then
					if math.abs(angle_diff(system.table.currentAimingAngle, 0)) > 0.01  then
						system.table.currentAimingAngle = move_angle_to(system.table.currentAimingAngle, 0, currentMaxRotationSpeed * time_increment(true))
					end
					if not ( Hyperspace.ships.enemy and Hyperspace.ships.enemy._targetable.hostile ) then
						system.table.currentTarget = nil
						system.table.currentlyTargetted = false
					end
				elseif shipManager.iShipId == 1 then
					if math.abs(angle_diff(system.table.currentAimingAngle, -90)) > 0.01 then
						system.table.currentAimingAngle = move_angle_to(system.table.currentAimingAngle, -90, currentMaxRotationSpeed * time_increment(true))
					end
				else
					if math.abs(angle_diff(system.table.currentAimingAngle, turretRestAngle)) > 0.01 then
						system.table.currentAimingAngle = move_angle_to(system.table.currentAimingAngle, turretRestAngle, currentMaxRotationSpeed * time_increment(true))
					end
				end

				local hasTarget = system.table.currentTarget or shipManager.iShipId == 1
				local readyFire = system.table.firingTime <= 0 and system.table.charges > 0 
				local otherShipTargetable = otherManager and not otherManager.ship.bCloaked
				--local notCloaked = not shipManager.ship.bCloaked

				local aimedAheadPlayer = shipManager.iShipId == 0 and math.abs(angle_diff(system.table.currentAimingAngle, 0)) < (currentTurret.aim_cone or 1)
				local aimedAheadEnemy = shipManager.iShipId == 1 and math.abs(angle_diff(system.table.currentAimingAngle, -90)) < (currentTurret.aim_cone or 1)
				local shouldFire = hasTarget and readyFire and otherShipTargetable --and notCloaked
				if (aimedAheadPlayer or aimedAheadEnemy) and shouldFire then
					local roomPosition = (system.table.currentTarget and otherManager:GetRoomCenter(system.table.currentTarget.roomId)) or otherManager:GetRandomRoomCenter()
					if currentTurret.blueprint_type == 3 and system.table.currentTarget then
						local targetShipGraph = Hyperspace.ShipGraph.GetShipInfo(otherManager.iShipId)
						local tempRoomPos = targetShipGraph:GetSlotWorldPosition(system.table.currentTarget.slotId, system.table.currentTarget.roomId)
						roomPosition = Hyperspace.Pointf(tempRoomPos.x, tempRoomPos.y) 
					end
					fireTurret(system, currentTurret, shipManager, otherManager, sysName, blueprint, pos, true, roomPosition, manningCrew)
				end
			elseif system.table.state == turret_states.offence or system.table.currentlyTargetted then
				if system.table.currentlyTargetted and system.table.currentTargetTemp then
					system.table.currentTarget = system.table.currentTargetTemp
					system.table.currentTargetTemp = nil
				end
				--Precheck target
				if system.table.currentTarget then
					local projectileDead = system.table.currentTarget.death_animation and system.table.currentTarget.death_animation.tracker.running
					local droneDead = (system.table.currentTarget.explosion and system.table.currentTarget.explosion.tracker.running) or system.table.currentTarget.bDead
					local targetDead = projectileDead or droneDead

					local projectileInactive = system.table.currentTarget.missed or system.table.currentTarget.passedTarget

					local targetInvalid = not checkValidTarget(system.table.currentTarget._targetable, currentTurret.defence_type, shipManager)
					local notThisSpace = system.table.currentTarget._targetable:GetSpaceId() ~= shipManager.iShipId and not system.table.currentlyTargetted
					local tryRetarget = system.table.charges <= 0 and not system.table.currentlyTargetted
					if targetDead or targetInvalid or tryRetarget or projectileInactive or notThisSpace then
						system.table.currentTarget = nil
						system.table.currentlyTargetted = false
					end
				end
				--Find New Target
				if not system.table.currentTarget then
					system.table.currentTarget = findTurretTarget(system, currentTurret, shipManager, pos, speed)
				end
				--Targeting Logic
				if system.table.currentTarget and system.table.currentTarget._targetable:GetSpaceId() == shipManager.iShipId then
					--Get Target Info
					local targetPos = system.table.currentTarget._targetable:GetRandomTargettingPoint(true)
					local targetVelocity = system.table.currentTarget._targetable:GetSpeed()
					targetVelocity = Hyperspace.Pointf(targetVelocity.x/(18.333*time_increment(true)), targetVelocity.y/(18.333*time_increment(true)))
					
					--Find Targetting Point
					local target_angle, int_point, t
					if currentTurret.blueprint_type ~= 3  then
						target_angle, int_point, t = find_intercept_angle(pos, speed, targetPos, targetVelocity)
						if target_angle then
							local tempChargeShot = (system.table.charges - 1)
							local currentShotNumber = tempChargeShot % #currentTurret.fire_points + 1
							local currentShot = currentTurret.fire_points[currentShotNumber]
							local tempNewPos = offset_point_in_direction(pos, target_angle, currentShot.x, currentShot.y)
							target_angle, int_point, t = find_intercept_angle(tempNewPos, speed, targetPos, targetVelocity)
						end
					end
					if not target_angle then 
						target_angle = get_angle_between_points(pos, targetPos)
						int_point = targetPos
						t = 1 -- calculate properly
					end

					--Rotate Turret
					if math.abs(angle_diff(system.table.currentAimingAngle, target_angle)) > 0.01 then
						system.table.currentAimingAngle = move_angle_to(system.table.currentAimingAngle, target_angle, currentMaxRotationSpeed * time_increment(true))
					end

					--Fire if within aim cone
					--local notCloaked = not shipManager.ship.bCloaked
					if math.abs(angle_diff(system.table.currentAimingAngle, target_angle)) < (currentTurret.aim_cone or 0.5) and system.table.firingTime <= 0 and system.table.charges > 0 then
						fireTurret(system, currentTurret, shipManager, otherManager, sysName, blueprint, pos, false, Hyperspace.Pointf(int_point.x, int_point.y), manningCrew)
					end
				elseif system.table.currentTarget and system.table.currentTarget.entryAngle then
					local target_angle = normalize_angle(system.table.currentTarget.entryAngle)
					if math.abs(angle_diff(system.table.currentAimingAngle, target_angle)) > 0.01 then
						system.table.currentAimingAngle = move_angle_to(system.table.currentAimingAngle, target_angle, currentMaxRotationSpeed * time_increment(true))
					end
				else -- if no possible target
					if math.abs(angle_diff(system.table.currentAimingAngle, turretRestAngle)) > 0.01 then
						system.table.currentAimingAngle = move_angle_to(system.table.currentAimingAngle, turretRestAngle, currentMaxRotationSpeed * time_increment(true))
					end
				end
			end
			local lastShot = ((system.table.charges) % #currentTurret.fire_points) + 1
			currentTurret.image:Update()
			if (currentTurret.image.currentFrame == currentTurret.image.info.numFrames - 1) or (currentTurret.multi_anim and currentTurret.image.currentFrame > currentTurret.multi_anim.frames * lastShot) then
				currentTurret.image.tracker:Stop(true)
				currentTurret.image:SetCurrentFrame(0)
			end

			if shipManager.iShipId == 1 and (not system.table.currentTarget) and system.table.charges >= currentTurret.charges and (currentTurret.enemy_burst or 1) > 0 then
				system.table.state = turret_states.defence
				system.table.entryAngle = math.random(360)
			elseif shipManager.iShipId == 1 and system.table.charges <= currentTurret.charges - (currentTurret.enemy_burst or 1) then
				system.table.state = turret_states.offence
			end
			if shipManager.iShipId == 1 and system.table.state == turret_states.defence and not Hyperspace.ships.enemy._targetable.hostile then
				system.table.state = turret_states.offence
			end
		end
		::END_SYSTEM_LOOP::
	end
end)

--TURRET PROJECTILE LOOP
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(s)
	if s.iShipId == 1 then return end
	local spaceManager = Hyperspace.App.world.space
	for projectile in vter(spaceManager.projectiles) do
		local shipManager = Hyperspace.ships(projectile.currentSpace)
		if not shipManager then 
			goto END_PROJECTILE_LOOP 
		end
		local ship = shipManager.ship
		local shipGraph = Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId)
		local shipBound_x = ship.shipImage.x + shipGraph.shipBox.x + ship.shipImage.w
		local shipBound_y = ship.shipImage.y + shipGraph.shipBox.y
		local playerFired = projectile.currentSpace == 0 and (projectile.position.x > shipBound_x or projectile.position.x > 800)
		local enemyFired = projectile.currentSpace == 1 and projectile.position.y < shipBound_y
		if userdata_table(projectile, "mods.og").turret_projectile and (playerFired or enemyFired) then
			projectile:SetDestinationSpace(userdata_table(projectile, "mods.og").turret_projectile.destination_space)
			projectile.target = userdata_table(projectile, "mods.og").turret_projectile.target
			projectile:ComputeHeading()
			if projectile.currentSpace == 0 then
				projectile.heading = 0
			else
				projectile.heading = -90
			end
			userdata_table(projectile, "mods.og").turret_projectile = nil
		end

		if userdata_table(projectile, "mods.og").targeted and projectile.passedTarget then
			userdata_table(projectile, "mods.og").targeted.table.og_targeted = math.max(0, (userdata_table(projectile, "mods.og").targeted.table.og_targeted - 1 or 1))
			userdata_table(projectile, "mods.og").targeted = nil
		end

		if userdata_table(projectile, "mods.og").homing and checkValidTarget(userdata_table(projectile, "mods.og").homing.target._targetable, defence_types.ALL, shipManager) then
			local target = userdata_table(projectile, "mods.og").homing.target
			local currentAngle = get_angle_between_points(projectile.position, projectile.target)

			local targetPos = target._targetable:GetRandomTargettingPoint(true)
			local targetVelocity = target._targetable:GetSpeed()
			local thisVelocity = projectile._targetable:GetSpeed()
			local speed = math.sqrt(thisVelocity.x^2 + thisVelocity.y^2)
			local target_angle, int_point, t = find_intercept_angle(projectile.position, speed, targetPos, targetVelocity)
			if not target_angle then 
				target_angle = get_angle_between_points(projectile.position, targetPos)
				int_point = targetPos
				t = 1
			end
			local currentMaxRotationSpeed = userdata_table(projectile, "mods.og").homing.turn_rate
			currentAngle = move_angle_to(currentAngle, target_angle, currentMaxRotationSpeed * time_increment(true))
			if math.abs(angle_diff(currentAngle, target_angle)) < 0.01 and get_distance(projectile.position, targetPos) < 50 then
				projectile.target = int_point
				--print("end homing, close")
				userdata_table(projectile, "mods.og").homing = nil
			else
				projectile.target = offset_point_in_direction(projectile.position, currentAngle, 0, -50)
			end
			projectile:ComputeHeading()
		elseif userdata_table(projectile, "mods.og").homing then
			userdata_table(projectile, "mods.og").homing = nil
		end
		::END_PROJECTILE_LOOP::
	end
end)

--ADAPTIVE TURRET POSITIONING
local positioning_turret = false
local lastPosition = {x = 0, y = 0, direction = turret_directions.right}
script.on_game_event("OG_TURRET_ADAPTIVE_POSITION", false, function() 
	positioning_turret = true
	lastPosition = {}
	lastPosition.x = turret_location[Hyperspace.ships.player.ship.shipName]["og_turret_adaptive"].x
	lastPosition.y = turret_location[Hyperspace.ships.player.ship.shipName]["og_turret_adaptive"].y
	lastPosition.direction = turret_location[Hyperspace.ships.player.ship.shipName]["og_turret_adaptive"].direction
end)

script.on_internal_event(Defines.InternalEvents.ON_MOUSE_L_BUTTON_DOWN, function(x, y)
	if positioning_turret then
		positioning_turret = false
		Hyperspace.playerVariables.og_turret_adaptive_saved_x = turret_location[Hyperspace.ships.player.ship.shipName]["og_turret_adaptive"].x
		Hyperspace.playerVariables.og_turret_adaptive_saved_y = turret_location[Hyperspace.ships.player.ship.shipName]["og_turret_adaptive"].y
		Hyperspace.playerVariables.og_turret_adaptive_saved_direction = 2 * turret_location[Hyperspace.ships.player.ship.shipName]["og_turret_adaptive"].direction
	end
	return Defines.Chain.CONTINUE
end)

script.on_internal_event(Defines.InternalEvents.ON_MOUSE_R_BUTTON_DOWN, function(x, y)
	if positioning_turret then
		positioning_turret = false
		turret_location[Hyperspace.ships.player.ship.shipName]["og_turret_adaptive"] = lastPosition
	end
	return Defines.Chain.CONTINUE
end)

script.on_internal_event(Defines.InternalEvents.ON_KEY_DOWN, function(key)
	if key == 114 and positioning_turret then --r key
		local newDir = turret_location[Hyperspace.ships.player.ship.shipName]["og_turret_adaptive"].direction + 0.5
		if newDir >= 2 then newDir = -2 end
		turret_location[Hyperspace.ships.player.ship.shipName]["og_turret_adaptive"].direction = newDir
	end
	return Defines.Chain.CONTINUE
end)

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
	if not Hyperspace.ships.player then return end
	if positioning_turret then
		local mousePosPlayer = worldToPlayerLocation(Hyperspace.Mouse.position)
		local ship = Hyperspace.ships.player.ship
		local shipGraph = Hyperspace.ShipGraph.GetShipInfo(0)
		local shipCorner = {x = ship.shipImage.x + shipGraph.shipBox.x, y = ship.shipImage.y + shipGraph.shipBox.y}
		local mousePosRelative = {x = mousePosPlayer.x - shipCorner.x, y = mousePosPlayer.y - shipCorner.y}
		local withinRect = mousePosRelative.x > 0 and mousePosRelative.x < ship.shipImage.w and mousePosRelative.y > 0 and mousePosRelative.y < ship.shipImage.h
		local mousePosMiddle = {x = mousePosRelative.x - ship.shipImage.w/2, y = mousePosRelative.y - ship.shipImage.h/2}
		local withinShield = isPointInEllipse(mousePosMiddle, ship.baseEllipse)
		--print("ellipse x:"..ship.baseEllipse.center.x.." y:"..ship.baseEllipse.center.y.." a:"..ship.baseEllipse.a.." b:"..ship.baseEllipse.b)
		--print("mouse x:"..mousePosRelative.x.." y:"..mousePosRelative.y)
		if withinRect and withinShield then
			turret_location[ship.shipName]["og_turret_adaptive"].x = mousePosRelative.x
			turret_location[ship.shipName]["og_turret_adaptive"].y = mousePosRelative.y
		end
	end
	if Hyperspace.App.menu.shipBuilder.bOpen then
		if Hyperspace.playerVariables.og_turret_adaptive_saved_x > 0 then
			local shipManager = Hyperspace.ships.player
			if turret_location[shipManager.ship.shipName] and turret_location[shipManager.ship.shipName]["og_turret_adaptive"] then
				turret_location[shipManager.ship.shipName]["og_turret_adaptive"].x = Hyperspace.playerVariables.og_turret_adaptive_saved_x
				turret_location[shipManager.ship.shipName]["og_turret_adaptive"].y = Hyperspace.playerVariables.og_turret_adaptive_saved_y
				turret_location[shipManager.ship.shipName]["og_turret_adaptive"].direction = Hyperspace.playerVariables.og_turret_adaptive_saved_direction/2
			end
		else
			local systemId = Hyperspace.ShipSystem.NameToSystemId("og_turret_adaptive")
			local shipManager = Hyperspace.ships.player
			local sysInfo = Hyperspace.ships.player.myBlueprint.systemInfo
			if sysInfo:has_key(systemId) then
				local roomId = sysInfo[systemId].location[0]
				local pos = shipManager:GetRoomCenter(roomId)

				local ship = shipManager.ship
				local shipGraph = Hyperspace.ShipGraph.GetShipInfo(0)
				local shipCorner = {x = ship.shipImage.x + shipGraph.shipBox.x, y = ship.shipImage.y + shipGraph.shipBox.y}
				local posRelative = {x = pos.x - shipCorner.x, y = pos.y - shipCorner.y}

				turret_location[shipManager.ship.shipName]["og_turret_adaptive"].x = posRelative.x
				turret_location[shipManager.ship.shipName]["og_turret_adaptive"].y = posRelative.y
			end
		end
	end
end)

--NEW DAWN TURRET EFFECT
script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA, function(shipManager, projectile, location, damage, forceHit, shipFriendlyFire)
	local room = get_room_at_location(shipManager, location, true)
	local system = shipManager:GetSystemInRoom(room)
	if system and systemNameCheck[Hyperspace.ShipSystem.SystemIdToName(system.iSystemType)] then
		local sysName = Hyperspace.ShipSystem.SystemIdToName(system.iSystemType)
		local currentTurret = turrets[ system.table.blueprint ]
		if currentTurret.dawn and damage.iDamage + damage.iSystemDamage > 0 then
			damage.iSystemDamage = damage.iSystemDamage + 1
		end
	end
	return Defines.Chain.CONTINUE, forceHit, shipFriendlyFire
end)

script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(shipManager, projectile, location, damage, realNewTile, beamHitType)
	if beamHitType ~= Defines.BeamHit.NEW_ROOM then return Defines.Chain.CONTINUE, beamHitType end
	local room = get_room_at_location(shipManager, location, true)
	local system = shipManager:GetSystemInRoom(room)
	if system and systemNameCheck[Hyperspace.ShipSystem.SystemIdToName(system.iSystemType)] then
		local sysName = Hyperspace.ShipSystem.SystemIdToName(system.iSystemType)
		local currentTurret = turrets[ system.table.blueprint ]
		if currentTurret.dawn and damage.iDamage + damage.iSystemDamage > 0 then
			damage.iSystemDamage = damage.iSystemDamage + 1
		end
	end
	return Defines.Chain.CONTINUE, beamHitType
end)

local render_vunerable = mods.og.render_vunerable

script.on_render_event(Defines.RenderEvents.SHIP_FLOOR, function() end, function(ship) 
	local shipManager = Hyperspace.ships(ship.iShipId)
	for room in vter(shipManager.ship.vRoomList) do
		local system = shipManager:GetSystemInRoom(room.iRoomId)
		--print("room:"..room.iRoomId.." sys:"..tostring(system))
		if system and systemNameCheck[Hyperspace.ShipSystem.SystemIdToName(system.iSystemType)] then
			--print("has system render")
			local sysName = Hyperspace.ShipSystem.SystemIdToName(system.iSystemType)
			local currentTurret = turrets[ system.table.blueprint ]
			if currentTurret and currentTurret.dawn then
				--print("render render_vunerable system")
				render_vunerable(room)
			end
		end
	end
end)


script.on_internal_event(Defines.InternalEvents.PROJECTILE_UPDATE_PRE, function(projectile)
	if not userdata_table(projectile, "mods.og").projectile_space then
		userdata_table(projectile, "mods.og").projectile_space = {last_space = projectile.currentSpace}
	else
		local projTable = userdata_table(projectile, "mods.og").projectile_space
		if projectile.currentSpace ~= projTable.last_space and defence_types.ALL[projectile._targetable.type] then
			local ship = Hyperspace.ships(projectile.currentSpace).ship
			local shipGraph = Hyperspace.ShipGraph.GetShipInfo(projectile.currentSpace)
			local shipCorner = {x = ship.shipImage.x + shipGraph.shipBox.x, y = ship.shipImage.y + shipGraph.shipBox.y}
			local ellipsePos = {x = ship.baseEllipse.center.x + shipCorner.x + ship.shipImage.w/2, y = ship.baseEllipse.center.y + shipCorner.y + ship.shipImage.h/2}
			local baseEllipseCorrected = {center = ellipsePos, a = ship.baseEllipse.a, b = ship.baseEllipse.b}
			local withinShield = isPointInEllipse(projectile.position, baseEllipseCorrected)
			if withinShield then
				--print("MOVE PROJECTILE")
				local dx = projectile.position.x - baseEllipseCorrected.center.x
				local verticalOffset = baseEllipseCorrected.b * math.sqrt(1 - (dx^2 / baseEllipseCorrected.a^2))
				local topY = baseEllipseCorrected.center.y + verticalOffset
				local bottomY = baseEllipseCorrected.center.y - verticalOffset
				if math.abs(projectile.position.y - topY) < math.abs(projectile.position.y - bottomY) then
					projectile.position.y = topY + 1
				else
					projectile.position.y = bottomY - 1
				end
			end 
		end
		userdata_table(projectile, "mods.og").projectile_space.last_space = projectile.currentSpace
	end
	if projectile.sub_start and projectile.currentSpace ~= projectile.destinationSpace then
		local ship = Hyperspace.ships(projectile.destinationSpace).ship
		local shipGraph = Hyperspace.ShipGraph.GetShipInfo(projectile.destinationSpace)
		local shipCorner = {x = ship.shipImage.x + shipGraph.shipBox.x, y = ship.shipImage.y + shipGraph.shipBox.y}
		local ellipsePos = {x = ship.baseEllipse.center.x + shipCorner.x + ship.shipImage.w/2, y = ship.baseEllipse.center.y + shipCorner.y + ship.shipImage.h/2}
		local baseEllipseCorrected = {center = ellipsePos, a = ship.baseEllipse.a, b = ship.baseEllipse.b}
		local withinShield = isPointInEllipse(projectile.sub_start, baseEllipseCorrected)
		--print("ellipse: center x:"..ship.baseEllipse.center.x.." y:"..ship.baseEllipse.center.y.." a:"..ship.baseEllipse.a.." b:"..ship.baseEllipse.b)
		--print("point: x:"..projectile.sub_start.x.." y:"..projectile.sub_start.y)
		if withinShield then
			--print("MOVE BEAM START")
			local dx = projectile.sub_start.x - baseEllipseCorrected.center.x
			local verticalOffset = baseEllipseCorrected.b * math.sqrt(1 - (dx^2 / baseEllipseCorrected.a^2))
			local topY = baseEllipseCorrected.center.y + verticalOffset
			local bottomY = baseEllipseCorrected.center.y - verticalOffset
			if math.abs(projectile.sub_start.y - topY) < math.abs(projectile.sub_start.y - bottomY) then
				projectile.sub_start.y = topY + 1
			else
				projectile.sub_start.y = bottomY - 1
			end
		end
	end
	return Defines.Chain.CONTINUE
end)

--
script.on_internal_event(Defines.InternalEvents.PRE_CREATE_CHOICEBOX, function(event)
	local removeItem = event.stuff.removeItem
	--print(tostring(removeItem))
	if turrets[removeItem] then
		local hasItem = false
		for item in vter(Hyperspace.App.gui.equipScreen:GetCargoHold()) do
			if item == removeItem then
				hasItem = true
			end
		end
		local shipManager = Hyperspace.ships.player
		if shipManager:HasSystem(3) then
			for weapon in vter(shipManager.weaponSystem.weapons) do
				if weapon.blueprint.name == removeItem then
					hasItem = true
				end
			end
		end
		if not hasItem then
			for _, sysName in ipairs(systemNameList) do
				if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(sysName)) then
					local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(sysName))
					local currentTurretName = system.table.blueprint
					if currentTurretName == removeItem then
						event.stuff.removeItem = "OG_TURRET_REMOVE_"..event.stuff.removeItem
					end
				end
			end
		end
	end
end)

script.on_internal_event(Defines.InternalEvents.POST_CREATE_CHOICEBOX, function(choiceBox, event)
	local removeItem = event.stuff.removeItem
	if string.sub(removeItem, 1, 17) == "OG_TURRET_REMOVE_" then
		removeItem = string.sub(removeItem, 18)
		local shipManager = Hyperspace.ships.player
		if removeItem then
			for _, sysName in ipairs(systemNameList) do
				if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(sysName)) then
					local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(sysName))
					local currentTurretName = system.table.blueprint
					if currentTurretName == removeItem then
						event.stuff.removeItem = "	 "
						Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemBlueprintVarName] = -1
					end
				end
			end
		end
	end
end)

script.on_internal_event(Defines.InternalEvents.HAS_EQUIPMENT, function(shipManager, equipment, value)
	if turrets[equipment] then
		for _, sysName in ipairs(systemNameList) do
			if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(sysName)) then
				local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(sysName))
				local currentTurretName = system.table.blueprint
				if currentTurretName == equipment then
					value = value + 1
				end
			end
		end
	else
		local list = Hyperspace.Blueprints:GetBlueprintList(equipment)
		if list:size() > 0 then
			for item in vter(list) do
				if turrets[item] then
					for _, sysName in ipairs(systemNameList) do
						if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(sysName)) then
							local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(sysName))
							local currentTurretName = system.table.blueprint
							if currentTurretName == item then
								value = value + 1
							end
						end
					end
				end
			end
		end
	end
	return Defines.Chain.CONTINUE, value
end)



script.on_internal_event(Defines.InternalEvents.HAS_EQUIPMENT, function(shipManager, equipment, value)
	if equipment == "BLUELIST_DRONES_DEFENSE" then
		for _, sysName in ipairs(systemNameList) do
			if Hyperspace.ships.player:HasSystem(Hyperspace.ShipSystem.NameToSystemId(sysName)) and Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemBlueprintVarName] > 0 then
				value = value + 1
			end
		end
	end
	return Defines.Chain.CONTINUE, value
end)