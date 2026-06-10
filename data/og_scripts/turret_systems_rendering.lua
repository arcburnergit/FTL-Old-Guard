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

local findStartingTurret = mods.og.findStartingTurret
--TURRET DEFINITIONS
local systemName = "og_turret"
local microTurrets = mods.og.microTurrets
local systemNameList = mods.og.systemNameList

local systemCacheList = mods.og.systemCacheList

local systemNameCheck = {}
for _, sysName in ipairs(systemNameList) do
	systemNameCheck[sysName] = true
end

local turretBlueprintsList = mods.og.turretBlueprintsList 
local turrets = mods.og.turrets

local scrambler_radius = mods.og.scrambler_radius

local turret_location = mods.og.turret_location
local starting_turrets = mods.og.starting_turrets


local systemBlueprintVarName = mods.og.systemBlueprintVarName
local systemStateVarName = mods.og.systemStateVarName
local systemChargesVarName = mods.og.systemChargesVarName
local systemChainVarName = mods.og.systemChainVarName
local systemTimeVarName = mods.og.systemTimeVarName

local is_system = mods.og.is_system
local is_system_enemy = mods.og.is_system_enemy
local system_ready = mods.og.system_ready
--TURRET ENUMS
local turret_directions = mods.og.turret_directions
local defence_types = mods.og.defence_types
local chain_types = mods.og.chain_types
local turret_states = mods.og.turret_states

--HELPER FUNCTIONS
local get_charge_time = mods.og.get_charge_time

--RENDER TARGETING ICON
local targetingImage = {
	hover = Hyperspace.Resources:CreateImagePrimitiveString("og_turrets/crosshairs_placed_hover.png", -20, -20, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	temp = Hyperspace.Resources:CreateImagePrimitiveString("og_turrets/crosshairs_placed_temp.png", -20, -20, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	full = Hyperspace.Resources:CreateImagePrimitiveString("og_turrets/crosshairs_placed.png", -20, -20, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
}

local autoFireOffButton= mods.og.autoFireOffButton
local autoFireOnButton= mods.og.autoFireOnButton
--RENDER ROOM TARGETING
local function render_active_targeting(shipManager, otherManager, combatControl, system, currentTurret, ship)
	--print("render_active_targeting")
	if combatControl.selectedRoom >= 0 then
		for room in vter(ship.vRoomList) do
			if room.iRoomId == combatControl.selectedRoom then
				Graphics.CSurface.GL_RenderPrimitive(room.highlightPrimitive) -- highlight the room
				Graphics.CSurface.GL_RenderPrimitive(room.highlightPrimitive2)
			end
		end
		if currentTurret.blueprint_type ~= 3 then
			if currentTurret.shot_radius then
				local targetPos = shipManager:GetRoomCenter(combatControl.selectedRoom)
				Graphics.CSurface.GL_PushMatrix()
				Graphics.CSurface.GL_Translate(targetPos.x, targetPos.y, 0)
				Graphics.CSurface.GL_DrawCircle(0, 0, currentTurret.shot_radius, Graphics.GL_Color(1, 0, 0, 0.25))
				Graphics.CSurface.GL_PopMatrix()
			end
		elseif currentTurret.shot_radius then
			local targetShipGraph = Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId)
			local roomShape = targetShipGraph:GetRoomShape(combatControl.selectedRoom)
			local mousePosEnemy = worldToEnemyLocation(Hyperspace.Mouse.position)
			local slotId = find_closest_slot(roomShape, mousePosEnemy)
			local targetPos = targetShipGraph:GetSlotWorldPosition(slotId, combatControl.selectedRoom)
			Graphics.CSurface.GL_PushMatrix()
			Graphics.CSurface.GL_Translate(targetPos.x, targetPos.y, 0)
			Graphics.CSurface.GL_DrawCircle(0, 0, currentTurret.shot_radius, Graphics.GL_Color(1, 0, 0, 0.25))
			Graphics.CSurface.GL_PopMatrix()
		end
	end
end

local function render_targeting(shipManager, otherManager, system, currentTurret, currentTarget, temp)
	local targetPos = shipManager:GetRoomCenter(currentTarget.roomId)
	if currentTurret.blueprint_type == 3 then
		local targetShipGraph = Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId)
		targetPos = targetShipGraph:GetSlotWorldPosition(currentTarget.slotId, currentTarget.roomId)
	end
	Graphics.CSurface.GL_PushMatrix()
	Graphics.CSurface.GL_Translate(targetPos.x, targetPos.y, 0)
	if currentTurret.shot_radius then
		Graphics.CSurface.GL_DrawCircle(0, 0, currentTurret.shot_radius, Graphics.GL_Color(1, 0, 0, 0.25))
	end
	if temp then
		Graphics.CSurface.GL_RenderPrimitive(targetingImage.temp)
	else
		Graphics.CSurface.GL_RenderPrimitive(targetingImage.full)
	end
	Graphics.CSurface.GL_PopMatrix()
end

script.on_render_event(Defines.RenderEvents.SHIP_SPARKS, function(ship) return Defines.Chain.CONTINUE end, function(ship) 
	local shipManager = Hyperspace.ships(ship.iShipId)
	local otherManager = Hyperspace.ships(1 - ship.iShipId)
	local combatControl = Hyperspace.App.gui.combatControl
	for _, sysName in ipairs(systemNameList) do
		if otherManager and systemCacheList[otherManager.iShipId][sysName] then
			local system = otherManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(sysName))
			if system then
				local currentTurret = turrets[ system.table.blueprint ]
				if system.table.currentlyTargetting then
					render_active_targeting(shipManager, otherManager, combatControl, system, currentTurret, ship)
				elseif system.table.currentTarget and system.table.state == turret_states.defence and not system.table.currentlyTargetted then
					render_targeting(shipManager, otherManager, system, currentTurret, system.table.currentTarget, false)
				elseif system.table.currentTargetTemp and system.table.state == turret_states.defence and not system.table.currentlyTargetted then
					render_targeting(shipManager, otherManager, system, currentTurret, system.table.currentTargetTemp, true)
				end
			end
		end
	end
	return Defines.Chain.CONTINUE
end)

--RENDER DRONE TARGETING
local function render_target_icon(targetPos, otherManager, currentTurret, type)
	Graphics.CSurface.GL_PushMatrix()
	Graphics.CSurface.GL_Translate(targetPos.x, targetPos.y, 0)
	if currentTurret.shot_radius or (otherManager and otherManager:HasAugmentation("DEFENSE_SCRAMBLER") > 0) then
		local rad = (currentTurret.shot_radius or 0)
		rad = rad/2
		if otherManager and otherManager:HasAugmentation("DEFENSE_SCRAMBLER") > 0 then rad = rad + scrambler_radius end
		Graphics.CSurface.GL_DrawCircle(0, 0, rad, Graphics.GL_Color(1, 0, 0, 0.25))
	end
	if type == 1 then
		Graphics.CSurface.GL_RenderPrimitive(targetingImage.hover)
	elseif type == 2 then
		Graphics.CSurface.GL_RenderPrimitive(targetingImage.temp)
	else
		Graphics.CSurface.GL_RenderPrimitive(targetingImage.full)
	end
	Graphics.CSurface.GL_PopMatrix()
end

local function render_target_icon_vectors(shipManager, otherManager, currentTurret, spaceManager, currentTarget, temp)
	local type = (temp and 2) or 0
	for projectile in vter(spaceManager.projectiles) do
		if projectile._targetable:GetSelfId() == currentTarget._targetable:GetSelfId() and projectile._targetable:GetSpaceId() == shipManager.iShipId then
			local targetPos = currentTarget._targetable:GetRandomTargettingPoint(true)
			render_target_icon(targetPos, otherManager, currentTurret, type)
		end
	end
	for drone in vter(spaceManager.drones) do
		if drone._targetable:GetSelfId() == currentTarget._targetable:GetSelfId() and drone._targetable:GetSpaceId() == shipManager.iShipId then
			local targetPos = currentTarget._targetable:GetRandomTargettingPoint(true)
			render_target_icon(targetPos, otherManager, currentTurret, type)
		end
	end
end

local checkValidTarget = mods.og.checkValidTarget
local function find_closest_target(spaceManager, currentTurret, mousePosPlayer, mousePosEnemy, ship)
	local currentClosest = nil
	for projectile in vter(spaceManager.projectiles) do
		local blueprint = Hyperspace.Blueprints:GetWeaponBlueprint(projectile.extend.name)
		if checkValidTarget(projectile._targetable, currentTurret.defence_type, Hyperspace.ships.player) and not projectile.missed and not projectile.passedTarget and blueprint.typeName ~= "BEAM" and projectile._targetable:GetSpaceId() == ship.iShipId then
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
		if checkValidTarget(drone._targetable, currentTurret.defence_type, Hyperspace.ships.player) and not drone.bDead and drone._targetable:GetSpaceId() == ship.iShipId then
			local targetPos = drone._targetable:GetRandomTargettingPoint(true)
			local dist
			if drone._targetable:GetSpaceId() == 0 then
				dist = get_distance(mousePosPlayer, targetPos)
			else
				dist = 500
			end
			if (not currentClosest and dist < 20) or (currentClosest and dist < 20 and dist < currentClosest.dist) then
				currentClosest = {target = drone._targetable, dist = dist}
			end
		end
	end
	return currentClosest
end

script.on_render_event(Defines.RenderEvents.SHIP, function() return Defines.Chain.CONTINUE end, function(ship)
	local shipManager = Hyperspace.ships.player
	local otherManager = Hyperspace.ships.enemy
	local combatControl = Hyperspace.App.gui.combatControl
	for _, sysName in ipairs(systemNameList) do
		if systemCacheList[shipManager.iShipId][sysName] then
			local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(sysName))
			if system then
				local currentTurret = turrets[ system.table.blueprint ]
				local spaceManager = Hyperspace.App.world.space
				if system.table.currentlyTargetting then
					system.table.autoFireInvert = mods.og.ctrl_held
					local mousePosPlayer = worldToPlayerLocation(Hyperspace.Mouse.position)
					local mousePosEnemy = worldToEnemyLocation(Hyperspace.Mouse.position)
					local currentClosest = find_closest_target(spaceManager, currentTurret, mousePosPlayer, mousePosEnemy, ship)
					if currentClosest and currentClosest.target:GetSpaceId() == ship.iShipId then
						local targetPos = currentClosest.target:GetRandomTargettingPoint(true)
						render_target_icon(targetPos, otherManager, currentTurret, 1)
					end
				elseif system.table.currentTarget and (system.table.state == turret_states.offence or system.table.currentlyTargetted) and system.table.currentTarget._targetable:GetSpaceId() == ship.iShipId then
					render_target_icon_vectors(shipManager, otherManager, currentTurret, spaceManager, system.table.currentTarget, false)
				elseif system.table.currentTargetTemp and system.table.currentlyTargetted and system.table.currentTargetTemp._targetable:GetSpaceId() == ship.iShipId then
					render_target_icon_vectors(shipManager, otherManager, currentTurret, spaceManager, system.table.currentTargetTemp, false)
				end
			end
		end
	end
	return Defines.Chain.CONTINUE
end)

--RENDER SYSTEM UI
local UIOffset_x = mods.og.UIOffset_x
local UIOffset_y = mods.og.UIOffset_y

local autoFireX = mods.og.autoFireX
local autoFireY = mods.og.autoFireY

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

--TUTORIAL STUFF
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

script.on_render_event(Defines.RenderEvents.CHOICE_BOX, function() return Defines.Chain.CONTINUE end, function()
	local commandGui = Hyperspace.App.gui
	local eventManager = Hyperspace.Event
	if commandGui.event_pause and tutorialType == 3 then
		toggleArrow:OnRender()
	end
	return Defines.Chain.CONTINUE
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

local function render_tutorial_systemBox(systemBox)
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
end

--SYSTEM UI RENDER

local function system_render(systemBox, ignoreStatus)
	local systemId = Hyperspace.ShipSystem.SystemIdToName(systemBox.pSystem.iSystemType)
	local shipId = (systemBox.bPlayerUI and 0) or 1
	if is_system(systemBox) and systemBox.pSystem.table.blueprint ~= "" then
		local shipManager = Hyperspace.ships.player
		local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(systemId))

		local targetButton = systemBox.table.targetButton
		targetButton.bActive = system_ready(system) and not system.table.currentlyTargetting
		local offenceButton = systemBox.table.offenceButton
		offenceButton.bActive = system_ready(system) and system.table.state ~= turret_states.defence
		local defenceButton = systemBox.table.defenceButton
		defenceButton.bActive = system_ready(system) and system.table.state ~= turret_states.offence

		local currentTurret = turrets[ system.table.blueprint ]
		local maxCharges = currentTurret.charges
		local charges = system.table.charges
		
		local chargeTime = get_charge_time(currentTurret, system)

		local chargeTimeDisplay = math.ceil(chargeTime)
		local time = math.floor(0.5 + system.table.time * chargeTimeDisplay * 2)

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
		elseif system.table.currentlyTargetting and xor(mods.og.turret_autofire_setting == 0, system.table.autoFireInvert) then
			renderColour = c_auto
		elseif system.table.currentlyTargetting then
			renderColour = c_single
		elseif charges == maxCharges then
			renderColour = c_charged
		end

		if targetButton.bHover and not (systemBox.table.offenceButton.bHover or systemBox.table.defenceButton.bHover) then
			Graphics.CSurface.GL_RenderPrimitiveWithColor(turretBoxInnerHover, renderColour)
		end

		if system.table.state == turret_states.offence then
			if systemBox.table.offenceButton.bHover then
				Graphics.CSurface.GL_RenderPrimitiveWithColor(turretBoxToggleHover, renderColour)
			end
			Graphics.CSurface.GL_RenderPrimitive(turretBoxDefense)
		elseif system.table.state == turret_states.defence then
			if systemBox.table.defenceButton.bHover then
				Graphics.CSurface.GL_RenderPrimitiveWithColor(turretBoxToggleHover, renderColour)
			end
			Graphics.CSurface.GL_RenderPrimitive(turretBoxOffense)
		end
		Graphics.CSurface.GL_RenderPrimitiveWithColor(turretBoxInner, renderColour)

		local chainAmount = system.table.chain_level
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

		local blueprint = Hyperspace.Blueprints:GetWeaponBlueprint(system.table.blueprint)
		local barColour = renderColour
		Graphics.CSurface.GL_SetColor(renderColour)
		if currentTurret.chain and chainAmount > 0 then
			Graphics.freetype.easy_printAutoNewlines(6, 56, 35, 43, "+"..math.floor(chainAmount))
		end
		Graphics.freetype.easy_printAutoNewlines(6, 40, 19, 43, blueprint.desc.shortTitle:GetText())

		if system_ready(system) and not system.table.currentlyTargetting and (system.table.currentTarget or system.table.currentTargetTemp) then
			if xor(mods.og.turret_autofire_setting == 0, system.table.autoFireInvert) then
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
			Graphics.freetype.easy_printNewlinesCentered(51, 53, -2, 80, tostring(math.floor(0.5 + system.table.time * chargeTime * 10)/10).."/"..tostring(math.floor(0.5 + chargeTime * 10)/10))
		end
		
		--Graphics.CSurface.GL_RemoveColorTint()

		local timePercent = math.floor(0.5 + system.table.time * 33)
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
			if mods.og.turret_autofire_setting == 0 then
				autoFireOffButton:OnRender()
			else
				autoFireOnButton:OnRender()
			end
		end

		render_tutorial_systemBox(systemBox)

	elseif is_system(systemBox) then
		Graphics.CSurface.GL_RenderPrimitive(turretBox)
	end
	Graphics.CSurface.GL_SetColor(Graphics.GL_Color(1, 1, 1, 1))
	return Defines.Chain.CONTINUE
end
script.on_render_event(Defines.RenderEvents.SYSTEM_BOX, function(systemBox, ignoreStatus) return Defines.Chain.CONTINUE end, system_render)

--TURRET IMAGE RENDERING
local turret_mount = Hyperspace.Resources:CreateImagePrimitiveString("og_turrets/ship_turret_mount.png", -31, -31, 0, Graphics.GL_Color(1, 1, 1, 1) , 1, false)
local turret_mount_mini = Hyperspace.Resources:CreateImagePrimitiveString("og_turrets/ship_turret_mount_mini.png", -14, -14, 0, Graphics.GL_Color(1, 1, 1, 1) , 1, false)
local turret_mount_back = Hyperspace.Resources:CreateImagePrimitiveString("og_turrets/ship_turret_mount_back.png", -50, -50, 0, Graphics.GL_Color(1, 1, 1, 1) , 1, false)
local turret_mount_mini_back = Hyperspace.Resources:CreateImagePrimitiveString("og_turrets/ship_turret_mount_mini_back.png", -23, -23, 0, Graphics.GL_Color(1, 1, 1, 1) , 1, false)
local turret_mount_back_above = Hyperspace.Resources:CreateImagePrimitiveString("og_turrets/ship_turret_mount_back_above.png", -50, -50, 0, Graphics.GL_Color(1, 1, 1, 1) , 1, false)
local turret_mount_mini_back_above = Hyperspace.Resources:CreateImagePrimitiveString("og_turrets/ship_turret_mount_mini_back_above.png", -23, -23, 0, Graphics.GL_Color(1, 1, 1, 1) , 1, false)

local stencil_mode = {ignore = 0, set = 1, use = 2}
local turretHover_text = {
	charges = Hyperspace.Text:GetText("og_lua_turret_hover_charges"),
	time = Hyperspace.Text:GetText("og_lua_turret_hover_time")
}
local function renderAdaptiveSpritesBelow(sysName, turretLoc, shipCorner)
	Graphics.CSurface.GL_PushMatrix()
	Graphics.CSurface.GL_Translate(shipCorner.x + turretLoc.x, shipCorner.y + turretLoc.y, 0)
	if microTurrets[sysName] then
		Graphics.CSurface.GL_RenderPrimitive(turret_mount_mini_back)
	else
		Graphics.CSurface.GL_RenderPrimitive(turret_mount_back)
	end
	Graphics.CSurface.GL_PopMatrix()
end
local function renderAdaptiveSpritesAbove(sysName, turretLoc, shipCorner)
	Graphics.CSurface.GL_PushMatrix()
	Graphics.CSurface.GL_Translate(shipCorner.x + turretLoc.x, shipCorner.y + turretLoc.y, 0)
	if microTurrets[sysName] then
		Graphics.CSurface.GL_RenderPrimitive(turret_mount_mini_back_above)
	else
		Graphics.CSurface.GL_RenderPrimitive(turret_mount_back_above)
	end
	Graphics.CSurface.GL_PopMatrix()
end

local function renderShipSpriteShrunk(ship, shipGraph, shipSize, scale)

	Graphics.CSurface.GL_PushMatrix()
	Graphics.CSurface.GL_Translate(shipGraph.shipBox.x + ship.shipImage.x + shipSize.x, shipGraph.shipBox.y + ship.shipImage.y + shipSize.y, 0)
	Graphics.CSurface.GL_Scale(scale, scale, 1)
	Graphics.CSurface.GL_Translate(-1 * (ship.shipImage.x + shipSize.x), -1 * (ship.shipImage.y + shipSize.y), 0)
	Graphics.CSurface.GL_RenderPrimitiveWithAlpha(ship.shipImagePrimitive, 1)
	Graphics.CSurface.GL_PopMatrix()
end

local function renderAdaptiveBack(shipManager, ship, spaceManager, shipGraph, sysName)
	local turretLoc = turret_location[ship.shipName] and turret_location[ship.shipName][sysName] or {x = 0, y = 0}
	local shipCorner = {x = ship.shipImage.x + shipGraph.shipBox.x, y = ship.shipImage.y + shipGraph.shipBox.y}
	local shipSize = {x = math.floor(ship.shipImage.w/2), y = math.floor(ship.shipImage.h/2)}

	renderAdaptiveSpritesAbove(sysName, turretLoc, shipCorner)

	--/////////////// PHASE A \\\\\\\\\\\\\\\\\\\
	--Draw 1s to 00000001
	Graphics.CSurface.GL_PushStencilMode()
	Graphics.CSurface.GL_SetStencilMode(stencil_mode.set, 1, 1)
	Graphics.CSurface.GL_DrawRect(
		-1280, 
		-720, 
		1280*3, 
		720*3, 
		Graphics.GL_Color(1, 1, 1, 1)
	)

	--Cut out ship unshrunk
	Graphics.CSurface.GL_SetStencilMode(stencil_mode.set, 0, 1)

	renderShipSpriteShrunk(ship, shipGraph, shipSize, 1)

	Graphics.CSurface.GL_PushMatrix()
	Graphics.CSurface.GL_Translate(shipGraph.shipBox.x, shipGraph.shipBox.y, 0)
	Graphics.CSurface.GL_RenderPrimitiveWithAlpha(ship.floorPrimitive, 1)
	Graphics.CSurface.GL_PopMatrix()

	--Render turret below section
	Graphics.CSurface.GL_SetStencilMode(stencil_mode.use, 1, 1)

	renderAdaptiveSpritesBelow(sysName, turretLoc, shipCorner)

	--Reset buffer bit 1
	Graphics.CSurface.GL_SetStencilMode(stencil_mode.set, 0, 1)
	Graphics.CSurface.GL_DrawRect(
		-1280, 
		-720, 
		1280*3, 
		720*3, 
		Graphics.GL_Color(1, 1, 1, 1)
	)

	--/////////////// PHASE B \\\\\\\\\\\\\\\\\\\
	--Now set 1s to unshrunk ship
	Graphics.CSurface.GL_SetStencilMode(stencil_mode.set, 1, 1)

	renderShipSpriteShrunk(ship, shipGraph, shipSize, 1)

	--Cut out ship shrunk ship
	Graphics.CSurface.GL_SetStencilMode(stencil_mode.set, 0, 1)

	renderShipSpriteShrunk(ship, shipGraph, shipSize, 0.975)

	Graphics.CSurface.GL_PushMatrix()
	Graphics.CSurface.GL_Translate(shipGraph.shipBox.x, shipGraph.shipBox.y, 0)
	Graphics.CSurface.GL_RenderPrimitiveWithAlpha(ship.floorPrimitive, 1)
	Graphics.CSurface.GL_PopMatrix()

	--Render turret below section on border between the two scales of ship
	Graphics.CSurface.GL_SetStencilMode(stencil_mode.use, 1, 1)

	renderAdaptiveSpritesBelow(sysName, turretLoc, shipCorner)

	--Reset buffer bit 2
	Graphics.CSurface.GL_SetStencilMode(stencil_mode.set, 0, 1)
	Graphics.CSurface.GL_DrawRect(
		-1280, 
		-720, 
		1280*3, 
		720*3, 
		Graphics.GL_Color(1, 1, 1, 1)
	)

	Graphics.CSurface.GL_SetStencilMode(stencil_mode.ignore, 1, 1)
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

local function renderTurret(shipManager, ship, spaceManager, shipGraph, sysName)
	--print("ship:"..shipManager.iShipId.." jump first:"..shipManager.jump_timer.first.." second:"..shipManager.jump_timer.second.." bJumping"..tostring(shipManager.bJumping))
	if shipManager.bJumping and shipManager.iShipId == 1 then return end
	
	if sysName == "og_turret_adaptive" or sysName == "og_turret_adaptive_2" or sysName == "og_turret_adaptive_single" then
		renderAdaptiveBack(shipManager, ship, spaceManager, shipGraph, sysName)
	end
	local system = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(sysName))
	local currentTurret = nil
	if Hyperspace.App.menu.shipBuilder.bOpen then
		local id, i = findStartingTurret(shipManager, sysName)
		if id then currentTurret = turrets[id] end
		if not currentTurret then return end

		local turretLoc = turret_location[ship.shipName] and turret_location[ship.shipName][sysName] or {x = 0, y = 0, direction = 0}
		local shipCorner = {x = ship.shipImage.x + shipGraph.shipBox.x, y = ship.shipImage.y + shipGraph.shipBox.y}
		local angleSet = 90 * turretLoc.direction
		local colour = Graphics.GL_Color(1,1,1,1)

		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(shipCorner.x + turretLoc.x, shipCorner.y + turretLoc.y, 0)
		Graphics.CSurface.GL_Rotate(angleSet, 0, 0, 1)
		if system.table.image and system.table.image.animName == currentTurret.image then
			system.table.image:OnRender(1, colour, false)
		else
			system.table.image = Hyperspace.Animations:GetAnimation(currentTurret.image)
			system.table.image.position.x = -1 * system.table.image.info.frameWidth/2
			system.table.image.position.y = -1 * system.table.image.info.frameHeight/2
			system.table.image.tracker.loop = false
		end
		if currentTurret.charge_image then
			Graphics.CSurface.GL_RenderPrimitiveWithAlpha(currentTurret.charge_image, 1)
		end
		if currentTurret.chain and currentTurret.chain.image then
			currentTurret.chain.image:SetCurrentFrame(currentTurret.chain.count - 1)
			currentTurret.chain.image:OnRender(1, Graphics.GL_Color(1,1,1,1), false)
		end
		if currentTurret.glow then

			if system.table.glow and system.table.glow.animName == currentTurret.glow then
				system.table.glow:SetCurrentFrame(currentTurret.charges - 1)
				system.table.glow:OnRender(1, colour, false)
			else
				system.table.glow = Hyperspace.Animations:GetAnimation(currentTurret.glow)
				system.table.glow.position.x = -1 * system.table.glow.info.frameWidth/2
				system.table.glow.position.y = -1 * system.table.glow.info.frameHeight/2
				system.table.glow.tracker.loop = false
			end
		end
		Graphics.CSurface.GL_PopMatrix()
	elseif system.table.blueprint ~= "" then
		currentTurret = turrets[ system.table.blueprint ]
		if not currentTurret then return end

		local turretLoc = turret_location[ship.shipName] and turret_location[ship.shipName][sysName] or {x = 0, y = 0}
		local shipCorner = {x = ship.shipImage.x + shipGraph.shipBox.x, y = ship.shipImage.y + shipGraph.shipBox.y}
		local angleSet = system.table.currentAimingAngle or 0
		local colour = Graphics.GL_Color(1,1,1,1)
		if shipManager.ship.bCloaked then
			colour = Graphics.GL_Color(1,1,1,0.5)
		end

		local charges = system.table.charges
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(shipCorner.x + turretLoc.x, shipCorner.y + turretLoc.y, 0)
		Graphics.CSurface.GL_Rotate(angleSet, 0, 0, 1)
		if (not currentTurret.charging_anim) or system.table.image.currentFrame > 0 then
			if system.table.image and system.table.image.animName == currentTurret.image then
				system.table.image:OnRender(1, colour, false)
			else
				system.table.image = Hyperspace.Animations:GetAnimation(currentTurret.image)
				system.table.image.position.x = -1 * system.table.image.info.frameWidth/2
				system.table.image.position.y = -1 * system.table.image.info.frameHeight/2
				system.table.image.tracker.loop = false
			end
		else
			if system.table.charging_anim and system.table.charging_anim.animName == currentTurret.charging_anim then
				system.table.charging_anim:OnRender(1, colour, false)
			else
				system.table.charging_anim = Hyperspace.Animations:GetAnimation(currentTurret.charging_anim)
				system.table.charging_anim.position.x = -1 * system.table.charging_anim.info.frameWidth/2
				system.table.charging_anim.position.y = -1 * system.table.charging_anim.info.frameHeight/2
				system.table.charging_anim.tracker.loop = false
			end
		end
		if currentTurret.charge_image then
			Graphics.CSurface.GL_RenderPrimitiveWithAlpha(currentTurret.charge_image, system.table.time or 1)
		end
		local chains = Hyperspace.playerVariables[math.floor(shipManager.iShipId)..sysName..systemChainVarName]
		if currentTurret.chain and currentTurret.chain.image and chains > 0 then
			currentTurret.chain.image:SetCurrentFrame(chains - 1)
			currentTurret.chain.image:OnRender(1, Graphics.GL_Color(1,1,1,1), false)
		end
		if currentTurret.glow and charges > 0 and (not currentTurret.hide_glow_firing or system.table.image.currentFrame <= 0) then
			if system.table.glow and system.table.glow.animName == currentTurret.glow then
				system.table.glow:SetCurrentFrame(charges - 1)
				system.table.glow:OnRender(1, Graphics.GL_Color(1,1,1,1), false)
			else
				system.table.glow = Hyperspace.Animations:GetAnimation(currentTurret.glow)
				system.table.glow.position.x = -1 * system.table.glow.info.frameWidth/2
				system.table.glow.position.y = -1 * system.table.glow.info.frameHeight/2
				system.table.glow.tracker.loop = false
			end
		end

		if currentTurret.custom_animations then
			if not system.table.custom_animations then system.table.custom_animations = {} end
			for id, anim_table in ipairs(currentTurret.custom_animations) do
				if system.table.custom_animations[id] and system.table.custom_animations[id].tracker.running then
					system.table.glow:OnRender(1, Graphics.GL_Color(1,1,1,1), false)
				end
			end
		end

		Graphics.CSurface.GL_PopMatrix()
		local mousePosEnemy = worldToEnemyLocation(Hyperspace.Mouse.position)
		local turretLocCorrected = {x = shipCorner.x + turretLoc.x, y = shipCorner.y + turretLoc.y}
		if shipManager.iShipId == 1 and get_distance(mousePosEnemy, turretLocCorrected) <= 15 then
			local s = string.format(turretHover_text.charges, math.floor(charges), math.floor(currentTurret.charges))
			if Hyperspace.ships.player:HasSystem(7) and Hyperspace.ships.player:GetSystem(7):GetEffectivePower() >= 2 then
				local chargeTime = get_charge_time(currentTurret, system)
				s = s .. string.format(turretHover_text.time, math.floor(0.5 + system.table.time * chargeTime * 10)/10, math.floor(0.5 + chargeTime * 10)/10)
			end
			Hyperspace.Mouse.tooltip = s
			Hyperspace.Mouse.bForceTooltip = true
		end
	end
end

local player_jump_timer = 0
local player_arrive_timer = 0
script.on_render_event(Defines.RenderEvents.SHIP_MANAGER, function(shipManager) return Defines.Chain.CONTINUE end, function(shipManager) 
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
	for _, sysName in ipairs(systemNameList) do
		if shipManager:HasSystem(Hyperspace.ShipSystem.NameToSystemId(sysName)) and not microTurrets[sysName] then
			renderTurret(shipManager, ship, spaceManager, shipGraph, sysName)		
		end
	end
	return Defines.Chain.CONTINUE
end)