
local turretBlueprintsList = mods.og.turretBlueprintsList 
turretBlueprintsList[0] = "OG_EMPTY_TURRET"
table.insert(turretBlueprintsList, "OG_TURRET_LASER_1")
table.insert(turretBlueprintsList, "OG_TURRET_LASER_RUSTY_1")
table.insert(turretBlueprintsList, "OG_TURRET_LASER_2")
table.insert(turretBlueprintsList, "OG_TURRET_LASER_BOSS_LIGHT")
table.insert(turretBlueprintsList, "OG_TURRET_LASER_BOSS_LIGHT_CHAOS")
table.insert(turretBlueprintsList, "OG_TURRET_LASER_ANCIENT")
table.insert(turretBlueprintsList, "OG_TURRET_LASER_CEL_1")
table.insert(turretBlueprintsList, "OG_TURRET_LASER_ZENITH")
table.insert(turretBlueprintsList, "OG_TURRET_LASER_BIO")
table.insert(turretBlueprintsList, "OG_TURRET_LASER_PIERCE")
table.insert(turretBlueprintsList, "OG_TURRET_LASER_HULL")
table.insert(turretBlueprintsList, "OG_TURRET_LASER_CHAINGUN")
table.insert(turretBlueprintsList, "OG_TURRET_LASER_PARTICLE")
table.insert(turretBlueprintsList, "OG_TURRET_LASER_GATLING")
table.insert(turretBlueprintsList, "OG_TURRET_LASER_RIFTWAKER")
table.insert(turretBlueprintsList, "OG_TURRET_ION_1")
table.insert(turretBlueprintsList, "OG_TURRET_ION_2")
table.insert(turretBlueprintsList, "OG_TURRET_ENERGY_1")
table.insert(turretBlueprintsList, "OG_TURRET_CRYSTAL_1")
table.insert(turretBlueprintsList, "OG_TURRET_CRYSTAL_1_ELITE")
table.insert(turretBlueprintsList, "OG_TURRET_MISSILE_1")
table.insert(turretBlueprintsList, "OG_TURRET_MISSILE_2")
table.insert(turretBlueprintsList, "OG_TURRET_KERNEL_HEAVY")
table.insert(turretBlueprintsList, "OG_TURRET_KERNEL_FIRE")
table.insert(turretBlueprintsList, "OG_TURRET_MISSILE_CLONE_CANNON")
table.insert(turretBlueprintsList, "OG_TURRET_FLAK_1")
table.insert(turretBlueprintsList, "OG_TURRET_FLAK_BIO")
table.insert(turretBlueprintsList, "OG_TURRET_FOCUS_1")
table.insert(turretBlueprintsList, "OG_TURRET_FOCUS_BIO")
table.insert(turretBlueprintsList, "OG_TURRET_FOCUS_CHAIN")
table.insert(turretBlueprintsList, "OG_TURRET_LASER_MINI_1")
table.insert(turretBlueprintsList, "OG_TURRET_LASER_RUSTY_MINI_1")
table.insert(turretBlueprintsList, "OG_TURRET_LASER_MINI_2")
table.insert(turretBlueprintsList, "OG_TURRET_ION_MINI_1")
table.insert(turretBlueprintsList, "OG_TURRET_FOCUS_MINI_1")
table.insert(turretBlueprintsList, "OG_TURRET_FLAK_MINI_1")
table.insert(turretBlueprintsList, "OG_TURRET_MISSILE_MINI_1")

table.insert(turretBlueprintsList, "OG_TURRET_LASER_DAWN")
table.insert(turretBlueprintsList, "OG_TURRET_ION_DAWN")
table.insert(turretBlueprintsList, "OG_TURRET_MISSILE_DAWN")
table.insert(turretBlueprintsList, "OG_TURRET_FLAK_DAWN")
table.insert(turretBlueprintsList, "OG_TURRET_FOCUS_DAWN")
table.insert(turretBlueprintsList, "OG_TURRET_LASER_MINI_DAWN_1")
table.insert(turretBlueprintsList, "OG_TURRET_LASER_MINI_DAWN_2")
table.insert(turretBlueprintsList, "OG_TURRET_FOCUS_MINI_DAWN")

--DARKEST DESIRE CROSSOVER
table.insert(turretBlueprintsList, "OG_TURRET_FOCUS_SOULPLAGUE")
table.insert(turretBlueprintsList, "OG_TURRET_MISSILE_FALSERADIANCE")
table.insert(turretBlueprintsList, "OG_TURRET_LASER_DARKNESS_MINI")

local defence_types = mods.og.defence_types
local chain_types = mods.og.chain_types

local turrets = mods.og.turrets
turrets["OG_EMPTY_TURRET"] = {
	image = "og_turret_laser_error",
	multi_anim = 3,
	glow = "og_turret_laser_1_glow",
	fire_points = {{x = -12, y = -42, fire_delay = 0.5}, {x = 12, y = -42, fire_delay = 0.5}},
	autofire = {
		offence = 2,
		defence = 2,
	},
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
	image = "og_turret_laser_1",
	multi_anim = 3,
	glow = "og_turret_laser_1_glow",
	fire_points = {{x = -12, y = -42, fire_delay = 0.5}, {x = 12, y = -42, fire_delay = 0.35}},
	autofire = {
		offence = 2,
		defence = 2,
	},
	defence_type = defence_types.PROJECTILES,
	blueprint_type = 1,
	blueprint = "OG_LASER_PROJECTILE_BASE",
	charges = 6,
	charges_per_charge = 2,
	rotation_speed = 180,
	charge_time = {[0] = 12, 12, 9, 7, 6, 5, 4, 3, 2.5},
}
turrets["OG_TURRET_LASER_RUSTY_1"] = {
	enemy_burst = 2,
	shot_radius = 42,
	image = "og_turret_laser_rusty_1",
	multi_anim = 3,
	glow = "og_turret_laser_1_glow",
	fire_points = {{x = -12, y = -42, fire_delay = 0.5}, {x = 12, y = -42, fire_delay = 0.35}},
	autofire = {
		offence = 2,
		defence = 2,
	},
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
	image = "og_turret_laser_2",
	glow = "og_turret_laser_2_glow",
	fire_points = {{x = 0, y = -60, fire_delay = 1}},
	defence_type = defence_types.DRONES,
	blueprint_type = 1,
	blueprint = "OG_LASER_PROJECTILE_HEAVY",
	charges = 3,
	charges_per_charge = 1,
	rotation_speed = 120,
	charge_time = {[0] = 9, 9, 7.5, 6, 5, 4.5, 4, 3.75, 3.5},
}
turrets["OG_TURRET_LASER_BOSS_LIGHT"] = {
	enemy_burst = 4,
	homing = 36,
	image = "og_turret_laser_boss_light",
	glow = "og_turret_laser_boss_light_glow",
	fire_points = {
		{x = 5, y = -32, fire_delay = 0.15}, {x = -5, y = -32, fire_delay = 0.15},
		{x = 10, y = -32, fire_delay = 0.15}, {x = -10, y = -32, fire_delay = 0.15}, 
		{x = 20, y = -32, fire_delay = 0.15}, {x = -20, y = -32, fire_delay = 0.15}, 
		{x = 15, y = -32, fire_delay = 0.15}, {x = -15, y = -32, fire_delay = 0.15}
	},
	defence_type = defence_types.PROJECTILES,
	blueprint_type = 1,
	blueprint = "OG_LASER_PROJECTILE_LIGHT",
	charges = 8,
	charges_per_charge = 2,
	rotation_speed = 360,
	charge_time = {[0] = 5, 5, 3.5, 2.5, 2, 1.75, 1.5, 1.25, 1},
}
turrets["OG_TURRET_LASER_BOSS_LIGHT_CHAOS"] = {
	enemy_burst = 4,
	homing = 36,
	image = "og_turret_laser_boss_light_chaos",
	glow = "og_turret_laser_boss_light_glow",
	fire_points = {
		{x = 5, y = -32, fire_delay = 0.15}, {x = -5, y = -32, fire_delay = 0.15},
		{x = 10, y = -32, fire_delay = 0.15}, {x = -10, y = -32, fire_delay = 0.15}, 
		{x = 20, y = -32, fire_delay = 0.15}, {x = -20, y = -32, fire_delay = 0.15}, 
		{x = 15, y = -32, fire_delay = 0.15}, {x = -15, y = -32, fire_delay = 0.15}
	},
	defence_type = defence_types.PROJECTILES_MISSILES,
	blueprint_type = 1,
	blueprint = "OG_LASER_PROJECTILE_LIGHT",
	charges = 8,
	charges_per_charge = 2,
	rotation_speed = 1800,
	charge_time = {[0] = 5, 5, 3.5, 2.5, 2, 1.75, 1.5, 1.25, 1},
}
turrets["OG_TURRET_LASER_ANCIENT"] = {
	enemy_burst = 3,
	image = "og_turret_laser_ancient",
	glow = "og_turret_laser_ancient_glow",
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_laser_ancient_charge.png", -74, -74, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 0, y = 0, fire_delay = 0.3}},
	autofire = {
		offence = 3, 
		defence = 3,
	},
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
	image = "og_turret_laser_cel_1",
	glow = "og_turret_laser_cel_1_glow",
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_laser_cel_1_charge.png", -13, -28, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 0, y = -40, fire_delay = 0.25}},
	defence_type = defence_types.ALL,
	blueprint_type = 1,
	blueprint = "OG_LASER_PROJECTILE_CEL",
	charges = 8,
	charges_per_charge = 4,
	rotation_speed = 240,
	charge_time = {[0] = 20, 20, 17, 14, 12, 10, 8, 7, 6},
}
turrets["OG_TURRET_LASER_ZENITH"] = {
	enemy_burst = 1,
	image = "og_turret_laser_zenith",
	glow = "og_turret_laser_zenith_glow",
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_laser_zenith_charge.png", -60, -60, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 0, y = -50, fire_delay = 0.5}},
	defence_type = defence_types.ALL,
	blueprint_type = 1,
	blueprint = "OG_LASER_PROJECTILE_ZENITH",
	charges = 3,
	charges_per_charge = 1,
	rotation_speed = 180,
	charge_time = {[0] = 14, 14, 12, 9, 7, 6, 5, 4, 3},
}
turrets["OG_TURRET_LASER_BIO"] = {
	enemy_burst = 1,
	image = "og_turret_laser_rad",
	glow = "og_turret_laser_rad_glow",
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_laser_rad_charge.png", -39, -39, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 0, y = -30, fire_delay = 0.25}},
	defence_type = defence_types.PROJECTILES,
	blueprint_type = 1,
	blueprint = "OG_LASER_PROJECTILE_BIO",
	charges = 3,
	charges_per_charge = 1,
	rotation_speed = 270,
	charge_time = {[0] = 5, 5, 3.5, 2.5, 2, 1.75, 1.5, 1.25, 1},
}
turrets["OG_TURRET_LASER_PIERCE"] = {
	enemy_burst = 2,
	stealth = true,
	image = "og_turret_laser_pierce",
	glow = "og_turret_laser_pierce_glow",
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_laser_pierce_charge.png", -65, -65, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 0, y = -65, fire_delay = 0.45}},
	autofire = {
		offence = true, 
		defence = true,
	},
	defence_type = defence_types.DRONES,
	blueprint_type = 1,
	blueprint = "OG_LASER_PROJECTILE_PIERCE",
	charges = 4,
	charges_per_charge = 2,
	rotation_speed = 180,
	charge_time = {[0] = 14, 14, 12, 9, 7, 6, 5, 4, 3},
}
turrets["OG_TURRET_LASER_HULL"] = {
	enemy_burst = 3,
	image = "og_turret_laser_hull",
	glow = "og_turret_laser_hull_glow",
	fire_points = {{x = 5, y = -20, fire_delay = 0.45}},
	defence_type = defence_types.MISSILES,
	blueprint_type = 1,
	blueprint = "OG_LASER_PROJECTILE_HULL",
	charges = 5,
	charges_per_charge = 1,
	rotation_speed = 180,
	charge_time = {[0] = 8, 8, 6.5, 5, 4, 3.5, 3, 2.75, 2.5},
}
turrets["OG_TURRET_LASER_CHAINGUN"] = {
	enemy_burst = 1,
	image = "og_turret_laser_chaingun",
	glow = "og_turret_laser_chaingun_glow",
	chain = {
		image = Hyperspace.Animations:GetAnimation("og_turret_laser_chaingun_chain"),
		type = chain_types.cooldown,
		amount = 0.2,
		count = 4,
	},
	fire_points = {{x = 0, y = -50, fire_delay = 0.325}},
	defence_type = defence_types.PROJECTILES_MISSILES,
	blueprint_type = 1,
	blueprint = "OG_LASER_PROJECTILE_BASE",
	charges = 3,
	charges_per_charge = 1,
	rotation_speed = 180,
	charge_time = {[0] = 14, 14, 12, 9, 7, 6, 5, 4, 3},
}
turrets["OG_TURRET_LASER_PARTICLE"] = {
	enemy_burst = 3,
	shot_radius = 32,
	image = "og_turret_laser_particle",
	glow = "og_turret_laser_particle_glow",
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_laser_particle_charge.png", -47, -47, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 5, y = -42, fire_delay = 0.4},{x = 5, y = -42, fire_delay = 0, auto_burst = true},{x = 5, y = -42, fire_delay = 0, auto_burst = true}},
	autofire = {
		offence = 3, 
		defence = 3,
	},
	defence_type = defence_types.PROJECTILES,
	blueprint_type = 1,
	blueprint = "OG_LASER_PROJECTILE_PARTICLE",
	charges = 6,
	charges_per_charge = 3,
	rotation_speed = 180,
	charge_time = {[0] = 14, 14, 12, 9, 7, 6, 5, 4, 3},
}
turrets["OG_TURRET_LASER_GATLING"] = {
	enemy_burst = 1,
	shot_radius = 90,
	image = "og_turret_laser_gatling",
	glow = "og_turret_laser_gatling_glow",
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_laser_gatling_charge.png", -90, -90, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	chain = {
		type = chain_types.cooldown,
		amount = 0.975,
		count = 1,
	},
	fire_points = {{x = 0, y = -90, fire_delay = 0.2}, {x = 0, y = -90, fire_delay = 0.0, auto_burst = true}},
	autofire = {
		offence = true, 
		defence = true,
	},
	defence_type = defence_types.PROJECTILES_MISSILES,
	blueprint_type = 1,
	blueprint = "OG_LASER_PROJECTILE_LIGHT",
	charges = 2,
	charges_per_charge = 2,
	rotation_speed = 180,
	charge_time = {[0] = 38, 38, 34, 30, 28, 26, 24, 22, 20},
}
turrets["OG_TURRET_LASER_RIFTWAKER"] = {
	enemy_burst = 1,
	image = "og_turret_laser_riftwaker",
	glow = "og_turret_laser_riftwaker_glow",
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_laser_riftwaker_charge.png", -90, -90, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	chain = {
		type = chain_types.cooldown,
		amount = 0.99,
		count = 1,
	},
	fire_points = {{x = 0, y = -90, fire_delay = 0.2}},
	defence_type = defence_types.PROJECTILES_MISSILES,
	blueprint_type = 1,
	blueprint = "OG_LASER_PROJECTILE_PIERCE",
	charges = 1,
	charges_per_charge = 1,
	rotation_speed = 180,
	charge_time = {[0] = 28, 28, 24, 20, 18, 16, 14, 12, 10},
}
turrets["OG_TURRET_ION_1"] = {
	enemy_burst = 1,
	image = "og_turret_ion_1",
	glow = "og_turret_ion_1_glow",
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
	image = "og_turret_ion_2",
	glow = "og_turret_ion_2_glow",
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_ion_2_charge.png", -30, -11, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 5, y = -32, fire_delay = 0.5}, {x = -5, y = -32, fire_delay = 0.25}},
	defence_type = defence_types.DRONES,
	blueprint_type = 1,
	blueprint = "OG_ION_PROJECTILE_FIRE",
	charges = 4,
	charges_per_charge = 2,
	rotation_speed = 180,
	charge_time = {[0] = 17, 17, 14, 11, 9, 7, 5, 5, 4},
}
turrets["OG_TURRET_ENERGY_1"] = {
	enemy_burst = 3,
	image = "og_turret_energy_1",
	glow = "og_turret_energy_1_glow",
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_energy_1_charge.png", -50, -50, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 0, y = -42, fire_delay = 0.45}},
	defence_type = defence_types.DRONES_PROJECTILES,
	blueprint_type = 1,
	blueprint = "OG_ION_PROJECTILE_ENERGY",
	charges = 5,
	charges_per_charge = 5,
	rotation_speed = 180,
	charge_time = {[0] = 20, 20, 17, 14, 12, 10, 8.5, 7, 6},
	enemy_charge_time = {[0] = 24, 24, 20, 17, 14, 12, 10, 8.5, 7},
}
turrets["OG_TURRET_CRYSTAL_1"] = {
	enemy_burst = 2,
	hide_glow_firing = true,
	image = "og_turret_crystal_1",
	glow = "og_turret_crystal_1_glow",
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_crystal_1_charge.png", -39, -39, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 0, y = -39, fire_delay = 0.35}},
	defence_type = defence_types.MISSILES,
	blueprint_type = 2,
	blueprint = "OG_CRYSTAL_PROJECTILE_BASE",
	charges = 4,
	charges_per_charge = 2,
	rotation_speed = 120,
	charge_time = {[0] = 10, 10, 8.5, 7, 6, 5.5, 5, 4.75, 4.5},
}
turrets["OG_TURRET_CRYSTAL_1_ELITE"] = {
	enemy_burst = 2,
	hide_glow_firing = true,
	image = "og_turret_crystal_1_elite",
	glow = "og_turret_crystal_1_glow",
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_crystal_1_charge.png", -39, -39, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 0, y = -35, fire_delay = 0.35}},
	defence_type = defence_types.DRONES_MISSILES,
	blueprint_type = 2,
	blueprint = "OG_CRYSTAL_PROJECTILE_ELITE",
	charges = 4,
	charges_per_charge = 2,
	rotation_speed = 120,
	charge_time = {[0] = 10, 10, 8.5, 7, 6, 5.5, 5, 4.75, 4.5},
}
turrets["OG_TURRET_MISSILE_1"] = {
	enemy_burst = 3,
	homing = 720,
	intercept_amount = 1,
	aim_cone = 45,
	image = "og_turret_missile_1",
	glow = "og_turret_missile_1_glow",
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
	intercept_amount = 1,
	aim_cone = 30,
	image = "og_turret_missile_2",
	glow = "og_turret_missile_2_glow",
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_missile_2_charge.png", -6, -4, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 26, y = -48, fire_delay = 0.5}, {x = 15, y = -48, fire_delay = 0.5}, {x = -15, y = -48, fire_delay = 0.5}, {x = -26, y = -48, fire_delay = 0.5}},
	defence_type = defence_types.DRONES_MISSILES,
	blueprint_type = 2,
	ammo_consumption = 1,
	blueprint = "OG_MISSILE_PROJECTILE_HEAVY",
	charges = 4,
	charges_per_charge = 2,
	rotation_speed = 120,
	charge_time = {[0] = 20, 20, 17, 14, 12, 10, 8.5, 7, 6},
	enemy_charge_time = {[0] = 24, 24, 20, 17, 14, 12, 10, 8.5, 7},
}
turrets["OG_TURRET_KERNEL_HEAVY"] = {
	enemy_burst = 1,
	image = "og_turret_kernel_heavy",
	glow = "og_turret_kernel_heavy_glow",
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_kernel_heavy_charge.png", -35, -35, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 0, y = -30, fire_delay = 0.4}},
	defence_type = defence_types.DRONES,
	blueprint_type = 2,
	ammo_consumption = 0.5,
	blueprint = "OG_KERNEL_PROJECTILE_HEAVY",
	charges = 3,
	charges_per_charge = 1,
	rotation_speed = 180,
	charge_time = {[0] = 20, 20, 17, 14, 12, 10, 8.5, 7, 6},
}
turrets["OG_TURRET_KERNEL_FIRE"] = {
	enemy_burst = 1,
	image = "og_turret_kernel_fire",
	glow = "og_turret_kernel_heavy_glow",
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_kernel_fire_charge.png", -35, -35, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 0, y = -30, fire_delay = 0.4}},
	defence_type = defence_types.DRONES_MISSILES,
	blueprint_type = 2,
	ammo_consumption = 0.5,
	blueprint = "OG_KERNEL_PROJECTILE_FIRE",
	charges = 3,
	charges_per_charge = 1,
	rotation_speed = 180,
	charge_time = {[0] = 17, 17, 14, 11, 9, 7, 5, 5, 4},
}
turrets["OG_TURRET_MISSILE_CLONE_CANNON"] = {
	enemy_burst = 1,
	shot_radius = 30,
	aim_cone = 1,
	image = "og_turret_missile_clone_cannon",
	glow = "og_turret_missile_clone_cannon_glow",
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_missile_clone_cannon_charge.png", -40, -40, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 0, y = -40, fire_delay = 0.4}},
	defence_type = defence_types.DRONES_MISSILES,
	blueprint_type = 1,
	blueprint = "OG_MISSILE_PROJECTILE_CLONE",
	charges = 2,
	charges_per_charge = 1,
	rotation_speed = 120,
	charge_time = {[0] = 12, 12, 10, 8, 6, 5, 4, 3.5, 3},
}
turrets["OG_TURRET_FLAK_1"] = {
	enemy_burst = 3,
	shot_radius = 45,
	aim_cone = 1,
	image = "og_turret_flak_1",
	glow = "og_turret_flak_1_glow",
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_flak_1_charge.png", -33, -33, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 0, y = -30, fire_delay = 0.5}, {x = 0, y = -30, fire_delay = 0, auto_burst = true}, {x = 0, y = -30, fire_delay = 0, auto_burst = true}},
	autofire = {
		offence = 3, 
		defence = 3,
	},
	defence_type = defence_types.ALL,
	blueprint_type = 1,
	blueprint = "OG_FLAK_PROJECTILE",
	charges = 9,
	charges_per_charge = 3,
	rotation_speed = 180,
	charge_time = {[0] = 14, 14, 12, 9, 7, 6, 5, 4, 3},
}
turrets["OG_TURRET_FLAK_BIO"] = {
	enemy_burst = 3,
	shot_radius = 55,
	aim_cone = 1,
	image = "og_turret_flak_rad",
	glow = "og_turret_flak_rad_glow",
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_flak_rad_charge.png", -35, -35, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 0, y = -30, fire_delay = 0.5}, {x = 0, y = -30, fire_delay = 0, auto_burst = true}, {x = 0, y = -30, fire_delay = 0, auto_burst = true}, {x = 0, y = -30, fire_delay = 0, auto_burst = true}},
	autofire = {
		offence = 4, 
		defence = 4,
	},
	defence_type = defence_types.ALL,
	blueprint_type = 1,
	blueprint = "OG_FLAK_PROJECTILE_BIO",
	charges = 8,
	charges_per_charge = 4,
	rotation_speed = 180,
	charge_time = {[0] = 20, 20, 17, 14, 12, 10, 8.5, 7, 6},
}
turrets["OG_TURRET_FOCUS_1"] = {
	enemy_burst = 1,
	hold_time = 0.4,
	stealth = true,
	speed_reduction = 0.5,
	image = "og_turret_focus_1",
	glow = "og_turret_focus_1_glow",
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
turrets["OG_TURRET_FOCUS_BIO"] = {
	enemy_burst = 1,
	hold_time = 0.4,
	stealth = true,
	fake_damage = {iDamage = -2},
	speed_reduction = 0.5,
	image = "og_turret_focus_bio",
	glow = "og_turret_focus_bio_glow",
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_focus_bio_charge.png", -24, -8, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 0, y = -7, fire_delay = 0.7}},
	defence_type = defence_types.PROJECTILES,
	blueprint_type = 3,
	blueprint = "OG_FOCUS_PROJECTILE_BIO",
	blueprint_fake = "OG_FOCUS_PROJECTILE_BIO_FAKE",
	charges = 3,
	charges_per_charge = 1,
	rotation_speed = 240,
	charge_time = {[0] = 9, 9, 7.5, 6, 5, 4.5, 4, 3.75, 3.5},
}
turrets["OG_TURRET_FOCUS_CHAIN"] = {
	enemy_burst = 1,
	hold_time = 0.4,
	stealth = true,
	speed_reduction = 0.5,
	image = "og_turret_focus_chain",
	glow = "og_turret_focus_chain_glow",
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_focus_chain_charge.png", -59, -59, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	chain = {
		image = Hyperspace.Animations:GetAnimation("og_turret_focus_chain_chain"),
		type = chain_types.cooldown,
		amount = 0.2,
		count = 4,
	},
	fire_points = {{x = 0, y = -15, fire_delay = 0.5}},
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
	image = "og_turret_laser_mini_1",
	glow = "og_turret_laser_mini_1_glow",
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_laser_mini_1_charge.png", -4, -3, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 0, y = -12, fire_delay = 0.25}},
	defence_type = defence_types.PROJECTILES_MISSILES,
	blueprint_type = 1,
	blueprint = "OG_LASER_PROJECTILE_BASE",
	charges = 2,
	charges_per_charge = 2,
	rotation_speed = 240,
	charge_time = {[0] = 12, 12, 10, 8, 6, 5, 4, 3.5, 3},
}
turrets["OG_TURRET_LASER_RUSTY_MINI_1"] = {
	mini = true,
	shot_radius = 21,
	image = "og_turret_laser_rusty_mini_1",
	glow = "og_turret_laser_mini_1_glow",
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_laser_mini_1_charge.png", -4, -3, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 0, y = -12, fire_delay = 0.25}},
	defence_type = defence_types.PROJECTILES_MISSILES,
	blueprint_type = 1,
	blueprint = "OG_LASER_PROJECTILE_BASE",
	charges = 2,
	charges_per_charge = 2,
	rotation_speed = 240,
	charge_time = {[0] = 15, 15, 12, 10, 8, 6, 5, 4, 3},
}
turrets["OG_TURRET_LASER_MINI_2"] = {
	enemy_burst = 1,
	mini = true,
	image = "og_turret_laser_mini_2",
	glow = "og_turret_laser_mini_2_glow",
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
	enemy_charge_time = {[0] = 7, 7, 6, 5, 4, 3.5, 3, 2.75, 2.5},
} 
turrets["OG_TURRET_ION_MINI_1"] = {
	enemy_burst = 1,
	mini = true,
	image = "og_turret_ion_mini_1",
	glow = "og_turret_ion_mini_1_glow",
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
	image = "og_turret_focus_mini_1",
	glow = "og_turret_focus_mini_1_glow",
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
turrets["OG_TURRET_FLAK_MINI_1"] = {
	enemy_burst = 2,
	shot_radius = 42,
	aim_cone = 1,
	mini = true,
	image = "og_turret_flak_mini_1",
	glow = "og_turret_flak_mini_1_glow",
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_flak_mini_1_charge.png", -21, -21, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 0, y = -20, fire_delay = 0.5}, {x = 0, y = -20, fire_delay = 0, auto_burst = true}},
	defence_type = defence_types.ALL,
	blueprint_type = 1,
	blueprint = "OG_FLAK_PROJECTILE",
	charges = 4,
	charges_per_charge = 2,
	rotation_speed = 240,
	charge_time = {[0] = 11.5, 11.5, 9, 7, 6, 5, 4, 3, 2},
}
turrets["OG_TURRET_MISSILE_MINI_1"] = {
	enemy_burst = 1,
	mini = true,
	homing = 360,
	intercept_amount = 1,
	aim_cone = 10,
	image = "og_turret_missile_mini_1",
	glow = "og_turret_missile_mini_1_glow",
	fire_points = {{x = 0, y = -30, fire_delay = 0.4}},
	defence_type = defence_types.ALL,
	blueprint_type = 2,
	ammo_consumption = 0.5,
	blueprint = "OG_MISSILE_PROJECTILE_WEAK",
	charges = 4,
	charges_per_charge = 1,
	rotation_speed = 240,
	charge_time = {[0] = 7, 7, 6, 5, 4, 3.5, 3, 2.75, 2.5},
}


turrets["OG_TURRET_LASER_DAWN"] = {
	enemy_burst = 1,
	dawn = true,
	image = "og_turret_laser_dawn",
	glow = "og_turret_laser_2_glow",
	fire_points = {{x = 0, y = -60, fire_delay = 1}},
	defence_type = defence_types.DRONES_MISSILES,
	blueprint_type = 1,
	blueprint = "OG_LASER_PROJECTILE_HEAVY_DAWN",
	charges = 3,
	charges_per_charge = 1,
	rotation_speed = 120,
	charge_time = turrets["OG_TURRET_LASER_2"].charge_time,
}
turrets["OG_TURRET_ION_DAWN"] = {
	enemy_burst = 2,
	dawn = true,
	image = "og_turret_ion_dawn",
	glow = "og_turret_ion_2_glow",
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_ion_2_charge.png", -30, -11, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 5, y = -32, fire_delay = 0.25}, {x = -5, y = -32, fire_delay = 0.5}},
	defence_type = defence_types.DRONES,
	blueprint_type = 1,
	blueprint = "OG_ION_PROJECTILE_FIRE_DAWN",
	charges = 4,
	charges_per_charge = 2,
	rotation_speed = 180,
	charge_time = turrets["OG_TURRET_ION_1"].charge_time,
}
turrets["OG_TURRET_MISSILE_DAWN"] = {
	enemy_burst = 2,
	homing = 480,
	aim_cone = 30,
	dawn = true,
	image = "og_turret_missile_dawn",
	glow = "og_turret_missile_dawn_glow",
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_missile_2_charge.png", -6, -4, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 15, y = -48, fire_delay = 0.5}, {x = -15, y = -48, fire_delay = 0.5}},
	defence_type = defence_types.DRONES_MISSILES,
	blueprint_type = 2,
	ammo_consumption = 1,
	blueprint = "OG_MISSILE_PROJECTILE_HEAVY_DAWN",
	charges = 2,
	charges_per_charge = 1,
	rotation_speed = 120,
	charge_time = turrets["OG_TURRET_LASER_2"].charge_time,
}
turrets["OG_TURRET_FLAK_DAWN"] = {
	enemy_burst = 3,
	shot_radius = 45,
	aim_cone = 1,
	dawn = true,
	image = "og_turret_flak_dawn",
	glow = "og_turret_flak_1_glow",
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_flak_1_charge.png", -33, -33, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 0, y = -30, fire_delay = 0.5}, {x = 0, y = -30, fire_delay = 0, auto_burst = true}, {x = 0, y = -30, fire_delay = 0, auto_burst = true}},
	autofire = {
		offence = 3, 
		defence = 3,
	},
	defence_type = defence_types.ALL,
	blueprint_type = 1,
	blueprint = "OG_FLAK_PROJECTILE_DAWN",
	charges = 9,
	charges_per_charge = 3,
	rotation_speed = 180,
	charge_time = turrets["OG_TURRET_FLAK_1"].charge_time,
}
turrets["OG_TURRET_FOCUS_DAWN"] = {
	enemy_burst = 1,
	hold_time = 0.4,
	speed_reduction = 0.5,
	stealth = true,
	dawn = true,
	image = "og_turret_focus_dawn",
	glow = "og_turret_focus_1_glow",
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_focus_1_charge.png", -24, -8, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 0, y = -7, fire_delay = 0.7}},
	defence_type = defence_types.MISSILES,
	blueprint_type = 3,
	blueprint = "OG_FOCUS_PROJECTILE_DAWN",
	blueprint_fake = "OG_FOCUS_PROJECTILE_FAKE",
	charges = 3,
	charges_per_charge = 1,
	rotation_speed = 240,
	charge_time = turrets["OG_TURRET_FOCUS_1"].charge_time,
}
turrets["OG_TURRET_LASER_MINI_DAWN_1"] = {
	mini = true,
	dawn = true,
	image = "og_turret_laser_mini_dawn_1",
	glow = "og_turret_laser_mini_1_glow",
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_laser_mini_1_charge.png", -4, -3, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 0, y = -12, fire_delay = 0.25}},
	defence_type = defence_types.PROJECTILES_MISSILES,
	blueprint_type = 1,
	blueprint = "OG_LASER_PROJECTILE_BASE_DAWN",
	charges = 2,
	charges_per_charge = 2,
	rotation_speed = 240,
	charge_time = turrets["OG_TURRET_LASER_MINI_1"].charge_time,
}
turrets["OG_TURRET_LASER_MINI_DAWN_2"] = {
	enemy_burst = 1,
	mini = true,
	dawn = true,
	image = "og_turret_laser_mini_dawn_2",
	glow = "og_turret_laser_mini_2_glow",
	glow_offset = {x = -6, y = -4},
	glow_name = "og_turrets/turret_laser_mini_2_glow",
	glow_images = {},
	fire_points = {{x = 0, y = -16, fire_delay = 0.4}},
	defence_type = defence_types.PROJECTILES,
	blueprint_type = 1,
	blueprint = "OG_LASER_PROJECTILE_LIGHT_DAWN",
	charges = 3,
	charges_per_charge = 1,
	rotation_speed = 240,
	charge_time = turrets["OG_TURRET_LASER_MINI_2"].charge_time,
}
turrets["OG_TURRET_FOCUS_MINI_DAWN"] = {
	enemy_burst = 1,
	mini = true,
	hold_time = 0.4,
	speed_reduction = 0.5,
	dawn = true,
	image = "og_turret_focus_mini_dawn",
	glow = "og_turret_focus_mini_1_glow",
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/turret_focus_mini_1_charge.png", -17, -6, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 0, y = -4, fire_delay = 0.7}},
	defence_type = defence_types.MISSILES,
	blueprint_type = 3,
	blueprint = "OG_FOCUS_PROJECTILE_WEAK_DAWN",
	blueprint_fake = "OG_FOCUS_PROJECTILE_WEAK_FAKE",
	charges = 2,
	charges_per_charge = 1,
	rotation_speed = 240,
	charge_time = turrets["OG_TURRET_FOCUS_MINI_1"].charge_time,
}


turrets["OG_TURRET_FOCUS_SOULPLAGUE"] = {
	enemy_burst = 1,
	hold_time = 0.4,
	stealth = true,
	fake_damage = {iDamage = -2},
	speed_reduction = 0.5,
	image = "og_turret_focus_soulplague",
	glow = "og_turret_focus_soulplague_glow",
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/dd/turret_focus_soulplague_charge.png", -59, -59, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 0, y = -20, fire_delay = 0.6}},
	defence_type = defence_types.PROJECTILES_MISSILES,
	blueprint_type = 3,
	blueprint = "OG_FOCUS_PROJECTILE_SOULPLAGUE",
	blueprint_fake = "OG_FOCUS_PROJECTILE_SOULPLAGUE_FAKE",
	charges = 1,
	charges_per_charge = 1,
	rotation_speed = 240,
	charge_time = {[0] = 8, 8, 6, 5, 4, 3.5, 3, 2.75, 2.5}
}
turrets["OG_TURRET_MISSILE_FALSERADIANCE"] = {
	enemy_burst = 8,
	homing = 720,
	intercept_amount = 2,
	aim_cone = 60,
	shot_radius = 84,
	image = "og_turret_missile_falseradiance",
	glow = "og_turret_missile_falseradiance_glow",
	charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "og_turrets/dd/turret_missile_falseradiance_charge.png", -31, -31, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	fire_points = {{x = 26, y = -48, fire_delay = 0.15}, {x = 15, y = -48, fire_delay = 0.15}, {x = -15, y = -48, fire_delay = 0.15}, {x = -26, y = -48, fire_delay = 0.15}},
	defence_type = defence_types.ALL,
	blueprint_type = 2,
	ammo_consumption = 0.1,
	blueprint = "OG_MISSILE_PROJECTILE_FALSERADIANCE",
	charges = 14,
	charges_per_charge = 2,
	rotation_speed = 120,
	charge_time = {[0] = 5, 5, 3.5, 2.5, 2, 1.75, 1.5, 1.25, 1},
	enemy_charge_time = {[0] = 6, 6, 4.5, 3.5, 3, 2.75, 2.5, 2.25, 2},
}
turrets["OG_TURRET_LASER_DARKNESS_MINI"] = {
	mini = true,
	image = "og_turret_laser_darkness_mini",
	glow = "og_turret_laser_darkness_mini_glow",
	fire_points = {{x = 0, y = -12, fire_delay = 0.25}},
	defence_type = defence_types.PROJECTILES_MISSILES,
	blueprint_type = 1,
	blueprint = "OG_LASER_PROJECTILE_DARKNESS",
	charges = 5,
	charges_per_charge = 1,
	rotation_speed = 240,
	charge_time = {[0] = 6, 6, 4.5, 3.5, 3, 2.75, 2.5, 2.25, 2},
}


for turretId, currentTurret in pairs(turrets) do
	--currentTurret.image.position.x = -1 * currentTurret.image.info.frameWidth/2
	--currentTurret.image.position.y = -1 * currentTurret.image.info.frameHeight/2
	--currentTurret.image.tracker.loop = false
	--if currentTurret.glow then
		--currentTurret.glow.position.x = -1 * currentTurret.glow.info.frameWidth/2
		--currentTurret.glow.position.y = -1 * currentTurret.glow.info.frameHeight/2
		--currentTurret.glow.tracker.loop = false
	--end
	if currentTurret.chain and currentTurret.chain.image then
		currentTurret.chain.image.position.x = -1 * currentTurret.chain.image.info.frameWidth/2
		currentTurret.chain.image.position.y = -1 * currentTurret.chain.image.info.frameHeight/2
		currentTurret.chain.image.tracker.loop = false
	end
end
