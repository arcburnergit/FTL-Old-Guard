--adding new turrets (this is patch order independent, can be in addons before or after OG)
local added = false
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
	if (not mods.og) or added then return end
	added = true
	local turretBlueprintsList = mods.og.turretBlueprintsList 
	table.insert(turretBlueprintsList, "EXAMPLE_TURRET_NAME")

	local defence_types = mods.og.defence_types
	local chain_types = mods.og.chain_types

	local turrets = mods.og.turrets --Look at OG to find a kind of weapon similar to the one you're trying to make, eg look for flak turret if you're trying to make a flak like turret.
	--YOU DO NOT NEED TO (AND SHOULDN'T) SPECIFY EVERY EFFECT, ONLY THE ONES RELAVANT TO THE TYPE OF TURRET YOU'RE MAKING, LOOK AT EXAMPLES IN OG
	turrets["EXAMPLE_TURRET_NAME"] = {
		mini = true, --Is this a small or large turret
		enemy_burst = 3, --How many shots the enemy should fire once they have charged the weapon to maximum shots, useful so that they keep a few charges to defend.
		hold_time = 0.4, --How loEng to hold the turret in place after firing, required for pinpoints
		speed_reduction = 0.5, --rotation speed is multiplied by this during the cooldown (firing time) of the current shot
		stealth = true, --Like pierce lasers or beams/pinpoints, doesn't consume cloak timer when firing
		image = "example_turret_name_anim", -- main animation
		charging_anim = "example_turret_name_charging_anim", -- charging animation, if not present first frame of main animation used instead
		custom_animations = { --animation to play over the top in different situations
			animation_id = {depowered = true, looping = true},
			animation_id = {charging = true, looping = true},
			animation_id = {charged = true, looping = false},
			animation_id = {firing = true, looping = true},
			animation_id = {charging = true, charged = true, depowered = true, looping = false}, -- when looping = false it will only play on the transition from inactive to active, so this one will only play after firing.
		} --an animation can be played under multiple conditions, this means that instead of stopping one anim and starting a new identical one we can just continue the same animation
		autofire = { --false/true/amount; false for 1 charge per shot, true for all stored charges, amount is amount; false is default
			offence = true, 
			defence = true,
		}, --if autofire tag is left undefined, will fire 1 charge per shot
		hide_glow_firing = true, --hides the glow image while turret is firing
		shot_radius = 42, --Makes the turret less accurate, radius is halved (making it more accurate) while performing defensive duties, ie shooting at a drone
		aim_cone = 45, --how close to aiming at the target does the turret need to be in order to fire at it
		intercept_amount = 1, --how many to fire at target in defensive mode
		homing = 36, --Gives projectiles the ability to steer and home in in the target, most useful with a higher aim cone to allow the turret to fire on the target earlier, and have the projectiles make up for the remaining aiming.
		multi_anim = {frames = 3}, -- Splits the Animation into a number of sections, each section corresponding to one projectile, in this case we split the first 3 frames for the left shot, and then the remaining are the right
		glow = "example_turret_name_anim_glow", -- glow, each frame is for 1 charge, so first frame is when the weapon has charged 1 shot, 2nd frame 2 shots, ect
		charge_image = Hyperspace.Resources:CreateImagePrimitiveString( "example_turrets/example_turret_name_anim_charge.png", -74, -74, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false), --Similar to beams which have a glow that becomes less transparent as the weapon charges
		chain = {
			image = Hyperspace.Animations:GetAnimation("example_turret_name_anim_charge_chain"), --animation for chain lights/effects
			type = chain_types.cooldown, --currently only cooldown is implemented
			amount = 0.2, --percentage of cooldown to reduce by
			count = 4, --how many times
		},
		fire_points = {{x = 12, y = -42, fire_delay = 0.1}, {x = -12, y = -42, fire_delay = 0.5}}, -- where shots are fired from on the weapon, can define multiple firing points, in this example every second is on one side and every other shot is on the other side
		defence_type = defence_types.ALL, --what to shoot at
		blueprint_type = 1, --1 is normal, 2 is missile weapon, 3 is pinpoint
		ammo_consumption = 1, --how many missiles are used
		blueprint = "OG_LASER_PROJECTILE_BASE", --Projectile to spawn when firing
		charges = 1, --maximum number of charges that the weapon can store
		charges_per_charge = 1, --number of charges to add each time the weapon's charge timer fills up
		rotation_speed = 360, --rotation speed
		charge_time = {[0] = 9, 9, 8, 7, 6, 5, 4, 3, 2, 1}, --charge time depending on power, first entry is for [0] power and so determines how quickly it drains when depowered
		enemy_charge_time = {[0] = 24, 24, 20, 17, 14, 12, 10, 8.5, 7}, --allows you to make enemy charge times different for the same turret
	}

	local craftedCategories = mods.og.craftedCategories


	local craftedExampleMod = {name = "Mod Name", id = "EXAMPLE_MOD", items = {}}
	table.insert(craftedCategories, craftedExampleMod)
	--match_cost tells it to add a scrap amount to the craft so that the components aren't cheaper than the result
	table.insert(craftedExampleMod.items, {weapon = "EXAMPLE_TURRET_NAME", match_cost = true, component_amounts = {1}, components = {{"LASER_BURST_2", "LASER_BURST_3"}}} )
end)

--example adding new components (this is patch order independent, can be in addons before or after OG)
local added2 = false
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
	if (not mods.og) or added2 then return end
	added2 = true
	mods.og.addComponent("OG_TURRET_LASER_1", "NEW_BURST_LASER_ID", 1) --add NEW_BURST_ID to the first component table (this turret only has 1 component table)
end)

--[[XML
<weaponBlueprint name="OG_TURRET_LASER_1">
	<type>BEAM</type>
	<flavorType>Turret</flavorType>
	<tip>tip_og_turret</tip>
	<title>Burst Laser Turret</title>
	<short>Burst L.</short>
	<desc>Standard Burst Laser Turret. A cheap and efficient middleground between offence and defence.</desc>
	<tooltip>Turret</tooltip>
	<damage>0</damage>
	<sp>0</sp>
	<cooldown>-1</cooldown>
	<speed>0</speed>
	<length>0</length>
	<rarity>0</rarity>
	<power>0</power>
	<cost>65</cost>
	<image>beam_contact</image>
	<weaponArt>invisible</weaponArt>
	<iconReplace>og_turret_laser_1_icon</iconReplace>
</weaponBlueprint>


<animSheet name="og_turret_laser_1_icon" w="81" h="38" fw="81" fh="38">og_turrets/turret_laser_1_icon.png</animSheet>
<anim name="og_turret_laser_1_icon">
	<sheet>og_turret_laser_1_icon</sheet>
	<desc length="1" x="0" y="0" />
	<time>1</time>
</anim>
<animSheet name="og_turret_laser_1" w="770" h="110" fw="110" fh="110">og_turrets/turret_laser_1.png</animSheet>
<anim name="og_turret_laser_1">
	<sheet>og_turret_laser_1</sheet>
	<desc length="7" x="0" y="0" />
	<time>0.45</time>
</anim>
<animSheet name="og_turret_laser_1_glow" w="132" h="12" fw="22" fh="12">og_turrets/turret_laser_1_glow.png</animSheet>
<anim name="og_turret_laser_1_glow">
	<sheet>og_turret_laser_1_glow</sheet>
	<desc length="6" x="0" y="0" />
	<time>1</time>
</anim>
You may need more animations for charge or chain images
]]