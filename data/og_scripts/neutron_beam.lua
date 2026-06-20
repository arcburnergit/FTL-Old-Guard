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

local stencil_mode = {ignore = 0, set = 1, use = 2}

local starMap_properties = {
	x = 344, y = 87,
	w = 744, h = 526,
	loc_offset = {x = 41, y = 36},
}

local rotation_var = "loc_environment_og_neutron_star_rotation"
local sector_name = "SECTOR_OG_IRON_SECRET"

local active_var = "loc_environment_og_neutron_beam"

local jumps_per_rotation = 18
local deg_per_jump = 360 / jumps_per_rotation

local lag_factor = 0.2
local segments = 50

local beam_angular_width = deg_per_jump*2
local line_thickness = 3

local max_radius = 500

mods.multiverse.register_environment("og_neutron_beam", active_var, "warnings/danger_og_neutron_beam.png")
local hazard_text = Hyperspace.Text:GetText("map_og_neutron_beam_loc")

local damage_speed = 6
local damage_loss = -12
local neutron_shield_damage_mult = 4
local shield_damage_reduction = 1.25
local shield_damage_mult = 1.5

script.on_internal_event(Defines.InternalEvents.DANGEROUS_ENVIRONMENT, function()
	if Hyperspace.playerVariables[active_var] > 0 then
		return true
	end
end)

script.on_game_event("START_OG_IRON_SECRET", false, function()
	Hyperspace.playerVariables[rotation_var] = 135
end)
local left_over_damage = {[0] = 0, [1] = 0}
local function damage_room(damage, system, room, shipManager)
	if system and system.iSystemType == 1 then
		damage = damage + left_over_damage[shipManager.iShipId]
		left_over_damage[shipManager.iShipId] = 0
	end
	--print(damage.." sys:"..tostring(system).." room:"..tostring(room.iRoomId).." ship:"..tostring(shipManager.iShipId))
	local damage_crew = false
	if damage <= 0 then
		system.fDamageOverTime = system.fDamageOverTime + damage
		if system.fDamageOverTime <= 0 then
			system.fDamageOverTime = 0
			system.table.og_keep_damage = false
		else
			system.table.og_keep_damage = true
		end
		system:PartialDamage(0)
	else
		if system then
			if system.fRepairOverTime >= damage then
				system.fRepairOverTime = system.fRepairOverTime - damage
				damage = 0
			else
				if system.fRepairOverTime > 0 then
					damage = damage - system.fRepairOverTime
					system.fRepairOverTime = 0
				end
				if system.healthState.first > (((system.iSystemType == 1 or system.iSystemType == 6) and 1) or 0) then
					system.fDamageOverTime = system.fDamageOverTime + damage
					if system.fDamageOverTime >= 100 then
						left_over_damage[shipManager.iShipId] = system.fDamageOverTime - 100
					else
						system.table.og_keep_damage = true
					end
					--print("fDamageOverTime"..system.fDamageOverTime)
					damage = 0
				end
				system:PartialDamage(0)
			end
		end

		if damage > 0 then
			for crewmem in vter(shipManager.vCrewList) do
				if crewmem:InsideRoom(room.iRoomId) then
					crewmem.health.first = crewmem.health.first - damage
					crewmem:ApplyDamage(0)
					damage_crew = true
					damage = 0
				end
			end
		end
	end
	return damage_crew
end

local has_shield = {[0] = false, [1] = false}
local room_status = {[0] = {}, [1] = {}}
local ignore_room_status = {[0] = false, [1] = false}
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if Hyperspace.App.menu.shipBuilder.bOpen then return end
	for system in vter(shipManager.vSystemList) do
		if system.table.og_keep_damage then
			system.table.og_keep_damage = false
			system.table.check_damage = true
		end
	end
	has_shield[shipManager.iShipId] = false
	ignore_room_status[shipManager.iShipId] = false
	local damage = damage_speed * time_increment(true)
	if shipManager:HasAugmentation("OG_NEUTRON_SHIELD") > 0 and shipManager:GetSystem(1):GetEffectivePower() > 1 then
		damage = damage * neutron_shield_damage_mult
		has_shield[shipManager.iShipId] = true
		local system = shipManager:GetSystem(1)
		if Hyperspace.playerVariables[active_var] > 0 or left_over_damage[shipManager.iShipId] > 0 then
			if Hyperspace.playerVariables[active_var] <= 0 then
				damage = 0
			end
			for room in vter(shipManager.ship.vRoomList) do
				if room.iRoomId == system.roomId then
					damage_room(damage, system, room, shipManager)
					ignore_room_status[shipManager.iShipId] = true
					break
				end
			end
		end
	elseif Hyperspace.playerVariables[active_var] > 0 then
		local mult_shield_damage = false
		if shipManager:HasSystem(0) and shipManager:GetShieldPower().first > 0 then
			damage = damage / shield_damage_reduction
			mult_shield_damage = true
		end
		for room in vter(shipManager.ship.vRoomList) do
			local system = shipManager:GetSystemInRoom(room.iRoomId)
			local temp_damage = damage
			if system and system.iSystemType == 0 and mult_shield_damage then
				temp_damage = temp_damage * shield_damage_reduction * shield_damage_mult
			end
			local damage_crew = damage_room(temp_damage, system, room, shipManager)
			room_status[shipManager.iShipId][room.iRoomId] = damage_crew
		end
	end
	for system in vter(shipManager.vSystemList) do
		if system.table.check_damage then
			system.table.check_damage = false
			if not system.table.og_keep_damage then
				damage_room(damage_loss * time_increment(true), system, room, shipManager)
			end
		end
	end
end)

local crew_irradiated_anim = Hyperspace.Animations:GetAnimation("og_neutron_beam_crew")
crew_irradiated_anim.position.x = -crew_irradiated_anim.info.frameWidth/2
crew_irradiated_anim.position.y = -crew_irradiated_anim.info.frameHeight/2
crew_irradiated_anim.tracker.loop = true
crew_irradiated_anim:Start(true)

script.on_render_event(Defines.RenderEvents.CREW_MEMBER_HEALTH, function(crewmem)
	if Hyperspace.playerVariables[active_var] > 0 and room_status[crewmem.currentShipId][crewmem.iRoomId] and not ignore_room_status[crewmem.currentShipId] then
		local position = crewmem:GetPosition()
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(position.x, position.y, 0)
		crew_irradiated_anim:OnRender(1, Graphics.GL_Color(1, 1, 1, 1), false)
		Graphics.CSurface.GL_PopMatrix()
	end
	return Defines.Chain.CONTINUE
end, function() return Defines.Chain.CONTINUE end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if shipManager.iShipId == 0 then
		crew_irradiated_anim:Update()
	end
end)

script.on_internal_event(Defines.InternalEvents.GET_AUGMENTATION_VALUE, function(shipManager, aug, value)
	--if aug == "ION_ARMOR" then print("GET_AUGMENTATION_VALUE ION_ARMOR") end
	if aug == "ION_ARMOR" and has_shield[shipManager.iShipId] then
		value = 1
	end
	return Defines.Chain.CONTINUE, value
end)
script.on_internal_event(Defines.InternalEvents.HAS_AUGMENTATION, function(shipManager, aug, value)
	--if aug == "ION_ARMOR" then print("HAS_AUGMENTATION ION_ARMOR") end
	if aug == "ION_ARMOR" and has_shield[shipManager.iShipId] then
		value = 1
	end
	return Defines.Chain.CONTINUE, value
end)
script.on_internal_event(Defines.InternalEvents.HAS_EQUIPMENT, function(shipManager, aug, value)
	--if aug == "ION_ARMOR" then print("HAS_EQUIPMENT ION_ARMOR") end
	if aug == "ION_ARMOR" and has_shield[shipManager.iShipId] then
		value = 1
	end
	return Defines.Chain.CONTINUE, value
end)
script.on_internal_event(Defines.InternalEvents.SHIELD_COLLISION_PRE, function(shipManager, projectile, damage, responce)
	--print("SHIELD_COLLISION_PRE:"..tostring(shipManager.iShipId).." ionDamage:"..damage.iIonDamage.." projectile:"..tostring(projectile))

	return Defines.Chain.CONTINUE
end)
script.on_internal_event(Defines.InternalEvents.SHIELD_COLLISION, function(shipManager, projectile, damage, responce)
	--print("SHIELD_COLLISION:"..tostring(shipManager.iShipId).." ionDamage:"..damage.iIonDamage.." projectile:"..tostring(projectile))
	if has_shield[shipManager.iShipId] and damage.iIonDamage > 0 then
		left_over_damage[shipManager.iShipId] = left_over_damage[shipManager.iShipId] + 33.4 * damage.iIonDamage
		--print("left_over_damage:"..left_over_damage[shipManager.iShipId])
	end
	return Defines.Chain.CONTINUE
end)
script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA, function(shipManager, projectile, location, damage, forceHit, shipFriendlyFire)
	--print("DAMAGE_AREA:"..tostring(shipManager.iShipId).." ionDamage:"..damage.iIonDamage.." projectile:"..tostring(projectile))
	return Defines.Chain.CONTINUE, forceHit, shipFriendlyFire
end)
script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
	--print("DAMAGE_AREA_HIT:"..tostring(shipManager.iShipId).." ionDamage:"..damage.iIonDamage.." projectile:"..tostring(projectile))
	if has_shield[shipManager.iShipId] and damage.iIonDamage > 0 then
		left_over_damage[shipManager.iShipId] = left_over_damage[shipManager.iShipId] + 33.4 * damage.iIonDamage
		--print("left_over_damage:"..left_over_damage[shipManager.iShipId])
	end
	return Defines.Chain.CONTINUE
end)
script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(ship, projectile, location, damage, realNewTile, beamHitType)
	if beamHitType == Defines.BeamHit.NEW_ROOM then
		--print("DAMAGE_BEAM:"..tostring(shipManager.iShipId).." ionDamage:"..damage.iIonDamage.." projectile:"..tostring(projectile))
		if has_shield[shipManager.iShipId] and damage.iIonDamage > 0 then
			left_over_damage[shipManager.iShipId] = left_over_damage[shipManager.iShipId] + 33.4 * damage.iIonDamage
			--print("left_over_damage:"..left_over_damage[shipManager.iShipId])
		end
	end
	return Defines.Chain.CONTINUE, beamHitType
end)

local last_alpha = 0
local triggered = false
script.on_internal_event(Defines.InternalEvents.GET_HAZARD_FLASH, function(alpha)
	--if alpha > 0 then print(alpha) end
	local spaceManager = Hyperspace.App.world.space
	if spaceManager.pulsarLevel and alpha < last_alpha and (not triggered) then
		triggered = true
		--print("PULSAR")
		if has_shield[0] then
			left_over_damage[0] = left_over_damage[0] + 100
			--print("left_over_damage:"..left_over_damage[0])
		end
		if has_shield[1] then
			left_over_damage[1] = left_over_damage[1] + 100
			--print("left_over_damage:"..left_over_damage[1])
		end
	end
	if triggered and alpha <= 0 then
		triggered = false
	end
	last_alpha = alpha
	return 1, 1, 1, alpha
end)

local active_colour = Graphics.GL_Color(0/255, 150/255, 255/255, 0.25)
local warning_colour = Graphics.GL_Color(255/255, 50/255, 0/255, 0.1)
local active_edge_colour = Graphics.GL_Color(0/255, 150/255, 255/255, 0.75)
local warning_edge_colour = Graphics.GL_Color(255/255, 50/255, 0/255, 0.25)
local warning_next_edge_colour = Graphics.GL_Color(255/255, 50/255, 0/255, 0.1)
local COLOUR_WHITE = Graphics.GL_Color(1, 1, 1, 1)
local function playerToWorldLocation(location)
	local cApp = Hyperspace.App
	local combatControl = cApp.gui.combatControl
	local playerPosition = combatControl.playerShipPosition
	if cApp.menu.shipBuilder.bOpen then
		return Hyperspace.Point(0, 0)
	end
	return Hyperspace.Point(location.x + playerPosition.x, location.y + playerPosition.y)
end

local function is_angle_in_wedge(check_angle, front_edge, width)
	local diff = (front_edge - check_angle) % 360
	return diff >= 0 and diff <= width
end

local function get_location_beam_status(target_x, target_y, current_angle_A)
	local r = math.sqrt(target_x * target_x + target_y * target_y)
	local location_angle = math.deg(math.atan(target_y, target_x)) % 360

	local lag_amount = r * lag_factor
	local unlagged_angle = (location_angle + lag_amount) % 360

	local current_front_A = current_angle_A
	local current_front_B = (current_front_A + 180) % 360

	local next_front_A = (current_front_A + deg_per_jump) % 360
	local next_front_B = (next_front_A + 180) % 360
	if is_angle_in_wedge(unlagged_angle, next_front_A, beam_angular_width) or
		is_angle_in_wedge(unlagged_angle, next_front_B, beam_angular_width) then
		return "WARNING"
	end

	if is_angle_in_wedge(unlagged_angle, current_front_A, beam_angular_width) or
		is_angle_in_wedge(unlagged_angle, current_front_B, beam_angular_width) then
		return "ACTIVE"
	end
	return false
end

script.on_internal_event(Defines.InternalEvents.GET_BEACON_HAZARD, function(location)
	local relative_x = location.loc.x + starMap_properties.loc_offset.x - starMap_properties.w/2
	local relative_y = location.loc.y + starMap_properties.loc_offset.y - starMap_properties.h/2
	--print(location.event.eventName.." GET_BEACON_HAZARD")
	if get_location_beam_status(relative_x, relative_y, Hyperspace.playerVariables[rotation_var]) == "WARNING" then
		return hazard_text
	end
end)

local last_hover_warning = false
script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function(ship)
	if ship.iShipId ~= 0 then return end
	local stop_music = false
	if Hyperspace.playerVariables[active_var] == 1 then
		Hyperspace.playerVariables[active_var] = 0
		stop_music = true
	end
	local map = Hyperspace.App.world.starMap
	--print("JUMP_ARRIVE:"..map.currentSector.description.type)
	Hyperspace.playerVariables[active_var] = 0
	if map.currentSector.description.type == sector_name then
		Hyperspace.playerVariables[rotation_var] = (Hyperspace.playerVariables[rotation_var] + 360/jumps_per_rotation) % 360
		--print("ROTATION:"..Hyperspace.playerVariables[rotation_var])
		if last_hover_warning then
			Hyperspace.playerVariables[active_var] = 1
			damage_timer = 1
			if not stop_music then
				local worldManager = Hyperspace.App.world
				Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager,"OG_ARRIVE_NEUTRON_BEAM",false,-1)
			end
		end
	end

	if stop_music and Hyperspace.playerVariables[active_var] == 0 then
		local worldManager = Hyperspace.App.world
		Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager,"OG_LEAVE_NEUTRON_BEAM",false,-1)
	end
end)
local map_stencil = Hyperspace.Resources:CreateImagePrimitiveString("map/og_map_stencil.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
local map_icon = Hyperspace.Resources:CreateImagePrimitiveString("map/map_icon_diamond_blue.png", -16, -16, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
local map_icon_warning = Hyperspace.Resources:CreateImagePrimitiveString("map/map_icon_og_neutron_warning.png", -16, -16, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
local map_icon_warning_blank = Hyperspace.Resources:CreateImagePrimitiveString("map/map_icon_og_neutron_warning_blank.png", -16, -16, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)

local function reset_stencil_buffer(buffer_bits)
	Graphics.CSurface.GL_SetStencilMode(stencil_mode.set, 0, buffer_bits)
	Graphics.CSurface.GL_DrawRect(
		-1280, 
		-720, 
		1280*3, 
		720*3, 
		COLOUR_WHITE
	)
	Graphics.CSurface.GL_SetStencilMode(stencil_mode.ignore, 0, buffer_bits)
end

local function get_spiral_point(base_angle_deg, radius, angle_offset)
	local lag_amount = radius * lag_factor
	local final_angle_deg = base_angle_deg + angle_offset - lag_amount
	
	local radians = math.rad(final_angle_deg)
	
	local x = radius * math.cos(radians)
	local y = radius * math.sin(radians)
	return x, y
end

local function draw_spiral_beam_wedge(base_angle, select_colour, draw_edges)
	local radius_step = max_radius / segments

	for i = 0, segments - 1 do
		local r1 = i * radius_step
		local r2 = (i + 1) * radius_step

		local x1_back,  y1_back  = get_spiral_point(base_angle, r1, -beam_angular_width)
		local x1_front, y1_front = get_spiral_point(base_angle, r1, 0)
		local x2_back,  y2_back  = get_spiral_point(base_angle, r2, -beam_angular_width)
		local x2_front, y2_front = get_spiral_point(base_angle, r2, 0)

		local p1_back  = Hyperspace.Point(x1_back, y1_back)
		local p1_front = Hyperspace.Point(x1_front, y1_front)
		local p2_back  = Hyperspace.Point(x2_back, y2_back)
		local p2_front = Hyperspace.Point(x2_front, y2_front)

		if draw_edges then
			if draw_edges == 1 then
				Graphics.CSurface.GL_DrawLine(x1_back, y1_back, x2_back, y2_back, line_thickness, select_colour)
			end
			Graphics.CSurface.GL_DrawLine(x1_front, y1_front, x2_front, y2_front, line_thickness, select_colour)
		else
			Graphics.CSurface.GL_DrawTriangle(p1_back, p1_front, p2_front, select_colour)
			Graphics.CSurface.GL_DrawTriangle(p1_back, p2_front, p2_back, select_colour)
		end
	end
end


script.on_render_event(Defines.RenderEvents.GUI_CONTAINER, function() end, function()
	local map = Hyperspace.App.world.starMap
	if map.bOpen and map.bChoosingNewSector then
		last_hover_warning = false
	elseif map.bOpen and map.potentialLoc then
		local relative_x = map.potentialLoc.loc.x + starMap_properties.loc_offset.x - starMap_properties.w/2
		local relative_y = map.potentialLoc.loc.y + starMap_properties.loc_offset.y - starMap_properties.h/2
		if get_location_beam_status(relative_x, relative_y, Hyperspace.playerVariables[rotation_var]) == "WARNING" then
			last_hover_warning = true
		else
			last_hover_warning = false
		end
	end
	if map.currentSector.description.type == sector_name and map.bOpen and (not map.bChoosingNewSector) then
		--if map.hoverLoc then print("hovering: x:"..map.hoverLoc.loc.x.." y:"..map.hoverLoc.loc.y.." event:"..map.hoverLoc.event.eventName) end

		local mid_x = starMap_properties.w/2
		local mid_y = starMap_properties.h/2
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(starMap_properties.x, starMap_properties.y, 0) -- move to map location
		Graphics.CSurface.GL_SetStencilMode(stencil_mode.set, 1, 1)
		Graphics.CSurface.GL_RenderPrimitiveWithAlpha(map_stencil, 0.5)
		Graphics.CSurface.GL_SetStencilMode(stencil_mode.use, 1, 1)
		Graphics.CSurface.GL_Translate(mid_x, mid_y, 0) -- move to center

		local current_angle_A = Hyperspace.playerVariables[rotation_var]
		local current_angle_B = (current_angle_A + 180) % 360
		
		local last_angle_A = (current_angle_A - deg_per_jump) % 360
		local last_angle_B = (last_angle_A + 180) % 360
		
		local next_angle_A = (current_angle_A + deg_per_jump) % 360
		local next_angle_B = (next_angle_A + 180) % 360
		
		local next_next_angle_A = (next_angle_A + deg_per_jump) % 360
		local next_next_angle_B = (next_next_angle_A + 180) % 360

		draw_spiral_beam_wedge(next_angle_A, warning_colour, false)
		draw_spiral_beam_wedge(next_angle_B, warning_colour, false)

		draw_spiral_beam_wedge(current_angle_A, active_colour, false)
		draw_spiral_beam_wedge(current_angle_B, active_colour, false)

		draw_spiral_beam_wedge(next_next_angle_A, warning_edge_colour, true)
		draw_spiral_beam_wedge(next_next_angle_B, warning_edge_colour, true)

		draw_spiral_beam_wedge(next_angle_A, warning_edge_colour, true)
		draw_spiral_beam_wedge(next_angle_B, warning_edge_colour, true)

		draw_spiral_beam_wedge(last_angle_A, active_colour, true)
		draw_spiral_beam_wedge(last_angle_B, active_colour, true)

		draw_spiral_beam_wedge(current_angle_A, active_edge_colour, 1)
		draw_spiral_beam_wedge(current_angle_B, active_edge_colour, 1)
		Graphics.CSurface.GL_RenderPrimitive(map_icon)

		reset_stencil_buffer(1)
		Graphics.CSurface.GL_PopMatrix()


		--[[Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(starMap_properties.x, starMap_properties.y, 0)
		Graphics.CSurface.GL_Translate(starMap_properties.loc_offset.x, starMap_properties.loc_offset.y, 0)
		for location in vter(map.locations) do
			local relative_x = location.loc.x + starMap_properties.loc_offset.x - mid_x
			local relative_y = location.loc.y + starMap_properties.loc_offset.y - mid_y
			local status = get_location_beam_status(relative_x, relative_y, current_angle_A)
			if status == "WARNING" then
				Graphics.CSurface.GL_PushMatrix()
				Graphics.CSurface.GL_Translate(location.loc.x, location.loc.y, 0)
				Graphics.CSurface.GL_RenderPrimitive(map_icon_warning)
				Graphics.CSurface.GL_PopMatrix()
			end
		end
		Graphics.CSurface.GL_PopMatrix()]]
	end
end)

local colour_list = {
	Graphics.GL_Color(0/255, 150/255, 255/255, 0.2),
	Graphics.GL_Color(50/255, 150/255, 255/255, 0.2),
	Graphics.GL_Color(25/255, 175/255, 255/255, 0.2),
	Graphics.GL_Color(225/255, 225/255, 255/255, 0.2),
	Graphics.GL_Color(255/255, 255/255, 255/255, 0.2),
	Graphics.GL_Color(5/255, 55/255, 205/255, 0.2),
	Graphics.GL_Color(5/255, 25/255, 155/255, 0.2),
}

local flash_timer = 0
local flash_timer_max = 0.35
local flash_timer_min = 0.2

local particle_image = Hyperspace.Resources:CreateImagePrimitiveString("effects/og_neutron_beam.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 0.8, false)
local particle_image_size = {w = 1280, h = 120}

local shield_image = Hyperspace.Resources:CreateImagePrimitiveString("ship/shield_base_og_shield_white.png", -500, -500, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
local shield_image_front = Hyperspace.Resources:CreateImagePrimitiveString("ship/shield_base_og_shield_front_white.png", -500, -500, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
local shield_image_top = Hyperspace.Resources:CreateImagePrimitiveString("ship/shield_base_og_shield_top_white.png", -500, -500, 0, Graphics.GL_Color(1, 1, 1, 1), 1, false)
local shield_image_size = {w = 1000, h = 1000}
local shield_image_colour = Graphics.GL_Color(150/255, 25/255, 255/255, 0.8)

local function reset_particle(particle)
	particle.w = math.random(256, 1280)
	particle.h = math.random(math.floor(particle.w/50), math.floor(particle.w/10))
	particle.y = math.random() * (720 + particle.h - 1) - particle.h
	particle.colour = math.random(1, #colour_list)
end

local particle_list_back_max = 800
local particle_list_front_max = 400
local particle_list_back = {}
local particle_list_front = {}
do
	for i = 1, particle_list_back_max do
		local particle = {}
		reset_particle(particle)
		particle.x = math.random() * (1280 + particle.w - 1) - particle.w
		particle.vel = math.random(250, 750)
		particle_list_back[i] = particle
	end
end
do
	for i = 1, particle_list_front_max do
		--print("particle_list_front:"..i)
		local particle = {}
		reset_particle(particle)
		particle.x = math.random() * (1280 + particle.w - 1) - particle.w
		particle.vel = math.random(750, 1250)
		particle_list_front[i] = particle
	end
end

script.on_render_event(Defines.RenderEvents.LAYER_FOREGROUND, function() return Defines.Chain.CONTINUE end, function()
	if Hyperspace.playerVariables[active_var] ~= 1 then return Defines.Chain.CONTINUE end
	Graphics.CSurface.GL_DrawRect(
		-1280, -720,
		1280*2, 720*2,
		colour_list[1]
	)
	for _, particle in ipairs(particle_list_back) do
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(particle.x, particle.y, 0)
		Graphics.CSurface.GL_Scale(particle.w / particle_image_size.w, particle.h / particle_image_size.h, 1)
		Graphics.CSurface.GL_RenderPrimitiveWithColor(particle_image, colour_list[particle.colour])
		Graphics.CSurface.GL_PopMatrix()
		--Graphics.CSurface.GL_DrawLine(
			--particle.x, particle.y,
			--particle.x + particle.w, particle.y,
			--particle.h, colour_list[particle.colour]
		--)
	end
	return Defines.Chain.CONTINUE 
end)

script.on_render_event(Defines.RenderEvents.SHIP, function(ship)
	local shipManager = Hyperspace.ships(ship.iShipId)
	if has_shield[ship.iShipId] then
		local ellipse = shipManager._targetable:GetShieldShape()
		local center = ellipse.center
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(center.x, center.y, 0)
		Graphics.CSurface.GL_Scale((ellipse.a*2) / shield_image_size.w, (ellipse.b*2) / shield_image_size.h, 1)
		
		Graphics.CSurface.GL_RenderPrimitiveWithColor(shield_image, shield_image_colour)
		if Hyperspace.playerVariables[active_var] == 1 then
			local alpha = 1 - (flash_timer_max * 3) + (flash_timer * 3)
			if ship.iShipId == 0 then
				Graphics.CSurface.GL_RenderPrimitiveWithAlpha(shield_image_front, alpha)
			else
				Graphics.CSurface.GL_RenderPrimitiveWithAlpha(shield_image_top, alpha)
			end
		end
		Graphics.CSurface.GL_PopMatrix()
	end
	return Defines.Chain.CONTINUE 
end, function(ship) 
	if ship.iShipId == 1 and Hyperspace.playerVariables[active_var] > 0 then
		for i, particle in ipairs(particle_list_front) do
			Graphics.CSurface.GL_PushMatrix()
			Graphics.CSurface.GL_Translate(-200, 720, 0)
			Graphics.CSurface.GL_Rotate(-90, 0, 0, 1)
			Graphics.CSurface.GL_Translate(particle.x, particle.y, 0)
			Graphics.CSurface.GL_Scale(particle.w / particle_image_size.w, particle.h / particle_image_size.h, 1)
			Graphics.CSurface.GL_RenderPrimitiveWithColor(particle_image, colour_list[particle.colour])
			Graphics.CSurface.GL_PopMatrix()
		end
	end
end)

script.on_render_event(Defines.RenderEvents.FTL_BUTTON, function() 
	if Hyperspace.playerVariables[active_var] ~= 1 then return Defines.Chain.CONTINUE end
	for i, particle in ipairs(particle_list_front) do
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(particle.x, particle.y, 0)
		Graphics.CSurface.GL_Scale(particle.w / particle_image_size.w, particle.h / particle_image_size.h, 1)
		Graphics.CSurface.GL_RenderPrimitiveWithColor(particle_image, colour_list[particle.colour])
		Graphics.CSurface.GL_PopMatrix()
	end
	return Defines.Chain.CONTINUE 
end, function() return Defines.Chain.CONTINUE end)

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
	if Hyperspace.playerVariables[active_var] ~= 1 then return end
	local commandGui = Hyperspace.App.gui
	if commandGui.bPaused or commandGui.event_pause or commandGui.menu_pause then return end

	flash_timer = flash_timer - time_increment(true)
	if flash_timer <= 0 then
		flash_timer = flash_timer_min + math.random() * (flash_timer_max - flash_timer_min)
	end
	for _, particle in ipairs(particle_list_back) do
		particle.x = particle.x - particle.vel * time_increment(true)
		if particle.x < (0 - particle.w) then
			reset_particle(particle)
			particle.x = 1280
		end
	end
	for _, particle in ipairs(particle_list_front) do
		particle.x = particle.x - particle.vel * time_increment(true)
		if particle.x < (0 - particle.w) then
			reset_particle(particle)
			particle.x = 1280
		end
	end
end)

local wallImageAnim = Hyperspace.Animations:GetAnimation("og_neutron_damage")
wallImageAnim.tracker.loop = true
wallImageAnim:Start(true)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if shipManager.iShipId == 0 then
		wallImageAnim:Update()
	end
end)

local tileImageString = "effects/og_neutron_damage_tile"
local tileImage =  Hyperspace.Resources:CreateImagePrimitiveString( (tileImageString..".png") , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)

local function render_beam_damage(room)
	--print("render_vunerable:"..room.iRoomId)
	if Hyperspace.App.menu.shipBuilder.bOpen then return end
	local opacity = 0.5
	local x = room.rect.x
	local y = room.rect.y
	local w = math.floor(room.rect.w/35)
	local h = math.floor(room.rect.h/35)
	local size = w * h
	for i = 0, size - 1 do
		local xOff = x + (i%w) * 35
		local yOff = y + math.floor(i/w) * 35
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(xOff, yOff, 0)
		Graphics.CSurface.GL_RenderPrimitiveWithAlpha(tileImage, opacity)
		Graphics.CSurface.GL_PopMatrix()
	end
	opacity = 1
	-- top and bottom edge
	for i = 0, w - 1 do
		local xOff = x + i * 35
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(xOff, y, 0)
		Graphics.CSurface.GL_Rotate(180, 0, 0, 1)
		Graphics.CSurface.GL_Translate(-35, -35, 0)
		wallImageAnim:OnRender(1, Graphics.GL_Color(1, 1, 1, 1), false)
		--Graphics.CSurface.GL_RenderPrimitiveWithAlpha(wallImage.up, opacity)
		Graphics.CSurface.GL_PopMatrix()

		local yOff = y + (h-1) * 35
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(xOff, yOff, 0)
		wallImageAnim:OnRender(1, Graphics.GL_Color(1, 1, 1, 1), false)
		--Graphics.CSurface.GL_RenderPrimitiveWithAlpha(wallImage.down, opacity)
		Graphics.CSurface.GL_PopMatrix()
	end
	-- left and right edge
	for i = 0, h - 1 do
		local yOff = y + i * 35
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(x, yOff, 0)
		Graphics.CSurface.GL_Rotate(90, 0, 0, 1)
		Graphics.CSurface.GL_Translate(0, -35, 0)
		wallImageAnim:OnRender(1, Graphics.GL_Color(1, 1, 1, 1), false)
		--Graphics.CSurface.GL_RenderPrimitiveWithAlpha(wallImage.left, opacity)
		Graphics.CSurface.GL_PopMatrix()

		local xOff = x + (w-1) * 35
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(xOff, yOff, 0)
		Graphics.CSurface.GL_Rotate(-90, 0, 0, 1)
		Graphics.CSurface.GL_Translate(-35, 0, 0)
		wallImageAnim:OnRender(1, Graphics.GL_Color(1, 1, 1, 1), false)
		--Graphics.CSurface.GL_RenderPrimitiveWithAlpha(wallImage.right, opacity)
		Graphics.CSurface.GL_PopMatrix()
	end
end

script.on_render_event(Defines.RenderEvents.SHIP_SPARKS, function(ship) end, function(ship)
	if Hyperspace.playerVariables[active_var] ~= 1 then return end
	local shipManager = Hyperspace.ships(ship.iShipId)
	if has_shield[ship.iShipId] then
		local system = shipManager:GetSystem(1)
		if system then
			for room in vter(shipManager.ship.vRoomList) do
				if room.iRoomId == system.roomId then
					render_beam_damage(room)
					break
				end
			end
		end
	else
		for room in vter(shipManager.ship.vRoomList) do
			render_beam_damage(room)
		end
	end
	return Defines.Chain.CONTINUE
end)
