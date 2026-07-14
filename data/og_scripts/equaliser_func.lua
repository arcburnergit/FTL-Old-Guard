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

local vunerable_weapons = mods.og.vunerable_weapons
--TURRET DEFINITIONS
local systemName = "og_equaliser"
local damage_reduction_level = 0.1
local system_cooldown = 4
local system_active = false

mods.multiverse.systemIcons[Hyperspace.ShipSystem.NameToSystemId(systemName)] = mods.multiverse.register_system_icon(systemName)

local button_hover_string = Hyperspace.Text:GetText("og_lua_equaliser_button_hover")

--Handles tooltips and mousever descriptions per level
local level_string = Hyperspace.Text:GetText("og_lua_equaliser_level")
local function get_level_description(systemId, level, tooltip)
	if systemId == Hyperspace.ShipSystem.NameToSystemId(systemName) then
		return string.format( level_string, math.floor((damage_reduction_level * (level - 1)) * 100) )
	end
end

script.on_internal_event(Defines.InternalEvents.GET_LEVEL_DESCRIPTION, get_level_description)

local function is_equaliser(systemBox)
	local systemNameTemp = Hyperspace.ShipSystem.SystemIdToName(systemBox.pSystem.iSystemType)
	return systemName == systemNameTemp and systemBox.bPlayerUI
end
local function is_equaliser_enemy(systemBox)
	local systemNameTemp = Hyperspace.ShipSystem.SystemIdToName(systemBox.pSystem.iSystemType)
	return systemName == systemNameTemp and not systemBox.bPlayerUI
end

local buttonOffset_x = 37
local buttonOffset_y = -37
local function construct_system_box(systemBox)
	if is_equaliser(systemBox) then
		systemBox.extend.xOffset = 54

		local equaliserButton = Hyperspace.Button()
		equaliserButton:OnInit("systemUI/button_default", Hyperspace.Point(buttonOffset_x, buttonOffset_y))
		equaliserButton.hitbox.x = 10
		equaliserButton.hitbox.y = 22
		equaliserButton.hitbox.w = 20
		equaliserButton.hitbox.h = 31
		systemBox.table.equaliserButton = equaliserButton

		systemBox.pSystem.bNeedsPower = false
		systemBox.pSystem.bBoostable = false -- make the system unmannable
	elseif is_equaliser_enemy(systemBox) then
		systemBox.pSystem.bNeedsPower = false
		systemBox.pSystem.bBoostable = false
	end
end
script.on_internal_event(Defines.InternalEvents.CONSTRUCT_SYSTEM_BOX, construct_system_box)

local system_icon_hitbox = {
	[true] = {
		x = 22, y = 43,
		w = 20, h = 10,
	},
	[false] = {
		x = 11, y = 22,
		w = 10, h = 20,
	}
}
local system_hover_text_on = Hyperspace.Text:GetText("og_lua_equaliser_system_hover_on")
local system_hover_text_off = Hyperspace.Text:GetText("og_lua_equaliser_system_hover_off")
local function is_in_hitbox(x, y, hb)
	return x > hb.x and x <= hb.x + hb.w and y > hb.y and y <= hb.y + hb.h
end

local function mouse_move(systemBox, x, y)
	if is_equaliser(systemBox) then
		local equaliserButton = systemBox.table.equaliserButton
		equaliserButton:MouseMove(x - buttonOffset_x, y - buttonOffset_y, false)
	elseif systemBox.bPlayerUI and system_active then
		if is_in_hitbox(x, y, system_icon_hitbox[systemBox.pSystem.bNeedsPower]) then
			systemBox.pSystem.table.og_equalizer_system_hover = true
		else
			systemBox.pSystem.table.og_equalizer_system_hover = false
		end
	end
	return Defines.Chain.CONTINUE
end
script.on_internal_event(Defines.InternalEvents.SYSTEM_BOX_MOUSE_MOVE, mouse_move)

local system_effects = {[0] = {}, [1] = {}}
local system_sound_name = {[0] = "og_equalise", [1] = "og_equalise_enemy"}

local function activate_equalizer(system, shipManager)
	--print("activate_equalizer")
	local reduction = 0
	if system:GetEffectivePower() > 1 then reduction = damage_reduction_level * (system:GetEffectivePower() - 1) end
	local health_sum = 0
	local max_sum = 0
	local system_health = {}
	for target_system in vter(shipManager.vSystemList) do
		if target_system.table.og_equalizer_system_active or shipManager.iShipId == 1 then
			health_sum = health_sum + target_system.healthState.first
			max_sum = max_sum + target_system.healthState.second
			table.insert(system_health, {ref = target_system, health = target_system.healthState.first, max = target_system.healthState.second})
		end
	end
	if max_sum == 0 or health_sum == max_sum then return end
	local total_damage = max_sum - health_sum
	local healed_damage = math.ceil(total_damage * reduction)
	local new_health_sum = health_sum + healed_damage

	local p = new_health_sum / max_sum
	local floor_sum = 0
	for _, system_table in ipairs(system_health) do
		system_table.target_exact = system_table.max * p
		system_table.target_floor = math.floor(system_table.target_exact)
		system_table.fraction = system_table.target_exact - system_table.target_floor
		floor_sum = floor_sum + system_table.target_floor
	end
	local remainder = new_health_sum - floor_sum

	table.sort(system_health, function(a, b)
		return a.fraction > b.fraction
	end)

	for i, system_table in ipairs(system_health) do
		local final_health = system_table.target_floor
		if i <= remainder then
			final_health = final_health + 1
		end
		system_table.ref.healthState.first = math.min(final_health, system_table.max)
		if not system_table.ref.bNeedsPower then
			system_table.ref.powerState.first = system_table.ref.healthState.first
		end
	end

	if shipManager.iShipId == 0 then
		table.insert(system_effects[shipManager.iShipId], {location = shipManager:GetRoomCenter(system.roomId), time = 0})
	end
	Hyperspace.Sounds:PlaySoundMix(system_sound_name[shipManager.iShipId], -1, false)

	system:LockSystem(system_cooldown)
end

local stencil_mode = {ignore = 0, set = 1, use = 2}
local system_effect_stats = {
	speed = 750,
	duration = 2,
	width = 50,
	colour = Graphics.GL_Color(0, 0, 0, 0.05),
}
local COLOUR_WHITE   = Graphics.GL_Color(1, 1, 1, 1)
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	local remove_effect = nil
	for i, effect in ipairs(system_effects[shipManager.iShipId]) do
		effect.time = effect.time + time_increment(true)
		if effect.time >= system_effect_stats.duration then
			remove_effect = i
		end
	end
	if remove_effect then
		table.remove(system_effects[shipManager.iShipId], remove_effect)
	end
end)
script.on_render_event(Defines.RenderEvents.SHIP_MANAGER, function(shipManager, showInterior, doorControlMode) end, function(shipManager, showInterior, doorControlMode)

	for _, effect in ipairs(system_effects[shipManager.iShipId]) do
		local width = system_effect_stats.width * (1 + effect.time)
		Graphics.CSurface.GL_PushStencilMode()
		Graphics.CSurface.GL_SetStencilMode(stencil_mode.set, 1, 1)
		Graphics.CSurface.GL_DrawRect(
			-1280, 
			-720, 
			1280*3, 
			720*3, 
			COLOUR_WHITE
		)
		for i = 0, math.floor(width/2) - 5, 2 do
			local new_width_inner = (effect.time * system_effect_stats.speed) + i - width
			local new_width_outer = (effect.time * system_effect_stats.speed) - i
			if new_width_inner > 0 then
				Graphics.CSurface.GL_SetStencilMode(stencil_mode.set, 0, 1)
				Graphics.CSurface.GL_DrawCircle(effect.location.x, effect.location.y, new_width_inner, COLOUR_WHITE)
			end
			if new_width_outer > 0 then
				Graphics.CSurface.GL_SetStencilMode(stencil_mode.use, 1, 1)
				Graphics.CSurface.GL_DrawCircle(effect.location.x, effect.location.y, new_width_outer, system_effect_stats.colour)
			end
		end
		Graphics.CSurface.GL_SetStencilMode(stencil_mode.set, 0, 1)
		Graphics.CSurface.GL_DrawRect(
			-1280, 
			-720, 
			1280*3, 
			720*3, 
			COLOUR_WHITE
		)
		Graphics.CSurface.GL_PopStencilMode()
	end
	return Defines.Chain.CONTINUE
end)

local function mouse_click(systemBox, shift)
	--print("mouse_click:"..systemBox.pSystem.iSystemType)
	if is_equaliser(systemBox) then
		local equaliserButton = systemBox.table.equaliserButton
		if equaliserButton.bHover and equaliserButton.bActive then
			activate_equalizer(systemBox.pSystem, Hyperspace.ships(systemBox.pSystem._shipObj.iShipId))
		end
	end
	return Defines.Chain.CONTINUE
end
script.on_internal_event(Defines.InternalEvents.SYSTEM_BOX_MOUSE_CLICK, mouse_click)

script.on_internal_event(Defines.InternalEvents.ON_MOUSE_L_BUTTON_DOWN, function(x, y)
	if system_active then
		for system in vter(Hyperspace.ships.player.vSystemList) do
			if system.table.og_equalizer_system_hover then
				system.table.og_equalizer_system_active = not system.table.og_equalizer_system_active
			end
		end
	end
end)

local equaliserButtonBack = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/button_og_equaliser_base.png", buttonOffset_x, buttonOffset_y, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
local select_overlay_base = {
	on = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/equaliser_select_base.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	off = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/equaliser_select_base_inactive.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	hover = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/equaliser_select_base_hover.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
}
local select_overlay_aux = {
	on = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/equaliser_select_aux.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	off = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/equaliser_select_aux_inactive.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	hover = Hyperspace.Resources:CreateImagePrimitiveString( "systemUI/equaliser_select_aux_hover.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
}

local function equaliser_ready(shipSystem)
   return not (shipSystem:GetLocked() and shipSystem.iLockCount ~= -1) and shipSystem:Functioning() and shipSystem.iHackEffect <= 1
end

--Handles custom rendering
local function system_render(systemBox, ignoreStatus)
	if is_equaliser(systemBox) then
		local system = systemBox.pSystem
		local effectivePower = system:GetEffectivePower()
		local maxPower = system:GetMaxPower()
		local mousePos = Hyperspace.Mouse.position

		Graphics.CSurface.GL_RenderPrimitive(equaliserButtonBack)
		local equaliserButton = systemBox.table.equaliserButton
		equaliserButton:OnRender()
		equaliserButton.bActive = equaliser_ready(systemBox.pSystem)
		if equaliserButton.bHover then
			Hyperspace.Mouse.tooltip = button_hover_string
		end
	elseif systemBox.bPlayerUI and system_active then
		if systemBox.pSystem.table.og_equalizer_system_active == nil then systemBox.pSystem.table.og_equalizer_system_active = true end
		if systemBox.pSystem.table.og_equalizer_system_hover then
			if systemBox.pSystem.bNeedsPower then
				Graphics.CSurface.GL_RenderPrimitive(select_overlay_base.hover)
			else
				Graphics.CSurface.GL_RenderPrimitive(select_overlay_aux.hover)
			end
			if systemBox.pSystem.table.og_equalizer_system_active then
				Hyperspace.Mouse.tooltip = system_hover_text_on
			else
				Hyperspace.Mouse.tooltip = system_hover_text_off
			end
		elseif systemBox.pSystem.table.og_equalizer_system_active then
			if systemBox.pSystem.bNeedsPower then
				Graphics.CSurface.GL_RenderPrimitive(select_overlay_base.on)
			else
				Graphics.CSurface.GL_RenderPrimitive(select_overlay_aux.on)
			end
		else
			if systemBox.pSystem.bNeedsPower then
				Graphics.CSurface.GL_RenderPrimitive(select_overlay_base.off)
			else
				Graphics.CSurface.GL_RenderPrimitive(select_overlay_aux.off)
			end
		end
	end
end
script.on_render_event(Defines.RenderEvents.SYSTEM_BOX, function(systemBox, ignoreStatus) return Defines.Chain.CONTINUE end, system_render)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(systemName)) then
		if shipManager.iShipId == 0 then
			system_active = true
		end
		local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(systemName))
		if shipManager.iShipId == 1 then
			if equaliser_ready(system) then
				activate_equalizer(system, shipManager)
			end
		end
	elseif shipManager.iShipId == 0 then
		system_active = false
	end
end)

local function repair_reactor_power(shipManager)
	local system_sum = 0
	for system in vter(shipManager.vSystemList) do
		if system.bNeedsPower then
			system_sum = system_sum + system.powerState.first
		end
	end
	local powerManager = Hyperspace.PowerManager.GetPowerManager(0)
	local reactor_sum = powerManager.currentPower.first
	if reactor_sum > system_sum then
		log("OG - repair reactor power:"..tostring(shipManager.iShipId))
		--print("system_sum:"..tostring(system_sum).." reactor_sum:"..tostring(reactor_sum))
		powerManager.currentPower.first = system_sum
	end
end

script.on_internal_event(Defines.InternalEvents.JUMP_LEAVE, function(shipManager)
	if shipManager.iShipId == 0 then
		repair_reactor_power(shipManager)
	end
end)

local update_power_tick = {[0] = false, [1] = false}
script.on_internal_event(Defines.InternalEvents.CONSTRUCT_SHIP_MANAGER, function(shipManager)
	update_power_tick[shipManager.iShipId] = true
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if update_power_tick[shipManager.iShipId] then
		update_power_tick[shipManager.iShipId] = false
		repair_reactor_power(shipManager)
	end
	if shipManager.iShipId == 1 and shipManager:HasSystem(9) and shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(systemName)) then
		if shipManager:GetSystem(9).roomId == shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(systemName)).roomId then
			if math.random(2) == 1 then
				shipManager:RemoveSystem(Hyperspace.ShipSystem.NameToSystemId(systemName))
				print("remove equaliser")
			else
				shipManager:RemoveSystem(9)
				print("remove teleporter")
			end
		end
	end
end)

script.on_internal_event(Defines.InternalEvents.GENERATOR_CREATE_SHIP_POST, function(name, sector, event, bp, shipManager)
	print("test")
	print(bp.blueprintName)
	return Defines.Chain.CONTINUE
end)