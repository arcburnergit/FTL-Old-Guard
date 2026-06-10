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
	if shipManager and shipManager.iShipId == 0 then
		local ok = Hyperspace.playerVariables and Hyperspace.playerVariables["og_test_variable"] == 1
		--print("OKL: ", ok and true or false)


		if ok and not loadComplete then
			local bonus = Hyperspace.playerVariables["og_systemslotbonus"]
			--print("BONUS: ", bonus)
			applySystemBonus(shipManager, bonus, true)
			--print("LOADED SYSTEM SLOT SCRIPT")

			local systemId = Hyperspace.ShipSystem.NameToSystemId("og_turret_adaptive_2")
			local sysInfo = Hyperspace.ships.player.myBlueprint.systemInfo
			if sysInfo:has_key(systemId) then
				Hyperspace.playerVariables["og_turret_adaptive_can_install_second"] = 1
			end
			loadComplete = true
		end
	end
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