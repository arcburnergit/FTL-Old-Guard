local vter = mods.multiverse.vter
local time_increment = mods.multiverse.time_increment
local userdata_table = mods.multiverse.userdata_table
local node_child_iter = mods.multiverse.node_child_iter
local node_get_number_default = mods.multiverse.node_get_number_default

local function worldToPlayerLocation(location)
	local cApp = Hyperspace.App
	local combatControl = cApp.gui.combatControl
	local playerPosition = combatControl.playerShipPosition
	return Hyperspace.Point(location.x - playerPosition.x, location.y - playerPosition.y)
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
mods.og.systemNameList = {systemName, "og_turret_alt", "og_turret_mini", "og_turret_mini_2", "og_turret_mini_3", "og_turret_mini_4"}
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
				starting_turrets[shipClass] = {}
				local xmlFile = node:first_attribute("layout"):value()
				local imgFile = node:first_attribute("img"):value()
				table.insert(xmlFilesToCheck, {xml=xmlFile, img=imgFile})
				for systemListNode in node_child_iter(node) do
					if systemListNode:name() == "systemList" then
						for systemNode in node_child_iter(systemListNode) do
							if systemNameCheck[systemNode:name()] then
								--print(shipClass.." "..systemNode:name().." "..systemNode:first_attribute("turret"):value())
								starting_turrets[shipClass][systemNode:name()] = systemNode:first_attribute("turret"):value()
							end
						end
					end
				end
			end
		end
		doc:clear()
	end

	for _, fileTable in ipairs(xmlFilesToCheck) do
		local doc = RapidXML.xml_document("data/"..fileTable.xml..".xml")
		for node in node_child_iter(doc:first_node("FTL") or doc) do
			if node:name() == "ogTurretMounts" then
				turret_location[fileTable.xml] = {}
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
	end
end
local beamDamageMods = mods.multiverse.beamDamageMods
beamDamageMods["OG_FOCUS_PROJECTILE_FAKE"] = {iDamage = 0}
beamDamageMods["OG_FOCUS_PROJECTILE_WEAK_FAKE"] = {iDamage = 0}

mods.og.turretBlueprintsList = {}
local turretBlueprintsList = mods.og.turretBlueprintsList 
turretBlueprintsList[0] = "OG_EMPTY_TURRET"
table.insert(turretBlueprintsList, "OG_TURRET_LASER_1")
table.insert(turretBlueprintsList, "OG_TURRET_LASER_RUSTY_1")
table.insert(turretBlueprintsList, "OG_TURRET_LASER_2")
table.insert(turretBlueprintsList, "OG_TURRET_LASER_ANCIENT")
table.insert(turretBlueprintsList, "OG_TURRET_LASER_CEL_1")
table.insert(turretBlueprintsList, "OG_TURRET_ION_1")
table.insert(turretBlueprintsList, "OG_TURRET_ION_2")
table.insert(turretBlueprintsList, "OG_TURRET_MISSILE_1")
table.insert(turretBlueprintsList, "OG_TURRET_MISSILE_2")
table.insert(turretBlueprintsList, "OG_TURRET_FLAK_1")
table.insert(turretBlueprintsList, "OG_TURRET_FOCUS_1")
table.insert(turretBlueprintsList, "OG_TURRET_LASER_MINI_1")
table.insert(turretBlueprintsList, "OG_TURRET_LASER_RUSTY_MINI_1")
table.insert(turretBlueprintsList, "OG_TURRET_LASER_MINI_2")
table.insert(turretBlueprintsList, "OG_TURRET_ION_MINI_1")
table.insert(turretBlueprintsList, "OG_TURRET_FOCUS_MINI_1")

table.insert(turretBlueprintsList, "OG_TURRET_LASER_DAWN")
table.insert(turretBlueprintsList, "OG_TURRET_ION_DAWN")
table.insert(turretBlueprintsList, "OG_TURRET_MISSILE_DAWN")
table.insert(turretBlueprintsList, "OG_TURRET_FLAK_DAWN")
table.insert(turretBlueprintsList, "OG_TURRET_FOCUS_DAWN")
table.insert(turretBlueprintsList, "OG_TURRET_LASER_MINI_DAWN_1")
table.insert(turretBlueprintsList, "OG_TURRET_LASER_MINI_DAWN_2")
table.insert(turretBlueprintsList, "OG_TURRET_FOCUS_MINI_DAWN")

--1 = MISSILES, 2 = FLAK, 3 = DRONES, 4 = PROJECTILES, 5 = HACKING 
local defence_types = {
	DRONES = {[3] = true, [7] = true, name = "Drones"},
	MISSILES = {[1] = true, [2] = true, [7] = true, name = "All Solid Projectiles"},
	DRONES_MISSILES = {[1] = true, [2] = true, [3] = true, [7] = true, name = "All Solid Projectiles and Drones"},
	PROJECTILES = {[4] = true, name = "Non-Solid Projectiles"},
	PROJECTILES_MISSILES = {[1] = true, [2] = true, [4] = true, [7] = true, name = "All Projectiles"},
	ALL = {[1] = true, [2] = true, [3] = true, [4] = true, [7] = true, name = "All"},
}

mods.og.turrets = {}
local turrets = mods.og.turrets
turrets["OG_EMPTY_TURRET"] = {
	image = Hyperspace.Animations:GetAnimation("og_turret_laser_error"),
	multi_anim = {frames = 3},
	glow = Hyperspace.Animations:GetAnimation("og_turret_laser_1_glow"),
	fire_points = {{x = 12, y = -42, fire_delay = 0.1}, {x = -12, y = -42, fire_delay = 0.5}},
	defence_type = defence_types.ALL,
	blueprint_type = 1,
	blueprint = "OG_LASER_PROJECTILE_BASE",
	charges = 1,
	charges_per_charge = 1,
	rotation_speed = 360,
	charge_time = {[0] = 9, 9, 8, 7, 6, 5, 4, 3, 2, 1},
}
turrets["OG_TURRET_LASER_1"] = {
	enemy_burst = 2,
	image = Hyperspace.Animations:GetAnimation("og_turret_laser_1"),
	multi_anim = {frames = 3},
	glow = Hyperspace.Animations:GetAnimation("og_turret_laser_1_glow"),
	fire_points = {{x = 12, y = -42, fire_delay = 0.5}, {x = -12, y = -42, fire_delay = 0.5}},
	defence_type = defence_types.PROJECTILES,
	blueprint_type = 1,
	blueprint = "OG_LASER_PROJECTILE_BASE",
	charges = 6,
	charges_per_charge = 2,
	rotation_speed = 180,
	charge_time = {[0] = 14, 14, 12, 9, 7, 6, 5, 4, 3},
}
turrets["OG_TURRET_LASER_RUSTY_1"] = {
	enemy_burst = 2,
	shot_radius = 42,
	image = Hyperspace.Animations:GetAnimation("og_turret_laser_rusty_1"),
	multi_anim = {frames = 3},
	glow = Hyperspace.Animations:GetAnimation("og_turret_laser_1_glow"),
	fire_points = {{x = 12, y = -42, fire_delay = 0.5}, {x = -12, y = -42, fire_delay = 0.5}},
	defence_type = defence_types.PROJECTILES,
	blueprint_type = 1,
	blueprint = "OG_LASER_PROJECTILE_BASE",
	charges = 6,
	charges_per_charge = 2,
	rotation_speed = 180,
	charge_time = {[0] = 16, 16, 13, 11, 9, 7, 6, 5, 4},
}
turrets["OG_TURRET_LASER_2"] = {
	enemy_burst = 1,
	image = Hyperspace.Animations:GetAnimation("og_turret_laser_2"),
	glow = Hyperspace.Animations:GetAnimation("og_turret_laser_2_glow"),
	fire_points = {{x = 0, y = -60, fire_delay = 1}},
	defence_type = defence_types.DRONES_MISSILES,
	blueprint_type = 1,
	blueprint = "OG_LASER_PROJECTILE_HEAVY",
	charges = 3,
	charges_per_charge = 1,
	rotation_speed = 120,
	charge_time = {[0] = 9, 9, 7.5, 6, 5, 4.5, 4, 3.75, 3.5},
}
turrets["OG_TURRET_LASER_ANCIENT"] = {
	enemy_burst = 3,
	image = Hyperspace.Animations:GetAnimation("og_turret_laser_ancient"),
	glow = Hyperspace.Animations:GetAnimation("og_turret_laser_ancient_glow"),
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_laser_ancient_charge.png", -74, -74, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 0, y = 0, fire_delay = 0.3}},
	defence_type = defence_types.PROJECTILES_MISSILES,
	blueprint_type = 1,
	blueprint = "OG_LASER_PROJECTILE_ANCIENT",
	charges = 6,
	charges_per_charge = 3,
	rotation_speed = 180,
	charge_time = {[0] = 14, 14, 12, 9, 7, 6, 5, 4, 3},
}
turrets["OG_TURRET_LASER_CEL_1"] = {
	enemy_burst = 4,
	image = Hyperspace.Animations:GetAnimation("og_turret_laser_cel_1"),
	glow = Hyperspace.Animations:GetAnimation("og_turret_laser_cel_1_glow"),
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_laser_cel_1_charge.png", -13, -28, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 0, y = -40, fire_delay = 0.25}},
	defence_type = defence_types.ALL,
	blueprint_type = 1,
	blueprint = "OG_LASER_PROJECTILE_CEL",
	charges = 8,
	charges_per_charge = 4,
	rotation_speed = 240,
	charge_time = {[0] = 24, 24, 20, 17, 14, 12, 10, 8, 7},
}
turrets["OG_TURRET_ION_1"] = {
	enemy_burst = 1,
	image = Hyperspace.Animations:GetAnimation("og_turret_ion_1"),
	glow = Hyperspace.Animations:GetAnimation("og_turret_ion_1_glow"),
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_ion_1_charge.png", -39, -10, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 0, y = -42, fire_delay = 0.5}},
	defence_type = defence_types.DRONES,
	blueprint_type = 1,
	blueprint = "OG_ION_PROJECTILE_BASE",
	charges = 1,
	charges_per_charge = 1,
	rotation_speed = 180,
	charge_time = {[0] = 9, 9, 7.5, 6, 5, 4.5, 4, 3.75, 3.5},
}
turrets["OG_TURRET_ION_2"] = {
	enemy_burst = 2,
	image = Hyperspace.Animations:GetAnimation("og_turret_ion_2"),
	glow = Hyperspace.Animations:GetAnimation("og_turret_ion_2_glow"),
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_ion_2_charge.png", -30, -11, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 5, y = -32, fire_delay = 0.25}, {x = -5, y = -32, fire_delay = 0.5}},
	defence_type = defence_types.DRONES,
	blueprint_type = 1,
	blueprint = "OG_ION_PROJECTILE_FIRE",
	charges = 4,
	charges_per_charge = 2,
	rotation_speed = 180,
	charge_time = {[0] = 17, 17, 14, 11, 9, 7, 5, 5, 4},
}
turrets["OG_TURRET_MISSILE_1"] = {
	enemy_burst = 3,
	homing = 720,
	aim_cone = 45,
	image = Hyperspace.Animations:GetAnimation("og_turret_missile_1"),
	glow = Hyperspace.Animations:GetAnimation("og_turret_missile_1_glow"),
	fire_points = {{x = 0, y = -30, fire_delay = 0.4}},
	defence_type = defence_types.ALL,
	blueprint_type = 2,
	ammo_consumption = 0.2,
	blueprint = "OG_MISSILE_PROJECTILE_SWARM",
	charges = 7,
	charges_per_charge = 1,
	rotation_speed = 120,
	charge_time = {[0] = 8.5, 8.5, 7, 6, 5, 4, 3.5, 3, 2.5},
}
turrets["OG_TURRET_MISSILE_2"] = {
	enemy_burst = 2,
	homing = 480,
	aim_cone = 30,
	image = Hyperspace.Animations:GetAnimation("og_turret_missile_2"),
	glow = Hyperspace.Animations:GetAnimation("og_turret_missile_2_glow"),
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_missile_2_charge.png", -6, -4, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 26, y = -48, fire_delay = 0.5}, {x = 15, y = -48, fire_delay = 0.5}, {x = -15, y = -48, fire_delay = 0.5}, {x = -26, y = -48, fire_delay = 0.5}},
	defence_type = defence_types.DRONES_MISSILES,
	blueprint_type = 2,
	ammo_consumption = 0.5,
	blueprint = "OG_MISSILE_PROJECTILE_HEAVY",
	charges = 4,
	charges_per_charge = 4,
	rotation_speed = 120,
	charge_time = {[0] = 20, 20, 17, 14, 12, 10, 8.5, 7, 6},
}
turrets["OG_TURRET_FLAK_1"] = {
	enemy_burst = 3,
	shot_radius = 42,
	aim_cone = 1,
	image = Hyperspace.Animations:GetAnimation("og_turret_flak_1"),
	glow = Hyperspace.Animations:GetAnimation("og_turret_flak_1_glow"),
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_flak_1_charge.png", -33, -33, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 0, y = -30, fire_delay = 0}, {x = 0, y = -30, fire_delay = 0}, {x = 0, y = -30, fire_delay = 0.25}},
	defence_type = defence_types.ALL,
	blueprint_type = 1,
	blueprint = "OG_FLAK_PROJECTILE",
	charges = 9,
	charges_per_charge = 3,
	rotation_speed = 180,
	charge_time = {[0] = 14, 14, 12, 9, 7, 6, 5, 4, 3},
}
turrets["OG_TURRET_FOCUS_1"] = {
	enemy_burst = 1,
	hold_time = 0.4,
	speed_reduction = 0.5,
	image = Hyperspace.Animations:GetAnimation("og_turret_focus_1"),
	glow = Hyperspace.Animations:GetAnimation("og_turret_focus_1_glow"),
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_focus_1_charge.png", -24, -8, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 0, y = -7, fire_delay = 0.7}},
	defence_type = defence_types.MISSILES,
	blueprint_type = 3,
	blueprint = "OG_FOCUS_PROJECTILE",
	blueprint_fake = "OG_FOCUS_PROJECTILE_FAKE",
	charges = 3,
	charges_per_charge = 1,
	rotation_speed = 240,
	charge_time = {[0] = 14, 14, 12, 9, 7, 6, 5, 4, 3},
}
turrets["OG_TURRET_LASER_MINI_1"] = {
	mini = true,
	image = Hyperspace.Animations:GetAnimation("og_turret_laser_mini_1"),
	glow = Hyperspace.Animations:GetAnimation("og_turret_laser_mini_1_glow"),
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_laser_mini_1_charge.png", -4, -3, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 0, y = -12, fire_delay = 0.25}},
	defence_type = defence_types.PROJECTILES_MISSILES,
	blueprint_type = 1,
	blueprint = "OG_LASER_PROJECTILE_BASE",
	charges = 1,
	charges_per_charge = 1,
	rotation_speed = 240,
	charge_time = {[0] = 10, 10, 8, 6, 5, 4, 3.5, 3, 2.5},
}
turrets["OG_TURRET_LASER_RUSTY_MINI_1"] = {
	mini = true,
	shot_radius = 21,
	image = Hyperspace.Animations:GetAnimation("og_turret_laser_rusty_mini_1"),
	glow = Hyperspace.Animations:GetAnimation("og_turret_laser_mini_1_glow"),
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_laser_mini_1_charge.png", -4, -3, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 0, y = -12, fire_delay = 0.25}},
	defence_type = defence_types.PROJECTILES_MISSILES,
	blueprint_type = 1,
	blueprint = "OG_LASER_PROJECTILE_BASE",
	charges = 1,
	charges_per_charge = 1,
	rotation_speed = 240,
	charge_time = {[0] = 12, 12, 10, 8, 6, 5, 4, 3.5, 3},
}
turrets["OG_TURRET_LASER_MINI_2"] = {
	enemy_burst = 1,
	mini = true,
	image = Hyperspace.Animations:GetAnimation("og_turret_laser_mini_2"),
	glow = Hyperspace.Animations:GetAnimation("og_turret_laser_mini_2_glow"),
	glow_offset = {x = -6, y = -4},
	glow_name = "og_turrets/turret_laser_mini_2_glow",
	glow_images = {},
	fire_points = {{x = 0, y = -16, fire_delay = 0.4}},
	defence_type = defence_types.PROJECTILES,
	blueprint_type = 1,
	blueprint = "OG_LASER_PROJECTILE_LIGHT",
	charges = 3,
	charges_per_charge = 1,
	rotation_speed = 240,
	charge_time = {[0] = 5, 5, 3.5, 2.5, 2, 1.75, 1.5, 1.25, 1},
} -- add mini ion (anti drone) and mini focus (anti laser)
turrets["OG_TURRET_ION_MINI_1"] = {
	enemy_burst = 1,
	mini = true,
	image = Hyperspace.Animations:GetAnimation("og_turret_ion_mini_1"),
	glow = Hyperspace.Animations:GetAnimation("og_turret_ion_mini_1_glow"),
	glow_offset = {x = -17, y = -6},
	glow_name = "og_turrets/turret_ion_mini_1_glow",
	glow_images = {},
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_ion_mini_1_charge.png", -17, -6, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 0, y = -12, fire_delay = 0.25}},
	defence_type = defence_types.DRONES,
	blueprint_type = 1,
	blueprint = "OG_ION_PROJECTILE_WEAK",
	charges = 1,
	charges_per_charge = 1,
	rotation_speed = 240,
	charge_time = {[0] = 7, 7, 6, 5, 4, 3.5, 3, 2.75, 2.5},
}
turrets["OG_TURRET_FOCUS_MINI_1"] = {
	enemy_burst = 1,
	mini = true,
	hold_time = 0.4,
	speed_reduction = 0.5,
	image = Hyperspace.Animations:GetAnimation("og_turret_focus_mini_1"),
	glow = Hyperspace.Animations:GetAnimation("og_turret_focus_mini_1_glow"),
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_focus_mini_1_charge.png", -17, -6, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 0, y = -4, fire_delay = 0.7}},
	defence_type = defence_types.MISSILES,
	blueprint_type = 3,
	blueprint = "OG_FOCUS_PROJECTILE_WEAK",
	blueprint_fake = "OG_FOCUS_PROJECTILE_WEAK_FAKE",
	charges = 2,
	charges_per_charge = 1,
	rotation_speed = 240,
	charge_time = {[0] = 7, 7, 6, 5, 4, 3.5, 3, 2.75, 2.5},
}


turrets["OG_TURRET_LASER_DAWN"] = {
	enemy_burst = 1,
	image = Hyperspace.Animations:GetAnimation("og_turret_laser_dawn"),
	glow = Hyperspace.Animations:GetAnimation("og_turret_laser_2_glow"),
	fire_points = {{x = 0, y = -60, fire_delay = 1}},
	defence_type = defence_types.DRONES_MISSILES,
	blueprint_type = 1,
	blueprint = "OG_LASER_PROJECTILE_HEAVY",
	charges = 3,
	charges_per_charge = 1,
	rotation_speed = 120,
	charge_time = {[0] = 7.5, 7.5, 6, 5, 4.5, 4, 3.75, 3.5},
}
turrets["OG_TURRET_ION_DAWN"] = {
	enemy_burst = 2,
	image = Hyperspace.Animations:GetAnimation("og_turret_ion_dawn"),
	glow = Hyperspace.Animations:GetAnimation("og_turret_ion_2_glow"),
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_ion_2_charge.png", -30, -11, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 5, y = -32, fire_delay = 0.25}, {x = -5, y = -32, fire_delay = 0.5}},
	defence_type = defence_types.DRONES,
	blueprint_type = 1,
	blueprint = "OG_ION_PROJECTILE_FIRE",
	charges = 4,
	charges_per_charge = 2,
	rotation_speed = 180,
	charge_time = {[0] = 14, 14, 11, 9, 7, 5, 5, 4},
}
turrets["OG_TURRET_MISSILE_DAWN"] = {
	enemy_burst = 2,
	homing = 480,
	aim_cone = 30,
	image = Hyperspace.Animations:GetAnimation("og_turret_missile_dawn"),
	glow = Hyperspace.Animations:GetAnimation("og_turret_missile_dawn_glow"),
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_missile_2_charge.png", -6, -4, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 26, y = -48, fire_delay = 0.5}, {x = 15, y = -48, fire_delay = 0.5}, {x = -15, y = -48, fire_delay = 0.5}, {x = -26, y = -48, fire_delay = 0.5}},
	defence_type = defence_types.DRONES_MISSILES,
	blueprint_type = 2,
	ammo_consumption = 0.5,
	blueprint = "OG_MISSILE_PROJECTILE_HEAVY",
	charges = 4,
	charges_per_charge = 4,
	rotation_speed = 120,
	charge_time = {[0] = 17, 17, 14, 12, 10, 8.5, 7, 6},
}
turrets["OG_TURRET_FLAK_DAWN"] = {
	enemy_burst = 3,
	shot_radius = 42,
	aim_cone = 1,
	image = Hyperspace.Animations:GetAnimation("og_turret_flak_dawn"),
	glow = Hyperspace.Animations:GetAnimation("og_turret_flak_1_glow"),
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_flak_1_charge.png", -33, -33, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 0, y = -30, fire_delay = 0}, {x = 0, y = -30, fire_delay = 0}, {x = 0, y = -30, fire_delay = 0.25}},
	defence_type = defence_types.ALL,
	blueprint_type = 1,
	blueprint = "OG_FLAK_PROJECTILE",
	charges = 9,
	charges_per_charge = 3,
	rotation_speed = 180,
	charge_time = {[0] = 12, 12, 9, 7, 6, 5, 4, 3},
}
turrets["OG_TURRET_FOCUS_DAWN"] = {
	enemy_burst = 1,
	hold_time = 0.4,
	speed_reduction = 0.5,
	image = Hyperspace.Animations:GetAnimation("og_turret_focus_dawn"),
	glow = Hyperspace.Animations:GetAnimation("og_turret_focus_1_glow"),
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_focus_1_charge.png", -24, -8, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 0, y = -7, fire_delay = 0.7}},
	defence_type = defence_types.MISSILES,
	blueprint_type = 3,
	blueprint = "OG_FOCUS_PROJECTILE",
	blueprint_fake = "OG_FOCUS_PROJECTILE_FAKE",
	charges = 3,
	charges_per_charge = 1,
	rotation_speed = 240,
	charge_time = {[0] = 12, 12, 9, 7, 6, 5, 4, 3},
}
turrets["OG_TURRET_LASER_MINI_DAWN_1"] = {
	mini = true,
	image = Hyperspace.Animations:GetAnimation("og_turret_laser_mini_dawn_1"),
	glow = Hyperspace.Animations:GetAnimation("og_turret_laser_mini_1_glow"),
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_laser_mini_1_charge.png", -4, -3, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 0, y = -12, fire_delay = 0.25}},
	defence_type = defence_types.PROJECTILES_MISSILES,
	blueprint_type = 1,
	blueprint = "OG_LASER_PROJECTILE_BASE",
	charges = 1,
	charges_per_charge = 1,
	rotation_speed = 240,
	charge_time = {[0] = 8, 8, 6, 5, 4, 3.5, 3, 2.5},
}
turrets["OG_TURRET_LASER_MINI_DAWN_2"] = {
	enemy_burst = 1,
	mini = true,
	image = Hyperspace.Animations:GetAnimation("og_turret_laser_mini_dawn_2"),
	glow = Hyperspace.Animations:GetAnimation("og_turret_laser_mini_2_glow"),
	glow_offset = {x = -6, y = -4},
	glow_name = "og_turrets/turret_laser_mini_2_glow",
	glow_images = {},
	fire_points = {{x = 0, y = -16, fire_delay = 0.4}},
	defence_type = defence_types.PROJECTILES,
	blueprint_type = 1,
	blueprint = "OG_LASER_PROJECTILE_LIGHT",
	charges = 3,
	charges_per_charge = 1,
	rotation_speed = 240,
	charge_time = {[0] = 3.5, 3.5, 2.5, 2, 1.75, 1.5, 1.25, 1},
}
turrets["OG_TURRET_FOCUS_MINI_DAWN"] = {
	enemy_burst = 1,
	mini = true,
	hold_time = 0.4,
	speed_reduction = 0.5,
	image = Hyperspace.Animations:GetAnimation("og_turret_focus_mini_dawn"),
	glow = Hyperspace.Animations:GetAnimation("og_turret_focus_mini_1_glow"),
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_focus_mini_1_charge.png", -17, -6, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 0, y = -4, fire_delay = 0.7}},
	defence_type = defence_types.MISSILES,
	blueprint_type = 3,
	blueprint = "OG_FOCUS_PROJECTILE_WEAK",
	blueprint_fake = "OG_FOCUS_PROJECTILE_WEAK_FAKE",
	charges = 2,
	charges_per_charge = 1,
	rotation_speed = 240,
	charge_time = {[0] = 6, 6, 5, 4, 3.5, 3, 2.75, 2.5},
}

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

for turretId, currentTurret in pairs(turrets) do
	currentTurret.image.position.x = -1 * currentTurret.image.info.frameWidth/2
	currentTurret.image.position.y = -1 * currentTurret.image.info.frameHeight/2
	currentTurret.image.tracker.loop = false
	if currentTurret.glow then
		currentTurret.glow.position.x = -1 * currentTurret.glow.info.frameWidth/2
		currentTurret.glow.position.y = -1 * currentTurret.glow.info.frameHeight/2
		currentTurret.glow.tracker.loop = false
	end
end

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
	desc = desc.."\n"
	if damage.bLockdown then
		desc = desc.."\nLocks down rooms on hit"
	end
	if damage.fireChance > 0 then
		desc = desc.."\nFire Chance: "..math.floor(damage.fireChance * 10).."%"
	end
	if damage.breachChance > 0 then
		desc = desc.."\nFire Chance: "..math.floor(damage.breachChance * 10).."% (Adjusted: "..math.floor((100 - 10 * damage.fireChance) * (damage.breachChance/10)).."%)"
	end
	if damage.stunChance > 0 then
		desc = desc.."\nStun Chance: "..math.floor(damage.stunChance * 10).."% ("..math.floor((damage.iStun > 0 and damage.iStun) or 3).." seconds long)"
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
mods.og.systemTimeVarName = "_time"

local systemBlueprintVarName = mods.og.systemBlueprintVarName
local systemStateVarName = mods.og.systemStateVarName
local systemChargesVarName = mods.og.systemChargesVarName
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

local UIOffset_x = 36
local UIOffset_y = -65

local function system_construct_system_box(systemBox)
	if is_system(systemBox) then
		systemBox.extend.xOffset = 54

		local targetButton = Hyperspace.Button()
		targetButton:OnInit("systemUI/button_og_turret_target", Hyperspace.Point(UIOffset_x + 9, UIOffset_y + 35))
		targetButton.hitbox.x = 0
		targetButton.hitbox.y = 0
		targetButton.hitbox.w = 22
		targetButton.hitbox.h = 22
		systemBox.table.targetButton = targetButton
		local offenseButton = Hyperspace.Button()
		offenseButton:OnInit("systemUI/button_og_turret_defence", Hyperspace.Point(UIOffset_x + 9, UIOffset_y + 61))
		offenseButton.hitbox.x = 0
		offenseButton.hitbox.y = 0
		offenseButton.hitbox.w = 22
		offenseButton.hitbox.h = 22
		systemBox.table.offenseButton = offenseButton
		local defenceButton = Hyperspace.Button()
		defenceButton:OnInit("systemUI/button_og_turret_offense", Hyperspace.Point(UIOffset_x + 9, UIOffset_y + 61))
		defenceButton.hitbox.x = 0
		defenceButton.hitbox.y = 0
		defenceButton.hitbox.w = 22
		defenceButton.hitbox.h = 22
		systemBox.table.defenceButton = defenceButton

		local systemId = Hyperspace.ShipSystem.SystemIdToName(systemBox.pSystem.iSystemType)
		if microTurrets[systemId] then
			systemBox.pSystem.table.micro = true
			systemBox.pSystem.bBoostable = false
		end

		systemBox.pSystem.table.chargeTime = 0
		systemBox.pSystem.table.firingTime = 0
		--systemBox.pSystem.table.currentShot = 1
		systemBox.pSystem.table.entryAngle = math.random(360)
		systemBox.pSystem.table.currentlyTargetting = false
		systemBox.pSystem.table.currentlyTargetted = false

		systemBox.pSystem.table.currentAimingAngle = 0
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
		targetButton:MouseMove(x - (UIOffset_x + 9), y - (UIOffset_y + 35), false)
		local offenseButton = systemBox.table.offenseButton
		offenseButton:MouseMove(x - (UIOffset_x + 9), y - (UIOffset_y + 61), false)
		local defenceButton = systemBox.table.defenceButton
		defenceButton:MouseMove(x - (UIOffset_x + 9), y - (UIOffset_y + 61), false)
		local x_hb = x - (UIOffset_x + hoverBox.x)
		local y_hb = y - (UIOffset_y + hoverBox.y)
		local shipId = (systemBox.bPlayerUI and 0) or 1
		if targetButton.bHover and Hyperspace.playerVariables[shipId..systemId..systemStateVarName] == 0 then
			Hyperspace.Mouse.tooltip = "Target the turret at the enemy ship or enemy projectiles and drones."
		elseif targetButton.bHover and Hyperspace.playerVariables[shipId..systemId..systemStateVarName] == 1 then
			Hyperspace.Mouse.tooltip = "Target the turret at enemy projectiles and drones."
		elseif offenseButton.bHover and Hyperspace.playerVariables[shipId..systemId..systemStateVarName] == 1 then
			Hyperspace.Mouse.tooltip = "Set the turret to offensive mode."
		elseif defenceButton.bHover and Hyperspace.playerVariables[shipId..systemId..systemStateVarName] == 0 then
			Hyperspace.Mouse.tooltip = "Set the turret to defensive mode."
		elseif x_hb >= 0 and x_hb <= hoverBox.w and y_hb >= 0 and y_hb <= hoverBox.h then
			local currentTurret = turrets[ turretBlueprintsList[ Hyperspace.playerVariables[shipId..systemId..systemBlueprintVarName] ] ]
			Hyperspace.Mouse.tooltip = add_stat_text("", currentTurret, systemBox.pSystem:GetMaxPower())
		end
	end
	return Defines.Chain.CONTINUE
end
script.on_internal_event(Defines.InternalEvents.SYSTEM_BOX_MOUSE_MOVE, system_mouse_move)

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
	if (not isDying) and (ownerId ~= shipManager.iShipId) and (space == shipManager.iShipId) and valid and (defence_type[type] or (defence_type[7] and hackingDrone)) then
		return true
	end
	return false
end

local cursorValid = Hyperspace.Resources:GetImageId("mouse/mouse_og_turret_valid.png")
local cursorValid2 = Hyperspace.Resources:GetImageId("mouse/mouse_og_turret_valid2.png")

local cursorDefault = Hyperspace.Resources:GetImageId("mouse/pointerValid.png")
local cursorDefault2 = Hyperspace.Resources:GetImageId("mouse/pointerInvalid.png")

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
				systemBox.pSystem.table.currentTargetTemp = combatControl.selectedRoom
			else
				local shipId = (systemBox.bPlayerUI and 0) or 1
				local currentTurret = turrets[ turretBlueprintsList[ Hyperspace.playerVariables[shipId..systemId..systemBlueprintVarName] ] ]
				local mousePosPlayer = worldToPlayerLocation(Hyperspace.Mouse.position)
				local spaceManager = Hyperspace.App.world.space
				local currentClosest = nil
				for projectile in vter(spaceManager.projectiles) do
					local blueprint = Hyperspace.Blueprints:GetWeaponBlueprint(projectile.extend.name)
					if checkValidTarget(projectile._targetable, currentTurret.defence_type, shipManager) and not projectile.missed and not projectile.passedTarget and blueprint.typeName ~= "BEAM" then
						local targetPos = projectile._targetable:GetRandomTargettingPoint(true)
						local dist = get_distance(mousePosPlayer, targetPos)
						if (not currentClosest and dist < 20) or (currentClosest and dist < 20 and dist < currentClosest.dist) then
							currentClosest = {target = projectile, dist = dist}
						end
					end
				end
				for drone in vter(spaceManager.drones) do
					if checkValidTarget(drone._targetable, currentTurret.defence_type, shipManager) and not drone.bDead then
						local targetPos = drone._targetable:GetRandomTargettingPoint(true)
						local dist = get_distance(mousePosPlayer, targetPos)
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
		if targetButton.bHover and targetButton.bActive then
			local shipManager = Hyperspace.ships.player
			systemBox.pSystem.table.currentTarget = nil
			systemBox.pSystem.table.currentTargetTemp = nil
			systemBox.pSystem.table.currentlyTargetted = false
			systemBox.pSystem.table.currentlyTargetting = true
			Hyperspace.Mouse.validPointer = cursorValid
			Hyperspace.Mouse.invalidPointer = cursorValid2
		end
		local offenseButton = systemBox.table.offenseButton
		if offenseButton.bHover and offenseButton.bActive then
			local shipManager = Hyperspace.ships.player
			systemBox.pSystem.table.currentTarget = nil
			systemBox.pSystem.table.currentlyTargetted = false
			systemBox.pSystem.table.currentTargetTemp = nil
			Hyperspace.playerVariables[shipId..Hyperspace.ShipSystem.SystemIdToName(systemBox.pSystem.iSystemType)..systemStateVarName] = 0
		end
		local defenceButton = systemBox.table.defenceButton
		if defenceButton.bHover and defenceButton.bActive then
			local shipManager = Hyperspace.ships.player
			systemBox.pSystem.table.currentTarget = nil
			systemBox.pSystem.table.currentlyTargetted = false
			systemBox.pSystem.table.currentTargetTemp = nil
			Hyperspace.playerVariables[shipId..Hyperspace.ShipSystem.SystemIdToName(systemBox.pSystem.iSystemType)..systemStateVarName] = 1
		end
	end
	return Defines.Chain.CONTINUE
end
script.on_internal_event(Defines.InternalEvents.SYSTEM_BOX_MOUSE_CLICK, system_click)

script.on_internal_event(Defines.InternalEvents.ON_MOUSE_R_BUTTON_DOWN, function(x,y) 
	local shipManager = Hyperspace.ships.player
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
			if system.table.currentlyTargetting then
				for room in vter(ship.vRoomList) do
					if room.iRoomId == combatControl.selectedRoom then
						Graphics.CSurface.GL_RenderPrimitive(room.highlightPrimitive) -- highlight the room
						Graphics.CSurface.GL_RenderPrimitive(room.highlightPrimitive2)
					end
				end
			elseif system.table.currentTarget and Hyperspace.playerVariables[math.floor(otherManager.iShipId)..sysName..systemStateVarName] == 0 and not system.table.currentlyTargetted then
				local targetPos = shipManager:GetRoomCenter(system.table.currentTarget)
				Graphics.CSurface.GL_PushMatrix()
				Graphics.CSurface.GL_Translate(targetPos.x, targetPos.y, 0)
				Graphics.CSurface.GL_RenderPrimitive(targetingImage.full)
				Graphics.CSurface.GL_PopMatrix()
			elseif system.table.currentTargetTemp and Hyperspace.playerVariables[math.floor(otherManager.iShipId)..sysName..systemStateVarName] == 0 and not system.table.currentlyTargetted then
				local targetPos = shipManager:GetRoomCenter(system.table.currentTargetTemp)
				Graphics.CSurface.GL_PushMatrix()
				Graphics.CSurface.GL_Translate(targetPos.x, targetPos.y, 0)
				Graphics.CSurface.GL_RenderPrimitive(targetingImage.temp)
				Graphics.CSurface.GL_PopMatrix()
			end
		end
		
	end
end)

script.on_render_event(Defines.RenderEvents.SHIP, function() end, function(ship)
	if ship.iShipId == 1 then return end
	local shipManager = Hyperspace.ships(ship.iShipId)
	local combatControl = Hyperspace.App.gui.combatControl
	for _, sysName in ipairs(systemNameList) do
		if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(sysName)) then
			local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(sysName))
			local currentTurret = turrets[ turretBlueprintsList[ Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemBlueprintVarName] ] ]
			local spaceManager = Hyperspace.App.world.space
			if system.table.currentlyTargetting then
				local mousePosPlayer = worldToPlayerLocation(Hyperspace.Mouse.position)
				local currentClosest = nil
				for projectile in vter(spaceManager.projectiles) do
					local blueprint = Hyperspace.Blueprints:GetWeaponBlueprint(projectile.extend.name)
					if checkValidTarget(projectile._targetable, currentTurret.defence_type, shipManager) and not projectile.missed and not projectile.passedTarget and blueprint.typeName ~= "BEAM" then
						local targetPos = projectile._targetable:GetRandomTargettingPoint(true)
						local dist = get_distance(mousePosPlayer, targetPos)
						if (not currentClosest and dist < 20) or (currentClosest and dist < 20 and dist < currentClosest.dist) then
							currentClosest = {target = projectile._targetable, dist = dist}
						end
					end
				end
				for drone in vter(spaceManager.drones) do
					if checkValidTarget(drone._targetable, currentTurret.defence_type, shipManager) and not drone.bDead then
						local targetPos = drone._targetable:GetRandomTargettingPoint(true)
						local dist = get_distance(mousePosPlayer, targetPos)
						if (not currentClosest and dist < 20) or (currentClosest and dist < 20 and dist < currentClosest.dist) then
							currentClosest = {target = drone._targetable, dist = dist}
						end
					end
				end
				if currentClosest then
					local targetPos = currentClosest.target:GetRandomTargettingPoint(true)
					Graphics.CSurface.GL_PushMatrix()
					Graphics.CSurface.GL_Translate(targetPos.x, targetPos.y, 0)
					Graphics.CSurface.GL_RenderPrimitive(targetingImage.hover)
					Graphics.CSurface.GL_PopMatrix()
				end
			elseif system.table.currentTarget and (Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemStateVarName] == 1 or system.table.currentlyTargetted) then
				for projectile in vter(spaceManager.projectiles) do
					if projectile._targetable:GetSelfId() == system.table.currentTarget._targetable:GetSelfId() then
						local targetPos = system.table.currentTarget._targetable:GetRandomTargettingPoint(true)
						Graphics.CSurface.GL_PushMatrix()
						Graphics.CSurface.GL_Translate(targetPos.x, targetPos.y, 0)
						Graphics.CSurface.GL_RenderPrimitive(targetingImage.full)
						Graphics.CSurface.GL_PopMatrix()
					end
				end
				for drone in vter(spaceManager.drones) do
					if drone._targetable:GetSelfId() == system.table.currentTarget._targetable:GetSelfId() then
						local targetPos = system.table.currentTarget._targetable:GetRandomTargettingPoint(true)
						Graphics.CSurface.GL_PushMatrix()
						Graphics.CSurface.GL_Translate(targetPos.x, targetPos.y, 0)
						Graphics.CSurface.GL_RenderPrimitive(targetingImage.full)
						Graphics.CSurface.GL_PopMatrix()
					end
				end
			elseif system.table.currentTargetTemp and system.table.currentlyTargetted then
				for projectile in vter(spaceManager.projectiles) do
					if projectile._targetable:GetSelfId() == system.table.currentTargetTemp._targetable:GetSelfId() then
						local targetPos = system.table.currentTargetTemp._targetable:GetRandomTargettingPoint(true)
						Graphics.CSurface.GL_PushMatrix()
						Graphics.CSurface.GL_Translate(targetPos.x, targetPos.y, 0)
						Graphics.CSurface.GL_RenderPrimitive(targetingImage.temp)
						Graphics.CSurface.GL_PopMatrix()
					end
				end
				for drone in vter(spaceManager.drones) do
					if drone._targetable:GetSelfId() == system.table.currentTargetTemp._targetable:GetSelfId() then
						local targetPos = system.table.currentTargetTemp._targetable:GetRandomTargettingPoint(true)
						Graphics.CSurface.GL_PushMatrix()
						Graphics.CSurface.GL_Translate(targetPos.x, targetPos.y, 0)
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

local targetButtonOn2
local buttonBase
local buttonBaseOff
local chargeBar
local chargeIcon
script.on_init(function()
	targetButtonOn2 = Hyperspace.Resources:CreateImagePrimitiveString("systemUI/button_og_turret_target_on_2.png", UIOffset_x+9, UIOffset_y+35, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
	buttonBase = Hyperspace.Resources:CreateImagePrimitiveString("systemUI/button_og_turret_base.png", UIOffset_x, UIOffset_y, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
	buttonBaseOff = Hyperspace.Resources:CreateImagePrimitiveString("systemUI/button_og_turret_base_off.png", UIOffset_x, UIOffset_y, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
	chargeBar = {
		x = 10,
		y = 32,
		mid = Hyperspace.Resources:CreateImagePrimitiveString("systemUI/button_og_turret_charge_stack.png", UIOffset_x, UIOffset_y, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false),
		top = Hyperspace.Resources:CreateImagePrimitiveString("systemUI/button_og_turret_charge_stack_top.png", UIOffset_x, UIOffset_y, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false),
	}
	chargeIcon = {
		x = 21,
		y = 32,
		back = Hyperspace.Resources:CreateImagePrimitiveString("systemUI/button_og_turret_charge_back.png", UIOffset_x, UIOffset_y, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false),
		off = Hyperspace.Resources:CreateImagePrimitiveString("systemUI/button_og_turret_charge_off.png", UIOffset_x, UIOffset_y, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false),
		on = Hyperspace.Resources:CreateImagePrimitiveString("systemUI/button_og_turret_charge_on.png", UIOffset_x, UIOffset_y, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false),
	}
end)

local function system_render(systemBox, ignoreStatus)
	local systemId = Hyperspace.ShipSystem.SystemIdToName(systemBox.pSystem.iSystemType)
	local shipId = (systemBox.bPlayerUI and 0) or 1
	--print(tostring(systemBox.bPlayerUI).." "..shipId)
	if is_system(systemBox) and Hyperspace.playerVariables[shipId..systemId..systemBlueprintVarName] >= 0 then
		local shipManager = Hyperspace.ships.player
		local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(systemId))

		local targetButton = systemBox.table.targetButton
		targetButton.bActive = system_ready(systemBox.pSystem) and not systemBox.pSystem.table.currentlyTargetting
		local offenseButton = systemBox.table.offenseButton
		offenseButton.bActive = system_ready(systemBox.pSystem) and Hyperspace.playerVariables[shipId..systemId..systemStateVarName] ~= 0
		local defenceButton = systemBox.table.defenceButton
		defenceButton.bActive = system_ready(systemBox.pSystem) and Hyperspace.playerVariables[shipId..systemId..systemStateVarName] ~= 1

		local currentTurret = turrets[ turretBlueprintsList[ Hyperspace.playerVariables[shipId..systemId..systemBlueprintVarName] ] ]
		local maxCharges = currentTurret.charges
		--print(turretBlueprintsList[ Hyperspace.playerVariables[shipId..systemId..systemBlueprintVarName] ].." "..tostring(shipId..systemId..systemBlueprintVarName))
		local charges = Hyperspace.playerVariables[shipId..systemId..systemChargesVarName]
		local chargeTime = currentTurret.charge_time[system:GetEffectivePower()]/(1 + system.iActiveManned * 0.1)
		local chargeTimeDisplay = math.ceil(chargeTime)
		--print(currentTurret.charge_time[system:GetEffectivePower()].." "..chargeTime.." "..system.iActiveManned)
		local time = math.floor(0.5 + system.table.chargeTime * chargeTimeDisplay * 2)

		Graphics.CSurface.GL_RenderPrimitive(buttonBase)

		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(chargeBar.x, chargeBar.y, 0)

		for i = 1, 2 * chargeTimeDisplay + 2 do
			Graphics.CSurface.GL_PushMatrix()
			Graphics.CSurface.GL_Translate(0, - i, 0)
			Graphics.CSurface.GL_RenderPrimitive(chargeBar.mid)
			Graphics.CSurface.GL_PopMatrix()
		end
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(0, - 2 * chargeTimeDisplay - 3, 0)
		Graphics.CSurface.GL_RenderPrimitive(chargeBar.top)
		Graphics.CSurface.GL_PopMatrix()

		Graphics.CSurface.GL_DrawRect(
			UIOffset_x + 2, 
			UIOffset_y - 1 - time, 
			5, 
			time, 
			Graphics.GL_Color(1, 1, 1, 1)
			)
		if maxCharges == charges then
			Graphics.CSurface.GL_DrawRect(
			UIOffset_x + 2, 
			UIOffset_y - 1 - chargeTimeDisplay * 2, 
			5, 
			chargeTimeDisplay * 2, 
			Graphics.GL_Color(1, 1, 1, 1)
			)
		end
		Graphics.CSurface.GL_PopMatrix()

		if maxCharges > 1 then
			Graphics.CSurface.GL_PushMatrix()
			Graphics.CSurface.GL_Translate(chargeIcon.x, chargeIcon.y, 0)
			
			for i = 1, maxCharges do
				Graphics.CSurface.GL_PushMatrix()
				Graphics.CSurface.GL_Translate(0, i * -8, 0)
				Graphics.CSurface.GL_RenderPrimitive(chargeIcon.back)
				Graphics.CSurface.GL_PopMatrix()
			end

			for i = 1, charges do
				Graphics.CSurface.GL_PushMatrix()
				Graphics.CSurface.GL_Translate(0, i * -8, 0)
				Graphics.CSurface.GL_RenderPrimitive(chargeIcon.on)
				Graphics.CSurface.GL_PopMatrix()
			end
			Graphics.CSurface.GL_PopMatrix()
		end

		systemBox.table.targetButton:OnRender()
		if not systemBox.table.targetButton.bHover and (systemBox.pSystem.table.currentlyTargetted or ((systemBox.pSystem.table.currentTarget or systemBox.pSystem.table.currentTargetTemp) and Hyperspace.playerVariables[shipId..systemId..systemStateVarName] == 0)) then
			Graphics.CSurface.GL_RenderPrimitive(targetButtonOn2)
		end

		if Hyperspace.playerVariables[shipId..systemId..systemStateVarName] == 1 then
			systemBox.table.offenseButton:OnRender()
		elseif Hyperspace.playerVariables[shipId..systemId..systemStateVarName] == 0 then
			systemBox.table.defenceButton:OnRender()
		end
		local offsetText = math.max(2 * chargeTimeDisplay + 3, maxCharges * 8)
		if maxCharges <= 1 then
			offsetText = 2 * chargeTimeDisplay + 2
		end

		local blueprint = Hyperspace.Blueprints:GetWeaponBlueprint(turretBlueprintsList[ Hyperspace.playerVariables[shipId..systemId..systemBlueprintVarName] ])
		Graphics.freetype.easy_printNewlinesCentered(51, UIOffset_x + 20, UIOffset_y + 12 - offsetText, 80, blueprint.desc.shortTitle:GetText().."\n"..tostring(math.floor(0.5 + system.table.chargeTime * chargeTime * 10)/10).."/"..tostring(math.floor(0.5 + chargeTime * 10)/10))
		--Graphics.CSurface.GL_DrawCircle(UIOffset_x + 20, UIOffset_y - 3, 1, Graphics.GL_Color(1, 0, 0, 1))
	elseif is_system(systemBox) then
		Graphics.CSurface.GL_RenderPrimitive(buttonBaseOff)
	end
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
			else
				Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName] = 0
			end
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
			if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(sysName)) then
				local id, i = findStartingTurret(shipManager, sysName)
				Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemBlueprintVarName] = i
			end
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
		elseif system.table.currentTarget.BlowUp then
			system.table.currentTarget:BlowUp(false)
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
	if manningCrew then
		manningCrew:IncreaseSkill(3)
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
			userdata_table(projectile, "mods.og").homing = {target = system.table.currentTarget, turn_rate = currentTurret.homing}
		end
	end
	if (not offensive) and (currentShot.fire_delay > 0 or Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName] == 1) then
		system.table.currentTarget = nil
		system.table.currentlyTargetted = false
	end
	if shipManager:HasAugmentation("UPG_OG_TURRET_SPEED") > 0 then
		projectile.speed_magnitude = projectile.speed_magnitude * 1.5
	end
	currentTurret.image:Start(true)
	if currentTurret.image.info.numFrames > 1 then
		if currentTurret.multi_anim then
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
			local lastShot = (Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName]) % #currentTurret.fire_points + 1
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
			local chargeTime = currentTurret.charge_time[system:GetEffectivePower()]/(1 + system.iActiveManned * 0.1)
			
			local otherManager = Hyperspace.ships(1 - shipManager.iShipId)
			system.table.firingTime = system.table.firingTime - time_increment(true)
			if Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName] > currentTurret.charges then
				Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName] = currentTurret.charges
			else
				if system_ready(system) and Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName] < currentTurret.charges and (not currentTurret.ammo_consumption or shipManager:GetMissileCount() > system.table.ammo_consumed + currentTurret.ammo_consumption * Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName]) then
					system.table.chargeTime = system.table.chargeTime + time_increment(true)/chargeTime
					if system.table.chargeTime >= 1 then
						local maxWithAmmo = ((not currentTurret.ammo_consumption) and math.huge) or ((shipManager:GetMissileCount() - system.table.ammo_consumed - currentTurret.ammo_consumption * Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName])/currentTurret.ammo_consumption) 
						Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName] = math.min(Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName] + maxWithAmmo , currentTurret.charges, Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName] + currentTurret.charges_per_charge)
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
				speed = speed * 1.5
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
				local notCloaked = not shipManager.ship.bCloaked

				local aimedAheadPlayer = shipManager.iShipId == 0 and math.abs(angle_diff(system.table.currentAimingAngle, 0)) < (currentTurret.aim_cone or 1)
				local aimedAheadEnemy = shipManager.iShipId == 1 and math.abs(angle_diff(system.table.currentAimingAngle, -90)) < (currentTurret.aim_cone or 1)
				local shouldFire = hasTarget and readyFire and otherShipTargetable and notCloaked
				if (aimedAheadPlayer or aimedAheadEnemy) and shouldFire then
					local roomPosition = (system.table.currentTarget and otherManager:GetRoomCenter(system.table.currentTarget)) or otherManager:GetRandomRoomCenter()
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
					local tryRetarget = Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName] <= 0 and not system.table.currentlyTargetted
					if targetDead or targetInvalid or tryRetarget or projectileInactive then
						system.table.currentTarget = nil
						system.table.currentlyTargetted = false
					end
				end
				--Find New Target
				if not system.table.currentTarget then
					system.table.currentTarget = findTurretTarget(system, currentTurret, shipManager, pos, speed)
				end
				--Targeting Logic
				if system.table.currentTarget then
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
					local notCloaked = not shipManager.ship.bCloaked
					if math.abs(angle_diff(system.table.currentAimingAngle, target_angle)) < (currentTurret.aim_cone or 0.5) and system.table.firingTime <= 0 and Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName] > 0 and notCloaked then
						fireTurret(system, currentTurret, shipManager, otherManager, sysName, blueprint, pos, false, Hyperspace.Pointf(int_point.x, int_point.y), manningCrew)
					end
				else -- if no possible target
					if math.abs(angle_diff(system.table.currentAimingAngle, turretRestAngle)) > 0.01 then
						system.table.currentAimingAngle = move_angle_to(system.table.currentAimingAngle, turretRestAngle, currentMaxRotationSpeed * time_increment(true))
					end
				end
			end
			currentTurret.image:Update()
			if (currentTurret.image:Done() and currentTurret.image.currentFrame ~= 0) or (currentTurret.multi_anim and currentTurret.image.currentFrame > currentTurret.multi_anim.frames * lastShot) then
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
		local playerFired = projectile.currentSpace == 0 and projectile.position.x > shipBound_x
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

local function renderTurret(shipManager, ship, spaceManager, shipGraph, sysName)
	--print("ship:"..shipManager.iShipId.." jump first:"..shipManager.jump_timer.first.." second:"..shipManager.jump_timer.second.." bJumping"..tostring(shipManager.bJumping))
	if shipManager.bJumping and shipManager.iShipId == 1 then return end
	local currentTurret = nil
	local overRideTurretAngle = false
	if Hyperspace.App.menu.shipBuilder.bOpen then
		local id, i = findStartingTurret(shipManager, sysName)
		if id then currentTurret = turrets[id] end
		overRideTurretAngle = true
	elseif Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemBlueprintVarName] >= 0 then
		currentTurret = turrets[ turretBlueprintsList[ Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemBlueprintVarName] ] ]
	end
	if currentTurret then
		local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(sysName))
		if not currentTurret then return end

		local turretLoc = turret_location[ship.shipName] and turret_location[ship.shipName][sysName] or {x = 0, y = 0}
		local shipCorner = {x = ship.shipImage.x + shipGraph.shipBox.x, y = ship.shipImage.y + shipGraph.shipBox.y}
		local angleSet = (overRideTurretAngle and 90 * turretLoc.direction) or (system.table.currentAimingAngle or 0)

		local charges = Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChargesVarName]
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(shipCorner.x + turretLoc.x, shipCorner.y + turretLoc.y, 0)
		Graphics.CSurface.GL_Rotate(angleSet, 0, 0, 1)
		currentTurret.image:OnRender(1, Graphics.GL_Color(1,1,1,1), false)
		if currentTurret.charge_image then
			Graphics.CSurface.GL_RenderPrimitiveWithAlpha(currentTurret.charge_image, system.table.chargeTime or 1)
		end
		if currentTurret.glow and charges > 0 then
			currentTurret.glow:SetCurrentFrame(charges - 1)
			currentTurret.glow:OnRender(1, Graphics.GL_Color(1,1,1,1), false)
		end
		Graphics.CSurface.GL_PopMatrix()
	end
end

script.on_render_event(Defines.RenderEvents.SHIP_MANAGER, function(shipManager) end, function(shipManager) 
	--local shipManager = Hyperspace.ships(ship.iShipId)
	--log("START RENDER SHIP_MANAGER TURRETS"..shipManager.iShipId)
	local ship = shipManager.ship
	local spaceManager = Hyperspace.App.world.space
	local shipGraph = Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId)
	for _, sysName in ipairs(systemNameList) do
		if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(sysName)) and microTurrets[sysName] then
			renderTurret(shipManager, ship, spaceManager, shipGraph, sysName)		
		end
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
	mods.multiverse.systemIcons[Hyperspace.ShipSystem.NameToSystemId(sysName)] = mods.multiverse.register_system_icon(sysName)
end
