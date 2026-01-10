local vter = mods.multiverse.vter
local time_increment = mods.multiverse.time_increment
local userdata_table = mods.multiverse.userdata_table
local node_child_iter = mods.multiverse.node_child_iter
local node_get_number_default = mods.multiverse.node_get_number_default

local get_room_at_location = mods.og.get_room_at_location

local function xor(a, b)
	return (a and not b) or (not a and b)
end
local function isPointInEllipse(point, ellipse)
	if ellipse.a <= 0 or ellipse.b <= 0 then
		return false
	end
	local dx = point.x - ellipse.center.x
	local dy = point.y - ellipse.center.y
	local result = (dx^2 / ellipse.a^2) + (dy^2 / ellipse.b^2)

	return result <= 1
end

local function worldToPlayerLocation(location)
	local cApp = Hyperspace.App
	local combatControl = cApp.gui.combatControl
	local playerPosition = combatControl.playerShipPosition
	return Hyperspace.Point(location.x - playerPosition.x, location.y - playerPosition.y)
end
local function worldToEnemyLocation(location)
	local cApp = Hyperspace.App
	local combatControl = cApp.gui.combatControl
	local position = combatControl.position
	local targetPosition = combatControl.targetPosition
	local enemyShipOriginX = position.x + targetPosition.x
	local enemyShipOriginY = position.y + targetPosition.y
	return Hyperspace.Point(location.x - enemyShipOriginX, location.y - enemyShipOriginY)
end

local function get_distance(point1, point2)
	return math.sqrt(((point2.x - point1.x)^ 2)+((point2.y - point1.y) ^ 2))
end

local function offset_point_in_direction(position, angle, offset_x, offset_y)
	local alpha = math.rad(angle)
	local newX = position.x - (offset_y * math.cos(alpha)) - (offset_x * math.cos(alpha+math.rad(90)))
	local newY = position.y - (offset_y * math.sin(alpha)) - (offset_x * math.sin(alpha+math.rad(90)))
	return Hyperspace.Pointf(newX, newY)
end

local function get_random_point_in_radius(center, radius)
	r = radius * math.sqrt(math.random())
	theta = math.random() * 2 * math.pi
	return Hyperspace.Pointf(center.x + r * math.cos(theta), center.y + r * math.sin(theta))
end

local function normalize_angle(angle)
	angle = angle % 360
	if angle < 0 then
		angle = angle + 360
	end
	return angle
end

local function angle_diff(angle1, angle2)
	local diff = angle2 - angle1
	while diff > 180 do
		diff = diff - 360
	end
	while diff < -180 do
		diff = diff + 360
	end
	return diff
end

local function move_angle_to(current_angle, target_angle, max_rotation)
	local diff = target_angle - current_angle
	if diff > 180 then
		diff = diff - 360
	elseif diff <= -180 then
		diff = diff + 360
	end

	local new_angle

	if math.abs(diff) <= math.abs(max_rotation) then
		new_angle = target_angle
	else
		if diff > 0 then
			new_angle = current_angle + math.abs(max_rotation)
		else
			new_angle = current_angle - math.abs(max_rotation)
		end
	end
	--print("current_angle:"..tostring(current_angle).." target_angle:"..tostring(target_angle).." max_rotation:"..tostring(max_rotation).." new_angle"..tostring(normalize_angle(new_angle)))
	return normalize_angle(new_angle)
end

local function get_angle_between_points(pos, target_pos)
	local alpha = math.atan((target_pos.y-pos.y), (target_pos.x-pos.x))
	return normalize_angle(math.deg(alpha))
end

local function find_intercept_angle(current_pos, speed, target_pos, target_velocity)
	--print("find_intercept")
	--print("current_pos x:"..tostring(current_pos.x).." y:"..tostring(current_pos.y))
	--print("speed:"..tostring(speed))
	--print("target_pos x:"..tostring(target_pos.x).." y:"..tostring(target_pos.y))
	--print("target_velocity x:"..tostring(target_velocity.x).." y:"..tostring(target_velocity.y).." speed:"..tostring(math.sqrt(target_velocity.x^2 + target_velocity.y^2)))
	local px = target_pos.x - current_pos.x
	local py = target_pos.y - current_pos.y
	local epsilon = 0.0001 -- tolerence for checking near 0

	if math.abs(target_velocity.x) < epsilon and math.abs(target_velocity.y) < epsilon then
		local p_sq = px^2 + py^2
		local dist = math.sqrt(p_sq)
		local t = dist / speed
		local intercept_angle = get_angle_between_points(current_pos, target_pos)
		--print("direct intercept")
		return intercept_angle, target_pos, t
	end

	local v_sq = target_velocity.x^2 + target_velocity.y^2
	local A = v_sq - speed^2

	local p_dot_v = px * target_velocity.x + py * target_velocity.y
	local B = 2 * p_dot_v

	local p_sq = px^2 + py^2
	local C = p_sq

	-- time to intercept
	local t = nil
	if math.abs(A) < epsilon then
		if math.abs(B) > epsilon then
			t = -C / B
		else
			--print("Failed Intercept, current_pos and target_pos are the same.")
			return nil 
		end
	else
		local D = B^2 - 4*A*C

		if D < 0 then
			--print("Failed Intercept, interception is impossible.")
			return nil
		end

		local D_sqrt = math.sqrt(D)
		local t1 = (-B + D_sqrt) / (2 * A)
		local t2 = (-B - D_sqrt) / (2 * A)

		if t1 > 0 and t2 > 0 then
			t = math.min(t1, t2)
		elseif t1 > 0 then
			t = t1
		elseif t2 > 0 then
			t = t2
		else
			--print("Failed Intercept, interception is impossible 2.")
			return nil
		end
	end

	if t <= 0 then
		--print("Failed Intercept, interception time is negative.")
		return nil
	end

	local cur_vx = (px / t) + target_velocity.x
	local cur_vy = (py / t) + target_velocity.y

	local intercept_angle = get_angle_between_points({x = 0, y = 0}, {x = cur_vx, y = cur_vy})
	local intercept_point = {
		x = target_pos.x + target_velocity.x * t,
		y = target_pos.y + target_velocity.y * t
	}
	return intercept_angle, Hyperspace.Pointf(intercept_point.x, intercept_point.y), t
end

local systemName = "og_turret"
mods.og.microTurrets = {["og_turret_mini"] = true, ["og_turret_mini_2"] = true, ["og_turret_mini_3"] = true, ["og_turret_mini_4"] = true}
local microTurrets = mods.og.microTurrets
mods.og.systemNameList = {systemName, "og_turret_2", "og_turret_3", "og_turret_4", "og_turret_mini", "og_turret_mini_2", "og_turret_mini_3", "og_turret_mini_4", "og_turret_adaptive"}
local systemNameList = mods.og.systemNameList
local systemNameCheck = {}
for _, sysName in ipairs(systemNameList) do
	systemNameCheck[sysName] = true
end

local turret_directions = {
	up = -1,
	right = 0,
	down = 1,
	left = -2,
	upright = -0.5,
	downright = 0.5,
	upleft = -1.5,
	downleft = 1.5,
}

local turret_location = {}
local starting_turrets = {}

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
local beamDamageMods = mods.multiverse.beamDamageMods
beamDamageMods["OG_FOCUS_PROJECTILE_FAKE"] = {iDamage = 0}
beamDamageMods["OG_FOCUS_PROJECTILE_WEAK_FAKE"] = {iDamage = 0}
beamDamageMods["OG_FOCUS_PROJECTILE_BIO"] = {iDamage = 0}
beamDamageMods["OG_FOCUS_PROJECTILE_BIO_FAKE"] = {iDamage = 0}

mods.og.turretBlueprintsList = {}
local turretBlueprintsList = mods.og.turretBlueprintsList 

--1 = MISSILES, 2 = FLAK, 3 = DRONES, 4 = PROJECTILES, 5 = HACKING 
local defence_types = {
	DRONES = {[3] = true, [7] = true, name = "Drones"},
	MISSILES = {[1] = true, [2] = true, [7] = true, name = "All Solid Projectiles"},
	DRONES_MISSILES = {[1] = true, [2] = true, [3] = true, [7] = true, name = "All Solid Projectiles and Drones"},
	PROJECTILES = {[4] = true, name = "Non-Solid Projectiles"},
	PROJECTILES_MISSILES = {[1] = true, [2] = true, [4] = true, [7] = true, name = "All Projectiles"},
	ALL = {[1] = true, [2] = true, [3] = true, [4] = true, [7] = true, name = "All"},
}
mods.og.chain_types = {
	cooldown = 1,
}
local chain_types = mods.og.chain_types

mods.og.turrets = {}
local turrets = mods.og.turrets
local vunerable_weapons = mods.og.vunerable_weapons

local function add_stat_text(desc, currentTurret, chargeMax)
	desc = desc.."Stats:\nCharge Time: "
	for i, t in ipairs(currentTurret.charge_time) do
		if i <= chargeMax then
			desc = desc..math.floor(t*10)/10
		end
		if i < #currentTurret.charge_time and i < chargeMax then
			desc = desc.."/"
		end
	end
	desc = desc.."\nMaximum Charges: "..math.floor(currentTurret.charges)
	desc = desc.."\nCharge Amount: "..math.floor(currentTurret.charges_per_charge)
	if currentTurret.ammo_consumption then
		desc = desc.."\nMissile Consumption: "..tostring(currentTurret.ammo_consumption)
	end
	if currentTurret.chain and currentTurret.chain.type == chain_types.cooldown then
		chain_amount = math.floor(currentTurret.chain.amount * 100)
		desc = desc.."\nChain Effect: Reduces cooldown by "..chain_amount.."%"
		local chain_count = math.floor(currentTurret.chain.count)
		local chain_max_effect = math.floor(currentTurret.chain.amount * currentTurret.chain.count * 100)
		desc = desc.."\nChain Reduction Cap: "..chain_max_effect.."% ("..chain_count.." chains)"
	end
	desc = desc.."\n\nRotation Speed: "..math.floor(currentTurret.rotation_speed)
	if currentTurret.shot_radius then
		desc = desc.."\nShot Radius: "..math.floor(currentTurret.shot_radius)
	end
	desc = desc.."\nFire Rate: "
	for i, t in ipairs(currentTurret.fire_points) do
		desc = desc..t.fire_delay.."s"
		if i < #currentTurret.fire_points then
			desc = desc.."/"
		end
	end
	desc = desc.."\nProjectile Target: "..currentTurret.defence_type.name
	local shotBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint(currentTurret.blueprint)
	local damage = shotBlueprint.damage
	desc = desc.."\n"
	if damage.iDamage > 0 then
		desc = desc.."\nBase Hull Damage: "..math.floor(damage.iDamage)
	end
	if damage.iSystemDamage + damage.iDamage > 0 then
		desc = desc.."\nTotal System Damage: "..math.floor(damage.iDamage + damage.iSystemDamage)
	end
	if damage.iPersDamage + damage.iDamage > 0 then
		desc = desc.."\nTotal Crew Damage: "..math.floor((damage.iDamage + damage.iPersDamage) * 15)
	end
	if damage.iIonDamage > 0 then
		desc = desc.."\nTotal Ion Damage: "..math.floor(damage.iIonDamage)
	end
	if damage.iShieldPiercing ~= 0 then
		desc = desc.."\nShield Piercing: "..math.floor(damage.iShieldPiercing)
	end
	if damage.bHullBuster then
		desc = desc.."\nDoes 2x damage to systemless rooms"
	end
	desc = desc.."\n"
	if damage.bLockdown then
		desc = desc.."\nLocks down rooms on hit"
	end
	if damage.fireChance > 0 then
		desc = desc.."\nFire Chance: "..math.floor(damage.fireChance * 10).."%"
	end
	if damage.breachChance > 0 then
		desc = desc.."\nBreach Chance: "..math.floor(damage.breachChance * 10).."% (Adjusted: "..math.floor((100 - 10 * damage.fireChance) * (damage.breachChance/10)).."%)"
	end
	if damage.stunChance > 0 then
		desc = desc.."\nStun Chance: "..math.floor(damage.stunChance * 10).."% ("..math.floor((damage.iStun > 0 and damage.iStun) or 3).." seconds long)"
	end
	if vunerable_weapons[currentTurret.blueprint] then
		desc = desc.."\nEffect Duration: "..math.floor(vunerable_weapons[currentTurret.blueprint]).." seconds long"
	end
	if currentTurret.stealth then
		desc = desc.."\n\n"..Hyperspace.Text:GetText("stat_stealth")
	end
	return desc
end

script.on_internal_event(Defines.InternalEvents.WEAPON_DESCBOX, function(blueprint, desc)
	if turrets[blueprint.name] then
		local currentTurret = turrets[blueprint.name]
		desc = add_stat_text((blueprint.desc.description:GetText().."\n\n"), currentTurret, 8)
		desc = desc.."\n\nDefault Price: "..math.floor(blueprint.desc.cost).."~   -   Selling Price: "..math.floor(blueprint.desc.cost/2).."~"
	end
	return Defines.Chain.CONTINUE, desc
end)

script.on_internal_event(Defines.InternalEvents.WEAPON_STATBOX, function(blueprint, stats)
	return Defines.Chain.CONTINUE, desc
end)

local function findStartingTurret(shipManager, sysName)
	local shipName = shipManager.myBlueprint.blueprintName
	if starting_turrets[shipName] and starting_turrets[shipName][sysName] then
		local weapon_id = starting_turrets[shipName][sysName]
		--print(weapon_id..":"..Hyperspace.Blueprints:GetBlueprintList(weapon_id):size())
		if Hyperspace.Blueprints:GetBlueprintList(weapon_id):size() > 0 then
			--print("WEAPON DOESN'T EXIST:"..weapon_id)
			local list = Hyperspace.Blueprints:GetBlueprintList(weapon_id)
			local r = math.random(list:size()) - 1
			weapon_id = list[r]
			--print("Selected Random Item:"..weapon_id)
		end
		--print("findStartingTurret: "..shipName.." "..sysName.." "..weapon_id)
		for i, id in ipairs(turretBlueprintsList) do
			if weapon_id == id then
				return id, i
			end
		end
		print("Failed to find starting turret")
	end
	return "", -1
end

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
--local systemTime = 0
--local systemFiringTime = 0
--local systemCurrentShot = 1
--local currentlyTargetting = false

local function is_system(systemBox)
	local systemId = Hyperspace.ShipSystem.SystemIdToName(systemBox.pSystem.iSystemType)
	local isSystemName = false
	for _, sysName in ipairs(systemNameList) do
		if systemId == sysName then
			isSystemName = true
		end
	end
	return isSystemName and systemBox.bPlayerUI
end
local function is_system_enemy(systemBox)
	local systemId = Hyperspace.ShipSystem.SystemIdToName(systemBox.pSystem.iSystemType)
	local isSystemName = false
	for _, sysName in ipairs(systemNameList) do
		if systemId == sysName then
			isSystemName = true
		end
	end
	return isSystemName and not systemBox.bPlayerUI
end

local function get_level_description_system(currentId, level, tooltip)
	for _, sysName in ipairs(systemNameList) do
		if currentId == Hyperspace.ShipSystem.NameToSystemId(sysName) then
			return string.format("More System Power")
		end
	end
end
script.on_internal_event(Defines.InternalEvents.GET_LEVEL_DESCRIPTION, get_level_description_system)

local UIOffset_x = 32
local UIOffset_y = -44

local autoFireX = 63
local autoFireY = 61
local autoFireOffButton = Hyperspace.Button()
autoFireOffButton:OnInit("button_small_autofireOff", Hyperspace.Point(UIOffset_x + autoFireX, UIOffset_y + autoFireY))
autoFireOffButton.hitbox.x = 9
autoFireOffButton.hitbox.y = 2
autoFireOffButton.hitbox.w = 22
autoFireOffButton.hitbox.h = 24
local autoFireOnButton = Hyperspace.Button()
autoFireOnButton:OnInit("button_small_autofireOn", Hyperspace.Point(UIOffset_x + autoFireX, UIOffset_y + autoFireY))
autoFireOnButton.hitbox.x = 9
autoFireOnButton.hitbox.y = 2
autoFireOnButton.hitbox.w = 22
autoFireOnButton.hitbox.h = 24

local function system_construct_system_box(systemBox)
	if is_system(systemBox) then
		systemBox.extend.xOffset = 113

		local targetButton = Hyperspace.Button()
		targetButton:OnInit("systemUI/button_og_turret_target", Hyperspace.Point(UIOffset_x, UIOffset_y))
		targetButton.hitbox.x = 16
		targetButton.hitbox.y = 16
		targetButton.hitbox.w = 75
		targetButton.hitbox.h = 39
		systemBox.table.targetButton = targetButton
		local offenseButton = Hyperspace.Button()
		offenseButton:OnInit("systemUI/button_og_turret_toggle_o", Hyperspace.Point(UIOffset_x, UIOffset_y))
		offenseButton.hitbox.x = 74
		offenseButton.hitbox.y = 37
		offenseButton.hitbox.w = 17
		offenseButton.hitbox.h = 18
		systemBox.table.offenseButton = offenseButton
		local defenceButton = Hyperspace.Button()
		defenceButton:OnInit("systemUI/button_og_turret_toggle_d", Hyperspace.Point(UIOffset_x, UIOffset_y))
		defenceButton.hitbox.x = 74
		defenceButton.hitbox.y = 37
		defenceButton.hitbox.w = 17
		defenceButton.hitbox.h = 18
		systemBox.table.defenceButton = defenceButton

		local systemId = Hyperspace.ShipSystem.SystemIdToName(systemBox.pSystem.iSystemType)
		if systemId == "og_turret_adaptive" then
			systemBox.pSystem.table.micro = true
			microTurrets[systemId] = true
			if Hyperspace.playerVariables.og_turret_adaptive_saved_x > 0 then
				--print("load pos")
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
		elseif microTurrets[systemId] then
			systemBox.pSystem.table.micro = true
			systemBox.pSystem.bBoostable = false
		end

		systemBox.pSystem.table.index = -1
		systemBox.pSystem.table.chargeTime = 0
		systemBox.pSystem.table.firingTime = 0
		--systemBox.pSystem.table.currentShot = 1
		systemBox.pSystem.table.entryAngle = math.random(360)
		systemBox.pSystem.table.currentlyTargetting = false
		systemBox.pSystem.table.currentlyTargetted = false

		systemBox.pSystem.table.currentAimingAngle = 0
		systemBox.pSystem.table.autoFireInvert = false
		systemBox.pSystem.table.currentTarget = nil
		systemBox.pSystem.table.currentTargetTemp = nil
		systemBox.pSystem.table.ammo_consumed = 0
	elseif is_system_enemy(systemBox) then
		systemBox.pSystem.table.chargeTime = 0
		systemBox.pSystem.table.firingTime = 0
		--systemBox.pSystem.table.currentShot = 1
		systemBox.pSystem.table.entryAngle = math.random(360)
		systemBox.pSystem.table.currentlyTargetting = false
		systemBox.pSystem.table.currentlyTargetted = false

		local systemId = Hyperspace.ShipSystem.SystemIdToName(systemBox.pSystem.iSystemType)
		if microTurrets[systemId] then
			systemBox.pSystem.table.micro = true
			--systemBox.pSystem.bBoostable = false
		end

		systemBox.pSystem.table.currentAimingAngle = -90
		systemBox.pSystem.table.currentTarget = nil
		systemBox.pSystem.table.ammo_consumed = 0
	end
end
script.on_internal_event(Defines.InternalEvents.CONSTRUCT_SYSTEM_BOX, system_construct_system_box)

local hoverBox = {
	x = 8,
	y = 85,
	w = 24,
	h = 14,
}
local function system_mouse_move(systemBox, x, y)
	if is_system(systemBox) then
		local systemId = Hyperspace.ShipSystem.SystemIdToName(systemBox.pSystem.iSystemType)
		local targetButton = systemBox.table.targetButton
		targetButton:MouseMove(x - (UIOffset_x), y - (UIOffset_y), false)
		local offenseButton = systemBox.table.offenseButton
		offenseButton:MouseMove(x - (UIOffset_x), y - (UIOffset_y), false)
		local defenceButton = systemBox.table.defenceButton
		defenceButton:MouseMove(x - (UIOffset_x), y - (UIOffset_y), false)
		local shipId = (systemBox.bPlayerUI and 0) or 1
		if offenseButton.bHover and Hyperspace.playerVariables[shipId..systemId..systemStateVarName] == 1 then
			systemBox.pSystem.table.tooltip_type = 1
		elseif defenceButton.bHover and Hyperspace.playerVariables[shipId..systemId..systemStateVarName] == 0 then
			systemBox.pSystem.table.tooltip_type = 2
		elseif targetButton.bHover then
			systemBox.pSystem.table.tooltip_type = 0
		else
			systemBox.pSystem.table.tooltip_type = -1
		end

		if systemBox.pSystem.table.index == Hyperspace.playerVariables.og_turret_count then
			if Hyperspace.playerVariables.og_turret_autofire == 0 then
				autoFireOffButton:MouseMove(x - (UIOffset_x + autoFireX), y - (UIOffset_y + autoFireY), false)
				if autoFireOffButton.bHover then
					systemBox.pSystem.table.tooltip_type = 3
				end
			else
				autoFireOnButton:MouseMove(x - (UIOffset_x + autoFireX), y - (UIOffset_y + autoFireY), false)
				if autoFireOnButton.bHover then
					systemBox.pSystem.table.tooltip_type = 4
				end
			end
		end
	end
	return Defines.Chain.CONTINUE
end
script.on_internal_event(Defines.InternalEvents.SYSTEM_BOX_MOUSE_MOVE, system_mouse_move)

script.on_internal_event(Defines.InternalEvents.ON_TICK, function() 
	local shipManager = Hyperspace.ships.player
	if not shipManager then return end
	for _, sysName in ipairs(systemNameList) do
		if shipManager and shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(sysName)) then
			local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(sysName))
			local shipId = 0
			if system.table.tooltip_type == 1 then
				Hyperspace.Mouse.bForceTooltip = true
				Hyperspace.Mouse.tooltip = "Set the turret to offensive mode."
			elseif system.table.tooltip_type == 2 then
				Hyperspace.Mouse.bForceTooltip = true
				Hyperspace.Mouse.tooltip = "Set the turret to defensive mode."
			elseif system.table.tooltip_type == 0 then
				Hyperspace.Mouse.bForceTooltip = true
				local currentTurret = turrets[ turretBlueprintsList[ Hyperspace.playerVariables[shipId..sysName..systemBlueprintVarName] ] ]
				Hyperspace.Mouse.tooltip = add_stat_text("", currentTurret, system:GetMaxPower())
			elseif system.table.tooltip_type == 3 or system.table.tooltip_type == 3 then
				Hyperspace.Mouse.bForceTooltip = true
				Hyperspace.Mouse.tooltip = "Toggle to activate/deactivate turrets automatically firing.\n\nLEFT CTRL + AIM can force a turret to do the opposite of current setting"
			end
		end
	end
end)

local function checkValidTarget(targetable, defence_type, shipManager)
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

local cursorValid = Hyperspace.Resources:GetImageId("mouse/mouse_og_turret_valid.png")
local cursorValid2 = Hyperspace.Resources:GetImageId("mouse/mouse_og_turret_valid2.png")

local cursorDefault = Hyperspace.Resources:GetImageId("mouse/pointerValid.png")
local cursorDefault2 = Hyperspace.Resources:GetImageId("mouse/pointerInvalid.png")

local function select_turret(system, shift)
	local shipManager = Hyperspace.ships.player
	system.table.currentTarget = nil
	system.table.autoFireInvert = shift 
	system.table.currentTargetTemp = nil
	system.table.currentlyTargetted = false
	system.table.currentlyTargetting = true
	Hyperspace.Mouse.validPointer = cursorValid
	Hyperspace.Mouse.invalidPointer = cursorValid2
end

local ctrl_held = false

local function find_closest_slot(roomShape, mousePos)
	local slotSize = 35
	local relX = mousePos.x - roomShape.x
	local relY = mousePos.y - roomShape.y
	if relX < 0 or relX >= roomShape.w or relY < 0 or relY >= roomShape.h then
		return 0
	end
	local slotsPerRow = math.floor(roomShape.w / slotSize)
	local col = math.floor(relX / slotSize)
	local row = math.floor(relY / slotSize)
	local slotID = (row * slotsPerRow) + col

	return slotID
end

local function system_click(systemBox, shift)
	local systemId = Hyperspace.ShipSystem.SystemIdToName(systemBox.pSystem.iSystemType)
	local shipId = (systemBox.bPlayerUI and 0) or 1
	if is_system(systemBox) then
		local targetButton = systemBox.table.targetButton
		local shipManager = Hyperspace.ships.player
		if Hyperspace.App.world.bStartedGame and systemBox.pSystem.table.currentlyTargetting then
			systemBox.pSystem.table.currentlyTargetting = false
			Hyperspace.Mouse.validPointer = cursorDefault
			Hyperspace.Mouse.invalidPointer = cursorDefault2
			local combatControl = Hyperspace.App.gui.combatControl
			if combatControl.selectedRoom >= 0 then
				local targetShipGraph = Hyperspace.ShipGraph.GetShipInfo(1)
				local roomShape = targetShipGraph:GetRoomShape(combatControl.selectedRoom)
				local mousePosEnemy = worldToEnemyLocation(Hyperspace.Mouse.position)
				local slotId = find_closest_slot(roomShape, mousePosEnemy)
				systemBox.pSystem.table.currentTargetTemp = {roomId = combatControl.selectedRoom, slotId = slotId}
			else
				local shipId = (systemBox.bPlayerUI and 0) or 1
				local currentTurret = turrets[ turretBlueprintsList[ Hyperspace.playerVariables[shipId..systemId..systemBlueprintVarName] ] ]
				local mousePosPlayer = worldToPlayerLocation(Hyperspace.Mouse.position)
				local mousePosEnemy = worldToEnemyLocation(Hyperspace.Mouse.position)
				local spaceManager = Hyperspace.App.world.space
				local currentClosest = nil
				for projectile in vter(spaceManager.projectiles) do
					local blueprint = Hyperspace.Blueprints:GetWeaponBlueprint(projectile.extend.name)
					if checkValidTarget(projectile._targetable, currentTurret.defence_type, shipManager) and not projectile.missed and not projectile.passedTarget and blueprint.typeName ~= "BEAM" then
						local targetPos = projectile._targetable:GetRandomTargettingPoint(true)
						local dist
						if projectile._targetable:GetSpaceId() == 0 then
							dist = get_distance(mousePosPlayer, targetPos)
						else
							dist = get_distance(mousePosEnemy, targetPos)
						end
						if (not currentClosest and dist < 20) or (currentClosest and dist < 20 and dist < currentClosest.dist) then
							currentClosest = {target = projectile, dist = dist}
						end
					end
				end
				for drone in vter(spaceManager.drones) do
					if checkValidTarget(drone._targetable, currentTurret.defence_type, shipManager) and not drone.bDead then
						local targetPos = drone._targetable:GetRandomTargettingPoint(true)
						local dist
						if projectile._targetable:GetSpaceId() == 0 then
							dist = get_distance(mousePosPlayer, targetPos)
						else
							dist = 500
						end
						if (not currentClosest and dist < 20) or (currentClosest and dist < 20 and dist < currentClosest.dist) then
							currentClosest = {target = drone, dist = dist}
						end
					end
				end
				if currentClosest then
					systemBox.pSystem.table.currentlyTargetted = true
					systemBox.pSystem.table.currentTargetTemp = currentClosest.target
				end
			end
		end
		local offenseButton = systemBox.table.offenseButton
		local defenceButton = systemBox.table.defenceButton
		if offenseButton.bHover and offenseButton.bActive then
			local shipManager = Hyperspace.ships.player
			systemBox.pSystem.table.currentTarget = nil
			systemBox.pSystem.table.currentlyTargetted = false
			systemBox.pSystem.table.currentTargetTemp = nil
			Hyperspace.playerVariables[shipId..Hyperspace.ShipSystem.SystemIdToName(systemBox.pSystem.iSystemType)..systemStateVarName] = 0
		elseif defenceButton.bHover and defenceButton.bActive then
			local shipManager = Hyperspace.ships.player
			systemBox.pSystem.table.currentTarget = nil
			systemBox.pSystem.table.currentlyTargetted = false
			systemBox.pSystem.table.currentTargetTemp = nil
			Hyperspace.playerVariables[shipId..Hyperspace.ShipSystem.SystemIdToName(systemBox.pSystem.iSystemType)..systemStateVarName] = 1
		elseif targetButton.bHover and targetButton.bActive then
			select_turret(systemBox.pSystem, ctrl_held)
		end

		if systemBox.pSystem.table.index == Hyperspace.playerVariables.og_turret_count then
			if Hyperspace.playerVariables.og_turret_autofire == 0 and autoFireOffButton.bHover and autoFireOffButton.bActive then
				Hyperspace.playerVariables.og_turret_autofire = 1
			elseif Hyperspace.playerVariables.og_turret_autofire == 1 and autoFireOnButton.bHover and autoFireOnButton.bActive then
				Hyperspace.playerVariables.og_turret_autofire = 0
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
			if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(sysName)) then
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

--local placedImage = Hyperspace.Resources:CreateImagePrimitiveString("icons/"..systemIdName.."_placed.png", -20, -20, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)

local targetingImage = {
	hover = Hyperspace.Resources:CreateImagePrimitiveString("og_turrets/crosshairs_placed_hover.png", -20, -20, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	temp = Hyperspace.Resources:CreateImagePrimitiveString("og_turrets/crosshairs_placed_temp.png", -20, -20, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	full = Hyperspace.Resources:CreateImagePrimitiveString("og_turrets/crosshairs_placed.png", -20, -20, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
}

script.on_render_event(Defines.RenderEvents.SHIP_SPARKS, function(ship) end, function(ship) 
	local shipManager = Hyperspace.ships(ship.iShipId)
	local otherManager = Hyperspace.ships(1 - ship.iShipId)
	local combatControl = Hyperspace.App.gui.combatControl
	for _, sysName in ipairs(systemNameList) do
		if otherManager and otherManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(sysName)) then
			local system = otherManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(sysName))
			local currentTurret = turrets[ turretBlueprintsList[ Hyperspace.playerVariables[math.floor(otherManager.iShipId)..sysName..systemBlueprintVarName] ] ]
			--print("render"..turretBlueprintsList[ Hyperspace.playerVariables[math.floor(otherManager.iShipId)..sysName..systemBlueprintVarName] ].." "..math.floor(shipManager.iShipId)..sysName..systemBlueprintVarName)
			if system.table.currentlyTargetting then
				if currentTurret.blueprint_type ~= 3 then
					for room in vter(ship.vRoomList) do
						if room.iRoomId == combatControl.selectedRoom then
							Graphics.CSurface.GL_RenderPrimitive(room.highlightPrimitive) -- highlight the room
							Graphics.CSurface.GL_RenderPrimitive(room.highlightPrimitive2)
						end
					end
				elseif combatControl.selectedRoom >= 0 then
					local targetShipGraph = Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId)
					local roomShape = targetShipGraph:GetRoomShape(combatControl.selectedRoom)
					local mousePosEnemy = worldToEnemyLocation(Hyperspace.Mouse.position)
					local slotId = find_closest_slot(roomShape, mousePosEnemy)
					local targetPos = targetShipGraph:GetSlotWorldPosition(slotId, combatControl.selectedRoom)
					Graphics.CSurface.GL_PushMatrix()
					Graphics.CSurface.GL_Translate(targetPos.x, targetPos.y, 0)
					if currentTurret.shot_radius then
						Graphics.CSurface.GL_DrawCircle(0, 0, currentTurret.shot_radius, Graphics.GL_Color(1, 0, 0, 0.25))
					end
					Graphics.CSurface.GL_RenderPrimitive(targetingImage.temp)
					Graphics.CSurface.GL_PopMatrix()
				end
			elseif system.table.currentTarget and Hyperspace.playerVariables[math.floor(otherManager.iShipId)..sysName..systemStateVarName] == 0 and not system.table.currentlyTargetted then
				local targetPos = shipManager:GetRoomCenter(system.table.currentTarget.roomId)
				if currentTurret.blueprint_type == 3 then
					local targetShipGraph = Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId)
					targetPos = targetShipGraph:GetSlotWorldPosition(system.table.currentTarget.slotId, system.table.currentTarget.roomId)
				end
				Graphics.CSurface.GL_PushMatrix()
				Graphics.CSurface.GL_Translate(targetPos.x, targetPos.y, 0)
				if currentTurret.shot_radius then
					Graphics.CSurface.GL_DrawCircle(0, 0, currentTurret.shot_radius, Graphics.GL_Color(1, 0, 0, 0.25))
				end
				Graphics.CSurface.GL_RenderPrimitive(targetingImage.full)
				Graphics.CSurface.GL_PopMatrix()
			elseif system.table.currentTargetTemp and Hyperspace.playerVariables[math.floor(otherManager.iShipId)..sysName..systemStateVarName] == 0 and not system.table.currentlyTargetted then
				local targetPos = shipManager:GetRoomCenter(system.table.currentTargetTemp.roomId)
				if currentTurret.blueprint_type == 3 then
					local targetShipGraph = Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId)
					targetPos = targetShipGraph:GetSlotWorldPosition(system.table.currentTargetTemp.slotId, system.table.currentTargetTemp.roomId)
				end
				Graphics.CSurface.GL_PushMatrix()
				Graphics.CSurface.GL_Translate(targetPos.x, targetPos.y, 0)
				if currentTurret.shot_radius then
					Graphics.CSurface.GL_DrawCircle(0, 0, currentTurret.shot_radius, Graphics.GL_Color(1, 0, 0, 0.25))
				end
				Graphics.CSurface.GL_RenderPrimitive(targetingImage.temp)
				Graphics.CSurface.GL_PopMatrix()
			end
		end
		
	end
end)

script.on_render_event(Defines.RenderEvents.SHIP, function() end, function(ship)
	local shipManager = Hyperspace.ships.player
	local combatControl = Hyperspace.App.gui.combatControl
	for _, sysName in ipairs(systemNameList) do
		if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(sysName)) then
			local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(sysName))
			local currentTurret = turrets[ turretBlueprintsList[ Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemBlueprintVarName] ] ]
			local spaceManager = Hyperspace.App.world.space
			if system.table.currentlyTargetting then
				system.table.autoFireInvert = ctrl_held
				local mousePosPlayer = worldToPlayerLocation(Hyperspace.Mouse.position)
				local mousePosEnemy = worldToEnemyLocation(Hyperspace.Mouse.position)
				local currentClosest = nil
				for projectile in vter(spaceManager.projectiles) do
					local blueprint = Hyperspace.Blueprints:GetWeaponBlueprint(projectile.extend.name)
					if checkValidTarget(projectile._targetable, currentTurret.defence_type, shipManager) and not projectile.missed and not projectile.passedTarget and blueprint.typeName ~= "BEAM" and projectile._targetable:GetSpaceId() == ship.iShipId then
						local targetPos = projectile._targetable:GetRandomTargettingPoint(true)
						local dist
						if projectile._targetable:GetSpaceId() == 0 then
							dist = get_distance(mousePosPlayer, targetPos)
						else
							dist = get_distance(mousePosEnemy, targetPos)
						end
						if (not currentClosest and dist < 20) or (currentClosest and dist < 20 and dist < currentClosest.dist) then
							currentClosest = {target = projectile._targetable, dist = dist}
						end
					end
				end
				for drone in vter(spaceManager.drones) do
					if checkValidTarget(drone._targetable, currentTurret.defence_type, shipManager) and not drone.bDead and drone._targetable:GetSpaceId() == ship.iShipId then
						local targetPos = drone._targetable:GetRandomTargettingPoint(true)
						local dist
						if projectile._targetable:GetSpaceId() == 0 then
							dist = get_distance(mousePosPlayer, targetPos)
						else
							dist = 500
						end
						if (not currentClosest and dist < 20) or (currentClosest and dist < 20 and dist < currentClosest.dist) then
							currentClosest = {target = drone._targetable, dist = dist}
						end
					end
				end
				if currentClosest then
					local targetPos = currentClosest.target:GetRandomTargettingPoint(true)
					Graphics.CSurface.GL_PushMatrix()
					Graphics.CSurface.GL_Translate(targetPos.x, targetPos.y, 0)
					if currentTurret.shot_radius then
						Graphics.CSurface.GL_DrawCircle(0, 0, currentTurret.shot_radius/2, Graphics.GL_Color(1, 0, 0, 0.25))
					end
					Graphics.CSurface.GL_RenderPrimitive(targetingImage.hover)
					Graphics.CSurface.GL_PopMatrix()
				end
			elseif system.table.currentTarget and (Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemStateVarName] == 1 or system.table.currentlyTargetted) then
				for projectile in vter(spaceManager.projectiles) do
					if projectile._targetable:GetSelfId() == system.table.currentTarget._targetable:GetSelfId() and projectile._targetable:GetSpaceId() == ship.iShipId then
						local targetPos = system.table.currentTarget._targetable:GetRandomTargettingPoint(true)
						Graphics.CSurface.GL_PushMatrix()
						Graphics.CSurface.GL_Translate(targetPos.x, targetPos.y, 0)
						if currentTurret.shot_radius then
							Graphics.CSurface.GL_DrawCircle(0, 0, currentTurret.shot_radius/2, Graphics.GL_Color(1, 0, 0, 0.25))
						end
						Graphics.CSurface.GL_RenderPrimitive(targetingImage.full)
						Graphics.CSurface.GL_PopMatrix()
					end
				end
				for drone in vter(spaceManager.drones) do
					if drone._targetable:GetSelfId() == system.table.currentTarget._targetable:GetSelfId() and drone._targetable:GetSpaceId() == ship.iShipId then
						local targetPos = system.table.currentTarget._targetable:GetRandomTargettingPoint(true)
						Graphics.CSurface.GL_PushMatrix()
						Graphics.CSurface.GL_Translate(targetPos.x, targetPos.y, 0)
						if currentTurret.shot_radius then
							Graphics.CSurface.GL_DrawCircle(0, 0, currentTurret.shot_radius/2, Graphics.GL_Color(1, 0, 0, 0.25))
						end
						Graphics.CSurface.GL_RenderPrimitive(targetingImage.full)
						Graphics.CSurface.GL_PopMatrix()
					end
				end
			elseif system.table.currentTargetTemp and system.table.currentlyTargetted then
				for projectile in vter(spaceManager.projectiles) do
					if projectile._targetable:GetSelfId() == system.table.currentTargetTemp._targetable:GetSelfId() and projectile._targetable:GetSpaceId() == ship.iShipId then
						local targetPos = system.table.currentTargetTemp._targetable:GetRandomTargettingPoint(true)
						Graphics.CSurface.GL_PushMatrix()
						Graphics.CSurface.GL_Translate(targetPos.x, targetPos.y, 0)
						if currentTurret.shot_radius then
							Graphics.CSurface.GL_DrawCircle(0, 0, currentTurret.shot_radius/2, Graphics.GL_Color(1, 0, 0, 0.25))
						end
						Graphics.CSurface.GL_RenderPrimitive(targetingImage.temp)
						Graphics.CSurface.GL_PopMatrix()
					end
				end
				for drone in vter(spaceManager.drones) do
					if drone._targetable:GetSelfId() == system.table.currentTargetTemp._targetable:GetSelfId() and drone._targetable:GetSpaceId() == ship.iShipId then
						local targetPos = system.table.currentTargetTemp._targetable:GetRandomTargettingPoint(true)
						Graphics.CSurface.GL_PushMatrix()
						Graphics.CSurface.GL_Translate(targetPos.x, targetPos.y, 0)
						if currentTurret.shot_radius then
							Graphics.CSurface.GL_DrawCircle(0, 0, currentTurret.shot_radius/2, Graphics.GL_Color(1, 0, 0, 0.25))
						end
						Graphics.CSurface.GL_RenderPrimitive(targetingImage.temp)
						Graphics.CSurface.GL_PopMatrix()
					end
				end
			end
		end
	end
end)

local function system_ready(shipSystem)
	return not shipSystem:GetLocked() and shipSystem:Functioning() and shipSystem.iHackEffect <= 1
end

local turretBox
local turretBoxInner
local turretBoxInnerBack
local turretBoxInnerHover
local turretBoxOffense
local turretBoxDefense
local turretBoxToggleHover
local turretBoxChain
do
	local c = Graphics.GL_Color(1, 1, 1, 1)
	turretBox = Hyperspace.Resources:CreateImagePrimitiveString("systemUI/box_og_turret.png", UIOffset_x, UIOffset_y, 0, c, 1, false)
	turretBoxInner = Hyperspace.Resources:CreateImagePrimitiveString("systemUI/box_inner_og_turret.png", UIOffset_x, UIOffset_y, 0, c, 1, false)
	turretBoxInnerHover = Hyperspace.Resources:CreateImagePrimitiveString("systemUI/box_inner_og_turret_hover.png", UIOffset_x, UIOffset_y, 0, c, 1, false)
	turretBoxInnerBack = Hyperspace.Resources:CreateImagePrimitiveString("systemUI/box_inner_og_turret_back.png", UIOffset_x, UIOffset_y, 0, c, 1, false)
	turretBoxOffense = Hyperspace.Resources:CreateImagePrimitiveString("systemUI/button_og_turret_toggle_o_on.png", UIOffset_x, UIOffset_y, 0, c, 1, false)
	turretBoxDefense = Hyperspace.Resources:CreateImagePrimitiveString("systemUI/button_og_turret_toggle_d_on.png", UIOffset_x, UIOffset_y, 0, c, 1, false)
	turretBoxToggleHover = Hyperspace.Resources:CreateImagePrimitiveString("systemUI/button_og_turret_toggle_hover.png", UIOffset_x, UIOffset_y, 0, c, 1, false)
	turretBoxChain = Hyperspace.Resources:CreateImagePrimitiveString("systemUI/box_inner_og_turret_chain.png", UIOffset_x, UIOffset_y, 0, c, 1, false)
end

local tutorialEvents = {}
tutorialEvents["OG_TURRET_ARROWS_1"] = 1
tutorialEvents["OG_TURRET_ARROWS_2"] = 2
tutorialEvents["OG_TURRET_ARROWS_3"] = 3
tutorialEvents["OG_TURRET_ARROWS_4"] = 4
tutorialEvents["OG_TURRET_ARROWS_5"] = 5
tutorialEvents["OG_TURRET_ARROWS_6"] = 6
tutorialEvents["OG_TURRET_ARROWS_7"] = 7
local tutorialType = 0

script.on_internal_event(Defines.InternalEvents.POST_CREATE_CHOICEBOX, function(choiceBox, event)
	if tutorialEvents[event.eventName] then
		tutorialType = tutorialEvents[event.eventName]
	else
		tutorialType = 0
	end
end)

local toggleArrow = Hyperspace.TutorialArrow(Hyperspace.Pointf(158, 110), 180)
toggleArrow.arrow = Hyperspace.Resources:GetImageId("tutorial_arrow.png")

script.on_render_event(Defines.RenderEvents.CHOICE_BOX, function() end, function()
	local commandGui = Hyperspace.App.gui
	local eventManager = Hyperspace.Event
	if commandGui.event_pause and tutorialType == 3 then
		toggleArrow:OnRender()
	end
end)

local sysArrow = Hyperspace.TutorialArrow(Hyperspace.Pointf(-50, -80), 90)
sysArrow.arrow = Hyperspace.Resources:GetImageId("tutorial_arrow.png")
local boxArrow = Hyperspace.TutorialArrow(Hyperspace.Pointf(4, -135), 90)
boxArrow.arrow = Hyperspace.Resources:GetImageId("tutorial_arrow.png")
local toggleModeArrow = Hyperspace.TutorialArrow(Hyperspace.Pointf(32, 70), 270)
toggleModeArrow.arrow = Hyperspace.Resources:GetImageId("tutorial_arrow.png")
local autoFireArrow = Hyperspace.TutorialArrow(Hyperspace.Pointf(33, -80), 90)
autoFireArrow.arrow = Hyperspace.Resources:GetImageId("tutorial_arrow.png")
local tut_colour = Graphics.GL_Color(1, 1, 0, 1)
local back_tut = Hyperspace.Resources:CreateImagePrimitiveString("systemUI/button_og_turret_toggle_back.png", UIOffset_x, UIOffset_y, 0, tut_colour, 1, false)
local offensive_tut = Hyperspace.Resources:CreateImagePrimitiveString("systemUI/button_og_turret_toggle_o_on.png", UIOffset_x, UIOffset_y, 0, tut_colour, 1, false)
local defensive_tut = Hyperspace.Resources:CreateImagePrimitiveString("systemUI/button_og_turret_toggle_d_on.png", UIOffset_x, UIOffset_y, 0, tut_colour, 1, false)


local function system_render(systemBox, ignoreStatus)
	local systemId = Hyperspace.ShipSystem.SystemIdToName(systemBox.pSystem.iSystemType)
	local shipId = (systemBox.bPlayerUI and 0) or 1
	--print(tostring(systemBox.bPlayerUI).." "..shipId)
	if is_system(systemBox) and Hyperspace.playerVariables[shipId..systemId..systemBlueprintVarName] >= 0 then
		local shipManager = Hyperspace.ships.player
		local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(systemId))

		local targetButton = systemBox.table.targetButton
		targetButton.bActive = system_ready(system) and not system.table.currentlyTargetting
		local offenseButton = systemBox.table.offenseButton
		offenseButton.bActive = system_ready(system) and Hyperspace.playerVariables[shipId..systemId..systemStateVarName] ~= 0
		local defenceButton = systemBox.table.defenceButton
		defenceButton.bActive = system_ready(system) and Hyperspace.playerVariables[shipId..systemId..systemStateVarName] ~= 1

		local currentTurret = turrets[ turretBlueprintsList[ Hyperspace.playerVariables[shipId..systemId..systemBlueprintVarName] ] ]
		local maxCharges = currentTurret.charges
		--print(turretBlueprintsList[ Hyperspace.playerVariables[shipId..systemId..systemBlueprintVarName] ].." "..tostring(shipId..systemId..systemBlueprintVarName))
		local charges = Hyperspace.playerVariables[shipId..systemId..systemChargesVarName]
		
		local hasMannedBonus = (system.iActiveManned > 0 and 0.05) or 0
		local chargeTime = currentTurret.charge_time[system:GetEffectivePower()]
		local chargeTimeReduction = 0
		local chainAmount = Hyperspace.playerVariables[shipId..systemId..systemChainVarName]
		if currentTurret.chain and currentTurret.chain.type == chain_types.cooldown then
			for i = 1, chainAmount do
				chargeTimeReduction = chargeTimeReduction + chargeTime * currentTurret.chain.amount
			end
		end
		chargeTime = chargeTime - chargeTimeReduction
		chargeTime = chargeTime/(1 + hasMannedBonus + system.iActiveManned * 0.05)

		local chargeTimeDisplay = math.ceil(chargeTime)
		local time = math.floor(0.5 + system.table.chargeTime * chargeTimeDisplay * 2)

		--[[local lastTint = Graphics.CSurface.GetColorTint()
		if lastTint then
			print("lastTint r:"..lastTint.r.." g:"..lastTint.g.." b:"..lastTint.b.." a:"..lastTint.a)
			Graphics.CSurface.GL_SetColorTint(lastTint)
		end
		local lastColor = Graphics.CSurface.GL_GetColor()
		if lastColor then
			print("lastColor r:"..lastColor.r.." g:"..lastColor.g.." b:"..lastColor.b.." a:"..lastColor.a)
			Graphics.CSurface.GL_SetColor(lastColor)
		end]]
		--Graphics.CSurface.GL_RemoveColorTint()

		Graphics.CSurface.GL_RenderPrimitive(turretBox)
		Graphics.CSurface.GL_SetColor(Graphics.GL_Color(40/255, 78/255, 82/255, 1))
		Graphics.freetype.easy_print(62, UIOffset_x + 19, UIOffset_y + 61, math.floor(system.table.index))
		Graphics.CSurface.GL_SetColor(Graphics.GL_Color(1, 1, 1, 1))
		Graphics.CSurface.GL_RenderPrimitive(turretBoxInnerBack)

		local c_off = Graphics.GL_Color(150/255, 150/255, 150/255, 1)
		local c_on = Graphics.GL_Color(243/255, 255/255, 230/255, 1)
		local c_charged = Graphics.GL_Color(120/255, 255/255, 120/255, 1)
		local c_single = Graphics.GL_Color(255/255, 255/255, 50/255, 1)
		local c_auto = Graphics.GL_Color(255/255, 120/255, 120/255, 1)
		local cApp = Hyperspace.App
		local combatControl = cApp.gui.combatControl
		local weapControl = combatControl.weapControl

		local renderColour = c_on
		if not system_ready(system) then
			renderColour = c_off
		elseif system.table.currentlyTargetting and xor(Hyperspace.playerVariables.og_turret_autofire == 0, system.table.autoFireInvert) then
			renderColour = c_auto
		elseif system.table.currentlyTargetting then
			renderColour = c_single
		elseif charges == maxCharges then
			renderColour = c_charged
		end
		if targetButton.bHover and not (systemBox.table.offenseButton.bHover or systemBox.table.defenceButton.bHover) then
			Graphics.CSurface.GL_RenderPrimitiveWithColor(turretBoxInnerHover, renderColour)
		end

		if Hyperspace.playerVariables[shipId..systemId..systemStateVarName] == 1 then
			if systemBox.table.offenseButton.bHover then
				Graphics.CSurface.GL_RenderPrimitiveWithColor(turretBoxToggleHover, renderColour)
			end
			Graphics.CSurface.GL_RenderPrimitiveWithColor(turretBoxDefense, renderColour)
		elseif Hyperspace.playerVariables[shipId..systemId..systemStateVarName] == 0 then
			if systemBox.table.defenceButton.bHover then
				Graphics.CSurface.GL_RenderPrimitiveWithColor(turretBoxToggleHover, renderColour)
			end
			Graphics.CSurface.GL_RenderPrimitiveWithColor(turretBoxOffense, renderColour)
		end
		Graphics.CSurface.GL_RenderPrimitiveWithColor(turretBoxInner, renderColour)

		if currentTurret.chain and chainAmount > 0 then
			Graphics.CSurface.GL_RenderPrimitiveWithColor(turretBoxChain, renderColour)
		elseif currentTurret.chain then
			Graphics.CSurface.GL_RenderPrimitiveWithColor(turretBoxChain, c_off)
		end

		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(UIOffset_x, UIOffset_y, 0)

		if maxCharges < 6 then
			local chargeDiff = 6 - maxCharges
			Graphics.CSurface.GL_DrawRect(
				18, 
				22, 
				6, 
				5 * chargeDiff, 
				renderColour
				)
		end

		local blueprint = Hyperspace.Blueprints:GetWeaponBlueprint(turretBlueprintsList[ Hyperspace.playerVariables[shipId..systemId..systemBlueprintVarName] ])
		local barColour = renderColour
		Graphics.CSurface.GL_SetColor(renderColour)
		if currentTurret.chain and chainAmount > 0 then
			Graphics.freetype.easy_printAutoNewlines(6, 56, 35, 43, "+"..math.floor(chainAmount))
		end
		Graphics.freetype.easy_printAutoNewlines(6, 40, 19, 43, blueprint.desc.shortTitle:GetText())

		if system_ready(system) and not system.table.currentlyTargetting and (system.table.currentTarget or system.table.currentTargetTemp) then
			if xor(Hyperspace.playerVariables.og_turret_autofire == 0, system.table.autoFireInvert) then
				barColour = c_auto
				--Graphics.CSurface.GL_SetColorTint(c_auto)
			else
				barColour = c_single
				--Graphics.CSurface.GL_SetColorTint(c_single)
			end
		end

		Graphics.CSurface.GL_SetColor(Graphics.GL_Color(1, 1, 1, 1))
		if maxCharges == charges then
			Graphics.freetype.easy_printNewlinesCentered(51, 53, -2, 80, tostring(math.floor(0.5 + chargeTime * 10)/10).."/"..tostring(math.floor(0.5 + chargeTime * 10)/10))
		else
			Graphics.freetype.easy_printNewlinesCentered(51, 53, -2, 80, tostring(math.floor(0.5 + system.table.chargeTime * chargeTime * 10)/10).."/"..tostring(math.floor(0.5 + chargeTime * 10)/10))
		end
		
		--Graphics.CSurface.GL_RemoveColorTint()

		local timePercent = math.floor(0.5 + system.table.chargeTime * 33)
		Graphics.CSurface.GL_DrawRect(
			27, 
			19 + (33 - timePercent), 
			4, 
			timePercent, 
			barColour
			)
		if maxCharges == charges then
			Graphics.CSurface.GL_DrawRect(
				27, 
				19, 
				4, 
				33, 
				barColour
				)
		end
		if maxCharges <= 6 then
			for i = 1, charges do
				Graphics.CSurface.GL_DrawRect(
					19, 
					53 - (5 * i), 
					4, 
					4, 
					barColour
					)
			end
		else
			local chargePercent = math.floor(0.5 + (charges/maxCharges) * 29)
			Graphics.CSurface.GL_DrawRect(
				19, 
				23 + (29 - chargePercent), 
				4, 
				chargePercent, 
				barColour
				)
		end

		Graphics.CSurface.GL_PopMatrix()
		Graphics.CSurface.GL_SetColor(Graphics.GL_Color(1, 1, 1, 1))

		if lastTint then 
			--Graphics.CSurface.GL_SetColorTint(lastTint)
		end

		if systemBox.pSystem.table.index == Hyperspace.playerVariables.og_turret_count then
			if Hyperspace.playerVariables.og_turret_autofire == 0 and autoFireOffButton.bActive then
				autoFireOffButton:OnRender()
			elseif Hyperspace.playerVariables.og_turret_autofire == 1 and autoFireOnButton.bActive then
				autoFireOnButton:OnRender()
			end
		end

		if tutorialType == 1 then
			sysArrow:OnRender()
		elseif tutorialType == 2 then
			boxArrow:OnRender()
		elseif tutorialType == 4 then
			toggleModeArrow:OnRender()
			Graphics.CSurface.GL_RenderPrimitiveWithColor(turretBoxToggleHover, Graphics.GL_Color(1,1,1,1))
		elseif tutorialType == 5 then
			toggleModeArrow:OnRender()
			Graphics.CSurface.GL_RenderPrimitive(back_tut)
			Graphics.CSurface.GL_RenderPrimitive(offensive_tut)
		elseif tutorialType == 6 then
			toggleModeArrow:OnRender()
			Graphics.CSurface.GL_RenderPrimitive(back_tut)
			Graphics.CSurface.GL_RenderPrimitive(defensive_tut)
		elseif tutorialType == 7 and systemBox.pSystem.table.index == Hyperspace.playerVariables.og_turret_count then
			autoFireArrow:OnRender()
		end

	elseif is_system(systemBox) then
		Graphics.CSurface.GL_RenderPrimitive(turretBox)
	end
	Graphics.CSurface.GL_SetColor(Graphics.GL_Color(1, 1, 1, 1))
end
script.on_render_event(Defines.RenderEvents.SYSTEM_BOX, 
function(systemBox, ignoreStatus) 
	return Defines.Chain.CONTINUE
end, system_render)


--local currentAimingAngle = 0
--local turretTarget = nil

local function resetTurrets(shipManager)
	for _, sysName in ipairs(systemNameList) do
		if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(sysName)) then
			local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(sysName))
			system.table.currentTarget = nil
			system.table.currentlyTargetted = false
			if shipManager:HasAugmentation("OG_TURRET_PREIGNITE") > 0 then
				local currentTurret = turrets[ turretBlueprintsList[ Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemBlueprintVarName] ] ]
				Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName] = currentTurret.charges
			elseif shipManager:HasAugmentation("OG_TURRET_PREIGNITE_WEAK") > 0 then
				local currentTurret = turrets[ turretBlueprintsList[ Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemBlueprintVarName] ] ]
				if shipManager.iShipId == 0 then
					Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName] = math.ceil(currentTurret.charges/2)
				else
					Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName] = math.floor(currentTurret.charges/2)
				end
			else
				Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName] = 0
			end
			Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChainVarName] = 0
			Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemTimeVarName] = 0
			system.table.chargeTime = 0
			system.table.firingTime = 0.1
			--system.table.currentShot = 0
			system.table.ammo_consumed = 0
			system.table.currentlyTargetting = false
		end
	end
end

script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, resetTurrets)

script.on_internal_event(Defines.InternalEvents.JUMP_LEAVE, function(shipManager)
	if shipManager.iShipId == 1 then
		for _, sysName in ipairs(systemNameList) do
			if Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemBlueprintVarName] > 0 then
				Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemTimeVarName] = -1
			end
		end
	end
end)

script.on_game_event("STORAGE_CHECK_OG_TURRET", false, function()
	local shipManager = Hyperspace.ships.player
	resetTurrets(shipManager)
end)

local needSetValues = false
script.on_init(function(newGame)
	if newGame then
		local shipManager = Hyperspace.ships.player
		for _, sysName in ipairs(systemNameList) do
			local id, i = findStartingTurret(shipManager, sysName)
			Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemBlueprintVarName] = i
		end
	else
		needSetValues = true
	end
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if shipManager.iShipId == 0 and needSetValues and Hyperspace.playerVariables["0"..systemName..systemTimeVarName] ~= 0 then
		needSetValues = false
		for _, sysName in ipairs(systemNameList) do
			if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(sysName)) then
				local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(sysName))
				system.table.chargeTime = Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemTimeVarName] / 10000000
			end
		end
	end
end)

script.on_internal_event(Defines.InternalEvents.GENERATOR_CREATE_SHIP_POST, function(name, sector, event, bp, shipManager)
	--print(shipManager.myBlueprint.blueprintName)
	for _, sysName in ipairs(systemNameList) do
		if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(sysName)) then
			local id, i = findStartingTurret(shipManager, sysName)
			--print(sysName.." "..tostring(id).." "..tostring(i))
			Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemBlueprintVarName] = i
			local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(sysName))
			system.table.currentAimingAngle = -90
		end
	end
	resetTurrets(shipManager)
	return Defines.Chain.CONTINUE
end)

local function fireTurret(system, currentTurret, shipManager, otherManager, sysName, blueprint, pos, offensive, targetPosition, manningCrew)
	local spaceManager = Hyperspace.App.world.space
	local currentShotNumber =(Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName] - 1) % #currentTurret.fire_points + 1
	local currentShot = currentTurret.fire_points[currentShotNumber]
	--if not currentShot then 
		--system.table.currentShot = 1
		--currentShot = currentTurret.fire_points[system.table.currentShot]
	--end
	local firingPosition = targetPosition
	if offensive and shipManager.iShipId == 0 then
		firingPosition = Hyperspace.Pointf(10000, pos.y)
	elseif offensive and shipManager.iShipId == 1 then
		firingPosition = Hyperspace.Pointf(pos.x, -10000)
	elseif currentTurret.shot_radius then
		firingPosition = get_random_point_in_radius(firingPosition, currentTurret.shot_radius/2)
	end
	local projectile = nil
	local spawnPos = offset_point_in_direction(pos, system.table.currentAimingAngle, currentShot.x, currentShot.y)
	if currentTurret.blueprint_type == 1 then
		projectile = spaceManager:CreateLaserBlast(
			blueprint,
			spawnPos,
			shipManager.iShipId,
			shipManager.iShipId,
			((currentTurret.homing and (not offensive) and offset_point_in_direction(spawnPos, system.table.currentAimingAngle, 0, -50)) or firingPosition),
			shipManager.iShipId,
			math.rad(system.table.currentAimingAngle)
			)
		projectile:ComputeHeading()
	elseif currentTurret.blueprint_type == 2 then
		projectile = spaceManager:CreateMissile(
			blueprint,
			spawnPos,
			shipManager.iShipId,
			shipManager.iShipId,
			((currentTurret.homing and (not offensive) and offset_point_in_direction(spawnPos, system.table.currentAimingAngle, 0, -50)) or firingPosition),
			shipManager.iShipId,
			math.rad(system.table.currentAimingAngle)
			)
		projectile:ComputeHeading()
	elseif currentTurret.blueprint_type == 3 then
		projectile = spaceManager:CreateBeam(
			Hyperspace.Blueprints:GetWeaponBlueprint(currentTurret.blueprint_fake) ,
			spawnPos,
			shipManager.iShipId,
			1-shipManager.iShipId,
			firingPosition,
			Hyperspace.Pointf(firingPosition.x, firingPosition.y + 1),
			shipManager.iShipId,
			1,
			math.rad(system.table.currentAimingAngle)
			)
		projectile:ComputeHeading()
		if offensive then
			projectile.speed_magnitude = projectile.speed_magnitude * 0.25
			local projectile2 = spaceManager:CreateBeam(
				blueprint,
				firingPosition,
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
		elseif system.table.currentTarget.death_animation then
			system.table.currentTarget.death_animation:Start(true)
			if mods.og.defended_ach and shipManager.iShipId == 0 then
				mods.og.defended_ach = mods.og.defended_ach + 1
			end
		elseif system.table.currentTarget.BlowUp then
			system.table.currentTarget:BlowUp(false)
			if mods.og.defended_ach and shipManager.iShipId == 0 then
				mods.og.defended_ach = mods.og.defended_ach + 1
			end
		end
	end
	if currentTurret.ammo_consumption then
		system.table.ammo_consumed = system.table.ammo_consumed + currentTurret.ammo_consumption
		--print("AMMO:"..system.table.ammo_consumed)
		if system.table.ammo_consumed >= 1 then 
			--print("REDUCE BY "..math.floor(system.table.ammo_consumed))
			shipManager:ModifyMissileCount(-1 * math.floor(system.table.ammo_consumed))
			system.table.ammo_consumed = system.table.ammo_consumed - math.floor(system.table.ammo_consumed)
		end
	end
	if blueprint.effects.launchSounds:size() > 0 then
		local randomSound = math.random(blueprint.effects.launchSounds:size()) - 1
		Hyperspace.Sounds:PlaySoundMix(blueprint.effects.launchSounds[randomSound], -1, false)
	end
	if manningCrew and otherManager and otherManager._targetable.hostile then
		manningCrew:IncreaseSkill(3)
	end
	if offensive and shipManager.ship.bCloaked and shipManager.cloakSystem and not currentTurret.stealth then
		local timer = shipManager.cloakSystem.timer
		timer.currTime = timer.currTime + timer.currGoal/5
		--shipManager.cloakSystem.timer.currTime = math.min(shipManager.cloakSystem.timer.currTime + (shipManager.cloakSystem.timer.maxTime/5), shipManager.cloakSystem.timer.maxTime)
	end
	if offensive and currentTurret.blueprint_type ~= 3 then
		if currentTurret.shot_radius then
			targetPosition = get_random_point_in_radius(targetPosition, currentTurret.shot_radius)
			projectile.bBroadcastTarget = true
		end
		projectile.entryAngle = system.table.entryAngle
		userdata_table(projectile, "mods.og").turret_projectile = {target = targetPosition, destination_space = otherManager.iShipId}
	elseif not offensive and currentTurret.blueprint_type ~= 3 then
		userdata_table(projectile, "mods.og").targeted = system.table.currentTarget
		system.table.currentTarget.table.og_targeted = (system.table.currentTarget.table.og_targeted or 0) + 1
		if currentTurret.homing then
			--print("start homing")
			--checkValidTarget(system.table.currentTarget._targetable, defence_types.ALL, shipManager, true)
			local home_rate = currentTurret.homing
			if shipManager:HasAugmentation("UPG_OG_TURRET_SPEED") > 0 then
				home_rate = home_rate * (1.5 ^ shipManager:GetAugmentationValue("UPG_OG_TURRET_SPEED"))
			end
			userdata_table(projectile, "mods.og").homing = {target = system.table.currentTarget, turn_rate = home_rate}
		end
	end
	if (not offensive) and ((not currentShot.auto_burst) or Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName] == 1) then
		system.table.currentTarget = nil
		system.table.currentlyTargetted = false
	end
	local cApp = Hyperspace.App
	local combatControl = cApp.gui.combatControl
	local weapControl = combatControl.weapControl
	if offensive and xor(Hyperspace.playerVariables.og_turret_autofire == 0, system.table.autoFireInvert) and ((not currentShot.auto_burst) or Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName] == 1) then
		system.table.currentTarget = nil
		system.table.currentlyTargetted = false
	end
	if shipManager:HasAugmentation("UPG_OG_TURRET_SPEED") > 0 then
		projectile.speed_magnitude = projectile.speed_magnitude * (1.5 ^ shipManager:GetAugmentationValue("UPG_OG_TURRET_SPEED"))
	end
	currentTurret.image:Start(true)
	if currentTurret.image.info.numFrames > 1 then
		if currentTurret.multi_anim then
			--print("set frame:"..tostring(1 + currentTurret.multi_anim.frames * (Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName] - 1)))
			currentTurret.image:SetCurrentFrame(1 + currentTurret.multi_anim.frames * (Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName] - 1))
		else
			currentTurret.image:SetCurrentFrame(1)
		end
	end
	
	system.table.firingTime = currentShot.fire_delay
	Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName] = Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName] - 1
	--system.table.currentShot = system.table.currentShot % #currentTurret.fire_points + 1
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
		local notTargeted = (not projectile.table.og_targeted) or (projectile.table.og_targeted < 2 and not currentTurret.homing) or projectile.table.og_targeted < 1
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

-- handle ship loop
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if Hyperspace.App.menu.shipBuilder.bOpen or (shipManager.bJumping and shipManager.iShipId == 1) or shipManager.ship.hullIntegrity.first <= 0 then return end
	--log("START SHIP_LOOP TURRETS"..shipManager.iShipId)
	local shipGraph = Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId)
	local shipCorner = {x = shipManager.ship.shipImage.x + shipGraph.shipBox.x, y = shipManager.ship.shipImage.y + shipGraph.shipBox.y}
	for _, sysName in ipairs(systemNameList) do
		if sysName == "og_turret_adaptive" and shipManager:HasAugmentation("UPG_OG_TURRET_ADAPTIVE_LARGE") > 0 then
			microTurrets["og_turret_adaptive"] = false
		elseif sysName == "og_turret_adaptive" then
			microTurrets["og_turret_adaptive"] = true
		end
		if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(sysName)) and Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemBlueprintVarName] >= 0 then
			local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(sysName))
			
			if not system.table.firingTime then 
				--log("GOTO 1 SHIP_LOOP TURRETS"..shipManager.iShipId..sysName)
				goto END_SYSTEM_LOOP
			end
			local turretLoc = turret_location[shipManager.ship.shipName] and turret_location[shipManager.ship.shipName][sysName] or {x = 0, y = 0, direction = turret_directions.RIGHT}
			local turretRestAngle = 90 * (turretLoc.direction or 0)
			local pos = {x = shipCorner.x + turretLoc.x, y = shipCorner.y + turretLoc.y}

			local currentTurret = turrets[ turretBlueprintsList[ Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemBlueprintVarName] ] ]
			local currentMaxRotationSpeed = currentTurret.rotation_speed * (1 + shipManager:GetAugmentationValue("UPG_OG_TURRET_ROTATION"))
			if (system.table.currentlyTargetted or system.table.currentlyTargetting) and shipManager:HasAugmentation("UPG_OG_TURRET_MANUAL") > 0 then
				currentMaxRotationSpeed = currentMaxRotationSpeed + shipManager:GetAugmentationValue("UPG_OG_TURRET_MANUAL")
			end
			if currentTurret.hold_time and system.table.firingTime > currentTurret.hold_time then
				currentMaxRotationSpeed = 0
			elseif currentTurret.speed_reduction and system.table.firingTime > 0 then
				currentMaxRotationSpeed = currentMaxRotationSpeed * currentTurret.speed_reduction
			end
			local manningCrew = nil
			if system.bBoostable then
				for crew in vter(shipManager.vCrewList) do
					if crew.bActiveManning and crew.currentSystem == system then
						system.iActiveManned = crew:GetSkillLevel(3)
						manningCrew = crew
					end
				end
			end
			local hasMannedBonus = (system.iActiveManned > 0 and 0.05) or 0
			local chargeTime = currentTurret.charge_time[system:GetEffectivePower()]
			local chargeTimeReduction = 0
			if currentTurret.chain and currentTurret.chain.type == chain_types.cooldown then
				local chainAmount = Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChainVarName]
				for i = 1, chainAmount do
					chargeTimeReduction = chargeTimeReduction + chargeTime * currentTurret.chain.amount
				end
			end
			chargeTime = chargeTime - chargeTimeReduction
			chargeTime = chargeTime/(1 + hasMannedBonus + system.iActiveManned * 0.05)
			
			local otherManager = Hyperspace.ships(1 - shipManager.iShipId)
			system.table.firingTime = system.table.firingTime - time_increment(true)
			if Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName] > currentTurret.charges then
				Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName] = currentTurret.charges
			else
				if system_ready(system) and Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName] < currentTurret.charges and (not currentTurret.ammo_consumption or shipManager:GetMissileCount() > system.table.ammo_consumed + currentTurret.ammo_consumption * Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName]) then
					local otherShipCloaking = otherManager and otherManager.ship.bCloaked
					local cloak_mult = (otherShipCloaking and 0.5) or 1
					system.table.chargeTime = system.table.chargeTime + cloak_mult * time_increment(true)/chargeTime
					if system.table.chargeTime >= 1 then
						local maxWithAmmo = ((not currentTurret.ammo_consumption) and math.huge) or ((shipManager:GetMissileCount() - system.table.ammo_consumed - currentTurret.ammo_consumption * Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName])/currentTurret.ammo_consumption) 
						Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName] = math.min(Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName] + maxWithAmmo , currentTurret.charges, Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName] + currentTurret.charges_per_charge)
						if currentTurret.chain then
							Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChainVarName] = math.min(currentTurret.chain.count, Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChainVarName] + 1)
						end
						system.table.chargeTime = 0
					end
					Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemTimeVarName] = system.table.chargeTime * 10000000 
				elseif currentTurret.ammo_consumption and Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName] > 0 and shipManager:GetMissileCount() < system.table.ammo_consumed + currentTurret.ammo_consumption * Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName] then
					local amountOver = math.ceil((system.table.ammo_consumed + currentTurret.ammo_consumption * Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName] - shipManager:GetMissileCount())/2)
					Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName] = math.max(0, Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName] - amountOver)
				elseif not system_ready(system) then
					system.table.chargeTime = math.max(0, system.table.chargeTime - 6 * time_increment(true)/chargeTime)
					if system.table.chargeTime <= 0 and Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName] > 0 then
						Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName] = math.max(0, Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName] - currentTurret.charges_per_charge)
						if currentTurret.chain then
							Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChainVarName] = math.max(0, Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChainVarName] - 1)
						end
						system.table.chargeTime = 1
					end
					Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemTimeVarName] = system.table.chargeTime * 10000000 
				end
			end

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
				--log("GOTO 2 SHIP_LOOP TURRETS"..shipManager.iShipId..sysName)
				goto END_SYSTEM_LOOP
			elseif system.table.currentlyTargetting then 
				local mousePosPlayer = worldToPlayerLocation(Hyperspace.Mouse.position)
				local target_angle = get_angle_between_points(pos, mousePosPlayer)
				if math.abs(angle_diff(system.table.currentAimingAngle, target_angle)) > 0.01 then
					system.table.currentAimingAngle = move_angle_to(system.table.currentAimingAngle, target_angle, currentMaxRotationSpeed * time_increment(true))
				end
			elseif Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemStateVarName] == 0 and not system.table.currentlyTargetted then
				
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
				local readyFire = system.table.firingTime <= 0 and Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName] > 0 
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
			elseif Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemStateVarName] == 1 or system.table.currentlyTargetted then
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
					local tryRetarget = Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName] <= 0 and not system.table.currentlyTargetted
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
					if math.abs(angle_diff(system.table.currentAimingAngle, target_angle)) < (currentTurret.aim_cone or 0.5) and system.table.firingTime <= 0 and Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName] > 0 then
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
			local lastShot = ((Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName]) % #currentTurret.fire_points) + 1
			--print("lastShot charges:"..tostring((Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName])).." % "..tostring(#currentTurret.fire_points).." + 1 = "..tostring(lastShot))
			currentTurret.image:Update()
			if (currentTurret.image.currentFrame == currentTurret.image.info.numFrames - 1) or (currentTurret.multi_anim and currentTurret.image.currentFrame > currentTurret.multi_anim.frames * lastShot) then
				--print("reset:"..tostring(currentTurret.image.currentFrame).." > "..tostring(currentTurret.multi_anim.frames * lastShot))
				currentTurret.image.tracker:Stop(true)
				currentTurret.image:SetCurrentFrame(0)
			end

			if shipManager.iShipId == 1 and (not system.table.currentTarget) and Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName] >= currentTurret.charges and (currentTurret.enemy_burst or 1) > 0 then
				Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemStateVarName] = 0
				system.table.entryAngle = math.random(360)
			elseif shipManager.iShipId == 1 and Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName] <= currentTurret.charges - (currentTurret.enemy_burst or 1) then
				Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemStateVarName] = 1
			end
			if shipManager.iShipId == 1 and Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemStateVarName] == 0 and not Hyperspace.ships.enemy._targetable.hostile then
				Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemStateVarName] = 1
			end
		end
		::END_SYSTEM_LOOP::
	end
	--log("END SHIP_LOOP TURRETS"..shipManager.iShipId)
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(s)
	if s.iShipId == 1 then return end
	--log("START SHIP_LOOP PROJECTILES")
	local spaceManager = Hyperspace.App.world.space
	for projectile in vter(spaceManager.projectiles) do
		local shipManager = Hyperspace.ships(projectile.currentSpace)
		if not shipManager then 
			--log("GOTO 1 SHIP_LOOP PROJECTILES")
			goto END_PROJECTILE_LOOP 
		end
		local ship = shipManager.ship
		local shipGraph = Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId)
		local shipBound_x = ship.shipImage.x + shipGraph.shipBox.x + ship.shipImage.w
		local shipBound_y = ship.shipImage.y + shipGraph.shipBox.y
		--if userdata_table(projectile, "mods.og").turret_projectile then print("PROJECTILE EXISTS") end
		local playerFired = projectile.currentSpace == 0 and (projectile.position.x > shipBound_x or projectile.position.x > 800)
		local enemyFired = projectile.currentSpace == 1 and projectile.position.y < shipBound_y
		if userdata_table(projectile, "mods.og").turret_projectile and (playerFired or enemyFired) then
			--print("UPDATE PROJECTILE DESTINATION"..tostring(shipBound_x))
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
			userdata_table(projectile, "mods.og").targeted.table.og_targeted = math.max(0, userdata_table(projectile, "mods.og").targeted.table.og_targeted - 1)
			userdata_table(projectile, "mods.og").targeted = nil
		end

		if userdata_table(projectile, "mods.og").homing and checkValidTarget(userdata_table(projectile, "mods.og").homing.target._targetable, defence_types.ALL, shipManager) then
			local target = userdata_table(projectile, "mods.og").homing.target
			local currentAngle = get_angle_between_points(projectile.position, projectile.target)

			local targetPos = target._targetable:GetRandomTargettingPoint(true)
			local targetVelocity = target._targetable:GetSpeed()
			--targetVelocity = Hyperspace.Pointf(targetVelocity.x/(18.333*time_increment(true)), targetVelocity.y/(18.333*time_increment(true)))
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
			--print("Homing Projectile"..projectile.extend.name.." heading:"..tostring(math.deg(projectile.heading)))
		elseif userdata_table(projectile, "mods.og").homing then
			--print("end homing, invalid proj")
			userdata_table(projectile, "mods.og").homing = nil
		end
		::END_PROJECTILE_LOOP::
	end
	--log("END SHIP_LOOP PROJECTILES")
end)

local turret_mount = Hyperspace.Resources:CreateImagePrimitiveString("og_turrets/ship_turret_mount.png", -31, -31, 0, Graphics.GL_Color(1, 1, 1, 1) , 1, false)
local turret_mount_mini = Hyperspace.Resources:CreateImagePrimitiveString("og_turrets/ship_turret_mount_mini.png", -14, -14, 0, Graphics.GL_Color(1, 1, 1, 1) , 1, false)
local turret_mount_back = Hyperspace.Resources:CreateImagePrimitiveString("og_turrets/ship_turret_mount_back.png", -50, -50, 0, Graphics.GL_Color(1, 1, 1, 1) , 1, false)
local turret_mount_mini_back = Hyperspace.Resources:CreateImagePrimitiveString("og_turrets/ship_turret_mount_mini_back.png", -23, -23, 0, Graphics.GL_Color(1, 1, 1, 1) , 1, false)
local turret_mount_back_above = Hyperspace.Resources:CreateImagePrimitiveString("og_turrets/ship_turret_mount_back_above.png", -50, -50, 0, Graphics.GL_Color(1, 1, 1, 1) , 1, false)
local turret_mount_mini_back_above = Hyperspace.Resources:CreateImagePrimitiveString("og_turrets/ship_turret_mount_mini_back_above.png", -23, -23, 0, Graphics.GL_Color(1, 1, 1, 1) , 1, false)

local stencil_mode = {ignore = 0, set = 1, use = 2}

local function renderTurret(shipManager, ship, spaceManager, shipGraph, sysName)
	--print("ship:"..shipManager.iShipId.." jump first:"..shipManager.jump_timer.first.." second:"..shipManager.jump_timer.second.." bJumping"..tostring(shipManager.bJumping))
	if shipManager.bJumping and shipManager.iShipId == 1 then return end
	local currentTurret = nil
	if sysName == "og_turret_adaptive" then
		local turretLoc = turret_location[ship.shipName] and turret_location[ship.shipName][sysName] or {x = 0, y = 0}
		local shipCorner = {x = ship.shipImage.x + shipGraph.shipBox.x, y = ship.shipImage.y + shipGraph.shipBox.y}
		local shipSize = {x = math.floor(ship.shipImage.w/2), y = math.floor(ship.shipImage.h/2)}

		Graphics.CSurface.GL_PushStencilMode()
		Graphics.CSurface.GL_SetStencilMode(stencil_mode.set, 1, 64)
		Graphics.CSurface.GL_DrawRect(
			-1280, 
			-720, 
			1280*3, 
			720*3, 
			Graphics.GL_Color(1, 1, 1, 1)
		)
		Graphics.CSurface.GL_SetStencilMode(stencil_mode.set, 0, 64)
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(shipGraph.shipBox.x + ship.shipImage.x + shipSize.x, shipGraph.shipBox.y + ship.shipImage.y + shipSize.y, 0)
		--Graphics.CSurface.GL_Translate(shipGraph.shipBox.x, shipGraph.shipBox.y, 0)
		Graphics.CSurface.GL_Scale(0.975, 0.975, 1)
		Graphics.CSurface.GL_Translate(-1 * (ship.shipImage.x + shipSize.x), -1 * (ship.shipImage.y + shipSize.y), 0)
		Graphics.CSurface.GL_RenderPrimitiveWithAlpha(ship.shipImagePrimitive, 1)
		Graphics.CSurface.GL_PopMatrix()

		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(shipGraph.shipBox.x, shipGraph.shipBox.y, 0)
		Graphics.CSurface.GL_RenderPrimitiveWithAlpha(ship.floorPrimitive, 1)
		Graphics.CSurface.GL_PopMatrix()

		Graphics.CSurface.GL_SetStencilMode(stencil_mode.use, 1, 64)

		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(shipCorner.x + turretLoc.x, shipCorner.y + turretLoc.y, 0)
		if microTurrets[sysName] then
			Graphics.CSurface.GL_RenderPrimitive(turret_mount_mini_back)
		else
			Graphics.CSurface.GL_RenderPrimitive(turret_mount_back)
		end
		Graphics.CSurface.GL_PopMatrix()

		Graphics.CSurface.GL_SetStencilMode(stencil_mode.use, 0, 64)
		
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(shipCorner.x + turretLoc.x, shipCorner.y + turretLoc.y, 0)
		if microTurrets[sysName] then
			Graphics.CSurface.GL_RenderPrimitive(turret_mount_mini_back_above)
		else
			Graphics.CSurface.GL_RenderPrimitive(turret_mount_back_above)
		end
		Graphics.CSurface.GL_PopMatrix()

		Graphics.CSurface.GL_SetStencilMode(stencil_mode.ignore, 1, 64)
		Graphics.CSurface.GL_PopStencilMode()

		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(shipCorner.x + turretLoc.x, shipCorner.y + turretLoc.y, 0)
		if microTurrets[sysName] then
			Graphics.CSurface.GL_RenderPrimitive(turret_mount_mini)
		else
			Graphics.CSurface.GL_RenderPrimitive(turret_mount)
		end
		Graphics.CSurface.GL_PopMatrix()
	end
	if Hyperspace.App.menu.shipBuilder.bOpen then
		local id, i = findStartingTurret(shipManager, sysName)
		if id then currentTurret = turrets[id] end
		if not currentTurret then return end

		local turretLoc = turret_location[ship.shipName] and turret_location[ship.shipName][sysName] or {x = 0, y = 0}
		local shipCorner = {x = ship.shipImage.x + shipGraph.shipBox.x, y = ship.shipImage.y + shipGraph.shipBox.y}
		local angleSet = 90 * turretLoc.direction
		local colour = Graphics.GL_Color(1,1,1,1)

		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(shipCorner.x + turretLoc.x, shipCorner.y + turretLoc.y, 0)
		Graphics.CSurface.GL_Rotate(angleSet, 0, 0, 1)
		currentTurret.image:OnRender(1, colour, false)
		if currentTurret.charge_image then
			Graphics.CSurface.GL_RenderPrimitiveWithAlpha(currentTurret.charge_image, 1)
		end
		Graphics.CSurface.GL_PopMatrix()
	elseif Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemBlueprintVarName] >= 0 then
		currentTurret = turrets[ turretBlueprintsList[ Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemBlueprintVarName] ] ]
		local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(sysName))
		if not currentTurret then return end

		local turretLoc = turret_location[ship.shipName] and turret_location[ship.shipName][sysName] or {x = 0, y = 0}
		local shipCorner = {x = ship.shipImage.x + shipGraph.shipBox.x, y = ship.shipImage.y + shipGraph.shipBox.y}
		local angleSet = system.table.currentAimingAngle or 0
		local colour = Graphics.GL_Color(1,1,1,1)
		if shipManager.ship.bCloaked then
			colour = Graphics.GL_Color(1,1,1,0.5)
		end

		local charges = Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName]
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(shipCorner.x + turretLoc.x, shipCorner.y + turretLoc.y, 0)
		Graphics.CSurface.GL_Rotate(angleSet, 0, 0, 1)
		currentTurret.image:OnRender(1, colour, false)
		if currentTurret.charge_image then
			Graphics.CSurface.GL_RenderPrimitiveWithAlpha(currentTurret.charge_image, system.table.chargeTime or 1)
		end
		local chains = Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChainVarName]
		if currentTurret.chain and currentTurret.chain.image and chains > 0 then
			currentTurret.chain.image:SetCurrentFrame(chains - 1)
			currentTurret.chain.image:OnRender(1, Graphics.GL_Color(1,1,1,1), false)
		end
		if currentTurret.glow and charges > 0 then
			currentTurret.glow:SetCurrentFrame(charges - 1)
			currentTurret.glow:OnRender(1, Graphics.GL_Color(1,1,1,1), false)
		end
		Graphics.CSurface.GL_PopMatrix()
	end
end


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


local player_jump_timer = 0
local player_arrive_timer = 0
script.on_render_event(Defines.RenderEvents.SHIP_MANAGER, function(shipManager) end, function(shipManager) 
	local cApp = Hyperspace.App
	if shipManager.iShipId == 0 and (not cApp.gui.jumpComplete) and shipManager.bJumping then
		player_jump_timer = player_jump_timer + time_increment(true)
		if player_jump_timer > 1.1 then return end
	elseif shipManager.iShipId == 0 and cApp.gui.jumpComplete and shipManager.bJumping then
		player_arrive_timer = player_arrive_timer + time_increment(true)
		if player_arrive_timer < 0.9 then return end
	elseif shipManager.iShipId == 0 then
		player_jump_timer = 0
		player_arrive_timer = 0
	end
	local ship = shipManager.ship
	local spaceManager = Hyperspace.App.world.space
	local shipGraph = Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId)
	local index_counter = 0
	for _, sysName in ipairs(systemNameList) do
		if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(sysName)) then
			index_counter = index_counter + 1
			local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(sysName))
			system.table.index = index_counter
			if microTurrets[sysName] then
				renderTurret(shipManager, ship, spaceManager, shipGraph, sysName)	
			end	
		end
	end
	if shipManager.iShipId == 0 then
		Hyperspace.playerVariables.og_turret_count = index_counter
	end
	--log("MIDDLE RENDER SHIP_MANAGER TURRETS")
	for _, sysName in ipairs(systemNameList) do
		if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(sysName)) and not microTurrets[sysName] then
			renderTurret(shipManager, ship, spaceManager, shipGraph, sysName)		
		end
	end
	--log("END RENDER SHIP_MANAGER TURRETS"..shipManager.iShipId)
end)

for _, sysName in ipairs(systemNameList) do
	--print("set icon:"..sysName)
	mods.multiverse.systemIcons[Hyperspace.ShipSystem.NameToSystemId(sysName)] = mods.multiverse.register_system_icon(sysName)
end

local key_names = {
	SDLK_UNKNOWN = {index = 0, name = "Unknown"},
	SDLK_0 = {index = 48, name = "0"},
	SDLK_1 = {index = 49, name = "1"},
	SDLK_2 = {index = 50, name = "2"},
	SDLK_3 = {index = 51, name = "3"},
	SDLK_4 = {index = 52, name = "4"},
	SDLK_5 = {index = 53, name = "5"},
	SDLK_6 = {index = 54, name = "6"},
	SDLK_7 = {index = 55, name = "7"},
	SDLK_8 = {index = 56, name = "8"},
	SDLK_9 = {index = 57, name = "9"},
	SDLK_AT = {index = 64, name = "@"},
	SDLK_AMPERSAND = {index = 38, name = "&"},
	SDLK_ASTERISK = {index = 42, name = "*"},
	SDLK_BACKQUOTE = {index = 96, name = "`"},
	SDLK_BACKSLASH = {index = 92, name = "\\"},
	SDLK_BACKSPACE = {index = 8, name = "Backspace"},
	SDLK_BREAK = {index = 318, name = "Break"},
	SDLK_CAPSLOCK = {index = 301, name = "Caps Lock"},
	SDLK_CARET = {index = 94, name = "^"},
	SDLK_CLEAR = {index = 12, name = "Clear"},
	SDLK_COLON = {index = 58, name = ":"},
	SDLK_COMMA = {index = 44, name = ","},
	SDLK_COMPOSE = {index = 314, name = "Compose"},
	SDLK_DELETE = {index = 127, name = "Delete"},
	SDLK_DOLLAR = {index = 36, name = "$"},
	SDLK_DOWN = {index = 274, name = "Down"},
	SDLK_END = {index = 279, name = "End"},
	SDLK_EQUALS = {index = 61, name = "="},
	SDLK_ESCAPE = {index = 27, name = "Escape"},
	SDLK_EURO = {index = 321, name = "Euro"},
	SDLK_EXCLAIM = {index = 33, name = "!"},
	SDLK_F1 = {index = 282, name = "F1"},
	SDLK_F10 = {index = 291, name = "F10"},
	SDLK_F11 = {index = 292, name = "F11"},
	SDLK_F12 = {index = 293, name = "F12"},
	SDLK_F13 = {index = 294, name = "F13"},
	SDLK_F14 = {index = 295, name = "F14"},
	SDLK_F15 = {index = 296, name = "F15"},
	SDLK_F2 = {index = 283, name = "F2"},
	SDLK_F3 = {index = 284, name = "F3"},
	SDLK_F4 = {index = 285, name = "F4"},
	SDLK_F5 = {index = 286, name = "F5"},
	SDLK_F6 = {index = 287, name = "F6"},
	SDLK_F7 = {index = 288, name = "F7"},
	SDLK_F8 = {index = 289, name = "F8"},
	SDLK_F9 = {index = 290, name = "F9"},
	SDLK_GREATER = {index = 62, name = ">"},
	SDLK_HASH = {index = 36, name = "#"}, -- Note: Value 0x24 is shared with SDLK_DOLLAR
	SDLK_HELP = {index = 315, name = "Help"},
	SDLK_HOME = {index = 278, name = "Home"},
	SDLK_INSERT = {index = 277, name = "Insert"},
	SDLK_KP0 = {index = 256, name = "Numpad 0"},
	SDLK_KP1 = {index = 257, name = "Numpad 1"},
	SDLK_KP2 = {index = 258, name = "Numpad 2"},
	SDLK_KP3 = {index = 259, name = "Numpad 3"},
	SDLK_KP4 = {index = 260, name = "Numpad 4"},
	SDLK_KP5 = {index = 261, name = "Numpad 5"},
	SDLK_KP6 = {index = 262, name = "Numpad 6"},
	SDLK_KP7 = {index = 263, name = "Numpad 7"},
	SDLK_KP8 = {index = 264, name = "Numpad 8"},
	SDLK_KP9 = {index = 265, name = "Numpad 9"},
	SDLK_KP_PERIOD = {index = 266, name = "Numpad ."},
	SDLK_KP_DIVIDE = {index = 267, name = "Numpad /"},
	SDLK_KP_MULTIPLY = {index = 268, name = "Numpad *"},
	SDLK_KP_MINUS = {index = 269, name = "Numpad -"},
	SDLK_KP_PLUS = {index = 270, name = "Numpad +"},
	SDLK_KP_ENTER = {index = 271, name = "Numpad Enter"},
	SDLK_KP_EQUALS = {index = 272, name = "Numpad ="},
	SDLK_LALT = {index = 308, name = "Left Alt"},
	SDLK_LCTRL = {index = 306, name = "Left Ctrl"},
	SDLK_LEFT = {index = 276, name = "Left"},
	SDLK_LEFTBRACKET = {index = 91, name = "["},
	SDLK_LEFTPAREN = {index = 40, name = "("},
	SDLK_LESS = {index = 60, name = "<"},
	SDLK_LMETA = {index = 310, name = "Left Meta"},
	SDLK_LSHIFT = {index = 304, name = "Left Shift"},
	SDLK_LSUPER = {index = 311, name = "Left Super"},
	SDLK_MENU = {index = 319, name = "Menu"},
	SDLK_MINUS = {index = 45, name = "-"},
	SDLK_MODE = {index = 313, name = "Mode"},
	SDLK_NUMLOCK = {index = 300, name = "Num Lock"},
	SDLK_PAGEDOWN = {index = 281, name = "Page Down"},
	SDLK_PAGEUP = {index = 280, name = "Page Up"},
	SDLK_PAUSE = {index = 19, name = "Pause"},
	SDLK_PERIOD = {index = 46, name = "."},
	SDLK_PLUS = {index = 43, name = "+"},
	SDLK_POWER = {index = 320, name = "Power"},
	SDLK_PRINTSCREEN = {index = 316, name = "Print Screen"},
	SDLK_QUESTION = {index = 63, name = "?"},
	SDLK_QUOTEDBL = {index = 34, name = "\""},
	SDLK_QUOTE = {index = 39, name = "'"},
	SDLK_RALT = {index = 307, name = "Right Alt"},
	SDLK_RCTRL = {index = 305, name = "Right Ctrl"},
	SDLK_RETURN = {index = 13, name = "Return"},
	SDLK_RIGHT = {index = 275, name = "Right"},
	SDLK_RIGHTBRACKET = {index = 93, name = "]"},
	SDLK_RIGHTPAREN = {index = 41, name = ")"},
	SDLK_RMETA = {index = 309, name = "Right Meta"},
	SDLK_RSHIFT = {index = 303, name = "Right Shift"},
	SDLK_RSUPER = {index = 312, name = "Right Super"},
	SDLK_SCROLLOCK = {index = 302, name = "Scroll Lock"},
	SDLK_SEMICOLON = {index = 59, name = ";"},
	SDLK_SLASH = {index = 47, name = "/"},
	SDLK_SPACE = {index = 32, name = "Space"},
	SDLK_SYSREQ = {index = 317, name = "Sys Req"},
	SDLK_TAB = {index = 9, name = "Tab"},
	SDLK_UNDERSCORE = {index = 95, name = "_"},
	SDLK_UNDO = {index = 322, name = "Undo"},
	SDLK_UP = {index = 273, name = "Up"},
	SDLK_a = {index = 97, name = "a"},
	SDLK_b = {index = 98, name = "b"},
	SDLK_c = {index = 99, name = "c"},
	SDLK_d = {index = 100, name = "d"},
	SDLK_e = {index = 101, name = "e"},
	SDLK_f = {index = 102, name = "f"},
	SDLK_g = {index = 103, name = "g"},
	SDLK_h = {index = 104, name = "h"},
	SDLK_i = {index = 105, name = "i"},
	SDLK_j = {index = 106, name = "j"},
	SDLK_k = {index = 107, name = "k"},
	SDLK_l = {index = 108, name = "l"},
	SDLK_m = {index = 109, name = "m"},
	SDLK_n = {index = 110, name = "n"},
	SDLK_o = {index = 111, name = "o"},
	SDLK_p = {index = 112, name = "p"},
	SDLK_q = {index = 113, name = "q"},
	SDLK_r = {index = 114, name = "r"},
	SDLK_s = {index = 115, name = "s"},
	SDLK_t = {index = 116, name = "t"},
	SDLK_u = {index = 117, name = "u"},
	SDLK_v = {index = 118, name = "v"},
	SDLK_w = {index = 119, name = "w"},
	SDLK_x = {index = 120, name = "x"},
	SDLK_y = {index = 121, name = "y"},
	SDLK_z = {index = 122, name = "z"},
	SDLK_LAST = {index = 323, name = "Last"},
}

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
		ctrl_held = false
	end
	return Defines.Chain.CONTINUE
end)

script.on_internal_event(Defines.InternalEvents.ON_KEY_DOWN, function(key)
	if key == auto_key then
		ctrl_held = true
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
					if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(sysName)) then
						local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(sysName))
						if system.table.index == i then
							select_turret(system, ctrl_held) -- enables targetting for a turret
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


script.on_internal_event(Defines.InternalEvents.HAS_EQUIPMENT, function(shipManager, equipment, value)
	if turrets[equipment] then
		for _, sysName in ipairs(systemNameList) do
			if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(sysName)) then
				local currentTurretName = turretBlueprintsList[ Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemBlueprintVarName] ]
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
							local currentTurretName = turretBlueprintsList[ Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemBlueprintVarName] ]
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
					local currentTurretName = turretBlueprintsList[ Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemBlueprintVarName] ]
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
	--print("removeItem:"..removeItem)
	--print(string.sub(removeItem, 1, 14))
	if string.sub(removeItem, 1, 17) == "OG_TURRET_REMOVE_" then
		removeItem = string.sub(removeItem, 18)
		local shipManager = Hyperspace.ships.player
		if removeItem then
			for _, sysName in ipairs(systemNameList) do
				if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(sysName)) then
					local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(sysName))
					local currentTurretName = turretBlueprintsList[ Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemBlueprintVarName] ]
					if currentTurretName == removeItem then
						event.stuff.removeItem = "	 "
						Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemBlueprintVarName] = -1
					end
				end
			end
		end
	end
end)

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA, function(shipManager, projectile, location, damage, forceHit, shipFriendlyFire)
	local room = get_room_at_location(shipManager, location, true)
	local system = shipManager:GetSystemInRoom(room)
	if system and systemNameCheck[Hyperspace.ShipSystem.SystemIdToName(system.iSystemType)] then
		local sysName = Hyperspace.ShipSystem.SystemIdToName(system.iSystemType)
		local currentTurret = turrets[ turretBlueprintsList[ Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemBlueprintVarName] ] ]
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
		local currentTurret = turrets[ turretBlueprintsList[ Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemBlueprintVarName] ] ]
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
			local currentTurret = turrets[ turretBlueprintsList[ Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemBlueprintVarName] ] ]
			if currentTurret and currentTurret.dawn then
				--print("render render_vunerable system")
				render_vunerable(room)
			end
		end
	end
end)