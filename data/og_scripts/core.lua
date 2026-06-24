local version = {major = 1, minor = 20}
if not (Hyperspace.version and Hyperspace.version.major == version.major and Hyperspace.version.minor >= version.minor) then
	error("Incorrect Hyperspace version detected! The Outer Expansion requires Hyperspace "..version.major.."."..version.minor.."+")
end
mods.og = {}
local time_increment = mods.multiverse.time_increment
local vter = mods.multiverse.vter
local userdata_table = mods.multiverse.userdata_table

--TURRET SYSTEM CORE
function mods.og.get_room_at_location(shipManager, location, includeWalls)
	return Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId):GetSelectedRoom(location.x, location.y, includeWalls)
end
local get_room_at_location = mods.og.get_room_at_location

function mods.og.xor(a, b)
	return (a and not b) or (not a and b)
end
local xor = mods.og.xor

function mods.og.isPointInEllipse(point, ellipse)
	if ellipse.a <= 0 or ellipse.b <= 0 then
		return false
	end
	local dx = point.x - ellipse.center.x
	local dy = point.y - ellipse.center.y
	local result = (dx^2 / ellipse.a^2) + (dy^2 / ellipse.b^2)

	return result <= 1
end
local isPointInEllipse = mods.og.isPointInEllipse

function mods.og.worldToPlayerLocation(location)
	local cApp = Hyperspace.App
	local combatControl = cApp.gui.combatControl
	local playerPosition = combatControl.playerShipPosition
	if cApp.menu.shipBuilder.bOpen then
		local commandGui = cApp.gui
		return Hyperspace.Point(location.x - commandGui.shipPosition.x - 30, location.y - commandGui.shipPosition.y + 139)
	end
	return Hyperspace.Point(location.x - playerPosition.x, location.y - playerPosition.y)
end
function mods.og.worldToEnemyLocation(location)
	local cApp = Hyperspace.App
	local combatControl = cApp.gui.combatControl
	local position = combatControl.position
	local targetPosition = combatControl.targetPosition
	local enemyShipOriginX = position.x + targetPosition.x
	local enemyShipOriginY = position.y + targetPosition.y
	return Hyperspace.Point(location.x - enemyShipOriginX, location.y - enemyShipOriginY)
end
local worldToPlayerLocation = mods.og.worldToPlayerLocation
local worldToEnemyLocation = mods.og.worldToEnemyLocation

function mods.og.get_distance(point1, point2)
	return math.sqrt(((point2.x - point1.x)^ 2)+((point2.y - point1.y) ^ 2))
end
local get_distance = mods.og.get_distance

function mods.og.offset_point_in_direction(position, angle, offset_x, offset_y)
	local alpha = math.rad(angle)
	local newX = position.x - (offset_y * math.cos(alpha)) - (offset_x * math.cos(alpha+math.rad(90)))
	local newY = position.y - (offset_y * math.sin(alpha)) - (offset_x * math.sin(alpha+math.rad(90)))
	return Hyperspace.Pointf(newX, newY)
end
local offset_point_in_direction = mods.og.offset_point_in_direction

function mods.og.get_random_point_in_radius(center, radius)
	r = radius * math.sqrt(math.random())
	theta = math.random() * 2 * math.pi
	return Hyperspace.Pointf(center.x + r * math.cos(theta), center.y + r * math.sin(theta))
end
local get_random_point_in_radius = mods.og.get_random_point_in_radius

function mods.og.normalize_angle(angle)
	angle = angle % 360
	if angle < 0 then
		angle = angle + 360
	end
	return angle
end
local normalize_angle = mods.og.normalize_angle

function mods.og.angle_diff(angle1, angle2)
	local diff = angle2 - angle1
	while diff > 180 do
		diff = diff - 360
	end
	while diff < -180 do
		diff = diff + 360
	end
	return diff
end
local angle_diff = mods.og.angle_diff

function mods.og.move_angle_to(current_angle, target_angle, max_rotation)
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
local move_angle_to = mods.og.move_angle_to

function mods.og.get_angle_between_points(pos, target_pos)
	local alpha = math.atan((target_pos.y-pos.y), (target_pos.x-pos.x))
	return normalize_angle(math.deg(alpha))
end
local get_angle_between_points = mods.og.get_angle_between_points

function mods.og.find_intercept_angle(current_pos, speed, target_pos, target_velocity)
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
local find_intercept_angle = mods.og.find_intercept_angle

function mods.og.find_closest_slot(roomShape, pos)
	local slotSize = 35
	local relX = pos.x - roomShape.x
	local relY = pos.y - roomShape.y
	if relX < 0 or relX >= roomShape.w or relY < 0 or relY >= roomShape.h then
		return 0
	end
	local slotsPerRow = math.floor(roomShape.w / slotSize)
	local col = math.floor(relX / slotSize)
	local row = math.floor(relY / slotSize)
	local slotID = (row * slotsPerRow) + col

	return slotID
end
local find_closest_slot = mods.og.find_closest_slot

mods.og.key_names = {
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
local key_names = mods.og.key_names
--OTHER CORE
local beamDamageMods = mods.multiverse.beamDamageMods
beamDamageMods["OG_FOCUS_PROJECTILE_FAKE"] = {iDamage = 0}
beamDamageMods["OG_FOCUS_PROJECTILE_WEAK_FAKE"] = {iDamage = 0}
beamDamageMods["OG_FOCUS_PROJECTILE_BIO"] = {iDamage = 0}
beamDamageMods["OG_LOOT_PROJECTILE_SLUG_1"] = {iDamage = 0}
beamDamageMods["OG_FOCUS_PROJECTILE_BIO_FAKE"] = {iDamage = 0}
beamDamageMods["OG_FOCUS_PROJECTILE_SOULPLAGUE"] = {iDamage = 0}
beamDamageMods["OG_FOCUS_PROJECTILE_SOULPLAGUE_FAKE"] = {iDamage = 0}

mods.multiverse.astrometricsSectors.og = {
	civilian = 0,
	neutral = 1,
	hostile = 0,
	hazard = 0
}

local repCombos = mods.multiverse.repCombos
repCombos.rep_comb_og_iron = {
	rep_og_iron = {buffer = 0},
	rep_pirate = {buffer = 2},
	rep_og_dawn = {buffer = 0, invert = true}
}
repCombos.rep_comb_all.rep_og_iron = {buffer = 0}

local pulsar_power = {}
pulsar_power["human_og_raider"] = 2

local crewStatName = {
	[0] = "MAX_HEALTH",
	"STUN_MULTIPLIER",
	"MOVE_SPEED_MULTIPLIER",
	"REPAIR_SPEED_MULTIPLIER",
	"DAMAGE_MULTIPLIER",
	"RANGED_DAMAGE_MULTIPLIER",
	"DOOR_DAMAGE_MULTIPLIER",
	"FIRE_REPAIR_MULTIPLIER",
	"SUFFOCATION_MODIFIER",
	"FIRE_DAMAGE_MULTIPLIER",
	"OXYGEN_CHANGE_SPEED",
	"DAMAGE_TAKEN_MULTIPLIER",
	"CLONE_SPEED_MULTIPLIER",
	"PASSIVE_HEAL_AMOUNT",
	"TRUE_PASSIVE_HEAL_AMOUNT",
	"TRUE_HEAL_AMOUNT",
	"PASSIVE_HEAL_DELAY",
	"ACTIVE_HEAL_AMOUNT",
	"SABOTAGE_SPEED_MULTIPLIER",
	"ALL_DAMAGE_TAKEN_MULTIPLIER",
	"HEAL_SPEED_MULTIPLIER",
	"HEAL_CREW_AMOUNT",
	"DAMAGE_ENEMIES_AMOUNT",
	"BONUS_POWER",
	"POWER_DRAIN",
	"ESSENTIAL",
	"CAN_FIGHT",
	"CAN_REPAIR",
	"CAN_SABOTAGE",
	"CAN_MAN",
	"CAN_TELEPORT",
	"CAN_SUFFOCATE",
	"CONTROLLABLE",
	"CAN_BURN",
	"IS_TELEPATHIC",
	"RESISTS_MIND_CONTROL",
	"IS_ANAEROBIC",
	"CAN_PHASE_THROUGH_DOORS",
	"DETECTS_LIFEFORMS",
	"CLONE_LOSE_SKILLS",
	"POWER_DRAIN_FRIENDLY",
	"DEFAULT_SKILL_LEVEL",
	"POWER_RECHARGE_MULTIPLIER",
	"HACK_DOORS",
	"NO_CLONE",
	"NO_SLOT",
	"NO_AI",
	"VALID_TARGET",
	"CAN_MOVE",
	"TELEPORT_MOVE",
	"TELEPORT_MOVE_OTHER_SHIP",
	"SILENCED",
	"LOW_HEALTH_THRESHOLD",
	"NO_WARNING",

	"CREW_SLOTS", 
	"ACTIVATE_WHEN_READY",
	"STAT_BOOST",
	"DEATH_EFFECT",
	"POWER_EFFECT",
	"POWER_MAX_CHARGES",
	"POWER_CHARGES_PER_JUMP",
	"POWER_COOLDOWN",
	"TRANSFORM_RACE"
}

script.on_internal_event(Defines.InternalEvents.CALCULATE_STAT_POST, function(crewmem, stat, def, amount, value)
	local spaceManager = Hyperspace.App.world.space
	--[[if pulsar_power[crewmem.type] then 
		print(stat.." "..Hyperspace.CrewStat[stat].." "..crewStatName[stat])
	end]]
	local pulsar_active = spaceManager.pulsarLevel or spaceManager.bStorm or Hyperspace.playerVariables.loc_environment_og_neutron_beam > 0
	if pulsar_power[crewmem.type] and stat == Hyperspace.CrewStat.BONUS_POWER and (pulsar_active) then
		amount = amount + pulsar_power[crewmem.type]
	elseif pulsar_power[crewmem.type] and (stat == Hyperspace.CrewStat.IS_TELEPATHIC) and (spaceManager.bNebula or spaceManager.bStorm or Hyperspace.playerVariables.loc_environment_lightnebula > 0) then
		value = true
	elseif pulsar_power[crewmem.type] and (stat == Hyperspace.CrewStat.DETECTS_LIFEFORMS or stat == Hyperspace.CrewStat.RESISTS_MIND_CONTROL) and (pulsar_active or Hyperspace.playerVariables.loc_environment_lightnebula >= 1) then
		value = false
	end
	return Defines.Chain.CONTINUE, amount, value
end)

script.on_internal_event(Defines.InternalEvents.HAS_EQUIPMENT, function(shipManager, equipment, value)
	if equipment == "LIST_CREW_POWER" then
		local spaceManager = Hyperspace.App.world.space
		if spaceManager.pulsarLevel then
			for crewmem in vter(Hyperspace.ships.player.vCrewList) do
				if pulsar_power[crewmem.type] and crewmem.iShipId == shipManager.iShipId then
					value = value + 1
				end
			end
			for crewmem in vter(Hyperspace.ships.enemy.vCrewList) do
				if pulsar_power[crewmem.type] and crewmem.iShipId == shipManager.iShipId then
					value = value + 1
				end
			end
		end
	end
	return Defines.Chain.CONTINUE, value
end)

local create_damage_message = mods.multiverse.create_damage_message
local damageMessages = mods.multiverse.damageMessages
local function handle_reduction_armor(ship, projectile, location, damage, immediateDmgMsg)
	if ship:HasAugmentation("OG_REFLECTIVE_PLATING") > 0 then
		--print("REDUCE DAMAGE:"..tostring(damage.iDamage))
		-- Check if incoming damage is greater than the reduction amount
		if damage.iDamage > 0 then
			damage.iDamage = math.max(1, math.floor(damage.iDamage * ship:GetAugmentationValue("OG_REFLECTIVE_PLATING")))
		elseif damage.iDamage < 0 then
			damage.iDamage = math.min(-1, math.ceil(damage.iDamage * ship:GetAugmentationValue("OG_REFLECTIVE_PLATING")))
		end
		if damage.iSystemDamage > 0 then
			damage.iSystemDamage = math.max(1, math.floor(damage.iSystemDamage * ship:GetAugmentationValue("OG_REFLECTIVE_PLATING")))
		elseif damage.iSystemDamage < 0 then
			damage.iSystemDamage = math.min(-1, math.ceil(damage.iSystemDamage * ship:GetAugmentationValue("OG_REFLECTIVE_PLATING")))
		end
		if damage.iPersDamage > 0 then
			damage.iPersDamage = math.max(1, math.floor(damage.iPersDamage * ship:GetAugmentationValue("OG_REFLECTIVE_PLATING")))
		elseif damage.iPersDamage < 0 then
			damage.iPersDamage = math.min(-1, math.ceil(damage.iPersDamage * ship:GetAugmentationValue("OG_REFLECTIVE_PLATING")))
		end
		if damage.iIonDamage > 0 then
			damage.iIonDamage = math.max(1, math.floor(damage.iIonDamage * ship:GetAugmentationValue("OG_REFLECTIVE_PLATING")))
		elseif damage.iIonDamage < 0 then
			damage.iIonDamage = math.min(-1, math.ceil(damage.iIonDamage * ship:GetAugmentationValue("OG_REFLECTIVE_PLATING")))
		end
		if damage.fireChance > 0 then
			damage.fireChance = math.max(1, math.floor(damage.fireChance * ship:GetAugmentationValue("OG_REFLECTIVE_PLATING")))
		end
		if damage.breachChance > 0 then
			damage.breachChance = math.max(1, math.floor(damage.breachChance * ship:GetAugmentationValue("OG_REFLECTIVE_PLATING")))
		end
	end
end
script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(ship, projectile, location, damage, realNewTile, beamHitType)
	if beamHitType == Defines.BeamHit.NEW_ROOM then
		handle_reduction_armor(ship, projectile, location, damage, true)
	end
	return Defines.Chain.CONTINUE, beamHitType
end)

script.on_internal_event(Defines.InternalEvents.POWER_ON_UPDATE, function(power)
	--local benchmark_start = os.clock()
	if power.temporaryPowerActive then
		local crewmem = power.crew
		if crewmem.type == "human_og_dawn" then
			if crewmem.bFighting then
				--power.temporaryPowerDuration.first = power.temporaryPowerDuration.first + time_increment(true)
			elseif crewmem:Repairing() then
				power.temporaryPowerDuration.first = power.temporaryPowerDuration.first + 0.25 * time_increment(true)
			elseif not crewmem:AtGoal() then
				power.temporaryPowerDuration.first = power.temporaryPowerDuration.first + 0.75 * time_increment(true)
			else
				power.temporaryPowerDuration.first = math.min(power.temporaryPowerDuration.second, power.temporaryPowerDuration.first + 1.25 * time_increment(true))
			end
		end
	end
	--local benchmark_end = os.clock()
	--print(string.format("core.lua POWER_ON_UPDATE 1: time: %.6f seconds", benchmark_end - benchmark_start))
	return Defines.Chain.CONTINUE
end)

local repToShow = {
	{id = "rep_comb_og_iron", name = Hyperspace.Text:GetText("og_lua_turret_rep_iron")},
	{id = "rep_og_dawn", name = Hyperspace.Text:GetText("og_lua_turret_rep_dawn"), hidden = true},
}

local emptyReq = Hyperspace.ChoiceReq()
script.on_internal_event(Defines.InternalEvents.PRE_CREATE_CHOICEBOX, function(event)
	if event.eventName == "STORAGE_CHECK_STATUS_NOTORIETY" then
		local eventManager = Hyperspace.Event
		for _, rep in ipairs(repToShow) do
			if not rep.hidden or Hyperspace.playerVariables[rep.id] ~= 0 then
				local repVal = Hyperspace.playerVariables[rep.id]
				local s = rep.name.." ["..math.floor(repVal).."]"
				local invalidEvent = eventManager:CreateEvent("OPTION_INVALID", 0, false)
				event:AddChoice(invalidEvent, s, emptyReq, true)
			end
		end
	end
end)

local roomIconImageString = "effects/og_vunerable_icon"
local tileImageString = "effects/og_vunerable_back"
local wallImageString = "effects/og_vunerable"
local roomIconImage =  Hyperspace.Resources:CreateImagePrimitiveString( (roomIconImageString..".png") , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
local tileImage =  Hyperspace.Resources:CreateImagePrimitiveString( (tileImageString..".png") , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
local wallImage =  {
	up = Hyperspace.Resources:CreateImagePrimitiveString( (wallImageString.."_up.png") , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	right = Hyperspace.Resources:CreateImagePrimitiveString( (wallImageString.."_right.png") , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	down = Hyperspace.Resources:CreateImagePrimitiveString( (wallImageString.."_down.png") , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
	left = Hyperspace.Resources:CreateImagePrimitiveString( (wallImageString.."_left.png") , 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
}

function mods.og.render_vunerable(room)
	--print("render_vunerable:"..room.iRoomId)
	if Hyperspace.App.menu.shipBuilder.bOpen then return end
	local opacity = 0.5
	local x = room.rect.x
	local y = room.rect.y
	local w = math.floor(room.rect.w/35)
	local h = math.floor(room.rect.h/35)
	local size = w * h
	--print("room:"..room.iRoomId.." gasLevel:"..gasLevel.." w:"..w.." h:"..h.." size:"..size)
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
		Graphics.CSurface.GL_RenderPrimitiveWithAlpha(wallImage.up, opacity)
		Graphics.CSurface.GL_PopMatrix()

		local yOff = y + (h-1) * 35
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(xOff, yOff, 0)
		Graphics.CSurface.GL_RenderPrimitiveWithAlpha(wallImage.down, opacity)
		Graphics.CSurface.GL_PopMatrix()
	end
	-- left and right edge
	for i = 0, h - 1 do
		local yOff = y + i * 35
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(x, yOff, 0)
		Graphics.CSurface.GL_RenderPrimitiveWithAlpha(wallImage.left, opacity)
		Graphics.CSurface.GL_PopMatrix()

		local xOff = x + (w-1) * 35
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(xOff, yOff, 0)
		Graphics.CSurface.GL_RenderPrimitiveWithAlpha(wallImage.right, opacity)
		Graphics.CSurface.GL_PopMatrix()
	end
	Graphics.CSurface.GL_PushMatrix()
	Graphics.CSurface.GL_Translate(x, y, 0)
	Graphics.CSurface.GL_RenderPrimitive(roomIconImage)
	Graphics.CSurface.GL_PopMatrix()
end
local render_vunerable = mods.og.render_vunerable

mods.og.vunerable_weapons = {}
local vunerable_weapons = mods.og.vunerable_weapons
vunerable_weapons["OG_LASER_PROJECTILE_BASE_DAWN"] = 10
vunerable_weapons["OG_LASER_PROJECTILE_HEAVY_DAWN"] = 10
vunerable_weapons["OG_LASER_PROJECTILE_LIGHT_DAWN"] = 10
vunerable_weapons["OG_ION_PROJECTILE_BASE_DAWN"] = 10
vunerable_weapons["OG_MISSILE_PROJECTILE_HEAVY_DAWN"] = 10
vunerable_weapons["OG_FLAK_PROJECTILE_DAWN"] = 10
vunerable_weapons["OG_FOCUS_PROJECTILE_DAWN"] = 5
vunerable_weapons["OG_FOCUS_PROJECTILE_WEAK_DAWN"] = 5
vunerable_weapons["LOOT_OG_DAWN_1"] = 5

mods.og.vunerable_rooms = {[0] = {}, [1] = {}}
local vunerable_rooms = mods.og.vunerable_rooms
script.on_init(function()
	mods.og.vunerable_rooms = {[0] = {}, [1] = {}}
end)

script.on_internal_event(Defines.InternalEvents.JUMP_LEAVE, function(shipManager)
	mods.og.vunerable_rooms[1] = {}
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	--local benchmark_start = os.clock()
	for room in vter(shipManager.ship.vRoomList) do
		if vunerable_rooms[shipManager.iShipId][room.iRoomId] then
			--print("LOOP CORE:"..room.iRoomId)
			vunerable_rooms[shipManager.iShipId][room.iRoomId].time = vunerable_rooms[shipManager.iShipId][room.iRoomId].time - time_increment(true)
			if vunerable_rooms[shipManager.iShipId][room.iRoomId].time <= 0 then
				vunerable_rooms[shipManager.iShipId][room.iRoomId] = nil
			end
		end
	end
	--local benchmark_end = os.clock()
	--print(string.format("core.lua SHIP_LOOP 1: time: %.6f seconds", benchmark_end - benchmark_start))
end)

script.on_render_event(Defines.RenderEvents.SHIP_FLOOR, function() end, function(ship)
	--local benchmark_start = os.clock()
	local shipManager = Hyperspace.ships(ship.iShipId)
	for room in vter(shipManager.ship.vRoomList) do
		if vunerable_rooms[shipManager.iShipId][room.iRoomId] then
			render_vunerable(room)
		end
	end
	--local benchmark_end = os.clock()
	--print(string.format("core.lua SHIP_FLOOR 1: time: %.6f seconds", benchmark_end - benchmark_start))
end)

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA, function(shipManager, projectile, location, damage, forceHit, shipFriendlyFire)
	local room = get_room_at_location(shipManager, location, true)
	if vunerable_rooms[shipManager.iShipId][room] then
		if damage.iDamage + damage.iSystemDamage > 0 then
			damage.iSystemDamage = damage.iSystemDamage + 1
		end
	end
	return Defines.Chain.CONTINUE, forceHit, shipFriendlyFire
end)



script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(shipManager, projectile, location, damage, realNewTile, beamHitType)
	if beamHitType ~= Defines.BeamHit.NEW_ROOM then return Defines.Chain.CONTINUE, beamHitType end
	local room = get_room_at_location(shipManager, location, true)
	if vunerable_rooms[shipManager.iShipId][room] then
		if damage.iDamage + damage.iSystemDamage > 0 then
			damage.iSystemDamage = damage.iSystemDamage + 1
			vunerable_rooms[shipManager.iShipId][room].triggers = vunerable_rooms[shipManager.iShipId][room].triggers + 1
		end
	end
	if projectile and projectile.extend.name and vunerable_weapons[projectile.extend.name] then
		if vunerable_rooms[shipManager.iShipId][room] then
			vunerable_rooms[shipManager.iShipId][room].time = math.max(vunerable_rooms[shipManager.iShipId][room].time, vunerable_weapons[projectile.extend.name])
			vunerable_rooms[shipManager.iShipId][room].triggers = 0
		else
			vunerable_rooms[shipManager.iShipId][room] = {time = vunerable_weapons[projectile.extend.name], triggers = 0}
		end
	end
	return Defines.Chain.CONTINUE, beamHitType
end)

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
	local room = get_room_at_location(shipManager, location, true)
	--if projectile and projectile.extend.name then print("attempt:"..projectile.extend.name) end
	if projectile and projectile.extend.name and vunerable_weapons[projectile.extend.name] then
		if vunerable_rooms[shipManager.iShipId][room] then
			vunerable_rooms[shipManager.iShipId][room].time = math.max(vunerable_rooms[shipManager.iShipId][room].time, vunerable_weapons[projectile.extend.name])
			vunerable_rooms[shipManager.iShipId][room].triggers = 0
		else
			vunerable_rooms[shipManager.iShipId][room] = {time = vunerable_weapons[projectile.extend.name], triggers = 0}
		end
		--print("set:"..room.." t:"..tostring(vunerable_rooms[shipManager.iShipId][room]))
	end
	if vunerable_rooms[shipManager.iShipId][room] then
		if damage.iDamage + damage.iSystemDamage > 0 then
			vunerable_rooms[shipManager.iShipId][room].triggers = vunerable_rooms[shipManager.iShipId][room].triggers + 1
		end
	end
	return Defines.Chain.CONTINUE
end)

local defNOCLONE = Hyperspace.StatBoostDefinition()
defNOCLONE.stat = Hyperspace.CrewStat.NO_CLONE
defNOCLONE.value = true
defNOCLONE.boostType = Hyperspace.StatBoostDefinition.BoostType.SET
defNOCLONE.boostSource = Hyperspace.StatBoostDefinition.BoostSource.AUGMENT
defNOCLONE.shipTarget = Hyperspace.StatBoostDefinition.ShipTarget.ALL
defNOCLONE.crewTarget = Hyperspace.StatBoostDefinition.CrewTarget.ALL
defNOCLONE.duration = -1
defNOCLONE.priority = 9999
defNOCLONE.realBoostId = Hyperspace.StatBoostDefinition.statBoostDefs:size()
Hyperspace.StatBoostDefinition.statBoostDefs:push_back(defNOCLONE)

local defNOSLOT = Hyperspace.StatBoostDefinition()
defNOSLOT.stat = Hyperspace.CrewStat.NO_SLOT
defNOSLOT.value = true
defNOSLOT.boostType = Hyperspace.StatBoostDefinition.BoostType.SET
defNOSLOT.boostSource = Hyperspace.StatBoostDefinition.BoostSource.AUGMENT
defNOSLOT.shipTarget = Hyperspace.StatBoostDefinition.ShipTarget.ALL
defNOSLOT.crewTarget = Hyperspace.StatBoostDefinition.CrewTarget.ALL
defNOSLOT.duration = -1
defNOSLOT.priority = 9999
defNOSLOT.realBoostId = Hyperspace.StatBoostDefinition.statBoostDefs:size()
Hyperspace.StatBoostDefinition.statBoostDefs:push_back(defNOSLOT)

local defNOWARNING = Hyperspace.StatBoostDefinition()
defNOWARNING.stat = Hyperspace.CrewStat.NO_WARNING
defNOWARNING.value = true
defNOWARNING.boostType = Hyperspace.StatBoostDefinition.BoostType.SET
defNOWARNING.boostSource = Hyperspace.StatBoostDefinition.BoostSource.AUGMENT
defNOWARNING.shipTarget = Hyperspace.StatBoostDefinition.ShipTarget.ALL
defNOWARNING.crewTarget = Hyperspace.StatBoostDefinition.CrewTarget.ALL
defNOWARNING.duration = -1
defNOWARNING.priority = 9999
defNOWARNING.realBoostId = Hyperspace.StatBoostDefinition.statBoostDefs:size()
Hyperspace.StatBoostDefinition.statBoostDefs:push_back(defNOWARNING)

local defLOWHPTHRESH = Hyperspace.StatBoostDefinition()
defLOWHPTHRESH.stat = Hyperspace.CrewStat.LOW_HEALTH_THRESHOLD
defLOWHPTHRESH.amount = -1
defLOWHPTHRESH.boostType = Hyperspace.StatBoostDefinition.BoostType.SET
defLOWHPTHRESH.boostSource = Hyperspace.StatBoostDefinition.BoostSource.AUGMENT
defLOWHPTHRESH.shipTarget = Hyperspace.StatBoostDefinition.ShipTarget.ALL
defLOWHPTHRESH.crewTarget = Hyperspace.StatBoostDefinition.CrewTarget.ALL
defLOWHPTHRESH.duration = -1
defLOWHPTHRESH.priority = 9999
defLOWHPTHRESH.realBoostId = Hyperspace.StatBoostDefinition.statBoostDefs:size()
Hyperspace.StatBoostDefinition.statBoostDefs:push_back(defLOWHPTHRESH)

local cloneName = Hyperspace.Text:GetText("og_lua_turret_clone_cannon")

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
	if projectile then
		local cloneTable = userdata_table(projectile, "mods.og").clone_cannon
		if cloneTable then
			local room = get_room_at_location(shipManager, location, true)
			local clone = shipManager:AddCrewMemberFromString(cloneName, cloneTable, true, room, true, true)
			Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(defNOCLONE), clone)
			Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(defNOSLOT), clone)
			Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(defNOWARNING), clone)
			Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(defLOWHPTHRESH), clone)
			clone.extend.deathTimer = Hyperspace.TimerHelper(false)
			clone.extend.deathTimer:Start(15)
		end
	end
end)

local og_eatmote_choice_text_none_original = Hyperspace.Text:GetText("storage_choice_og_eatmote_none_original")

local og_eatmote_choice_event_1 = "STORAGE_CHECK_DDDIVINEGIMMICK_EATMOTE_SYSTEMPART_OG_TURRET_SINGLE_1"
local og_eatmote_choice_text_1 = Hyperspace.Text:GetText("storage_choice_og_eatmote_1")
local og_eatmote_choice_req_1 = Hyperspace.ChoiceReq()
og_eatmote_choice_req_1.object = "OG_EATMOTE_SINGLE_TURRET_ADD"
og_eatmote_choice_req_1.blue = false
og_eatmote_choice_req_1.min_level = 1
og_eatmote_choice_req_1.max_level = mods.multiverse.INT_MAX
og_eatmote_choice_req_1.max_group = -1

local og_eatmote_choice_text_drone_original = Hyperspace.Text:GetText("storage_choice_og_eatmote_drone_original")
local og_eatmote_choice_text_drone = Hyperspace.Text:GetText("storage_choice_og_eatmote_drone")

local og_eatmote_choice_text_1_drone = Hyperspace.Text:GetText("storage_choice_og_eatmote_1_drone")
local og_eatmote_choice_req_1_drone = Hyperspace.ChoiceReq()
og_eatmote_choice_req_1_drone.object = "OG_EATMOTE_SINGLE_TURRET_ADD_DRONE"
og_eatmote_choice_req_1_drone.blue = false
og_eatmote_choice_req_1_drone.min_level = 1
og_eatmote_choice_req_1_drone.max_level = mods.multiverse.INT_MAX
og_eatmote_choice_req_1_drone.max_group = -1


local og_eatmote_choice_event_2 = "STORAGE_CHECK_DDDIVINEGIMMICK_EATMOTE_SYSTEMPART_OG_TURRET_SINGLE_2"
local og_eatmote_choice_text_2 = Hyperspace.Text:GetText("storage_choice_og_eatmote_2")
local og_eatmote_choice_req_2 = Hyperspace.ChoiceReq()
og_eatmote_choice_req_2.object = "og_turret_adaptive_single"
og_eatmote_choice_req_2.blue = false
og_eatmote_choice_req_2.min_level = 1
og_eatmote_choice_req_2.max_level = 5
og_eatmote_choice_req_2.max_group = -1
	
local og_eatmote_choice_event_3 = "OPTION_INVALID"
local og_eatmote_choice_text_3 = Hyperspace.Text:GetText("storage_choice_og_eatmote_3")
local og_eatmote_choice_req_3 = Hyperspace.ChoiceReq()
og_eatmote_choice_req_3.object = "og_turret_adaptive_single"
og_eatmote_choice_req_3.blue = false
og_eatmote_choice_req_3.min_level = 6
og_eatmote_choice_req_3.max_level = mods.multiverse.INT_MAX
og_eatmote_choice_req_3.max_group = -1

script.on_internal_event(Defines.InternalEvents.PRE_CREATE_CHOICEBOX, function(event)
	local eventManager = Hyperspace.Event
	if event.eventName == "STORAGE_CHECK_DDDIVINEGIMMICK_EATMOTE_SYSTEMPART" then
		local old_last = event.choices:back()
		event.choices:pop_back()

		local event_1 = eventManager:CreateEvent(og_eatmote_choice_event_1, 0, true)
		event:AddChoice(event_1, og_eatmote_choice_text_1, og_eatmote_choice_req_1, false)

		event:AddChoice(event_1, og_eatmote_choice_text_1_drone, og_eatmote_choice_req_1_drone, false)

		local event_2 = eventManager:CreateEvent(og_eatmote_choice_event_2, 0, true)
		event:AddChoice(event_2, og_eatmote_choice_text_2, og_eatmote_choice_req_2, false)

		local event_3 = eventManager:CreateEvent(og_eatmote_choice_event_3, 0, true)
		event:AddChoice(event_3, og_eatmote_choice_text_3, og_eatmote_choice_req_3, false)

		event.choices:push_back(old_last)
	end
end)

script.on_internal_event(Defines.InternalEvents.POST_CREATE_CHOICEBOX, function(choiceBox, event)
	if event.eventName == "STORAGE_CHECK_DDDIVINEGIMMICK_EATMOTE_SYSTEMPART" then
		for choice in vter(choiceBox:GetChoices()) do
			if choice.text == og_eatmote_choice_text_drone_original then
				--print("Found text")
				if Hyperspace.ships.player:HasSystem(Hyperspace.ShipSystem.NameToSystemId("og_turret_adaptive_single")) then
					--print("replaced text")
					choice.text = og_eatmote_choice_text_drone
				end
				break
			end
		end
	end
end)

local crewId = "human_og_midnight"
local powerId = "og_midnight_main_power"
local hackingId = "og_midnight_hacking_"
local hackingDeviceName = Hyperspace.Text:GetText("og_lua_midnight_hacking_name")
local hackingImage = Hyperspace.Resources:CreateImagePrimitiveString( "people/human_og_midnight_hacking_base.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
local hackingText = Hyperspace.Text:GetText("og_lua_midnight_hacking_text")
local hackingAvoidSystems = {
	[0] = true,
	[3] = true,
	[4] = true,
}

local hackingCooldown = 20
local droneHack = {
	duration = 5,
}

local hackingDrones = {[0] = {}, [1] = {}}
local function create_hacking_drone(slot, cooldown, shipManager)
	local shipGraph = Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId)
	local rect = shipGraph:GetRoomShape(slot.roomId)
	local width = math.floor((rect.w+1)/35)
	local render_pos = nil
	if width > 0 then
		local slot_number = slot.slotId
		local xOff = (slot_number%width) * 35
		local yOff = math.floor(slot_number/width) * 35
		render_pos = Hyperspace.Point(rect.x + xOff, rect.y + yOff)
	else
		print("error creating hacking drone, width:"..tostring(width).." rect.w:"..tostring(rect.w))
	end
	local drone = {time = 0, cooldown = cooldown, room = slot.roomId, slot = slot.slotId, position = render_pos}
	table.insert(hackingDrones[shipManager.iShipId], drone)
	--print("save drone room:"..tostring(slot.roomId).." slot:"..tostring(slot.slotId).." ship"..tostring(shipManager.iShipId))
	Hyperspace.playerVariables[hackingId..math.floor(shipManager.iShipId).."_"..math.floor(slot.roomId).."_"..math.floor(slot.slotId)] = cooldown
end
-- from MV hack.lua
local function hack_start(system)
	system:SetHackingLevel(2)
	system.bUnderAttack = true
end
local function apply_hack(hack, system)
	if system then
		local sysHackData = userdata_table(system, "mods.mv.hackStuff")
		if not sysHackData.immuneTime or sysHackData.immuneTime <= 0 then
			local sysDuration = hack.systemDurations and hack.systemDurations[Hyperspace.ShipSystem.SystemIdToName(system:GetId())]

			-- Set hacking time for system
			if sysDuration then
				sysHackData.time = math.max(sysDuration.duration, sysHackData.time or 0)
				sysHackData.immuneTime = math.max(sysDuration.immuneAfterHack or hack.immuneAfterHack or 0, sysHackData.immuneTime or 0)
			else
				sysHackData.time = math.max(hack.duration, sysHackData.time or 0)
				sysHackData.immuneTime = math.max(hack.immuneAfterHack or 0, sysHackData.immuneTime or 0)
			end

			-- Apply the actual hack effect
			hack_start(system)
		end
	end
end

local needSetValues = false
local needSetValuesEnemy = false
script.on_init(function(newGame)
	if not newGame then
		needSetValues = true
		needSetValuesEnemy = true
	else
		hackingDrones[0] = {}
		hackingDrones[1] = {}
	end
end)

local function load_hacking_drones(shipManager)
	for room in vter(shipManager.ship.vRoomList) do
		local w = math.floor(room.rect.w/35)
		local h = math.floor(room.rect.h/35)
		local slots = w*h
		for slot = 0, slots - 1 do
			local val = Hyperspace.playerVariables[hackingId..math.floor(shipManager.iShipId).."_"..math.floor(room.iRoomId).."_"..math.floor(slot)]
			if val > 0 then
				--print("load drone room:"..tostring(room.iRoomId).." slot:"..tostring(slot).." ship"..tostring(shipManager.iShipId))
				create_hacking_drone({roomId = room.iRoomId, slotId = slot}, val, shipManager)
			end
		end
	end
end

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if shipManager.iShipId == 0 and needSetValues and Hyperspace.playerVariables.og_test_variable == 1 then
		needSetValues = false
		load_hacking_drones(shipManager)
	elseif shipManager.iShipId == 1 and needSetValuesEnemy and Hyperspace.playerVariables.og_test_variable == 1 then
		needSetValuesEnemy = false
		load_hacking_drones(shipManager)
	end
end)

script.on_internal_event(Defines.InternalEvents.JUMP_LEAVE, function(shipManager)
	if needSetValuesEnemy then needSetValuesEnemy = false end
	if shipManager.iShipId == 0 then
		for _, drone_table in ipairs(hackingDrones[0]) do
			Hyperspace.playerVariables[hackingId..math.floor(shipManager.iShipId).."_"..math.floor(drone_table.room).."_"..math.floor(drone_table.slot)] = 0
		end
		for _, drone_table in ipairs(hackingDrones[1]) do
			Hyperspace.playerVariables[hackingId..math.floor(shipManager.iShipId).."_"..math.floor(drone_table.room).."_"..math.floor(drone_table.slot)] = 0
		end
		hackingDrones[0] = {}
		hackingDrones[1] = {}
	else
		for _, drone_table in ipairs(hackingDrones[1]) do
			Hyperspace.playerVariables[hackingId..math.floor(shipManager.iShipId).."_"..math.floor(drone_table.room).."_"..math.floor(drone_table.slot)] = 0
		end
		hackingDrones[1] = {}
	end
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	local remove = nil
	for i, drone_table in ipairs(hackingDrones[shipManager.iShipId]) do
		drone_table.time = drone_table.time - time_increment(true)
		local system = shipManager:GetSystemInRoom(drone_table.room)
		if drone_table.time <= 0 then
			drone_table.time = drone_table.cooldown
			if system then
				apply_hack(droneHack, system)
			end
		end
		if system and system.healthState.first <= 0 then
			remove = i
			Hyperspace.playerVariables[hackingId..math.floor(shipManager.iShipId).."_"..math.floor(drone_table.room).."_"..math.floor(drone_table.slot)] = 0
		end
	end
	if remove then
		table.remove(hackingDrones[shipManager.iShipId], remove)
	end
end)

script.on_render_event(Defines.RenderEvents.SHIP_SPARKS, function(ship) 
	if Hyperspace.App.menu.shipBuilder.bOpen then return end
	for _, drone_table in ipairs(hackingDrones[ship.iShipId]) do
		local pos = drone_table.position
		Graphics.CSurface.GL_PushMatrix()
		Graphics.CSurface.GL_Translate(pos.x, pos.y)
		Graphics.CSurface.GL_RenderPrimitive(hackingImage)
		Graphics.CSurface.GL_PopMatrix()
		local mousePosition = worldToPlayerLocation(Hyperspace.Mouse.position)
		if ship.iShipId == 1 then
			mousePosition = worldToEnemyLocation(Hyperspace.Mouse.position)
		end
		if mousePosition.x > pos.x and mousePosition.y <= pos.x + 35 and mousePosition.y > pos.y and mousePosition.y <= pos.y + 35 then
			Hyperspace.Mouse.tooltip = (Hyperspace.Mouse.tooltip or "")..string.format(hackingText, drone_table.time, (drone_table.cooldown - droneHack.duration), droneHack.duration)
		end
	end
	return Defines.Chain.CONTINUE 
end, function(ship) return Defines.Chain.CONTINUE end)

script.on_internal_event(Defines.InternalEvents.ACTIVATE_POWER, function(power, shipManager)
	local crewmem = power.crew
	if crewmem.type == crewId and power.def.name == powerId then
		local hackingDeviceSlot = crewmem.currentSlot
		create_hacking_drone(hackingDeviceSlot, hackingCooldown + droneHack.duration, shipManager)
		local homeShip = Hyperspace.ships(crewmem.iShipId)
		local teleport_target_room = 0
		local teleporter = homeShip:GetSystem(9)
		if teleporter then
			teleport_target_room = teleporter.roomId
		end
		crewmem.extend:InitiateTeleport(homeShip.iShipId, teleport_target_room, 0)
		--print("teleport crew")
	end
	return Defines.Chain.CONTINUE
end)

local powerStates = {}
local powerStatesInverse = {
	[0] = "POWER_NOT_READY_COOLDOWN",
	"POWER_READY",
	"POWER_NOT_READY_ACTIVATED",
	"POWER_NOT_READY_ENEMY_SHIP",
	"POWER_NOT_READY_PLAYER_SHIP",
	"POWER_NOT_READY_ENEMY_IN_ROOM",
	"POWER_NOT_READY_FRIENDLY_IN_ROOM",
	"POWER_NOT_READY_WHITELIST",
	"POWER_NOT_READY_ENEMY_WHITELIST",
	"POWER_NOT_READY_FRIENDLY_WHITELIST",
	"POWER_NOT_READY_ENEMY_BLACKLIST",
	"POWER_NOT_READY_FRIENDLY_BLACKLIST",
	"POWER_NOT_READY_SYSTEM_IN_ROOM",
	"POWER_NOT_READY_HAS_CLONEBAY",
	"POWER_NOT_READY_AI_DISABLED",
	"POWER_NOT_READY_OUT_OF_COMBAT",
	"POWER_NOT_READY_IN_COMBAT",
	"POWER_NOT_READY_SYSTEM",
	"POWER_NOT_READY_SYSTEM_FUNCTIONAL",
	"POWER_NOT_READY_MIN_HEALTH",
	"POWER_NOT_READY_MAX_HEALTH",
	"POWER_NOT_READY_SYSTEM_DAMAGED",
	"POWER_NOT_READY_CHARGES",
	"POWER_NOT_READY_SILENCED",
	"POWER_NOT_READY_EXTRACONDITION_OR",
	[16384] = "POWER_NOT_READY_EXTRACONDITION_TRUE",
	[32768] = "POWER_NOT_READY_EXTRACONDITION_FALSE",
	[65536] = "POWER_NOT_READY_CUSTOM",
}
for i, state in pairs(powerStatesInverse) do
	powerStates[state] = i
end

script.on_internal_event(Defines.InternalEvents.POWER_REQ, function(power, req, state)
	local crewmem = power.crew
	if crewmem.type == crewId and power.def.name == powerId then
		--print(tostring(state).." "..powerStatesInverse[state])
		if state == powerStates.POWER_READY then
			local shipManager = Hyperspace.ships(crewmem.currentShipId)
			local system = shipManager:GetSystemInRoom(crewmem.iRoomId)
			if (not system) or hackingAvoidSystems[system.iSystemType] then
				state = powerStates.POWER_NOT_READY_SYSTEM_IN_ROOM
			end
		end
	end
	return Defines.Chain.CONTINUE, state
end)

script.on_internal_event(Defines.InternalEvents.POWER_ON_UPDATE, function(power)
	local crewmem = power.crew
	if crewmem.type == crewId and power.def.name == powerId and crewmem.iShipId == 1 and crewmem.currentShipId == 0 and power.powerCharges.first > 0 then
		local shipManager = Hyperspace.ships(crewmem.currentShipId)
		if not shipManager then return end
		local goalSystem = nil
		if crewmem:AtFinalGoal() then
			goalSystem = shipManager:GetSystemInRoom(crewmem.iRoomId)
		else
			goalSystem = shipManager:GetSystemInRoom(crewmem.finalGoal.roomId)
		end
		if goalSystem and not hackingAvoidSystems[goalSystem.iSystemType] then return end
		local crewPos = crewmem:GetPosition()
		local closest = nil
		local closest_dist
		for system in vter(shipManager.vSystemList) do
			if not hackingAvoidSystems[system.iSystemType] then
				local sysPos = shipManager:GetRoomCenter(system.roomId)
				local dist = get_distance(sysPos, crewPos)
				if (not closest) or dist < closest_dist then
					closest = system
					closest_dist = dist
				end
			end
		end
		if closest then
			local shipGraph = Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId)
			local room_center = shipManager:GetRoomCenter(closest.roomId)
			local move_slot = Hyperspace.Point(room_center.x, room_center.y)
			local slot = shipGraph:GetClosestSlot(move_slot, 1, true)
			crewmem:MoveToRoom(slot.roomId, slot.slotId, false)
		end
	end
	return Defines.Chain.CONTINUE, state	
end)

local neutron_weapons = {}
neutron_weapons["ARTILLERY_OG_NEUTRON_BEAM_1"] = {damage = 40, duration = 8, width = 22}
script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
	if weapon and neutron_weapons[weapon.blueprint.name] then
		local weapon_data = neutron_weapons[weapon.blueprint.name]
		local shipManager = Hyperspace.ships(weapon.iShipId)
		local otherManager = Hyperspace.ships(1-weapon.iShipId)
		mods.og.create_neutron_beam(
			Hyperspace.Pointf(projectile.target.x, projectile.target.y),
			math.random(0,360),
			weapon_data.width,
			otherManager,
			shipManager,
			weapon_data.duration,
			weapon_data.damage,
			true
			)
		mods.og.create_neutron_beam(
			Hyperspace.Pointf(projectile.position.x, projectile.position.y),
			(shipManager.iShipId == 0 and 0) or -90,
			weapon_data.width,
			shipManager,
			shipManager,
			weapon_data.duration,
			0,
			false
			)
		projectile:Kill()
	end
end)

local c = Graphics.GL_Color(1, 1, 1, 1)
local back_plates = {}
back_plates["ogp_hunter_a"] = Hyperspace.Resources:CreateImagePrimitiveString("weapon_laser/og_neutron_beam_artillery_back_player.png", 236, 124, 0, c, 1, false)
back_plates["og_midnight_hunter"] = Hyperspace.Resources:CreateImagePrimitiveString("weapon_laser/og_neutron_beam_artillery_back.png", 126, -2, 0, c, 1, false)
script.on_render_event(Defines.RenderEvents.SHIP_MANAGER, function(shipManager, showInterior, doorControlMode)
	--print(shipManager.ship.shipName)
	if back_plates[shipManager.ship.shipName] then
		Graphics.CSurface.GL_RenderPrimitive(back_plates[shipManager.ship.shipName])
	end
	return Defines.Chain.CONTINUE
end, function(shipManager, showInterior, doorControlMode)
	return Defines.Chain.CONTINUE 
end)

--add artillery mid fight
script.on_internal_event(Defines.InternalEvents.GENERATOR_CREATE_SHIP_POST, function(name, sector, event, blueprint, shipManager)
	return Defines.Chain.CONTINUE
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
	if shipManager.myBlueprint.name == "OG_MIDNIGHT_HUNTER" then
	end
end)