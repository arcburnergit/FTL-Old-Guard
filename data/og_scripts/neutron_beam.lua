-- MV CORE
local vter = mods.multiverse.vter
local time_increment = mods.multiverse.time_increment
local userdata_table = mods.multiverse.userdata_table
local node_child_iter = mods.multiverse.node_child_iter
local string_starts = mods.multiverse.string_starts
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

local COLOUR_WHITE = Graphics.GL_Color(1, 1, 1, 1)

local stencil_mode = {ignore = 0, set = 1, use = 2}

local starMap_properties = {
	x = 344, y = 87,
	w = 744, h = 526,
	loc_offset = {x = 41, y = 36},
}

local rotation_var = "loc_environment_og_neutron_star_rotation"
local sector_name = "SECTOR_OG_NEUTRON"
local event_string = "OG_NEUTRON_HAZARD_"
local station_event_string = "OG_NEUTRON_HAZARD_RESEARCH_STATION"

local star_pos = Hyperspace.Pointf(0, 0)

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

local damage_speed = 5
local damage_loss = -10
local neutron_shield_damage_mult = 3
local shield_damage_reduction = 1.25
local shield_damage_mult = 1.5

script.on_internal_event(Defines.InternalEvents.DANGEROUS_ENVIRONMENT, function()
	if Hyperspace.playerVariables[active_var] > 0 then
		return true
	end
end)

script.on_game_event("START_OG_NEUTRON", false, function()
	Hyperspace.playerVariables[rotation_var] = 135
end)
local function vter_i(cvec)
	if not (type(cvec) == "userdata") then
		error("invalid arg passed to vter ("..tostring(cvec)..")", 2)
	end
	local i = -1
	local n = cvec:size()
	return function()
		i = i + 1
		if i < n then return i, cvec[i] end
	end
end

local map_updated = false
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
	local map = Hyperspace.App.world.starMap
	if (not map_updated) and map.currentSector and map.currentSector.description.type == sector_name then
		map_updated = true

		local closest = nil
		local closest_distance = math.huge
		local research_station = nil
		for location in vter(map.locations) do
			local relative_x = location.loc.x + starMap_properties.loc_offset.x - starMap_properties.w/2
			local relative_y = location.loc.y + starMap_properties.loc_offset.y - starMap_properties.h/2
			local relative_p = Hyperspace.Pointf(relative_x, relative_y)
			local dist = get_distance(relative_p, star_pos)
			if (not closest) or dist < closest_distance then
				closest = location
				closest_distance = dist
			end

			if location.event.eventName == station_event_string then
				research_station = location
			end
		end

		if closest and research_station then
			--print("closest name:"..closest.event.eventName)
			if closest.event.eventName ~= station_event_string then
				-- 
				local all_locations_affected_list = {}
				for location in vter(closest.connectedLocations) do
					--print("adding:"..tostring(location).." from closest")
					all_locations_affected_list[location] = true
				end
				for location in vter(research_station.connectedLocations) do
					--print("adding:"..tostring(location).." from station")
					if all_locations_affected_list[location] then print("Overlap on:"..tostring(location)) end
					all_locations_affected_list[location] = true
				end
				all_locations_affected_list[closest] = true
				--print("adding:"..tostring(closest).." as closest")
				all_locations_affected_list[research_station] = true
				--print("adding:"..tostring(research_station).." as station")
				local rebuild_connections = {}
				for location, _ in pairs(all_locations_affected_list) do
					--print("creating rebuild:"..tostring(location))
					local connections = {}
					for connected in vter(location.connectedLocations) do
						if connected == closest then
							--print("store connection from:"..tostring(location).." to:"..tostring(research_station).." instead of closest")
							table.insert(connections, research_station)
						elseif connected == research_station then
							--print("store connection from:"..tostring(location).." to:"..tostring(closest).." instead of station")
							table.insert(connections, closest)
						else
							--print("store connection from:"..tostring(location).." to:"..tostring(connected))
							table.insert(connections, connected)
						end
					end
					if location == closest then
						--print("adding rebuild to rebuild as station:"..tostring(research_station))
						rebuild_connections[research_station] = connections
					elseif location == research_station then
						--print("adding rebuild to rebuild as closest:"..tostring(closest))
						rebuild_connections[closest] = connections
					else
						--print("adding rebuild to rebuild as:"..tostring(location))
						rebuild_connections[location] = connections
					end
				end

				for location, connection_table in pairs(rebuild_connections) do
					--print("rebuilding:"..tostring(location))
					location.connectedLocations:clear()
					for _, connected in ipairs(connection_table) do
						--print("add connection from:"..tostring(location).." to:"..tostring(connected))
						location.connectedLocations:push_back(connected)
					end
				end
				closest.loc = Hyperspace.Pointf(research_station.loc.x, research_station.loc.y)
				local star_x = starMap_properties.w/2 - starMap_properties.loc_offset.x
				local star_y = starMap_properties.h/2 - starMap_properties.loc_offset.y
				research_station.loc = Hyperspace.Pointf(star_x - 15, star_y)
			end
		end
	end
end)

script.on_internal_event(Defines.InternalEvents.POST_CREATE_CHOICEBOX, function(choiceBox, event)
	local map = Hyperspace.App.world.starMap
	if event.eventName == map.currentLoc.event.eventName then
		map_updated = false
		--print("RESET_MAP_UPDATE_TRACKER:"..map.currentSector.description.type)
	end
end)

function beam_shield_entry_t(beam, shield)
	local cx, cy, a, b = shield.center.x, shield.center.y, shield.a, shield.b
	local angle = math.rad(beam.angle)
	local dx = math.cos(angle)
	local dy = math.sin(angle)

	local ox = (beam.target.x - cx) / a
	local oy = (beam.target.y - cy) / b
	local vx = dx / a
	local vy = dy / b

	-- |O + t*V|² = 1
	local A = vx*vx + vy*vy
	local B = 2 * (ox*vx + oy*vy)
	local C = ox*ox + oy*oy - 1

	local disc = B*B - 4*A*C
	if disc < 0 then return nil end

	local sq = math.sqrt(disc)
	local t1 = (-B - sq) / (2*A)
	local t2 = (-B + sq) / (2*A)
	if t2 < 0 then return nil end
	return t1
end

local active_beams = {}

function mods.og.create_neutron_beam(target, target_angle, width, shipManager, owner, time, damage, extend)
	--local target_angle = get_angle_between_points(target1, target2)
	if not target then print("NO TARGET") end
	local shieldShape = shipManager._targetable:GetShieldShape()
	local new_beam = {targetShip = shipManager.iShipId, ownerShip = owner.iShipId, target = target, angle = target_angle, width = width, time = time, damage = damage, extend = extend}
	local t_shield = nil
	if shipManager.iShipId ~= owner.iShipId then
		t_shield = beam_shield_entry_t(new_beam, shieldShape)
	end
	new_beam.t_shield = t_shield
	table.insert(active_beams, new_beam)
end
local create_neutron_beam = mods.og.create_neutron_beam

function mods.og.test_cnb()
	create_neutron_beam(Hyperspace.Point(100,100),45,20,Hyperspace.ships.player, Hyperspace.ships.enemy,10,5,true)
end

script.on_internal_event(Defines.InternalEvents.JUMP_LEAVE, function(shipManager)
	if shipManager.iShipId == 0 then
		active_beams = {}
	end
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if shipManager.iShipId == 0 then
		local remove_beam = nil
		for i, beam_table in ipairs(active_beams) do
			beam_table.time = beam_table.time - time_increment(true)
			if beam_table.time <= 0 then
				remove_beam = i
			end
		end
		if remove_beam then
			table.remove(active_beams, remove_beam)
		end
	end
end)

local has_shield = {[0] = false, [1] = false}
local room_damage_active = {[0] = {}, [1] = {}}
do --HAZARD DAMAGE TRACKING
	local left_over_damage = {[0] = 0, [1] = 0}
	local function damage_room(damage, system, room, shipManager)
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
					local system_min = 0
					if shipManager.iShipId == 0 and (system.iSystemType == 1 or system.iSystemType == 6) then
						system_min = 1
					end
					if system.healthState.first > system_min then
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

			if damage > 0 and room then
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

	function room_protected_by_shield(room, shield)
		local cx, cy, a, b = shield.center.x, shield.center.y, shield.a, shield.b
		local corners = {
			{ room.x, room.y },
			{ room.x + room.w, room.y },
			{ room.x, room.y + room.h },
			{ room.x + room.w, room.y + room.h },
		}
		for _, c in ipairs(corners) do
			local ex = (c[1] - cx) / a
			local ey = (c[2] - cy) / b
			if ex*ex + ey*ey > 1 then
				return false
			end
		end
		return true
	end

	function beam_intersects_room(beam, room)
		local angle = math.rad(beam.angle)
		local dx =  math.cos(angle)
		local dy =  math.sin(angle)
		local nx = -dy
		local ny =  dx

		local half_w = beam.width / 2

		local corners = {
			{ room.x,		  room.y		  },
			{ room.x + room.w, room.y		  },
			{ room.x,		  room.y + room.h },
			{ room.x + room.w, room.y + room.h },
		}
		local min_proj =  math.huge
		local max_proj = -math.huge
		for _, c in ipairs(corners) do
			local proj = (c[1] - beam.target.x) * nx + (c[2] - beam.target.y) * ny
			if proj < min_proj then min_proj = proj end
			if proj > max_proj then max_proj = proj end
		end

		if min_proj > half_w or max_proj < -half_w then
			return false
		end

		return true
	end

	local function beam_room_t_range(beam, room)
		local angle = math.rad(beam.angle)
		local dx = math.cos(angle)
		local dy = math.sin(angle)

		local corners = {
			{ room.x,		  room.y		  },
			{ room.x + room.w, room.y		  },
			{ room.x,		  room.y + room.h },
			{ room.x + room.w, room.y + room.h },
		}

		if not beam_intersects_room(beam, room) then return nil end

		local t_min =  math.huge
		local t_max = -math.huge
		for _, c in ipairs(corners) do
			local t = (c[1] - beam.target.x) * dx + (c[2] - beam.target.y) * dy
			if t < t_min then t_min = t end
			if t > t_max then t_max = t end
		end

		return t_min, t_max
	end

	local room_status = {[0] = {}, [1] = {}}
	local ignore_room_status = {[0] = false, [1] = false}
	script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
		if Hyperspace.App.menu.shipBuilder.bOpen then return end

		has_shield[shipManager.iShipId] = false
		local enginesOnline = shipManager:HasSystem(1) and shipManager:GetSystem(1):GetEffectivePower() > ((shipManager.iShipId == 0 and 1) or 0)
		if shipManager:HasAugmentation("OG_NEUTRON_SHIELD") > 0 and enginesOnline then
			has_shield[shipManager.iShipId] = true
		end

		local has_check_damage = false
		for system in vter(shipManager.vSystemList) do
			if system.table.og_keep_damage then
				system.table.og_keep_damage = false
				system.table.check_damage = true
				has_check_damage = true
			end
		end

		local shieldShape = shipManager._targetable:GetShieldShape()
		for room in vter(shipManager.ship.vRoomList) do
			local damage = 0
			local system = shipManager:GetSystemInRoom(room.iRoomId)
			local room_protected = room.table.og_neutron_protected
			if room_protected == nil then
				room.table.og_neutron_protected = room_protected_by_shield(room.rect, shieldShape)
				room_protected = room.table.og_neutron_protected
			end
			room_protected_full = room_protected and has_shield[shipManager.iShipId]
			if Hyperspace.playerVariables[active_var] > 0 then
				if not room_protected_full then
					damage = damage + damage_speed * time_increment(true)
				end
				if has_shield[shipManager.iShipId] and system and system.iSystemType == 1 then
					damage = damage + damage_speed * time_increment(true) * neutron_shield_damage_mult
				end
			end
			if left_over_damage[shipManager.iShipId] > 0 and system and system.iSystemType == 1 then
				damage = damage + left_over_damage[shipManager.iShipId]
				left_over_damage[shipManager.iShipId] = 0
			end
			for _, beam_table in ipairs(active_beams) do
				if beam_table.targetShip == shipManager.iShipId and beam_table.damage > 0 then
					local t_limit = (has_shield[shipManager.iShipId] and beam_table.t_shield) or math.huge
					if not room_protected_full then
						local t_min, t_max = beam_room_t_range(beam_table, room.rect)
						if t_min and t_min < t_limit then
							damage = damage + beam_table.damage * time_increment(true)
						end
					end
					if beam_table.t_shield and has_shield[shipManager.iShipId] and system and system.iSystemType == 1 then
						damage = damage + beam_table.damage * time_increment(true) * neutron_shield_damage_mult
					end
				end
			end
			if damage > 0 then
				local damage_crew = damage_room(damage, system, room, shipManager)
				room_damage_active[shipManager.iShipId][room.iRoomId] = true
				room_status[shipManager.iShipId][room.iRoomId] = damage_crew
			else
				room_damage_active[shipManager.iShipId][room.iRoomId] = false
				room_status[shipManager.iShipId][room.iRoomId] = false
			end
		end

		if has_check_damage then
			for system in vter(shipManager.vSystemList) do
				if system.table.check_damage then
					system.table.check_damage = false
					if not system.table.og_keep_damage then
						damage_room(damage_loss * time_increment(true), system, nil, shipManager)
					end
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
			crew_irradiated_anim:OnRender(1, COLOUR_WHITE, false)
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
		if aug == "ION_ARMOR" and has_shield[shipManager.iShipId] then
			value = 1
		end
		return Defines.Chain.CONTINUE, value
	end)
	script.on_internal_event(Defines.InternalEvents.HAS_AUGMENTATION, function(shipManager, aug, value)
		if aug == "ION_ARMOR" and has_shield[shipManager.iShipId] then
			value = 1
		end
		return Defines.Chain.CONTINUE, value
	end)
	script.on_internal_event(Defines.InternalEvents.HAS_EQUIPMENT, function(shipManager, aug, value)
		if aug == "ION_ARMOR" and has_shield[shipManager.iShipId] then
			value = 1
		end
		return Defines.Chain.CONTINUE, value
	end)
	script.on_internal_event(Defines.InternalEvents.SHIELD_COLLISION, function(shipManager, projectile, damage, responce)
		if has_shield[shipManager.iShipId] and damage.iIonDamage > 0 then
			left_over_damage[shipManager.iShipId] = left_over_damage[shipManager.iShipId] + 33.4 * damage.iIonDamage
		end
		return Defines.Chain.CONTINUE
	end)
	script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
		if has_shield[shipManager.iShipId] and damage.iIonDamage > 0 then
			left_over_damage[shipManager.iShipId] = left_over_damage[shipManager.iShipId] + 33.4 * damage.iIonDamage
		end
		return Defines.Chain.CONTINUE
	end)
	script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(shipManager, projectile, location, damage, realNewTile, beamHitType)
		if beamHitType == Defines.BeamHit.NEW_ROOM then
			if has_shield[shipManager.iShipId] and damage.iIonDamage > 0 then
				left_over_damage[shipManager.iShipId] = left_over_damage[shipManager.iShipId] + 33.4 * damage.iIonDamage
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
			if has_shield[0] then
				left_over_damage[0] = left_over_damage[0] + 100
			end
			if has_shield[1] then
				left_over_damage[1] = left_over_damage[1] + 100
			end
		end
		if triggered and alpha <= 0 then
			triggered = false
		end
		last_alpha = alpha
		return 1, 1, 1, alpha
	end)
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
	local map = Hyperspace.App.world.starMap
	if map.currentSector.description.type == sector_name then
		local relative_x = location.loc.x + starMap_properties.loc_offset.x - starMap_properties.w/2
		local relative_y = location.loc.y + starMap_properties.loc_offset.y - starMap_properties.h/2
		local isNeutronBeamEvent = string_starts(location.event.eventName, event_string)
		--print(location.event.eventName.." GET_BEACON_HAZARD")
		if get_location_beam_status(relative_x, relative_y, Hyperspace.playerVariables[rotation_var]) == "WARNING" or isNeutronBeamEvent then
			return hazard_text
		end
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
	if map.currentSector.description.type == sector_name then
		Hyperspace.playerVariables[rotation_var] = (Hyperspace.playerVariables[rotation_var] + 360/jumps_per_rotation) % 360
		if last_hover_warning then
			Hyperspace.playerVariables[active_var] = 1
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
script.on_internal_event(Defines.InternalEvents.PRE_CREATE_CHOICEBOX, function(event)
	local isNeutronBeamEvent = string_starts(event.eventName, event_string)
	if isNeutronBeamEvent and Hyperspace.playerVariables[active_var] == 0 then
		Hyperspace.playerVariables[active_var] = 1
		local worldManager = Hyperspace.App.world
		Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager,"OG_ARRIVE_NEUTRON_BEAM",false,-1)
	end
end)

local iron_watch_ship_list = {}
for item in vter(Hyperspace.Blueprints:GetBlueprintList("LIST_SHIPS_OG_IRON_ALL")) do
	iron_watch_ship_list[item] = true
end
for item in vter(Hyperspace.Blueprints:GetBlueprintList("LIST_SHIPS_OG_MIDNIGHT_ALL")) do
	iron_watch_ship_list[item] = true
end
script.on_internal_event(Defines.InternalEvents.GENERATOR_CREATE_SHIP, function(name, sector, event, blueprint, ret)
	local map = Hyperspace.App.world.starMap
	--print(name)
	if map.currentSector.description.type == sector_name and iron_watch_ship_list[blueprint.blueprintName] then
		local has_shield = false
		for blueprint in vter(blueprint.augments) do
			if blueprint == "OG_NEUTRON_SHIELD" then
				has_shield = true
				break
			end
		end
		if not has_shield then
			blueprint.augments:push_back("OG_NEUTRON_SHIELD")
		end
		blueprint.systemInfo[1].powerLevel = math.min(8, blueprint.systemInfo[1].powerLevel + 2)
		blueprint.systemInfo[1].maxPower = math.min(8, blueprint.systemInfo[1].maxPower + 2)
	end
	return Defines.Chain.CONTINUE, sector, event, blueprint, ret
end)
script.on_internal_event(Defines.InternalEvents.GET_DODGE_FACTOR, function(shipManager, value)
	if value > 5 and shipManager:HasAugmentation("OG_NEUTRON_SHIELD") > 0 then
		value = value - 5
	end
	return Defines.Chain.CONTINUE, value
end)

local bar_outline = Hyperspace.Resources:CreateImagePrimitiveString("systemUi/og_neutron_shield_outline.png", 0, 0, 0, COLOUR_WHITE, 1.0, false)
local bar_position = {x = 24, y = 16}
script.on_render_event(Defines.RenderEvents.SYSTEM_BOX, function(systemBox, ignoreStatus) return Defines.Chain.CONTINUE end, function(systemBox, ignoreStatus) 
	local shipId = (systemBox.bPlayerUI and 0) or 1
	local shipManager = Hyperspace.ships(shipId)
	local system = systemBox.pSystem
	if has_shield[shipId] and system.iSystemType == 1 then
		if systemBox.bPlayerUI and system:GetEffectivePower() >= 2 then
			for i = 2, system:GetEffectivePower() do
				Graphics.CSurface.GL_PushMatrix()
				Graphics.CSurface.GL_Translate(bar_position.x, bar_position.y - i * 8, 0)
				Graphics.CSurface.GL_RenderPrimitive(bar_outline)
				Graphics.CSurface.GL_PopMatrix()
			end
		elseif (not systemBox.bPlayerUI) and system:GetEffectivePower() >= 2 then
			for i = 2, system:GetEffectivePower() do
				Graphics.CSurface.GL_PushMatrix()
				Graphics.CSurface.GL_Translate(bar_position.x, bar_position.y - i * 8, 0)
				Graphics.CSurface.GL_RenderPrimitive(bar_outline)
				Graphics.CSurface.GL_PopMatrix()
			end
		end
	end
	return Defines.Chain.CONTINUE 
end)

local warning_stripe_colour = Graphics.GL_Color(0.8, 0.8, 0.8, 0.25)
local active_colour = Graphics.GL_Color(0/255, 150/255, 255/255, 40/255)
local warning_colour = Graphics.GL_Color(255/255, 50/255, 0/255, 40/255)

local active_edge_colour = Graphics.GL_Color(188/255, 224/255, 245/255, 1)
local warning_edge_colour = Graphics.GL_Color(255/255, 193/255, 173/255, 1)

local future_edge_colour = Graphics.GL_Color(255/255, 231/255, 214/255, 146/255)

local map_stencil = Hyperspace.Resources:CreateImagePrimitiveString("map/og_map_stencil.png", 0, 0, 0, COLOUR_WHITE, 1.0, false)
local map_stencil_warning = Hyperspace.Resources:CreateImagePrimitiveString("map/og_map_stencil_warning.png", 0, 0, 0, COLOUR_WHITE, 1.0, false)
local map_icon = Hyperspace.Resources:CreateImagePrimitiveString("map/map_icon_diamond_blue.png", -16, -16, 0, COLOUR_WHITE, 1.0, false)
local map_icon_warning = Hyperspace.Resources:CreateImagePrimitiveString("map/map_icon_og_neutron_warning.png", -16, -16, 0, COLOUR_WHITE, 1.0, false)
local map_icon_warning_blank = Hyperspace.Resources:CreateImagePrimitiveString("map/map_icon_og_neutron_warning_blank.png", -16, -16, 0, COLOUR_WHITE, 1.0, false)

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

local function get_spiral_point(base_angle_deg, radius)
	local lag_amount = radius * lag_factor
	local final_angle_deg = base_angle_deg - lag_amount
	
	local radians = math.rad(final_angle_deg)
	
	local x = radius * math.cos(radians)
	local y = radius * math.sin(radians)
	return x, y
end

local function draw_spiral_fill(first_angle, second_angle, colour)
	local radius_step = max_radius / segments

	for i = 0, segments - 1 do
		local r1 = i * radius_step
		local r2 = (i + 1) * radius_step

		local x1_front, y1_front = get_spiral_point(first_angle, r1)
		local x1_back,  y1_back  = get_spiral_point(second_angle, r1)

		local x2_front, y2_front = get_spiral_point(first_angle, r2)
		local x2_back,  y2_back  = get_spiral_point(second_angle, r2)

		local p1_back  = Hyperspace.Point(x1_back, y1_back)
		local p1_front = Hyperspace.Point(x1_front, y1_front)
		local p2_back  = Hyperspace.Point(x2_back, y2_back)
		local p2_front = Hyperspace.Point(x2_front, y2_front)

		Graphics.CSurface.GL_DrawTriangle(p1_back, p1_front, p2_front, colour)
		Graphics.CSurface.GL_DrawTriangle(p1_back, p2_front, p2_back, colour)
	end
end

local function draw_spiral_edge(angle, colour, thickness)
	local radius_step = max_radius / segments
	for i = 0, segments - 1 do
		local r1 = i * radius_step
		local r2 = (i + 1) * radius_step

		local x1, y1 = get_spiral_point(angle, r1)
		local x2, y2 = get_spiral_point(angle, r2)
		Graphics.CSurface.GL_DrawLine(x1, y1, x2, y2, thickness, colour)
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

		--CURRENT BEAM
		local current_angle_A = Hyperspace.playerVariables[rotation_var]
		local current_angle_B = (current_angle_A + 180) % 360

		local current_back_angle_A = (current_angle_A - beam_angular_width) % 360
		local current_back_angle_B = (current_back_angle_A + 180) % 360
		
		--BEAM NEXT JUMP
		local next_angle_A = (current_angle_A + deg_per_jump) % 360
		local next_angle_B = (next_angle_A + 180) % 360

		local next_back_angle_A = (next_angle_A - beam_angular_width) % 360
		local next_back_angle_B = (next_back_angle_A + 180) % 360
		
		--2 JUMPS
		local future_angle_A = (next_angle_A + deg_per_jump) % 360
		local future_angle_B = (future_angle_A + 180) % 360

		reset_stencil_buffer(1)

		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(starMap_properties.x, starMap_properties.y, 0) -- move to map location

		Graphics.CSurface.GL_SetStencilMode(stencil_mode.set, 1, 16)
		Graphics.CSurface.GL_RenderPrimitive(map_stencil_warning)
		Graphics.CSurface.GL_SetStencilMode(stencil_mode.use, 1, 16)

		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(mid_x, mid_y, 0)
		draw_spiral_fill(next_angle_A, next_back_angle_A, warning_stripe_colour)
		draw_spiral_fill(next_angle_B, next_back_angle_B, warning_stripe_colour)
		Graphics.CSurface.GL_PopMatrix()

		Graphics.CSurface.GL_SetStencilMode(stencil_mode.set, 1, 16)
		Graphics.CSurface.GL_RenderPrimitive(map_stencil)
		Graphics.CSurface.GL_SetStencilMode(stencil_mode.use, 1, 17)

		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(mid_x, mid_y, 0) -- move to center

		draw_spiral_fill(next_angle_A, current_angle_A, warning_colour)
		draw_spiral_fill(next_angle_B, current_angle_B, warning_colour)

		draw_spiral_fill(current_angle_A, current_back_angle_A, active_colour)
		draw_spiral_fill(current_angle_B, current_back_angle_B, active_colour)

		draw_spiral_edge(current_angle_A, active_edge_colour, 3)
		draw_spiral_edge(current_angle_B, active_edge_colour, 3)

		draw_spiral_edge(current_back_angle_A, active_edge_colour, 3)
		draw_spiral_edge(current_back_angle_B, active_edge_colour, 3)

		draw_spiral_edge(next_angle_A, warning_edge_colour, 2)
		draw_spiral_edge(next_angle_B, warning_edge_colour, 2)

		draw_spiral_edge(future_angle_A, future_edge_colour, 2)
		draw_spiral_edge(future_angle_B, future_edge_colour, 2)

		Graphics.CSurface.GL_RenderPrimitive(map_icon)
		Graphics.CSurface.GL_PopMatrix()

		Graphics.CSurface.GL_PopMatrix()
		reset_stencil_buffer(16)
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
local colour_list_high_alpha = {}
for _, colour in ipairs(colour_list) do
	table.insert(colour_list_high_alpha, Graphics.GL_Color(colour.r,colour.g,colour.b, 0.6))
end

local flash_timer = 0
local flash_timer_max = 0.4
local flash_timer_min = 0.1

local particle_image = Hyperspace.Resources:CreateImagePrimitiveString("effects/og_neutron_beam.png", 0, 0, 0, COLOUR_WHITE, 0.8, false)
local particle_image_size = {w = 1280, h = 120}
local shield_image = Hyperspace.Resources:CreateImagePrimitiveString("ship/shield_base_og_shield_white.png", -500, -500, 0, COLOUR_WHITE, 1, false)
local shield_image_front = Hyperspace.Resources:CreateImagePrimitiveString("ship/shield_base_og_shield_front_white.png", -500, -500, 0, COLOUR_WHITE, 1, false)
local shield_image_top = Hyperspace.Resources:CreateImagePrimitiveString("ship/shield_base_og_shield_top_white.png", -500, -500, 0, COLOUR_WHITE, 1, false)

local shield_anim_front = Hyperspace.Animations:GetAnimation("shield_base_og_shield_front_burn")
shield_anim_front.position.x = -1 * shield_anim_front.info.frameWidth/2
shield_anim_front.position.y = -1 * shield_anim_front.info.frameHeight/2
shield_anim_front.tracker.loop = true
shield_anim_front:Start(true)
local shield_anim_up = Hyperspace.Animations:GetAnimation("shield_base_og_shield_up_burn")
shield_anim_up.position.x = -1 * shield_anim_up.info.frameWidth/2
shield_anim_up.position.y = -1 * shield_anim_up.info.frameHeight/2
shield_anim_up.tracker.loop = true
shield_anim_up:Start(true)


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

script.on_render_event(Defines.RenderEvents.SHIP_HULL, function(ship, alpha) 
	local shipManager = Hyperspace.ships(ship.iShipId)
	if has_shield[ship.iShipId] then
		local ellipse = shipManager._targetable:GetShieldShape()
		local center = ellipse.center
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(center.x, center.y, 0)
		Graphics.CSurface.GL_Scale((ellipse.a*2) / shield_image_size.w, (ellipse.b*2) / shield_image_size.h, 1)
		if Hyperspace.playerVariables[active_var] == 1 then
			local alpha = 1 - (flash_timer_max * 3) + (flash_timer * 3)
			if ship.iShipId == 0 then
				shield_anim_front:OnRender(1, COLOUR_WHITE, false)
			else
				shield_anim_up:OnRender(1, COLOUR_WHITE, false)
			end
		end
		Graphics.CSurface.GL_PopMatrix()
	end
	return Defines.Chain.CONTINUE
end, function(ship, alpha) return Defines.Chain.CONTINUE end)

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

	for _, beam_table in ipairs(active_beams) do
		if beam_table.targetShip == ship.iShipId then
			local t_limit = (has_shield[ship.iShipId] and beam_table.t_shield) or 2000
			local origin = offset_point_in_direction(beam_table.target, beam_table.angle, 0, 2000)
			local impact = offset_point_in_direction(beam_table.target, beam_table.angle, 0, -t_limit -10)
			if not beam_table.extend then
				origin = beam_table.target
				impact = offset_point_in_direction(beam_table.target, beam_table.angle, 0, -2000)
			end
			local mask_hide = 1
			local mask_show = -1
			if ship.iShipId == 0 then
				mask_hide = -1
				mask_show = 1
			end
			Graphics.CSurface.GL_PushStencilMode()
			Graphics.CSurface.GL_SetStencilMode(stencil_mode.set, mask_hide, 16)
			Graphics.CSurface.GL_DrawRect(
				-1280,-720,
				1280*3,720*3,
				COLOUR_WHITE)
			Graphics.CSurface.GL_SetStencilMode(stencil_mode.set, mask_show, 16)
			local new_width = beam_table.width + (math.floor(beam_table.time*3)%3 - 1)
			Graphics.CSurface.GL_DrawLine(origin.x, origin.y, impact.x, impact.y, new_width, COLOUR_WHITE)

			local shipManager = Hyperspace.ships(ship.iShipId)
			local ellipse = shipManager._targetable:GetShieldShape()
			local center = ellipse.center
			if has_shield[ship.iShipId] and beam_table.damage > 0 then
				Graphics.CSurface.GL_SetStencilMode(stencil_mode.set, mask_hide, 16)
				Graphics.CSurface.GL_PushMatrix()
				Graphics.CSurface.GL_Translate(center.x, center.y, 0)
				Graphics.CSurface.GL_Scale((ellipse.a*2) / shield_image_size.w, (ellipse.b*2) / shield_image_size.h, 1)
				Graphics.CSurface.GL_RenderPrimitiveWithColor(shield_image, shield_image_colour)
				Graphics.CSurface.GL_PopMatrix()
			end

			Graphics.CSurface.GL_SetStencilMode(stencil_mode.use, mask_show, 48)
			if new_width > 2 then
				for i=1, math.floor(new_width/2) - 1 do
					local n = i*2
					Graphics.CSurface.GL_DrawLine(origin.x, origin.y, impact.x, impact.y, new_width - n, colour_list_high_alpha[1])
				end
			end
			for i = 1, 50 do
				local particle = particle_list_front[i]
				Graphics.CSurface.GL_PushMatrix()
				Graphics.CSurface.GL_Translate(beam_table.target.x, beam_table.target.y, 0)
				Graphics.CSurface.GL_Rotate(beam_table.angle+180, 0, 0, 1)
				Graphics.CSurface.GL_Scale(1.25, (beam_table.width * 2) / 720, 1)
				Graphics.CSurface.GL_Translate(-640, -360, 0)
				Graphics.CSurface.GL_Translate(particle.x, particle.y, 0)
				Graphics.CSurface.GL_Scale(particle.w / particle_image_size.w, 4*particle.h / particle_image_size.h, 1)
				Graphics.CSurface.GL_RenderPrimitiveWithColor(particle_image, colour_list_high_alpha[particle.colour])
				Graphics.CSurface.GL_PopMatrix()
			end
			reset_stencil_buffer(16)
			Graphics.CSurface.GL_PopStencilMode()
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
	if Hyperspace.playerVariables[active_var] ~= 1 and #active_beams <= 0 then return end
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
	shield_anim_front:Update()
	shield_anim_up:Update()
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
local tileImage =  Hyperspace.Resources:CreateImagePrimitiveString( (tileImageString..".png") , 0, 0, 0, COLOUR_WHITE, 1.0, false)

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
		wallImageAnim:OnRender(1, COLOUR_WHITE, false)
		--Graphics.CSurface.GL_RenderPrimitiveWithAlpha(wallImage.up, opacity)
		Graphics.CSurface.GL_PopMatrix()

		local yOff = y + (h-1) * 35
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(xOff, yOff, 0)
		wallImageAnim:OnRender(1, COLOUR_WHITE, false)
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
		wallImageAnim:OnRender(1, COLOUR_WHITE, false)
		--Graphics.CSurface.GL_RenderPrimitiveWithAlpha(wallImage.left, opacity)
		Graphics.CSurface.GL_PopMatrix()

		local xOff = x + (w-1) * 35
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(xOff, yOff, 0)
		Graphics.CSurface.GL_Rotate(-90, 0, 0, 1)
		Graphics.CSurface.GL_Translate(-35, 0, 0)
		wallImageAnim:OnRender(1, COLOUR_WHITE, false)
		--Graphics.CSurface.GL_RenderPrimitiveWithAlpha(wallImage.right, opacity)
		Graphics.CSurface.GL_PopMatrix()
	end
end

script.on_render_event(Defines.RenderEvents.SHIP_SPARKS, function(ship) end, function(ship)
	for room in vter(ship.vRoomList) do
		if room_damage_active[ship.iShipId][room.iRoomId] then
			render_beam_damage(room)
		end
	end
	return Defines.Chain.CONTINUE
end)

mods.og.test_stencil = nil
mods.og.test_stencil_value = 1
script.on_render_event(Defines.RenderEvents.MOUSE_CONTROL, function()
	if not mods.og.test_stencil then return Defines.Chain.CONTINUE end
	Graphics.CSurface.GL_PushStencilMode()
	Graphics.CSurface.GL_SetStencilMode(stencil_mode.use, mods.og.test_stencil_value, mods.og.test_stencil)
	Graphics.CSurface.GL_DrawRect(
		0,0,
		1280,720,
		Graphics.GL_Color(1,0,0,0.5))
	Graphics.CSurface.GL_PopStencilMode()
	return Defines.Chain.CONTINUE
end, function() return Defines.Chain.CONTINUE end)