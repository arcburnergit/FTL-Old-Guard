mods.og = {}
local vter = mods.multiverse.vter
local time_increment = mods.multiverse.time_increment

local function offset_point_in_direction(position, angle, offset_x, offset_y)
	local alpha = math.rad(angle)
	local newX = position.x - (offset_y * math.cos(alpha)) - (offset_x * math.cos(alpha+math.rad(90)))
	local newY = position.y - (offset_y * math.sin(alpha)) - (offset_x * math.sin(alpha+math.rad(90)))
	return Hyperspace.Pointf(newX, newY)
end

local function normalize_angle(angle)
	angle = angle % 360
	if angle < 0 then
		angle = angle + 360
	end
	return angle
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
	return intercept_angle, intercept_point, t
end

mods.og.turretBlueprintsList = {}
local turretBlueprintsList = mods.og.turretBlueprintsList 
turretBlueprintsList[0] = "OG_EMPTY_TURRET"
table.insert(turretBlueprintsList, "OG_TURRET_LASER_1")
table.insert(turretBlueprintsList, "OG_TURRET_LASER_2")
table.insert(turretBlueprintsList, "OG_TURRET_ION_1")
table.insert(turretBlueprintsList, "OG_TURRET_ION_2")

--1 = MISSILES, 2 = FLAK, 3 = DRONES, 4 = PROJECTILES, 5 = HACKING 
local defence_types = {
	DRONES = {[3] = true, [5] = true},
	MISSILES = {[1] = true, [2] = true, [5] = true},
	DRONES_MISSILES = {[1] = true, [2] = true, [3] = true, [5] = true},
	PROJECTILES = {[4] = true},
	PROJECTILES_MISSILES = {[1] = true, [2] = true, [4] = true, [5] = true},
	ALL = {[1] = true, [2] = true, [3] = true, [4] = true, [5] = true},
}

mods.og.turrets = {}
local turrets = mods.og.turrets
turrets["OG_EMPTY_TURRET"] = {
	image_offset = {x = -55, y = -55},
	image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_laser_error.png", -55, -55, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	glow_offset = {x = -11, y = -6},
	glow_name = "og_turrets/turret_laser_1_glow",
	glow_images = {},
	fire_points = {{x = -12, y = -42, fire_delay = 0.1}, {x = 12, y = -42, fire_delay = 0.5}},
	defence_type = defence_types.ALL,
	blueprint_type = 1,
	blueprint = "LASER_BURST_1",
	charges = 1,
	charges_per_charge = 1,
	rotation_speed = 360,
	charge_time = {[0] = 9, 9, 8, 7, 6, 5, 4, 3, 2, 1},
}
turrets["OG_TURRET_LASER_1"] = {
	image_offset = {x = -55, y = -55},
	image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_laser_1.png", -55, -55, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	glow_offset = {x = -11, y = -6},
	glow_name = "og_turrets/turret_laser_1_glow",
	glow_images = {},
	fire_points = {{x = -12, y = -42, fire_delay = 0.5}, {x = 12, y = -42, fire_delay = 0.5}},
	defence_type = defence_types.ALL,
	blueprint_type = 1,
	blueprint = "LASER_BURST_1",
	charges = 6,
	charges_per_charge = 2,
	rotation_speed = 180,
	charge_time = {[0] = 14, 14, 12, 9, 7, 6, 5, 4, 3},
}
turrets["OG_TURRET_LASER_2"] = {
	image_offset = {x = -70, y = -70},
	image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_laser_2.png", -70, -70, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	glow_offset = {x = -9, y = -4},
	glow_name = "og_turrets/turret_laser_2_glow",
	glow_images = {},
	fire_points = {{x = 0, y = -42, fire_delay = 1}},
	defence_type = defence_types.DRONES_MISSILES,
	blueprint_type = 1,
	blueprint = "LASER_HEAVY_1",
	charges = 3,
	charges_per_charge = 1,
	rotation_speed = 180,
	charge_time = {[0] = 11, 11, 9, 7, 6, 5, 4.5, 4, 3.5},
}
turrets["OG_TURRET_ION_1"] = {
	image_offset = {x = -55, y = -55},
	image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_laser_1.png", -55, -55, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	glow_offset = {x = -11, y = -6},
	glow_name = "og_turrets/turret_laser_1_glow",
	glow_images = {},
	fire_points = {{x = 0, y = -42, fire_delay = 0.1}},
	defence_type = defence_types.DRONES,
	blueprint_type = 1,
	blueprint = "ION_1",
	charges = 1,
	charges_per_charge = 1,
	rotation_speed = 270,
	charge_time = {[0] = 8, 8, 6, 4.5, 3.5, 3, 2.5, 2.25, 2},
}
turrets["OG_TURRET_ION_2"] = {
	image_offset = {x = -55, y = -55},
	image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_laser_1.png", -55, -55, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	glow_offset = {x = -11, y = -6},
	glow_name = "og_turrets/turret_laser_1_glow",
	glow_images = {},
	fire_points = {{x = 0, y = -42, fire_delay = 0.5}},
	defence_type = defence_types.DRONES,
	blueprint_type = 1,
	blueprint = "ION_STUN",
	charges = 5,
	charges_per_charge = 5,
	rotation_speed = 270,
	charge_time = {[0] = 22, 22, 20, 18, 16, 14, 12, 10, 8},
}

for turretId, currentTurret in pairs(turrets) do
	for i = 1, currentTurret.charges do
		local new_glow_name = currentTurret.glow_name.."_"..tostring(math.floor(i))
		local prim = Hyperspace.Resources:CreateImagePrimitiveString(new_glow_name, currentTurret.glow_offset.x, currentTurret.glow_offset.y, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
		table.insert(currentTurret.glow_images, prim)
	end
end

local function findStartingTurret(shipManager)
	for i, id in ipairs(turretBlueprintsList) do
		if shipManager:HasAugmentation(id.."_AUG") > 0 then
			return id, i
		end
	end
	return "", -1
end

local systemId = "og_turret"
local systemBlueprintVarName = "og_turret_blueprint"
local systemStateVarName = "og_turret_state"
local systemChargesVarName = "og_turret_charges"
local systemTimeVarName = "og_turret_time"
local systemTime = 0
local systemFiringTime = 0
local systemCurrentShot = 1
local currentlyTargetting = false

local function is_system(systemBox)
	local systemName = Hyperspace.ShipSystem.SystemIdToName(systemBox.pSystem.iSystemType)
	return systemName == systemId and systemBox.bPlayerUI
end
local function is_system_enemy(systemBox)
	local systemName = Hyperspace.ShipSystem.SystemIdToName(systemBox.pSystem.iSystemType)
	return systemName == systemId and not systemBox.bPlayerUI
end

local function get_level_description_system(currentId, level, tooltip)
	if currentId == Hyperspace.ShipSystem.NameToSystemId(systemId) then
		if level == 1 then
			return string.format("More System Power")
		else
			return string.format("More System Power")
		end
	end
end
script.on_internal_event(Defines.InternalEvents.GET_LEVEL_DESCRIPTION, get_level_description_system)

local UIOffset_x = 36
local UIOffset_y = -65

local function system_construct_system_box(systemBox)
	if is_system(systemBox) then
		systemBox.extend.xOffset = 54

		local targetButton = Hyperspace.Button()
		targetButton:OnInit("systemUI/button_og_turret_target", Hyperspace.Point(UIOffset_x + 9, UIOffset_y + 9))
		targetButton.hitbox.x = 0
		targetButton.hitbox.y = 0
		targetButton.hitbox.w = 22
		targetButton.hitbox.h = 22
		systemBox.table.targetButton = targetButton
		local offenseButton = Hyperspace.Button()
		offenseButton:OnInit("systemUI/button_og_turret_offense", Hyperspace.Point(UIOffset_x + 9, UIOffset_y + 35))
		offenseButton.hitbox.x = 0
		offenseButton.hitbox.y = 0
		offenseButton.hitbox.w = 22
		offenseButton.hitbox.h = 22
		systemBox.table.offenseButton = offenseButton
		local defenceButton = Hyperspace.Button()
		defenceButton:OnInit("systemUI/button_og_turret_defence", Hyperspace.Point(UIOffset_x + 9, UIOffset_y + 61))
		defenceButton.hitbox.x = 0
		defenceButton.hitbox.y = 0
		defenceButton.hitbox.w = 22
		defenceButton.hitbox.h = 22
		systemBox.table.defenceButton = defenceButton
	end
end
script.on_internal_event(Defines.InternalEvents.CONSTRUCT_SYSTEM_BOX, system_construct_system_box)

local function system_mouse_move(systemBox, x, y)
	if is_system(systemBox) then
		local targetButton = systemBox.table.targetButton
		targetButton:MouseMove(x - (UIOffset_x + 9), y - (UIOffset_y + 9), false)
		local offenseButton = systemBox.table.offenseButton
		offenseButton:MouseMove(x - (UIOffset_x + 9), y - (UIOffset_y + 35), false)
		local defenceButton = systemBox.table.defenceButton
		defenceButton:MouseMove(x - (UIOffset_x + 9), y - (UIOffset_y + 61), false)
	end
	return Defines.Chain.CONTINUE
end
script.on_internal_event(Defines.InternalEvents.SYSTEM_BOX_MOUSE_MOVE, system_mouse_move)

local function system_click(systemBox, shift)
	if is_system(systemBox) then
		local targetButton = systemBox.table.targetButton
		if targetButton.bHover and targetButton.bActive then
			--print("TARGET CLICK")
			local shipManager = Hyperspace.ships.player
			currentlyTargetting = true
		end
		local offenseButton = systemBox.table.offenseButton
		if offenseButton.bHover and offenseButton.bActive then
			--print("OFFENSE CLICK")
			local shipManager = Hyperspace.ships.player
			Hyperspace.playerVariables[systemStateVarName] = 0
		end
		local defenceButton = systemBox.table.defenceButton
		if defenceButton.bHover and defenceButton.bActive then
			--print("DEFENCE CLICK")
			local shipManager = Hyperspace.ships.player
			Hyperspace.playerVariables[systemStateVarName] = 1
		end
	end
	return Defines.Chain.CONTINUE
end
script.on_internal_event(Defines.InternalEvents.SYSTEM_BOX_MOUSE_CLICK, system_click)

local function system_ready(shipSystem)
	return not shipSystem:GetLocked() and shipSystem:Functioning() and shipSystem.iHackEffect <= 1
end

local buttonBase
local chargeBar
local chargeIcon
script.on_init(function()
	buttonBase = Hyperspace.Resources:CreateImagePrimitiveString("systemUI/button_og_turret_base.png", UIOffset_x, UIOffset_y, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
	chargeBar = {
		bottom = Hyperspace.Resources:CreateImagePrimitiveString("systemUI/button_og_turret_charge_bottom.png", UIOffset_x, UIOffset_y, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false),
		middle = Hyperspace.Resources:CreateImagePrimitiveString("systemUI/button_og_turret_charge_middle.png", UIOffset_x, UIOffset_y, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false),
		top = Hyperspace.Resources:CreateImagePrimitiveString("systemUI/button_og_turret_charge_top.png", UIOffset_x, UIOffset_y, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false),
	}
	chargeIcon = {
		off = Hyperspace.Resources:CreateImagePrimitiveString("systemUI/button_og_turret_charge_off.png", UIOffset_x, UIOffset_y, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false),
		on = Hyperspace.Resources:CreateImagePrimitiveString("systemUI/button_og_turret_charge_on.png", UIOffset_x, UIOffset_y, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false),
	}
end)

local function system_render(systemBox, ignoreStatus)
	if is_system(systemBox) and Hyperspace.playerVariables[systemBlueprintVarName] >= 0 then
		local shipManager = Hyperspace.ships.player
		local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(systemId))

		local targetButton = systemBox.table.targetButton
		targetButton.bActive = system_ready(systemBox.pSystem)
		local offenseButton = systemBox.table.offenseButton
		offenseButton.bActive = system_ready(systemBox.pSystem) and Hyperspace.playerVariables[systemStateVarName] ~= 0
		local defenceButton = systemBox.table.defenceButton
		defenceButton.bActive = system_ready(systemBox.pSystem) and Hyperspace.playerVariables[systemStateVarName] ~= 1

		if targetButton.bHover and Hyperspace.playerVariables[systemStateVarName] == 0 then
			Hyperspace.Mouse.tooltip = "Target the turret at the enemy ship."
		elseif targetButton.bHover and Hyperspace.playerVariables[systemStateVarName] == 1 then
			Hyperspace.Mouse.tooltip = "Target the turret at enemy projectiles and drones."
		elseif offenseButton.bHover then
			Hyperspace.Mouse.tooltip = "Set the turret to offensive mode."
		elseif defenceButton.bHover then
			Hyperspace.Mouse.tooltip = "Set the turret to defensive mode."
		end

		local currentTurret = turrets[ turretBlueprintsList[ Hyperspace.playerVariables[systemBlueprintVarName] ] ]
		local maxCharges = currentTurret.charges
		local charges = Hyperspace.playerVariables[systemChargesVarName]
		local chargeTime = currentTurret.charge_time[system:GetEffectivePower()]/1 + system.iActiveManned * 0.1
		local time = math.floor(0.5 + systemTime * chargeTime)
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(32, 74, 0)
		Graphics.CSurface.GL_RenderPrimitive(chargeBar.bottom)
		for i = 1, maxCharges * 6 do
			Graphics.CSurface.GL_PushMatrix()
			Graphics.CSurface.GL_Translate(0, i * -1, 0)
			Graphics.CSurface.GL_RenderPrimitive(chargeBar.middle)
			Graphics.CSurface.GL_PopMatrix()
		end
		for i = 1, 2 * chargeTime + 2 do
			Graphics.CSurface.GL_PushMatrix()
			Graphics.CSurface.GL_Translate(0, maxCharges * -6 - i, 0)
			Graphics.CSurface.GL_RenderPrimitive(chargeBar.middle)
			Graphics.CSurface.GL_PopMatrix()
		end
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(0, maxCharges * -6 - 2 * chargeTime - 8 , 0)
		Graphics.CSurface.GL_RenderPrimitive(chargeBar.top)
		Graphics.CSurface.GL_PopMatrix()

		Graphics.CSurface.GL_PopMatrix()

		Graphics.CSurface.GL_RenderPrimitive(buttonBase)

		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(32, 74, 0)
		local y = 0
		for i = 1, maxCharges do
			y = y - 6
			Graphics.CSurface.GL_PushMatrix()
			Graphics.CSurface.GL_Translate(0, i * -6, 0)
			if i <= charges then
				Graphics.CSurface.GL_RenderPrimitive(chargeIcon.on)
			else
				Graphics.CSurface.GL_RenderPrimitive(chargeIcon.off)
			end
			Graphics.CSurface.GL_PopMatrix()
		end

		Graphics.CSurface.GL_DrawRect(
			UIOffset_x + 3, 
			UIOffset_y + y - 1 - 2 * chargeTime, 
			5, 
			2 * chargeTime, 
			Graphics.GL_Color(0.5, 0.5, 0.5, 1)
			)
		Graphics.CSurface.GL_DrawRect(
			UIOffset_x + 3, 
			UIOffset_y + y - 1 - 2 * time, 
			5, 
			2 * time, 
			Graphics.GL_Color(1, 1, 1, 1)
			)

		Graphics.CSurface.GL_PopMatrix()
		systemBox.table.targetButton:OnRender()
		systemBox.table.offenseButton:OnRender()
		systemBox.table.defenceButton:OnRender()
		Graphics.freetype.easy_printNewlinesCentered(51, UIOffset_x + 20, UIOffset_y - 3, 50, tostring(math.floor(0.5 + systemTime * chargeTime * 10)/10).."/"..tostring(math.floor(0.5 + chargeTime * 10)/10))
		--Graphics.CSurface.GL_DrawCircle(UIOffset_x + 20, UIOffset_y - 3, 1, Graphics.GL_Color(1, 0, 0, 1))
	end
end
script.on_render_event(Defines.RenderEvents.SYSTEM_BOX, 
function(systemBox, ignoreStatus) 
	return Defines.Chain.CONTINUE
end, system_render)

local turret_directions = {
	UP = -1,
	RIGHT = 0,
	DOWN = 1,
	LEFT = -2,
	UP_RIGHT = -0.5,
	DOWN_RIGHT = 0.5,
}

local turret_location = {}
turret_location["og_raider_a"] = {x = 216, y = 158, direction = turret_directions.RIGHT}
turret_location["og_raider_b"] = {x = 216, y = 158, direction = turret_directions.RIGHT}
turret_location["og_raider_c"] = {x = 216, y = 158, direction = turret_directions.RIGHT}

local currentAimingAngle = 0
local turretTarget = nil

script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function(shipManager)
	if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(systemId)) then
		turretTarget = nil
		Hyperspace.playerVariables[systemChargesVarName] = 0
		systemTime = 0
		Hyperspace.playerVariables[systemTimeVarName] = 0 
		systemFiringTime = 0
		systemCurrentShot = 1
		currentlyTargetting = false
	end
end)
local needSetValues = false
script.on_init(function(newGame)
	if newGame then
		local id, i = findStartingTurret(Hyperspace.ships.player)
		Hyperspace.playerVariables[systemBlueprintVarName] = i
	else
		needSetValues = true
	end
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if shipManager.iShipId == 0 and needSetValues and Hyperspace.playerVariables[systemTimeVarName] ~= 0 then
		needSetValues = false
		systemTime = Hyperspace.playerVariables[systemTimeVarName] / 10000000
	end
end)

local function checkValidTarget(targetable, turret, shipManager)
	if not targetable then return false end
	local isDying = targetable.GetIsDying and targetable:GetIsDying()
	local ownerId = targetable.GetOwnerId and targetable:GetOwnerId()
	local space = targetable.GetSpaceId and targetable:GetSpaceId()
	local valid = targetable.ValidTarget and targetable:ValidTarget()
	local hostile = targetable.hostile -- bool
	local type = targetable.type -- int
	local targeted = targetable.targeted -- bool
	--print("target: isDying"..tostring(isDying).." ownerId"..tostring(ownerId).." space"..tostring(space).." valid"..tostring(valid).." hostile"..tostring(hostile).." type"..tostring(type).." targeted"..tostring(targeted))
	if not isDying and ownerId ~= shipManager.iShipId and space == shipManager.iShipId and valid and hostile and turret.defence_type[type] and not targeted then
		return true
	end
	return false
end

local function findTurretTarget(currentTurret, shipManager, pos, speed)
	local spaceManager = Hyperspace.App.world.space
	local targetList = {}
	for projectile in vter(spaceManager.projectiles) do
		--print(projectile.extend.name.." type:"..tostring(projectile:GetType()))
		if checkValidTarget(projectile._targetable, currentTurret, shipManager) and not projectile.missed and not projectile.passedTarget and not projectile:GetType() == 5 then
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
		if checkValidTarget(drone._targetable, currentTurret, shipManager) and not drone.bDead then
			local targetPos = drone._targetable:GetRandomTargettingPoint(true)
			local targetVelocity = drone._targetable:GetSpeed()
			targetVelocity = Hyperspace.Pointf(targetVelocity.x/(18.333*time_increment(true)), targetVelocity.y/(18.333*time_increment(true)))
			local target_angle, int_point, t = find_intercept_angle(pos, speed, targetPos, targetVelocity)
			if not target_angle then 
				target_angle = get_angle_between_points(pos, targetPos)
				int_point = targetPos
				t = 1
			end
			table.insert(targetList, {target = drone._targetable, angle = target_angle})
		end
	end
	if #targetList > 0 then
		local currentLowest = targetList[1]
		for i, targetTable in ipairs(targetList) do
			local diffCurrent = targetTable.angle - currentAimingAngle
			if diffCurrent > 180 then
				diffCurrent = diffCurrent - 360
			elseif diffCurrent <= -180 then
				diffCurrent = diffCurrent + 360
			end
			local diffLowest = currentLowest.angle - currentAimingAngle
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
	if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(systemId)) and Hyperspace.playerVariables[systemBlueprintVarName] >= 0  then
		local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(systemId))
		local spaceManager = Hyperspace.App.world.space
		local shipGraph = Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId)
		local shipCorner = {x = shipManager.ship.shipImage.x + shipGraph.shipBox.x, y = shipManager.ship.shipImage.y + shipGraph.shipBox.y}
		local turretLoc = turret_location[shipManager.ship.shipName] or {x = 0, y = 0, direction = turret_directions.RIGHT}
		local turretRestAngle = 90 * turretLoc.direction
		local pos = {x = shipCorner.x + turretLoc.x, y = shipCorner.y + turretLoc.y}

		local currentTurret = turrets[ turretBlueprintsList[ Hyperspace.playerVariables[systemBlueprintVarName] ] ]
		local currentMaxRotationSpeed = currentTurret.rotation_speed + shipManager:GetAugmentationValue("OG_TURRET_ROTATION_SPEED")
		local chargeTime = currentTurret.charge_time[system:GetEffectivePower()]/1 + system.iActiveManned * 0.1
		local manningCrew = nil
		for crew in vter(shipManager.vCrewList) do
			if crew.bActiveManning and crew.currentSystem == aea_super_shields_system then
				aea_super_shields_system.iActiveManned = crew:GetSkillLevel(2)
				manningCrew = crew
			end
		end

		systemFiringTime = systemFiringTime - time_increment(true)
		if Hyperspace.playerVariables[systemChargesVarName] > currentTurret.charges then
			systemTime = systemTime - time_increment(true)/chargeTime
			if systemTime <= 0 then
				Hyperspace.playerVariables[systemChargesVarName] = Hyperspace.playerVariables[systemChargesVarName] - 1
				systemTime = 0
			end
			Hyperspace.playerVariables[systemTimeVarName] = systemTime * 10000000 
		elseif Hyperspace.playerVariables[systemChargesVarName] < currentTurret.charges then
			systemTime = systemTime + time_increment(true)/(currentTurret.charge_time[system:GetEffectivePower()] or math.huge)
			if systemTime >= 1 then
				Hyperspace.playerVariables[systemChargesVarName] = Hyperspace.playerVariables[systemChargesVarName] + 1
				systemTime = 0
			end
			Hyperspace.playerVariables[systemTimeVarName] = systemTime * 10000000 
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

		if Hyperspace.playerVariables[systemStateVarName] == 0 then
			if math.abs(normalize_angle(currentAimingAngle)) > 0.01 then
				currentAimingAngle = move_angle_to(currentAimingAngle, 0, currentMaxRotationSpeed * time_increment(true))
			end
		elseif Hyperspace.playerVariables[systemStateVarName] == 1 then
			if turretTarget and not checkValidTarget(turretTarget, currentTurret, shipManager) then
				turretTarget = nil
			end
			if not turretTarget then
				turretTarget = findTurretTarget(currentTurret, shipManager, pos, speed)
			end
			if turretTarget then
				local targetPos = turretTarget:GetRandomTargettingPoint(true)
				local targetVelocity = turretTarget:GetSpeed()
				targetVelocity = Hyperspace.Pointf(targetVelocity.x/(18.333*time_increment(true)), targetVelocity.y/(18.333*time_increment(true)))
				local target_angle, int_point, t = find_intercept_angle(pos, speed, targetPos, targetVelocity)
				--print("AFTER FINDING INTERCEPT"..tostring(target_angle).." t:"..tostring(t))
				if not target_angle then 
					--print("int failed")
					target_angle = get_angle_between_points(pos, targetPos)
					int_point = targetPos
					t = 1
				end
				if target_angle then
					if math.abs(normalize_angle(currentAimingAngle - target_angle)) > 0.01 then
						currentAimingAngle = move_angle_to(currentAimingAngle, target_angle, currentMaxRotationSpeed * time_increment(true))
					end
					if math.abs(normalize_angle(currentAimingAngle - target_angle)) < 1 and systemFiringTime <= 0 and Hyperspace.playerVariables[systemChargesVarName] > 0 then
						--print(systemCurrentShot)
						local currentShot = currentTurret.fire_points[systemCurrentShot]
						local fired_laser = spaceManager:CreateLaserBlast(
							blueprint,
							offset_point_in_direction(pos, currentAimingAngle, currentShot.x, currentShot.y),
							shipManager.iShipId,
							shipManager.iShipId, 
							Hyperspace.Pointf(int_point.x, int_point.y),
							shipManager.iShipId,
							math.rad(target_angle)
							)
						fired_laser:ComputeHeading()
						systemFiringTime = currentShot.fire_delay
						Hyperspace.playerVariables[systemChargesVarName] = Hyperspace.playerVariables[systemChargesVarName] - 1
						--[[if systemCurrentShot == #currentTurret.fire_points or Hyperspace.playerVariables[systemChargesVarName] == 0 then
							turretTarget = nil
						end]]
						turretTarget = nil
						systemCurrentShot = systemCurrentShot % #currentTurret.fire_points + 1
					end
				end
			else
				if math.abs(normalize_angle(currentAimingAngle - turretRestAngle)) > 0.01 then
					currentAimingAngle = move_angle_to(currentAimingAngle, turretRestAngle, currentMaxRotationSpeed * time_increment(true))
				end
			end
		end
	end
end)


script.on_render_event(Defines.RenderEvents.SHIP, function(ship) end, function(ship) 
	local shipManager = Hyperspace.ships(ship.iShipId)
	if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(systemId)) then
		local currentTurret = nil
		if Hyperspace.App.menu.shipBuilder.bOpen then
			local id, i = findStartingTurret(shipManager)
			if id then currentTurret = turrets[id] end
			print(id)
		else
			currentTurret = turrets[ turretBlueprintsList[ Hyperspace.playerVariables[systemBlueprintVarName] ] ]
		end
		if currentTurret then
			local shipGraph = Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId)

			local turretLoc = turret_location[ship.shipName] or {x = 0, y = 0}
			local shipCorner = {x = ship.shipImage.x + shipGraph.shipBox.x, y = ship.shipImage.y + shipGraph.shipBox.y}

			local charges = Hyperspace.playerVariables[systemChargesVarName]
			local glowImage = currentTurret.glow_images[charges]
			Graphics.CSurface.GL_PushMatrix()
			Graphics.CSurface.GL_Translate(shipCorner.x + turretLoc.x, shipCorner.y + turretLoc.y, 0)
			Graphics.CSurface.GL_Rotate(currentAimingAngle, 0, 0, 1)
			Graphics.CSurface.GL_RenderPrimitive(currentTurret.image)
			if glowImage then
				Graphics.CSurface.GL_RenderPrimitive(glowImage)
			end
			Graphics.CSurface.GL_PopMatrix()
		end
	end
end)

mods.multiverse.systemIcons[Hyperspace.ShipSystem.NameToSystemId(systemId)] = mods.multiverse.register_system_icon(systemId)