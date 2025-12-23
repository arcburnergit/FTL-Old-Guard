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

local turretBlueprintsList = mods.og.turretBlueprintsList
local turrets = mods.og.turrets

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

local hookedEvents = {}
local function turret_install_event(installEvent, sysName, shipManager, eventManager)
	if shipManager:HasSystem(3) then
		for weapon in vter(shipManager.weaponSystem.weapons) do
			if turrets[weapon.blueprint.name] and (turrets[weapon.blueprint.name].mini or not microTurrets[sysName]) then
				local removeEvent = eventManager:CreateEvent("STORAGE_CHECK_OG_TURRET_EMPTY", 0, false)
				removeEvent.eventName = removeEvent.eventName.."_INSTALL_"..sysName.."_"..weapon.blueprint.name
				local index = 0
				for i, turretId in ipairs(turretBlueprintsList) do
					if turretId == weapon.blueprint.name then
						index = i
					end
				end
				if not hookedEvents[removeEvent.eventName] then
					hookedEvents[removeEvent.eventName] = true
					script.on_game_event(removeEvent.eventName, false, function()
						Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemBlueprintVarName] = index
						return
					end)
				end
				removeEvent.stuff.removeItem = weapon.blueprint.name
				removeEvent.stuff.weapon = weapon.blueprint
				installEvent:AddChoice(removeEvent, "Install this:", emptyReq, false)
			end
		end
	end
	for item in vter(Hyperspace.App.gui.equipScreen:GetCargoHold()) do
		if turrets[item] and (turrets[item].mini or not microTurrets[sysName]) then
			local removeEvent = eventManager:CreateEvent("STORAGE_CHECK_OG_TURRET_EMPTY", 0, false)
			removeEvent.eventName = removeEvent.eventName.."_INSTALL_"..sysName.."_"..item
			local index = 0
			for i, turretId in ipairs(turretBlueprintsList) do
				if turretId == item then
					index = i
				end
			end
			if not hookedEvents[removeEvent.eventName] then
				hookedEvents[removeEvent.eventName] = true
				script.on_game_event(removeEvent.eventName, false, function()
					Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemBlueprintVarName] = index
					return
				end)
			end
			removeEvent.stuff.removeItem = item
			local blueprint = Hyperspace.Blueprints:GetWeaponBlueprint(item)
			removeEvent.stuff.weapon = blueprint
			installEvent:AddChoice(removeEvent, "Install this:", emptyReq, false)
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
				if Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemBlueprintVarName] < 0 then
					local installEvent = eventManager:CreateEvent("STORAGE_CHECK_OG_TURRET_INSTALL", 0, false)
					turret_install_event(installEvent, sysName, shipManager, eventManager)
					event:AddChoice(installEvent, "Manage Empty Turret.", emptyReq, false)
				else
					local removeEvent = eventManager:CreateEvent("STORAGE_CHECK_OG_TURRET_REMOVE", 0, false)

					removeEvent.eventName = removeEvent.eventName.."_"..sysName
					turret_install_event(removeEvent, sysName, shipManager, eventManager)

					if not hookedEvents[removeEvent.eventName] then
						hookedEvents[removeEvent.eventName] = true
						script.on_game_event(removeEvent.eventName, false, function()
							Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemBlueprintVarName] = -1
							system.table.currentTarget = nil
							Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName] = 0
							Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemTimeVarName] = 0
							system.table.chargeTime = 0
							system.table.firingTime = 0
							system.table.currentShot = 0
							system.table.currentlyTargetting = false
							return
						end)
					end
					local blueprint = Hyperspace.Blueprints:GetWeaponBlueprint(turretBlueprintsList[Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemBlueprintVarName] ])
					removeEvent.stuff.weapon = blueprint
					event:AddChoice(removeEvent, "Uninstall Turret:", emptyReq, false)
				end
			end
		end
	elseif string.sub(event.eventName, 1, 37) == "STORAGE_CHECK_OG_TURRET_EMPTY_INSTALL" then
		event.stuff.weapon = nil
	end
end)

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
	hideName[item] = "Something Old"
end
hideName["PRIME_LASER"] = "Let it hit you and you're already dead."
hideName["DEFENSE_PRIME"] = "Let it hit you and you're already dead."
hideName["COMBAT_PRIME"] = "Let it hit you and you're already dead."
hideName["BEAM_HARDSCIFI"] = "REAL SCIENCE"
hideName["GATLING_SYLVAN"] = "You greedy, murdering traitor you"

mods.og.craftedWeapons = {}
local craftedWeapons = mods.og.craftedWeapons
table.insert(craftedWeapons, {weapon = "OG_TURRET_LASER_1", component_amounts = {1, 1}, components = {defence_drones_laser, {"LASER_BURST_2", "LASER_BURST_3", "LASER_BURST_5", "LASER_CHAINGUN", "LASER_CHAINGUN_2", "LASER_CHAINGUN_DAMAGE", "LASER_CHARGEGUN", "LASER_CHARGEGUN_2", "LASER_CHARGEGUN_3", "LASER_CHARGE_CHAIN"}}} )
table.insert(craftedWeapons, {weapon = "OG_TURRET_LASER_2", component_amounts = {1, 1}, components = {defence_drones_laser, {"LASER_HEAVY_1", "LASER_HEAVY_2", "LASER_HEAVY_3", "LASER_HEAVY_CHAINGUN", "LASER_HEAVY_PIERCE"}}} )
table.insert(craftedWeapons, {weapon = "OG_TURRET_ION_1", component_amounts = {1, 1}, components = {defence_drones_ion, {"ION_1", "ION_2", "ION_3", "ION_4", "ION_CHAINGUN", "ION_CHARGEGUN", "ION_CHARGEGUN_2"}}} )
table.insert(craftedWeapons, {weapon = "OG_TURRET_ION_2", component_amounts = {1, 1}, components = {defence_drones_ion, {"ION_FIRE", "ION_BIO", "ION_TRI", "ION_STUN", "ION_STUN_2", "ION_STUN_HEAVY", "ION_STUN_CHARGEGUN"}}} )
table.insert(craftedWeapons, {weapon = "OG_TURRET_MISSILE_1", component_amounts = {1, 1}, components = {defence_drones_missile, {"MISSILES_1", "MISSILES_2", "MISSILES_BURST", "MISSILES_BURST_2", "MISSILES_BURST_2_PLAYER", "MISSILES_FREE"}}} )
table.insert(craftedWeapons, {weapon = "OG_TURRET_MISSILE_2", component_amounts = {1, 1}, components = {defence_drones_missile, {"MISSILES_3", "MISSILES_4", "MISSILES_ENERGY", "MISSILES_FIRE", "MISSILES_FIRE_PLAYER", "MISSILES_CLOAK", "MISSILES_CLOAK_PLAYER"}}} )
table.insert(craftedWeapons, {weapon = "OG_TURRET_FLAK_1", component_amounts = {1, 1}, components = {defence_drones_missile, {"SHOTGUN_1", "SHOTGUN_2", "SHOTGUN_3", "SHOTGUN_4", "SHOTGUN_CHARGE", "SHOTGUN_CHAIN", "SHOTGUN_INSTANT"}}} )
table.insert(craftedWeapons, {weapon = "OG_TURRET_FOCUS_1", component_amounts = {1, 1}, components = {defence_drones_focus, {"FOCUS_1", "FOCUS_2", "FOCUS_3", "FOCUS_CHAIN", "FOCUS_BIO"}}} )

table.insert(craftedWeapons, {weapon = "OG_TURRET_LASER_MINI_1", component_amounts = {1, 1}, components = {defence_drones_mini, {"LASER_BURST_2", "LASER_BURST_2", "LASER_BURST_3", "LASER_BURST_3"}}} )
table.insert(craftedWeapons, {weapon = "OG_TURRET_LASER_MINI_2", component_amounts = {1, 1}, components = {defence_drones_mini, {"LASER_LIGHT", "LASER_LIGHT_2", "LASER_LIGHT_BURST", "LASER_LIGHT_CHARGEGUN", "LASER_LIGHT_CHARGEGUN_CHAOS"}}} )
table.insert(craftedWeapons, {weapon = "OG_TURRET_ION_MINI_1", component_amounts = {1, 1}, components = {defence_drones_mini, {"ION_1", "ION_2", "ION_3", "ION_4", "ION_CHAINGUN", "ION_CHARGEGUN", "ION_CHARGEGUN_2"}}} )
table.insert(craftedWeapons, {weapon = "OG_TURRET_FOCUS_MINI_1", component_amounts = {1, 1}, components = {defence_drones_mini, {"FOCUS_1", "FOCUS_2", "FOCUS_3", "FOCUS_CHAIN", "FOCUS_BIO"}}} )
 
table.insert(craftedWeapons, {weapon = "OG_TURRET_LASER_ANCIENT", component_amounts = {1, 1}, components = {{"ANCIENT_DEFENSE_1"}, {"LASER_BURST_2", "LASER_BURST_3", "LASER_BURST_5", "LASER_CHAINGUN", "LASER_CHAINGUN_2", "LASER_CHAINGUN_DAMAGE", "LASER_CHARGEGUN", "LASER_CHARGEGUN_2", "LASER_CHARGEGUN_3", "LASER_CHARGE_CHAIN"}}} )
table.insert(craftedWeapons, {weapon = "OG_TURRET_LASER_ANCIENT", component_amounts = {1, 1}, components = {defence_drones_laser, {"ANCIENT_LASER", "ANCIENT_LASER_2", "ANCIENT_LASER_3", "ANCIENT_BEAM", "ANCIENT_BEAM_2", "ANCIENT_BEAM_3"}}} )

table.insert(craftedWeapons, {weapon = "OG_TURRET_LASER_CEL", component_amounts = {1, 1}, components = {{"DEFENSE_PRIME"}, {"LASER_BURST_2", "LASER_BURST_3", "LASER_BURST_5", "LASER_CHAINGUN", "LASER_CHAINGUN_2", "LASER_CHAINGUN_DAMAGE", "LASER_CHARGEGUN", "LASER_CHARGEGUN_2", "LASER_CHARGEGUN_3", "LASER_CHARGE_CHAIN"}}} )
table.insert(craftedWeapons, {weapon = "OG_TURRET_LASER_CEL", component_amounts = {1, 1}, components = {defence_drones_laser, {"PRIME_LASER", "COMBAT_PRIME", "BEAM_HARDSCIFI", "GATLING_SYLVAN"}}} )
local craftedItemsVisible = {}

function TEST(needed)
	local neededBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint(needed) or Hyperspace.Blueprints:GetDroneBlueprint(needed) or Hyperspace.Blueprints:GetAugmentBlueprint(needed)
	print(neededBlueprint.desc.title:GetText())
end

local function addComponentStep(currentEvent, weapon, craftingData, itemLevel, itemAmount)
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
			currentEvent:AddChoice(tempEvent, "Use your "..neededBlueprint.desc.title:GetText(), emptyReq, true)
			if itemAmount >= craftingData.component_amounts[itemLevel] then
				if itemLevel >= #craftingData.components then
					tempEvent.eventName = "OG_CRAFT_FINISH_ITEM"
					tempEvent.stuff.weapon = Hyperspace.Blueprints:GetWeaponBlueprint(weapon)
					tempEvent.text.data = "You follow the supplied blueprint and eventually come away with a new item."
					tempEvent.text.isLiteral = true
				else
					addComponentStep(tempEvent, weapon, craftingData, itemLevel + 1, 1)
				end
			else
				addComponentStep(tempEvent, weapon, craftingData, itemLevel, itemAmount + 1)
			end
		end
	end
end

script.on_internal_event(Defines.InternalEvents.PRE_CREATE_CHOICEBOX, function(event)
	if event.eventName == "OG_CRAFT_MAIN_MENU" then
		local player = Hyperspace.ships.player
		local eventManager = Hyperspace.Event
		craftedItemsVisible = {}
		for _, craftingData in ipairs(craftedWeapons) do
			local weapon = craftingData.weapon
			local weaponBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint(weapon)
			local displayOption = true -- false to only show when atleast 1 component
			local showBlueprint = true
			for _, components in ipairs(craftingData.components) do
				local hasHidden = false
				local hiddenSeen = false
				for _, needed in ipairs(components) do
					if hideName[needed] and player:HasEquipment(needed, true) > 0 then
						displayOption = true

						hiddenSeen = true
						--print("has Hidden Seen"..needed)
						hasHidden = true
					elseif hideName[needed] then
						hasHidden = true
						--print("has Hidden"..needed)
						--print("hasHidden:"..needed)
					elseif player:HasEquipment(needed, true) > 0 then
						displayOption = true
					end
				end
				local componentList = components ~= defence_drones and components ~= defence_drones_laser and 
					components ~= defence_drones_ion and components ~= defence_drones_missile and 
					components ~= defence_drones_focus and components ~= defence_drones_mini
				if hasHidden and (not hiddenSeen) and componentList then
					showBlueprint = false

				end
			end
			if displayOption then
				local weaponEvent = eventManager:CreateEvent("OG_CRAFT_CRAFT", 0, false)
				if showBlueprint then
					weaponEvent.eventName = "OG_CRAFT_CRAFT_"..weapon
					weaponEvent:AddChoice(weaponEvent, "Blueprint:", emptyReq, false)
				else
					weaponEvent.eventName = "OG_CRAFT_HIDDEN_"..weapon
					weaponEvent:AddChoice(weaponEvent, "Blueprint:", emptyReq, false)
				end

				local eventString = ((showBlueprint and weaponBlueprint.desc.title:GetText()) or "???") .." Requires:"
				for i, components in ipairs(craftingData.components) do
					eventString = eventString.."\n  Atleast "..craftingData.component_amounts[i]..":"
					if components == defence_drones then
						eventString = eventString.."\n	Any Defense Drone"
					elseif components == defence_drones_laser then
						eventString = eventString.."\n	Any Defense Drone\n	Laser Turret Base"
					elseif components == defence_drones_ion then
						eventString = eventString.."\n	Any Defense Drone\n	Ion Turret Base"
					elseif components == defence_drones_missile then
						eventString = eventString.."\n	Any Defense Drone\n	Missile Turret Base"
					elseif components == defence_drones_focus then
						eventString = eventString.."\n	Any Defense Drone\n	Focus Turret Base"
					elseif components == defence_drones_mini then
						eventString = eventString.."\n	Any Defense Drone\n	Micro Turret Base"
					else
						for _, needed in ipairs(components) do
							if hideName[needed] and not (player:HasEquipment(needed, true) > 0) then
								eventString = eventString.."\n	"..hideName[needed]
							else
								local tempBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint(needed)
								if tempBlueprint.desc.title:GetText() == "" then
									tempBlueprint = Hyperspace.Blueprints:GetDroneBlueprint(needed)
								end
								eventString = eventString.."\n	"..tempBlueprint.desc.title:GetText()
							end
						end
					end
				end
				weaponEvent.text.data = eventString
				weaponEvent.text.isLiteral = true

				local canCraft = true
				for i, components in ipairs(craftingData.components) do
					local amount = 0
					local amount_need = craftingData.component_amounts[i]
					for _, needed in ipairs(components) do
						amount = amount + player:HasEquipment(needed, true)
					end
					if amount < amount_need then 
						canCraft = false
					end
				end

				if canCraft then
					local craftStepEvent = eventManager:CreateEvent("OG_CRAFT_CRAFT_STEP", 0, false)
					weaponEvent:AddChoice(craftStepEvent, "Craft this item.", blueReq, false)

					addComponentStep(craftStepEvent, weapon, craftingData, 1, 1)


					if showBlueprint then
						event:AddChoice(weaponEvent, weaponBlueprint.desc.title:GetText(), blueReq, false)
					end
				else
					local tempEvent = eventManager:CreateEvent("OPTION_INVALID", 0, false)
					weaponEvent:AddChoice(tempEvent, "Craft this item.", emptyReq, true)


					if showBlueprint then
						event:AddChoice(weaponEvent, weaponBlueprint.desc.title:GetText(), emptyReq, false)
					end
				end
				if showBlueprint then
					table.insert(craftedItemsVisible, weapon)
				else
					event:AddChoice(weaponEvent, "Unknown Turret", emptyReq, false)
					table.insert(craftedItemsVisible, "OG_TURRET_UNKNOWN")
				end
			end
		end
	end
end)

script.on_internal_event(Defines.InternalEvents.POST_CREATE_CHOICEBOX, function(choiceBox, event)
	--print(A(event.eventName, 1, 16).." AND "..string.sub(event.eventName, 17, string.len(event.eventName)))
	if event.eventName == "OG_CRAFT_MAIN_MENU" then
		local i = 0
		for choice in vter(choiceBox:GetChoices()) do
			if i > 1 then
				choice.rewards.weapon = Hyperspace.Blueprints:GetWeaponBlueprint(craftedItemsVisible[i-1])
			end
			i = i + 1
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