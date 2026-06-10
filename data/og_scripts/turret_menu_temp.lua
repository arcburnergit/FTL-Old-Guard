local vter = mods.multiverse.vter
local time_increment = mods.multiverse.time_increment
local userdata_table = mods.multiverse.userdata_table
local node_child_iter = mods.multiverse.node_child_iter
local node_get_number_default = mods.multiverse.node_get_number_default

local systemName = "og_turret"
local microTurrets = mods.og.microTurrets
local systemNameList = mods.og.systemNameList
local systemNameCheck = {}
for _, sysName in ipairs(systemNameList) do
	systemNameCheck[sysName] = true
end

local emptyReq = Hyperspace.ChoiceReq()
local blueReq = Hyperspace.ChoiceReq()
blueReq.object = "pilot"
blueReq.blue = true
blueReq.max_level = mods.multiverse.INT_MAX
blueReq.max_group = -1

local function string_starts(str, start)
	return string.sub(str, 1, string.len(start)) == start
end

local turretBlueprintsList = mods.og.turretBlueprintsList
local turrets = mods.og.turrets

local saveTurret = mods.og.saveTurret

local systemBlueprintVarName = mods.og.systemBlueprintVarName
local systemStateVarName = mods.og.systemStateVarName
local systemChargesVarName = mods.og.systemChargesVarName
local systemTimeVarName = mods.og.systemTimeVarName

script.on_internal_event(Defines.InternalEvents.HAS_EQUIPMENT, function(shipManager, equipment, value) 
	if equipment == "OG_HAS_TURRET" then
		for _, sysName in ipairs(systemNameList) do
			if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(sysName)) then
				value = value + 1
			end
		end
	end
	return Defines.Chain.CONTINUE, value
end)

local manageText = {
	nevermind = Hyperspace.Text:GetText("og_lua_turret_manage_nevermind"),
	uninstall = Hyperspace.Text:GetText("og_lua_turret_manage_uninstall"),
	empty = Hyperspace.Text:GetText("og_lua_turret_manage_empty"),
	leave = Hyperspace.Text:GetText("og_lua_turret_manage_leave"),
	install = Hyperspace.Text:GetText("og_lua_turret_manage_install"),
}

local hookedEvents = {}
local function turret_install_event(installEvent, sysName, shipManager, eventManager, system, toAddBlueprint)
	--print("turret_install_event"..installEvent.eventName.." sys:"..sysName)
	if shipManager:HasSystem(3) then
		for weapon in vter(shipManager.weaponSystem.weapons) do
			--print("weapons:"..weapon.blueprint.name.." "..tostring((turrets[weapon.blueprint.name] and true) or false).." "..tostring((turrets[weapon.blueprint.name].mini and true) or false).." "..tostring((not microTurrets[sysName] and true) or false))
			if turrets[weapon.blueprint.name] and (turrets[weapon.blueprint.name].mini or not microTurrets[sysName]) then
				local removeEvent = eventManager:CreateEvent("STORAGE_CHECK_OG_TURRET_EMPTY", 0, false)
				removeEvent.eventName = removeEvent.eventName.."_INSTALL_"..sysName.."_"..weapon.blueprint.name
				if toAddBlueprint then
					removeEvent.eventName = removeEvent.eventName.."_REFUND_"..toAddBlueprint.name
				end
				--[[local index = 0
				for i, turretId in ipairs(turretBlueprintsList) do
					if turretId == weapon.blueprint.name then
						index = i
					end
				end]]
				if not hookedEvents[removeEvent.eventName] then
					hookedEvents[removeEvent.eventName] = true
					script.on_game_event(removeEvent.eventName, false, function()
						--Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemBlueprintVarName] = index
						system.table.blueprint = weapon.blueprint.name
						shipManager:RemoveItem(weapon.blueprint.name, true)
						if toAddBlueprint then
							Hyperspace.App.gui.equipScreen:AddWeapon(toAddBlueprint, true, false)
						end
						saveTurret(shipManager, system, sysName)
						return
					end)
				end
				--removeEvent.stuff.removeItem = weapon.blueprint.name
				removeEvent.stuff.weapon = weapon.blueprint
				installEvent:AddChoice(removeEvent, manageText.install, emptyReq, false)
				--print("added choice:"..weapon.blueprint.name)
			end
		end
	end
	for item in vter(Hyperspace.App.gui.equipScreen:GetCargoHold()) do
		--print("items:"..item)
		if turrets[item] and (turrets[item].mini or not microTurrets[sysName]) then

			local removeEvent = eventManager:CreateEvent("STORAGE_CHECK_OG_TURRET_EMPTY", 0, false)
			removeEvent.eventName = removeEvent.eventName.."_INSTALL_"..sysName.."_"..item
			if toAddBlueprint then
				removeEvent.eventName = removeEvent.eventName.."_REFUND_"..toAddBlueprint.name
			end
			--[[local index = 0
			for i, turretId in ipairs(turretBlueprintsList) do
				if turretId == item then
					index = i
				end
			end]]
			if not hookedEvents[removeEvent.eventName] then
				hookedEvents[removeEvent.eventName] = true
				script.on_game_event(removeEvent.eventName, false, function()
					--Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemBlueprintVarName] = index
					system.table.blueprint = item
					shipManager:RemoveItem(item, true)
					if toAddBlueprint then
						Hyperspace.App.gui.equipScreen:AddWeapon(toAddBlueprint, true, false)
					end
					saveTurret(shipManager, system, sysName)
					return
				end)
			end
			--removeEvent.stuff.removeItem = item
			local blueprint = Hyperspace.Blueprints:GetWeaponBlueprint(item)
			removeEvent.stuff.weapon = blueprint

			installEvent:AddChoice(removeEvent, manageText.install, emptyReq, false)

			--print("added item choice:"..item)
		end
	end
end


script.on_internal_event(Defines.InternalEvents.PRE_CREATE_CHOICEBOX, function(event)
	local eventManager = Hyperspace.Event
	local shipManager = Hyperspace.ships.player
	if event.eventName == "STORAGE_CHECK_OG_TURRET" then 
		for _, sysName in ipairs(systemNameList) do
			if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(sysName)) then
				local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(sysName))
				if system.table.blueprint == "" then
					local installEvent = eventManager:CreateEvent("STORAGE_CHECK_OG_TURRET_INSTALL", 0, false)
					turret_install_event(installEvent, sysName, shipManager, eventManager, system, nil)
					event:AddChoice(installEvent, manageText.empty, emptyReq, false)
				else
					local removeEvent = eventManager:CreateEvent("STORAGE_CHECK_OG_TURRET_REMOVE", 0, false)
					removeEvent:RemoveChoice(0)

					local toAddBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint(system.table.blueprint)
					local addEvent = eventManager:CreateEvent("STORAGE_CHECK_OG_TURRET_EMPTY", 0, false)
					addEvent.eventName = addEvent.eventName.."_REFUND_"..toAddBlueprint.name
					if not hookedEvents[addEvent.eventName] then
						hookedEvents[addEvent.eventName] = true
						script.on_game_event(addEvent.eventName, false, function()
							Hyperspace.App.gui.equipScreen:AddWeapon(toAddBlueprint, true, false)
							saveTurret(shipManager, system, sysName)
							return
						end)
					end
					removeEvent:AddChoice(addEvent, manageText.leave, emptyReq, false)

					removeEvent.eventName = removeEvent.eventName.."_"..sysName
					turret_install_event(removeEvent, sysName, shipManager, eventManager, system, toAddBlueprint)

					if not hookedEvents[removeEvent.eventName] then
						hookedEvents[removeEvent.eventName] = true
						script.on_game_event(removeEvent.eventName, false, function()
							local sys = Hyperspace.ships.player:GetSystem(Hyperspace.ShipSystem.NameToSystemId(sysName))
							if sys.table then
								sys.table.blueprint = ""
								sys.table.charges = 0
								sys.table.time = 0
								sys.table.firingTime = 0
								sys.table.currentShot = 0
								sys.table.currentTarget = nil
								sys.table.currentlyTargetting = false
								saveTurret(Hyperspace.ships.player, sys, sysName)
							else
								print("og: failed to get sys.table")
							end
							return
						end)
					end
					event:AddChoice(removeEvent, manageText.uninstall, emptyReq, false)
				end
			end
		end
	elseif string.sub(event.eventName, 1, 37) == "STORAGE_CHECK_OG_TURRET_EMPTY_INSTALL" then
		event.stuff.weapon = nil
	end
end)

local turret_bases = {}
turret_bases["OG_TURRET_BASE_LASER"] = true
turret_bases["OG_TURRET_BASE_ION"] = true
turret_bases["OG_TURRET_BASE_MISSILE"] = true
turret_bases["OG_TURRET_BASE_FOCUS"] = true
turret_bases["OG_TURRET_BASE_MINI"] = true

local defence_drones = {}
for drone in vter(Hyperspace.Blueprints:GetBlueprintList("BLUELIST_DRONES_DEFENSE")) do
	table.insert(defence_drones, drone)
end

local defence_drones_laser = {}
for _, i in ipairs(defence_drones) do
	table.insert(defence_drones_laser, i)
end
table.insert(defence_drones_laser, "OG_TURRET_BASE_LASER")

local defence_drones_ion = {}
for _, i in ipairs(defence_drones) do
	table.insert(defence_drones_ion, i)
end
table.insert(defence_drones_ion, "OG_TURRET_BASE_ION")

local defence_drones_missile = {}
for _, i in ipairs(defence_drones) do
	table.insert(defence_drones_missile, i)
end
table.insert(defence_drones_missile, "OG_TURRET_BASE_MISSILE")

local defence_drones_focus = {}
for _, i in ipairs(defence_drones) do
	table.insert(defence_drones_focus, i)
end
table.insert(defence_drones_focus, "OG_TURRET_BASE_FOCUS")

local defence_drones_mini = {}
for _, i in ipairs(defence_drones) do
	table.insert(defence_drones_mini, i)
end
table.insert(defence_drones_mini, "OG_TURRET_BASE_MINI")

mods.og.hideName = {}
local hideName = mods.og.hideName
for item in vter(Hyperspace.Blueprints:GetBlueprintList("BLUELIST_OBELISK")) do
	--print("add to hideName:"..item)
	hideName[item] = "Something Old..."
end
local clone_cannon_list = {}
for item in vter(Hyperspace.Blueprints:GetBlueprintList("LIST_CLONE_CANNON")) do
	hideName[item] = "Something Ethically Dubious."
	table.insert(clone_cannon_list, item)
end
hideName["GATLING"] = "Unleash hell on your opposition!"
hideName["GATLING_VERSION1"] = ""
hideName["GATLING_VERSION2"] = ""
hideName["GATLING_VERSION3"] = ""
hideName["GATLING_VERSION4"] = ""
hideName["GATLING_VERSION5"] = ""
hideName["GATLING_VERSION6"] = ""
hideName["GATLING_VERSION7"] = ""
hideName["GATLING_VERSION8"] = ""
hideName["PRIME_LASER"] = "Let it hit you and you're already dead."
hideName["DEFENSE_PRIME"] = "Guardian Angel."
hideName["COMBAT_PRIME"] = "Angel of Vengeance."
hideName["BEAM_HARDSCIFI"] = "REAL SCIENCE!"
hideName["GATLING_SYLVAN"] = "You greedy, murdering traitor you."
hideName["GATLING_SYLVAN_HONOR"] = "Go kick some Rebel asses."

hideName["DDSHOTGUN_SOULPLAGUE"] = "You're hungry for more turrets - the turrets are hungry for more... well, everything."
hideName["DDFOCUS_SOULPLAGUE"] = ""
hideName["DDPHASE_SOULPLAGUE"] = ""
hideName["DDMISSILES_SOULPLAGUE"] = ""
hideName["DDLASER_HEAVY_SOULPLAGUE"] = ""
hideName["DDCHAINLASER_SOULPLAGUE"] = ""
hideName["DDCHAINLASER_SOULPLAGUE_CHAOS"] = ""
hideName["DDSOULPLAGUE_SHATTEREDPROMISE"] = ""

hideName["DDFALSERADIANCE_BURSTMISSILE"] = "And then, upon the eighth day... your enemies cried out, with an ardent voice - pleading for salvation. It would never come."
hideName["DDFALSERADIANCE_CHAINLASER"] = ""
hideName["DDFALSERADIANCE_PIERCELASER"] = ""
hideName["DDFALSERADIANCE_CHAINFOCUS"] = ""
hideName["DDFALSERADIANCE_BREACHBEAM"] = ""
hideName["DDFALSERADIANCE_HEAVYION"] = ""
hideName["DDFALSERADIANCE_HEAVYSHOTGUN"] = ""
hideName["DDFALSERADIANCE_LOST_GODHOOD"] = ""
hideName["DDFALSERADIANCE_LOOT"] = ""

hideName["SHOTGUN_DARKGOD"] = "Things are getting a bit darker than you'd desire, aren't they?"
hideName["LASER_DARKGOD"] = ""
hideName["BOMB_DARKGOD"] = ""
hideName["DD_BEAM_INSTANT_DARKGOD"] = ""
hideName["DDLASER_CHARGE_DARKGOD"] = ""
hideName["DDDEEP_ONE_SHOTGUN"] = ""
hideName["DDDEEP_ONE_SHOTGUN_CHAOS"] = ""
hideName["LASER_DISPARITY_LOOT"] = ""

--
mods.og.craftedCategories = {}
local craftedCategories = mods.og.craftedCategories

mods.og.craftedLasers = {name = "Lasers", id = "LASER", items = {}}
table.insert(craftedCategories, mods.og.craftedLasers)
local craftedLasers = mods.og.craftedLasers

mods.og.craftedIons = {name = "Ions", id = "ION", items = {}}
table.insert(craftedCategories, mods.og.craftedIons)
local craftedIons = mods.og.craftedIons

mods.og.craftedCrystals = {name = "Crystals", id = "CRYSTAL", items = {}}
table.insert(craftedCategories, mods.og.craftedCrystals)
local craftedCrystals = mods.og.craftedCrystals

mods.og.craftedMissiles = {name = "Missiles", id = "MISSILE", items = {}}
table.insert(craftedCategories, mods.og.craftedMissiles)
local craftedMissiles = mods.og.craftedMissiles

mods.og.craftedFlak = {name = "Flak", id = "SHOTGUN", items = {}}
table.insert(craftedCategories, mods.og.craftedFlak)
local craftedFlak = mods.og.craftedFlak

mods.og.craftedPinpoints = {name = "Pinpoints", id = "FOCUS", items = {}}
table.insert(craftedCategories, mods.og.craftedPinpoints)
local craftedPinpoints = mods.og.craftedPinpoints

mods.og.craftedMicro = {name = "Micro Turrets", id = "MICRO", items = {}}
table.insert(craftedCategories, mods.og.craftedMicro)
local craftedMicro = mods.og.craftedMicro

mods.og.craftedSpecial = {name = "Special", id = "SPECIAL", items = {}}
table.insert(craftedCategories, mods.og.craftedSpecial)
local craftedSpecial = mods.og.craftedSpecial

--

mods.og.craftedDarkestDesire = {name = "Darkest Desire", id = "DD", items = {}, var = "og_dd_enabled"}
table.insert(craftedCategories, mods.og.craftedDarkestDesire)
local craftedDarkestDesire = mods.og.craftedDarkestDesire

--

--mods.og.craftedWeapons = {}
--local craftedWeapons = mods.og.craftedWeapons

table.insert(craftedLasers.items, {weapon = "OG_TURRET_LASER_1", match_cost = true, component_amounts = {1}, components = {{"LASER_BURST_2", "LASER_BURST_3", "LASER_BURST_5", "LASER_CHARGEGUN", "LASER_CHARGEGUN_2", "LASER_CHARGEGUN_3", "LASER_CHARGE_CHAIN"}}} )
table.insert(craftedLasers.items, {weapon = "OG_TURRET_LASER_2", match_cost = true, component_amounts = {1}, components = {{"LASER_HEAVY_1", "LASER_HEAVY_2", "LASER_HEAVY_3", "LASER_HEAVY_CHAINGUN", "LASER_HEAVY_PIERCE"}}} )
table.insert(craftedLasers.items, {weapon = "OG_TURRET_LASER_PIERCE", match_cost = true, component_amounts = {1}, components = {{"LASER_PIERCE", "LASER_PIERCE_2", "LASER_HEAVY_PIERCE", "ION_PIERCE_1", "ION_PIERCE_2"}}} )
table.insert(craftedLasers.items, {weapon = "OG_TURRET_LASER_CHAINGUN", match_cost = true, component_amounts = {1}, components = {{ "LASER_CHAINGUN", "LASER_CHAINGUN_2", "LASER_CHAINGUN_DAMAGE", "LASER_CHARGE_CHAIN", "LASER_HULL_CHAINGUN"}}} )
table.insert(craftedLasers.items, {weapon = "OG_TURRET_LASER_BIO", match_cost = true, component_amounts = {1}, components = {{"LASER_BIO", "LOOT_CLAN_1", "BOMB_BIO", "ION_BIO", "LASER_FIRE", "LASER_FIRE_PLAYER"}}} )
table.insert(craftedLasers.items, {weapon = "OG_TURRET_LASER_HULL", match_cost = true, component_amounts = {1}, components = {{"LASER_HULL_1", "LASER_HULL_2", "LASER_HULL_3", "LASER_HULL_3_PLAYER", "LASER_HULL_CHAINGUN"}}} )
table.insert(craftedLasers.items, {weapon = "OG_TURRET_LASER_PARTICLE", match_cost = true, component_amounts = {1}, components = {{"LASER_PARTICLE", "LASER_PARTICLE_2", "BEAM_PARTICLE", "MISSILES_PARTICLE", "MISSILES_PARTICLE_PLAYER"}}} )

table.insert(craftedIons.items, {weapon = "OG_TURRET_ION_1", match_cost = true, component_amounts = {1}, components = {{"ION_1", "ION_2", "ION_3", "ION_4", "ION_CHAINGUN", "ION_CHARGEGUN", "ION_CHARGEGUN_2"}}} )
table.insert(craftedIons.items, {weapon = "OG_TURRET_ION_2", match_cost = true, component_amounts = {1}, components = {{"ION_FIRE", "ION_FIRE_PLAYER", "ION_BIO", "ION_TRI", "ION_STUN", "ION_STUN_2", "ION_STUN_HEAVY", "ION_STUN_CHARGEGUN", "ION_STUN_CHARGEGUN_PLAYER"}}} )
table.insert(craftedIons.items, {weapon = "OG_TURRET_ENERGY_1", match_cost = true, component_amounts = {1}, components = {{"ENERGY_1", "ENERGY_2", "ENERGY_2_PLAYER", "ENERGY_3", "ENERGY_HULL", "ENERGY_STUN", "ENERGY_STUN_PLAYER", "ENERGY_CHAINGUN", "ENERGY_CHARGEGUN", "ENERGY_CHARGEGUN_PLAYER"}}} )

table.insert(craftedCrystals.items, {weapon = "OG_TURRET_CRYSTAL_1", match_cost = true, component_amounts = {1}, components = {{"CRYSTAL_BURST_1", "CRYSTAL_BURST_2", "CRYSTAL_HEAVY_1", "CRYSTAL_HEAVY_2", "CRYSTAL_STUN", "CRYSTAL_SHOTGUN", "CRYSTAL_CHARGEGUN"}}} )
table.insert(craftedCrystals.items, {weapon = "OG_TURRET_CRYSTAL_1_ELITE", match_cost = true, component_amounts = {1}, components = {{"CRYSTAL_BURST_1_RED", "CRYSTAL_BURST_2_RED", "CRYSTAL_HEAVY_1_RED", "CRYSTAL_HEAVY_2_RED", "CRYSTAL_STUN_RED", "CRYSTAL_SHOTGUN_RED", "CRYSTAL_CHARGEGUN_RED"}}} )

table.insert(craftedMissiles.items, {weapon = "OG_TURRET_MISSILE_1", match_cost = true, component_amounts = {1}, components = {{"MISSILES_1", "MISSILES_2", "MISSILES_BURST", "MISSILES_BURST_2", "MISSILES_BURST_2_PLAYER", "MISSILES_FREE"}}} )
table.insert(craftedMissiles.items, {weapon = "OG_TURRET_MISSILE_2", match_cost = true, component_amounts = {1}, components = {{"MISSILES_3", "MISSILES_4", "MISSILES_ENERGY", "MISSILES_FIRE", "MISSILES_FIRE_PLAYER", "MISSILES_CLOAK", "MISSILES_CLOAK_PLAYER"}}} )
table.insert(craftedMissiles.items, {weapon = "OG_TURRET_KERNEL_HEAVY", match_cost = true, component_amounts = {1}, components = {{"KERNEL_1", "KERNEL_1_ELITE", "KERNEL_2", "KERNEL_2_ELITE", "KERNEL_HEAVY", "KERNEL_HEAVY_ELITE"}}} )
table.insert(craftedMissiles.items, {weapon = "OG_TURRET_KERNEL_FIRE", match_cost = true, component_amounts = {1}, components = {{"KERNEL_FIRE", "KERNEL_FIRE_ELITE", "KERNEL_CHAIN", "KERNEL_CHAIN_ELITE", "KERNEL_CHARGE", "KERNEL_CHARGE_ELITE"}}} )

table.insert(craftedFlak.items, {weapon = "OG_TURRET_FLAK_1", match_cost = true, component_amounts = {1}, components = {{"SHOTGUN_1", "SHOTGUN_2", "SHOTGUN_2_PLAYER", "SHOTGUN_3", "SHOTGUN_4", "SHOTGUN_CHARGE", "SHOTGUN_CHAIN", "SHOTGUN_INSTANT"}}} )
table.insert(craftedFlak.items, {weapon = "OG_TURRET_FLAK_BIO", match_cost = true, component_amounts = {1}, components = {{"SHOTGUN_TOXIC", "SHOTGUN_TOXIC_PLAYER", "MISSILES_BIO", "BOMB_BIO", "SHOTGUN_INSTANT"}}} )

table.insert(craftedPinpoints.items, {weapon = "OG_TURRET_FOCUS_1", match_cost = true, component_amounts = {1}, components = {{"FOCUS_1", "FOCUS_2", "FOCUS_3", "BEAM_1", "BEAM_2", "BEAM_2_PLAYER", "BEAM_3"}}} )
table.insert(craftedPinpoints.items, {weapon = "OG_TURRET_FOCUS_BIO", match_cost = true, component_amounts = {1}, components = {{"FOCUS_BIO", "BEAM_BIO", "BEAM_BIO_CHAIN", "BEAM_BIO_CONSERVATIVE", "BEAM_GUILLOTINE", "BEAM_GUILLOTINE_PLAYER"}}} )
table.insert(craftedPinpoints.items, {weapon = "OG_TURRET_FOCUS_CHAIN", match_cost = true, component_amounts = {1}, components = {{"BEAM_CHAIN", "FOCUS_CHAIN", "BEAM_BIO_CHAIN", "BEAM_ADAPT", "BEAM_ADAPT_2", "BEAM_2", "BEAM_2_PLAYER", "BEAM_3"}}} )

table.insert(craftedMicro.items, {weapon = "OG_TURRET_LASER_MINI_1", match_cost = true, component_amounts = {1}, components = {{"LASER_BURST_2", "LASER_BURST_3", "LASER_BURST_3", "LASER_CONSERVATIVE"}}} )
table.insert(craftedMicro.items, {weapon = "OG_TURRET_LASER_MINI_2", match_cost = true, component_amounts = {1}, components = {{"LASER_LIGHT", "LASER_LIGHT_2", --[["LASER_LIGHT_BURST",]] "LASER_LIGHT_CHARGEGUN", "LASER_LIGHT_CHARGEGUN_CHAOS"}}} )
table.insert(craftedMicro.items, {weapon = "OG_TURRET_ION_MINI_1", match_cost = true, component_amounts = {1}, components = {{"ION_1", "ION_2", "ION_3", "ION_4", "ION_CHAINGUN", "ION_CHARGEGUN", "ION_CHARGEGUN_2", "ION_CONSERVATIVE"}}} )
table.insert(craftedMicro.items, {weapon = "OG_TURRET_FOCUS_MINI_1", match_cost = true, component_amounts = {1}, components = {{"FOCUS_1", "FOCUS_2", "FOCUS_3", "FOCUS_CHAIN", "FOCUS_BIO", "BEAM_CONSERVATIVE"}}} )
table.insert(craftedMicro.items, {weapon = "OG_TURRET_FLAK_MINI_1", match_cost = true, component_amounts = {1}, components = {{"SHOTGUN_1", "SHOTGUN_2", "SHOTGUN_3", "SHOTGUN_4", "SHOTGUN_CHARGE", "SHOTGUN_CHAIN", "SHOTGUN_INSTANT"}}} )
table.insert(craftedMicro.items, {weapon = "OG_TURRET_MISSILE_MINI_1", match_cost = true, component_amounts = {1}, components = {{"MISSILES_1", "MISSILES_2", "MISSILES_BURST", "MISSILES_BURST_2", "MISSILES_BURST_2_PLAYER", "MISSILES_FREE", "MISSILES_CONSERVATIVE"}}} )

table.insert(craftedSpecial.items, {weapon = "OG_TURRET_MISSILE_CLONE_CANNON", match_cost = true, component_amounts = {1}, components = {clone_cannon_list}} )
table.insert(craftedSpecial.items, {weapon = "OG_TURRET_LASER_ANCIENT", match_cost = true, component_amounts = {1}, components = {{"ANCIENT_LASER", "ANCIENT_LASER_2", "ANCIENT_LASER_3", "ANCIENT_BEAM", "ANCIENT_BEAM_2", "ANCIENT_BEAM_3", "ANCIENT_DEFENSE_1"}}} )
table.insert(craftedSpecial.items, {weapon = "OG_TURRET_LASER_CEL_1", match_cost = true, component_amounts = {1}, components = {{"PRIME_LASER", "COMBAT_PRIME", "BEAM_HARDSCIFI", "DEFENSE_PRIME"}}} )
table.insert(craftedSpecial.items, {weapon = "OG_TURRET_LASER_GATLING", match_cost = true, component_amounts = {1}, components = {{"GATLING"}}} )
table.insert(craftedSpecial.items, {weapon = "OG_TURRET_LASER_RIFTWAKER", match_cost = true, component_amounts = {1}, components = {{"GATLING_SYLVAN", "GATLING_SYLVAN_HONOR"}}} )

-- DARKEST DESIRE

table.insert(craftedDarkestDesire.items, {weapon = "OG_TURRET_FOCUS_SOULPLAGUE", match_cost = true, component_amounts = {1}, components = {{"DDSHOTGUN_SOULPLAGUE", "DDFOCUS_SOULPLAGUE", "DDPHASE_SOULPLAGUE", "DDMISSILES_SOULPLAGUE", "DDLASER_HEAVY_SOULPLAGUE", "DDCHAINLASER_SOULPLAGUE", "DDCHAINLASER_SOULPLAGUE_CHAOS", "DDSOULPLAGUE_SHATTEREDPROMISE"}}} )
table.insert(craftedDarkestDesire.items, {weapon = "OG_TURRET_MISSILE_FALSERADIANCE", match_cost = true, component_amounts = {1}, components = {{"DDFALSERADIANCE_BURSTMISSILE", "DDFALSERADIANCE_CHAINLASER", "DDFALSERADIANCE_PIERCELASER", "DDFALSERADIANCE_CHAINFOCUS", "DDFALSERADIANCE_BREACHBEAM", "DDFALSERADIANCE_HEAVYION", "DDFALSERADIANCE_HEAVYSHOTGUN", "DDFALSERADIANCE_LOST_GODHOOD", "DDFALSERADIANCE_LOOT"}}} )
table.insert(craftedDarkestDesire.items, {weapon = "OG_TURRET_LASER_DARKNESS_MINI", match_cost = true, component_amounts = {1}, components = {{"SHOTGUN_DARKGOD", "LASER_DARKGOD", "BOMB_DARKGOD", "DD_BEAM_INSTANT_DARKGOD", "DDLASER_CHARGE_DARKGOD", "DDDEEP_ONE_SHOTGUN", "DDDEEP_ONE_SHOTGUN_CHAOS", "LASER_DISPARITY_LOOT"}}} )

script.on_init(function()
	Hyperspace.metaVariables[craftedDarkestDesire.var] = 0
	if Hyperspace.Blueprints:GetWeaponBlueprint("DDDIVINE_DUALITY").desc.title:GetText() ~= "" then
		Hyperspace.metaVariables[craftedDarkestDesire.var] = 1
	end
end)

-- OTHER

local craftedItemsVisible = {}

function TEST(needed)
	local neededBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint(needed) or Hyperspace.Blueprints:GetDroneBlueprint(needed) or Hyperspace.Blueprints:GetAugmentBlueprint(needed)
	print(neededBlueprint.desc.title:GetText())
end

local cost_increase = 0

local craftText = {
	use = Hyperspace.Text:GetText("og_lua_turret_craft_use"),
	use_scrap = Hyperspace.Text:GetText("og_lua_turret_craft_use_scrap"),
	finish = Hyperspace.Text:GetText("og_lua_turret_craft_finish"),
	blueprint = Hyperspace.Text:GetText("og_lua_turret_craft_blueprint"),
	mystery = Hyperspace.Text:GetText("og_lua_turret_craft_mystery"),
	requires = Hyperspace.Text:GetText("og_lua_turret_craft_requires"),
	atleast = Hyperspace.Text:GetText("og_lua_turret_craft_atleast"),
	list = Hyperspace.Text:GetText("og_lua_turret_craft_list"),
	list_scrap = Hyperspace.Text:GetText("og_lua_turret_craft_list_scrap"),
	craft = Hyperspace.Text:GetText("og_lua_turret_craft_craft"),
	unknown = Hyperspace.Text:GetText("og_lua_turret_craft_unknown"),
}

local function addComponentStep(currentEvent, weapon, craftingData, weaponCost, itemLevel, itemAmount)
	--print(weapon.." ITEM LEVEL AT: "..itemLevel.." NEEDS: "..#craftingData.components.." ITEM AMOUNT AT: "..itemAmount.." NEEDS: "..craftingData.component_amounts[itemLevel])
	local eventManager = Hyperspace.Event
	local player = Hyperspace.ships.player
	currentEvent:RemoveChoice(0)
	for _, needed in ipairs(craftingData.components[itemLevel]) do
		if player:HasEquipment(needed, true) > 0 then
			local tempEvent = eventManager:CreateEvent("OG_CRAFT_CRAFT_STEP", 0, false)
			tempEvent.stuff.removeItem = needed
			local neededBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint(needed)
			if neededBlueprint.desc.title:GetText() == "" then
				neededBlueprint = Hyperspace.Blueprints:GetDroneBlueprint(needed)
			end

			local tempCost = weaponCost - neededBlueprint.desc.cost + cost_increase
			if craftingData.match_cost and tempCost > 0 then
				tempEvent.stuff.scrap = -1 * tempCost
				currentEvent:AddChoice(tempEvent, string.format(craftText.use_scrap, neededBlueprint.desc.title:GetText(), math.floor(tempCost)), emptyReq, true)
			else
				currentEvent:AddChoice(tempEvent, string.format(craftText.use, neededBlueprint.desc.title:GetText()), emptyReq, true)
			end
			if itemAmount >= craftingData.component_amounts[itemLevel] then
				if itemLevel >= #craftingData.components then
					tempEvent.eventName = "OG_CRAFT_FINISH_ITEM"
					tempEvent.stuff.weapon = Hyperspace.Blueprints:GetWeaponBlueprint(weapon)
					tempEvent.text.data = craftText.finish
					tempEvent.text.isLiteral = true
				else
					addComponentStep(tempEvent, weapon, craftingData, weaponCost, itemLevel + 1, 1)
				end
			else
				addComponentStep(tempEvent, weapon, craftingData, weaponCost, itemLevel, itemAmount + 1)
			end
		end
	end
end

local function generate_crafts(event, player, eventManager, craftingTable)
	craftedItemsVisible[craftingTable.id] = {}
	local blue = false
	for _, craftingData in ipairs(craftingTable.items) do
		local weapon = craftingData.weapon
		local weaponBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint(weapon)
		local weaponCost = weaponBlueprint.desc.cost
		local displayOption = true -- false to only show when atleast 1 component
		local showBlueprint = true
		for _, components in ipairs(craftingData.components) do
			local hasHidden = false
			local hiddenSeen = false
			for _, needed in ipairs(components) do
				local neededBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint(needed)
				if neededBlueprint.desc.title:GetText() == "" then
					neededBlueprint = Hyperspace.Blueprints:GetDroneBlueprint(needed)
				end
				local tempCost = weaponCost - neededBlueprint.desc.cost + cost_increase
				local hasScrapCost = Hyperspace.ships.player.currentScrap >= tempCost
				local canAfford = (not craftingData.match_cost) or hasScrapCost
				if hideName[needed] and player:HasEquipment(needed, true) > 0 and canAfford then
					displayOption = true

					hiddenSeen = true
					--print("has Hidden Seen"..needed)
					hasHidden = true
				elseif hideName[needed] then
					hasHidden = true
					--print("has Hidden"..needed)
					--print("hasHidden:"..needed)
				elseif player:HasEquipment(needed, true) > 0 and canAfford then
					displayOption = true
				end
			end
			local componentList = components ~= defence_drones and components ~= defence_drones_laser and 
				components ~= defence_drones_ion and components ~= defence_drones_missile and 
				components ~= defence_drones_focus and components ~= defence_drones_mini
			if hasHidden and (not hiddenSeen) and componentList and Hyperspace.metaVariables["og_turret_craft_"..weapon] == 0 then
				showBlueprint = false
			elseif hasHidden and hiddenSeen and componentList then
				Hyperspace.metaVariables["og_turret_craft_"..weapon] = 1
			end
		end
		if displayOption then
			local weaponEvent = eventManager:CreateEvent("OG_CRAFT_CRAFT", 0, false)
			weaponEvent:RemoveChoice(0)
			weaponEvent:AddChoice(event, manageText.nevermind, emptyReq, false)
			if showBlueprint then
				weaponEvent.eventName = "OG_CRAFT_CRAFT_"..weapon
				weaponEvent:AddChoice(weaponEvent, craftText.blueprint, emptyReq, false)
			else
				weaponEvent.eventName = "OG_CRAFT_HIDDEN_"..weapon
				weaponEvent:AddChoice(weaponEvent, craftText.blueprint, emptyReq, false)
			end

			local eventString = string.format(craftText.requires, ((showBlueprint and weaponBlueprint.desc.title:GetText()) or craftText.mystery))
			for i, components in ipairs(craftingData.components) do
				eventString = eventString..string.format(craftText.atleast, craftingData.component_amounts[i])
				for _, needed in ipairs(components) do
					if hideName[needed] and (not showBlueprint) and not (player:HasEquipment(needed, true) > 0) then
						if hideName[needed] ~= "" then
							eventString = eventString..string.format(craftText.list, hideName[needed])
						end
					else
						local tempBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint(needed)
						if tempBlueprint.desc.title:GetText() == "" then
							tempBlueprint = Hyperspace.Blueprints:GetDroneBlueprint(needed)
						end
						local tempCost = weaponCost - tempBlueprint.desc.cost + cost_increase
						--print("weapon:"..weapon.." cost:"..math.floor(weaponCost).." item:"..needed.." cost:"..math.floor(tempBlueprint.desc.cost).." tempCost:"..math.floor(tempCost))
						if craftingData.match_cost and tempCost > 0 then
							eventString = eventString..string.format(craftText.list_scrap, tempBlueprint.desc.title:GetText(), math.floor(tempCost))
						else
							eventString = eventString..string.format(craftText.list, tempBlueprint.desc.title:GetText())
						end
					end
				end
				--end
			end
			weaponEvent.text.data = eventString
			weaponEvent.text.isLiteral = true

			local canCraft = true
			for i, components in ipairs(craftingData.components) do
				local amount = 0
				local amount_need = craftingData.component_amounts[i]
				for _, needed in ipairs(components) do
					local neededBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint(needed)
					if neededBlueprint.desc.title:GetText() == "" then
						neededBlueprint = Hyperspace.Blueprints:GetDroneBlueprint(needed)
					end
					local tempCost = weaponCost - neededBlueprint.desc.cost + cost_increase
					local hasScrapCost = Hyperspace.ships.player.currentScrap >= tempCost
					local canAfford = (not craftingData.match_cost) or hasScrapCost
					if canAfford then
						amount = amount + player:HasEquipment(needed, true)
					end
				end
				if amount < amount_need then 
					canCraft = false
				end
			end

			if canCraft then
				local craftStepEvent = eventManager:CreateEvent("OG_CRAFT_CRAFT_STEP", 0, false)
				weaponEvent:AddChoice(craftStepEvent, craftText.craft, blueReq, false)

				addComponentStep(craftStepEvent, weapon, craftingData, weaponCost, 1, 1)


				if showBlueprint then
					event:AddChoice(weaponEvent, weaponBlueprint.desc.title:GetText(), blueReq, false)
				end
				blue = true
			else
				local tempEvent = eventManager:CreateEvent("OPTION_INVALID", 0, false)
				weaponEvent:AddChoice(tempEvent, craftText.craft, emptyReq, true)


				if showBlueprint then
					event:AddChoice(weaponEvent, weaponBlueprint.desc.title:GetText(), emptyReq, false)
				end
			end

			if showBlueprint then
				table.insert(craftedItemsVisible[craftingTable.id], weapon)
			else
				event:AddChoice(weaponEvent, craftText.unknown, emptyReq, false)
				table.insert(craftedItemsVisible[craftingTable.id], "OG_TURRET_UNKNOWN")
			end
		end
	end
	return blue
end

script.on_internal_event(Defines.InternalEvents.PRE_CREATE_CHOICEBOX, function(event)
	if event.eventName == "OG_CRAFT_MAIN_MENU" then
		local player = Hyperspace.ships.player
		local eventManager = Hyperspace.Event
		
		for _, craftingTable in ipairs(craftedCategories) do
			if (not craftingTable.var) or Hyperspace.metaVariables[craftingTable.var] >= 1 then
				local cat_event = eventManager:CreateEvent("OG_CRAFT_CATEGORY_", 0, false)
				cat_event.eventName = cat_event.eventName..craftingTable.id

				local blue = generate_crafts(cat_event, player, eventManager, craftingTable)

				event:AddChoice(cat_event, craftingTable.name, (blue and blueReq) or emptyReq, false)
			end
		end
	end
end)

script.on_internal_event(Defines.InternalEvents.POST_CREATE_CHOICEBOX, function(choiceBox, event)
	--print(A(event.eventName, 1, 16).." AND "..string.sub(event.eventName, 17, string.len(event.eventName)))
	if string.sub(event.eventName, 1, 18) == "OG_CRAFT_CATEGORY_" then
		local id = string.sub(event.eventName, 19)
		local i = 0
		for choice in vter(choiceBox:GetChoices()) do
			if i > 0 then
				choice.rewards.weapon = Hyperspace.Blueprints:GetWeaponBlueprint(craftedItemsVisible[id][i])
			end
			i = i + 1
		end
	elseif event.eventName == "STORAGE_CHECK_OG_TURRET" then
		local turretItemsUninstall = {}
		for _, sysName in ipairs(systemNameList) do
			if Hyperspace.ships.player:HasSystem(Hyperspace.ShipSystem.NameToSystemId(sysName)) then
				local system = Hyperspace.ships.player:GetSystem(Hyperspace.ShipSystem.NameToSystemId(sysName))
				table.insert(turretItemsUninstall, Hyperspace.Blueprints:GetWeaponBlueprint(system.table.blueprint))
			end
		end
		local i = 1
		for choice in vter(choiceBox:GetChoices()) do
			if choice.text == manageText.uninstall then
				choice.rewards.weapon = turretItemsUninstall[i]
				i = i + 1
			elseif choice.text == manageText.empty then
				i = i + 1
			end
		end
	elseif string.sub(event.eventName, 1, 15) == "OG_CRAFT_CRAFT_" then
		local weapon = string.sub(event.eventName, 16, string.len(event.eventName))
		local i = 1
		for choice in vter(choiceBox:GetChoices()) do
			if i == 2 then
				choice.rewards.weapon = Hyperspace.Blueprints:GetWeaponBlueprint(weapon)
			end
			i = i + 1
		end
	elseif string.sub(event.eventName, 1, 16) == "OG_CRAFT_HIDDEN_" then
		local weapon = string.sub(event.eventName, 17, string.len(event.eventName))
		local i = 1
		for choice in vter(choiceBox:GetChoices()) do
			if i == 2 then
				choice.rewards.weapon = Hyperspace.Blueprints:GetWeaponBlueprint("OG_TURRET_UNKNOWN")
			end
			i = i + 1
		end
	end
end)

local text_fab = Hyperspace.Text:GetText("og_lua_turret_fabricate")
local text_item = Hyperspace.Text:GetText("og_lua_turret_fabricate_item")
local text_mystery = Hyperspace.Text:GetText("og_lua_turret_fabricate_mystery")
local text_price = Hyperspace.Text:GetText("og_lua_turret_stats_price"),
script.on_internal_event(Defines.InternalEvents.WEAPON_DESCBOX, function(blueprint, desc)
	if turret_bases[blueprint.name] then
		desc = text_fab
		for _, craftingTable in ipairs(craftedCategories) do
			for _, craftingData in ipairs(craftingTable.items) do
				local has_base = false
				local hidden = false
				for _, componentList in ipairs(craftingData.components) do
					hiddenList = true
					for _, item in ipairs(componentList) do
						if item == blueprint.name then
							has_base = true
						elseif not hideName[item] then
							--print("has hidden"..item)
							hiddenList = false
						end
					end
					if hiddenList then
						hidden = true
					end
				end
				if has_base and ((not hidden) or Hyperspace.metaVariables["og_turret_craft_"..craftingData.weapon] == 1) then
					local weaponBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint(craftingData.weapon)
					desc = desc..string.format(text_item, weaponBlueprint.desc.title:GetText())
				elseif has_base then
					desc = desc..text_mystery
				end
			end
		end
		desc = desc..string.format(text_price, math.floor(blueprint.desc.cost), math.floor(blueprint.desc.cost/2))
	end
	return Defines.Chain.CONTINUE, desc
end)

local craftingMats = {}
script.on_init(function()
	craftingMats = {}
	for _, craftingTable in ipairs(craftedCategories) do
		for _, craftingData in ipairs(craftingTable.items) do
			local weaponBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint(craftingData.weapon)
			local name = weaponBlueprint.desc.title:GetText()
			for _, components in ipairs(craftingData.components) do
				for _, needed in ipairs(components) do
					if hideName[needed] then
						if craftingMats[needed] then
							table.insert(craftingMats[needed], {name = name, var = "og_turret_craft_"..craftingData.weapon})
						else
							craftingMats[needed] = {{name = name, var = "og_turret_craft_"..craftingData.weapon}}
						end
					else
						if craftingMats[needed] then
							table.insert(craftingMats[needed], {name = name,})
						else
							craftingMats[needed] = {{name = name}}
						end
					end
				end
			end
		end
	end
end)

local last_mat = ""
local last_mats = {}


local systemCacheList = mods.og.systemCacheList
local text_fab_hover = Hyperspace.Text:GetText("og_lua_turret_fabricate_hover")

script.on_internal_event(Defines.InternalEvents.WEAPON_DESCBOX, function(bp, desc)
	if Hyperspace.App.menu.shipBuilder.bOpen then return desc end
	local has_system = false
	for _, sysName in ipairs(systemNameList) do
		if systemCacheList[0][sysName] then
			has_system = true
			break
		end
	end
	if not has_system then return desc end

	if last_mat == bp.name then
		if #last_mats > 0 then
			local s = text_fab_hover..table.concat(last_mats, ", ")
			Hyperspace.Mouse.tooltip = #Hyperspace.Mouse.tooltip > 0 and Hyperspace.Mouse.tooltip.."\n" or ""
			Hyperspace.Mouse.tooltip = Hyperspace.Mouse.tooltip..s
			Hyperspace.Mouse.bForceTooltip = true
		end
		return desc
	elseif last_mat ~= "" then
		last_mat = ""
		last_mats = {}
	end

	local mats = craftingMats[bp.name]

	if mats and Hyperspace.metaVariables.og_turret_fab_tips == 0 then
		local mats_dupe = {}
		for _, item_data in ipairs(mats) do
			if (not item_data.var) or Hyperspace.metaVariables[item_data.var] > 0 then
				table.insert(mats_dupe, item_data.name)
			end
		end
		last_mat = bp.name
		last_mats = mats_dupe
	end
	return desc
end)