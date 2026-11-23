--Written by MsBinaryLily for Lily's Innovations, you should check it out!
local lastModifiedShipName = nil
local lastModifiedShipValue = 0
local loadComplete = false

local function resetLastBonus()
	--print("RESET")
	if lastModifiedShipName then
		local def0 = Hyperspace.CustomShipSelect.GetInstance():GetDefinition(lastModifiedShipName)
		def0.systemLimit = lastModifiedShipValue
		lastModifiedShipName = nil
		lastModifiedShipValue = 0
		--print("RESET DONE")
	end
end

---@param shipManager Hyperspace.ShipManager
---@param bonus integer
---@param load boolean
local function applySystemBonus(shipManager, bonus, load)
	resetLastBonus()
	if bonus ~= 0 then
		local def = Hyperspace.CustomShipSelect.GetInstance():GetDefinition(shipManager.myBlueprint.blueprintName)
		lastModifiedShipName = shipManager.myBlueprint.blueprintName
		lastModifiedShipValue = def.systemLimit
		def.systemLimit = def.systemLimit + bonus
	end
	if not load then
		Hyperspace.playerVariables["og_systemslotbonus"] = bonus
		--print("SET: ", bonus)
	end
end

script.on_init(function (newGame)
	resetLastBonus()
	--local ok = Hyperspace.playerVariables and Hyperspace.playerVariables["og_test_variable"] == 1
	--print("OK: ", ok and true or false)
	loadComplete = false
end)


script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	--local benchmark_start = os.clock()
	if shipManager and Hyperspace.ships.player and shipManager.iShipId == 0 then
		local ok = Hyperspace.playerVariables and Hyperspace.playerVariables["og_test_variable"] == 1
		--print("OKL: ", ok and true or false)


		if ok and not loadComplete then
			local bonus = Hyperspace.playerVariables["og_systemslotbonus"]
			--print("BONUS: ", bonus)
			applySystemBonus(shipManager, bonus, true)
			--print("LOADED SYSTEM SLOT SCRIPT")

			local sysInfo = Hyperspace.ships.player.myBlueprint.systemInfo

			local systemId_2 = Hyperspace.ShipSystem.NameToSystemId("og_turret_adaptive_2")
			if sysInfo:has_key(systemId_2) then
				Hyperspace.playerVariables["og_turret_adaptive_can_install_second"] = 1
			end

			local systemId_single = Hyperspace.ShipSystem.NameToSystemId("og_turret_adaptive_single")
			if sysInfo:has_key(systemId_single) then
				Hyperspace.playerVariables["og_turret_adaptive_can_install_single"] = 1
			end
			loadComplete = true
		end
	end
	--local benchmark_end = os.clock()
	--print(string.format("core.lua SHIP_FLOOR 1: time: %.6f seconds", benchmark_end - benchmark_start))
end)


local function installSystemSlot()
	applySystemBonus(Hyperspace.ships.player, 1, false)
	if Hyperspace.ships.player:HasSystem(4) then --drones
		local droneSys = Hyperspace.ships.player:GetSystem(4)
		if droneSys:GetMaxPower() > 4 then
			droneSys:UpgradeSystem(-1 * (droneSys:GetMaxPower() - 4))

			--[[for i = droneSys:GetMaxPower(), 4 + 1 do
				droneSys]]
		end
	end
end

script.on_game_event("INSTALL_OG_TURRET_ADAPTIVE_SECONDARY_BEFORE", false, installSystemSlot)

script.on_game_event("INSTALL_OG_TURRET_ADAPTIVE_SECONDARY_BEFORE_2", false, installSystemSlot)

local function installSystemSlotMini()
	applySystemBonus(Hyperspace.ships.player, 1, false)
end

script.on_game_event("INSTALL_OG_TURRET_MINI_1_BEFORE", false, installSystemSlotMini)
script.on_game_event("INSTALL_OG_TURRET_MINI_2_BEFORE", false, installSystemSlotMini)
script.on_game_event("INSTALL_OG_TURRET_MINI_3_BEFORE", false, installSystemSlotMini)
script.on_game_event("INSTALL_OG_TURRET_MINI_4_BEFORE", false, installSystemSlotMini)

local CheckInstallSystemsShow = {}
CheckInstallSystemsShow["UPG_OG_TURRET_INSTALL_MINI_1_SHOW"] = "og_turret_mini"
CheckInstallSystemsShow["UPG_OG_TURRET_INSTALL_MINI_2_SHOW"] = "og_turret_mini_2"
CheckInstallSystemsShow["UPG_OG_TURRET_INSTALL_MINI_3_SHOW"] = "og_turret_mini_3"
CheckInstallSystemsShow["UPG_OG_TURRET_INSTALL_MINI_4_SHOW"] = "og_turret_mini_4"
local CheckInstallSystemsBuy = {}
CheckInstallSystemsBuy["UPG_OG_TURRET_INSTALL_MINI_1_BUY"] = "og_turret_mini"
CheckInstallSystemsBuy["UPG_OG_TURRET_INSTALL_MINI_2_BUY"] = "og_turret_mini_2"
CheckInstallSystemsBuy["UPG_OG_TURRET_INSTALL_MINI_3_BUY"] = "og_turret_mini_3"
CheckInstallSystemsBuy["UPG_OG_TURRET_INSTALL_MINI_4_BUY"] = "og_turret_mini_4"
script.on_internal_event(Defines.InternalEvents.HAS_EQUIPMENT, function(shipManager, equipment, value)
	if CheckInstallSystemsShow[equipment] then
		local sysId = Hyperspace.ShipSystem.NameToSystemId(CheckInstallSystemsShow[equipment])
		local sysInfo = shipManager.myBlueprint.systemInfo
		if sysInfo:has_key(sysId) and not shipManager:HasSystem(sysId) then
			value = value + 1
		end
	elseif CheckInstallSystemsBuy[equipment] then
		local sysId = Hyperspace.ShipSystem.NameToSystemId(CheckInstallSystemsBuy[equipment])
		if shipManager:HasSystem(sysId) then
			value = value + 1
		end
	end
	return Defines.Chain.CONTINUE, value
end)

local vter = mods.multiverse.vter

script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function(shipManager)
	if shipManager.iShipId == 1 then return end
	if shipManager:HasAugmentation("UPG_OG_TURRET_ADAPTIVE_SECONDARY") > 0 and not shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId("og_turret_adaptive_2")) then
		local count = 0
		for sys in vter(shipManager.vSystemList) do
			if not Hyperspace.ShipSystem.IsSubsystem(sys.iSystemType) then
				count = count + 1
			end
		end
		--print("count:"..count.." lastModifiedShipValue:"..lastModifiedShipValue)
		if count > lastModifiedShipValue then
			Hyperspace.ships.player:RemoveSystem(Hyperspace.ShipSystem.NameToSystemId("og_turret_adaptive"))
			print("As both turret systems share a system slot, both were removed when replacing the secondary one with drones while at maximum system slots.")
		end
		resetLastBonus()
		Hyperspace.ships.player:RemoveAugmentation("HIDDEN UPG_OG_TURRET_ADAPTIVE_SECONDARY")
	end
end)