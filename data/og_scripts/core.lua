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
	if pulsar_power[crewmem.type] and stat == Hyperspace.CrewStat.BONUS_POWER and (spaceManager.pulsarLevel or spaceManager.bStorm) then
		amount = amount + pulsar_power[crewmem.type]
	elseif pulsar_power[crewmem.type] and (stat == Hyperspace.CrewStat.IS_TELEPATHIC) and (spaceManager.bNebula or spaceManager.bStorm or Hyperspace.playerVariables.loc_environment_lightnebula >= 1) then
		value = true
	elseif pulsar_power[crewmem.type] and (stat == Hyperspace.CrewStat.DETECTS_LIFEFORMS or stat == Hyperspace.CrewStat.RESISTS_MIND_CONTROL) and (spaceManager.bNebula or spaceManager.bStorm or Hyperspace.playerVariables.loc_environment_lightnebula >= 1) then
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
		damage.fireChance = math.max(1, math.floor(damage.fireChance * ship:GetAugmentationValue("OG_REFLECTIVE_PLATING")))
		damage.breachChance = math.max(1, math.floor(damage.breachChance * ship:GetAugmentationValue("OG_REFLECTIVE_PLATING")))
	end
end
script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(ship, projectile, location, damage, realNewTile, beamHitType)
	if beamHitType == Defines.BeamHit.NEW_ROOM then
		handle_reduction_armor(ship, projectile, location, damage, true)
	end
end)

script.on_internal_event(Defines.InternalEvents.POWER_ON_UPDATE, function(power)
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
	return Defines.Chain.CONTINUE
end)

local repToShow = {
	{id = "rep_comb_og_iron", name = "Iron Watch Reputation"},
	{id = "rep_og_dawn", name = "New Dawn Reputation", hidden = true},
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
	for room in vter(shipManager.ship.vRoomList) do
		if vunerable_rooms[shipManager.iShipId][room.iRoomId] then
			--print("LOOP CORE:"..room.iRoomId)
			vunerable_rooms[shipManager.iShipId][room.iRoomId].time = vunerable_rooms[shipManager.iShipId][room.iRoomId].time - time_increment(true)
			if vunerable_rooms[shipManager.iShipId][room.iRoomId].time <= 0 then
				vunerable_rooms[shipManager.iShipId][room.iRoomId] = nil
			end
		end
	end
end)

script.on_render_event(Defines.RenderEvents.SHIP_FLOOR, function() end, function(ship) 
	local shipManager = Hyperspace.ships(ship.iShipId)
	for room in vter(shipManager.ship.vRoomList) do
		if vunerable_rooms[shipManager.iShipId][room.iRoomId] then
			render_vunerable(room)
		end
	end
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

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
	if projectile then
		local cloneTable = userdata_table(projectile, "mods.og").clone_cannon
		if cloneTable then
			local room = get_room_at_location(shipManager, location, true)
			local clone = shipManager:AddCrewMemberFromString("Clone", cloneTable, true, room, true, true)
			Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(defNOCLONE), clone)
			Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(defNOSLOT), clone)
			Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(defNOWARNING), clone)
			Hyperspace.StatBoostManager.GetInstance():CreateTimedAugmentBoost(Hyperspace.StatBoost(defLOWHPTHRESH), clone)
			clone.extend.deathTimer = Hyperspace.TimerHelper(false)
			clone.extend.deathTimer:Start(15)
		end
	end
end)