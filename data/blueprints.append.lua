local root = document.root

-- file example: "/data/kestral.txt
local function getRoomCount(file)
	local file_as_string = mod.vfs.pkg:read(file)
	local rooms_iter = string.gmatch(file_as_string, "ROOM%s+(%d+)")
	return mod.iter.count(rooms_iter)
end

local systemsToAppend = {}
systemsToAppend["og_turret_adaptive"] = {attributes = {power = 1, start = "false", turret = "OG_TURRET_LASER_RUSTY_MINI_1"}, manning = true, avoid = {"og_turret", "og_turret_2", "og_turret_3", "og_turret_4", "og_turret_mini", "og_turret_mini_2", "og_turret_mini_3", "og_turret_mini_4"},
	image_list = {
		{room_image = "room_og_turret_5", w = 2, h = 2, top = "00", bottom = "00", left="00", right="10", manning_slot = 1, manning_direction = "right"},
		{room_image = "room_og_turret_6", w = 2, h = 2, top = "00", bottom = "00", left="00", right="01", manning_slot = 3, manning_direction = "right"},

		{room_image = "room_og_turret", w = 1, h = 3, top = "0", bottom = "0", left="000", right="010", manning_slot = 1, manning_direction = "right"},
		{room_image = "room_og_turret_2", w = 2, h = 1, top = "00", bottom = "00", left="0", right="1", manning_slot = 1, manning_direction = "right"},
		{room_image = "room_og_turret_3", w = 1, h = 2, top = "0", bottom = "0", left="00", right="10", manning_slot = 0, manning_direction = "right"},
		{room_image = "room_og_turret_4", w = 2, h = 1, top = "10", bottom = "00", left="0", right="0", manning_slot = 0, manning_direction = "up"},
		{room_image = "room_og_turret_7", w = 2, h = 1, top = "01", bottom = "00", left="0", right="0", manning_slot = 1, manning_direction = "up"},
		{room_image = "room_og_turret_8", w = 1, h = 2, top = "0", bottom = "0", left="00", right="01", manning_slot = 1, manning_direction = "right"},
		{room_image = "room_og_turret_9", w = 2, h = 1, top = "00", bottom = "01", left="0", right="0", manning_slot = 1, manning_direction = "down"},
		{room_image = "room_og_turret_10", w = 2, h = 1, top = "00", bottom = "10", left="0", right="0", manning_slot = 0, manning_direction = "down"},
		{room_image = "room_og_turret_11", w = 1, h = 1, top = "1", bottom = "0", left="0", right="0", manning_slot = 0, manning_direction = "up"},
	}
}

local function noDoorOverlap(rT, rB, rL, rR, iT, iB, iL, iR, shipName)
	local room = table.concat({rT,rB,rL,rR},"")
	local roomNumber = tonumber(room,2)
	local image = table.concat({iT,iB,iL,iR},"")
	local imageNumber = tonumber(image,2)
	return roomNumber & imageNumber == 0
end

local usedFTLMAN = mod.xml.element("usedFTLman", {})
root:append(usedFTLMAN)

local patchedOG = mod.xml.element("patchedOG", {})
root:append(patchedOG)

for blueprint in root:children() do
	if blueprint.name == "shipBlueprint" then
		local layoutString = blueprint.attrs.layout --find the layout so we can read the text file later
		local a = nil
		pcall(function() a = mod.vfs.pkg:read("/data/"..layoutString..".txt") end) 
		if a then
			local roomList = {}
			for idx, x, y, w, h in string.gmatch(a, "ROOM%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)") do
				roomList[idx+1] = { x = tonumber(x), y = tonumber(y), w = tonumber(w), h = tonumber(h), size = (w*h)}
			end

			local doorList = {}
			for x, y, r1, r2, vert in string.gmatch(a, "DOOR%s+(%d+)%s+(%d+)%s+(-?%d+)%s+(-?%d+)%s+(%d+)") do
				doorList[#doorList + 1] = { x = tonumber(x), y = tonumber(y), rl = tonumber(r1), rr = tonumber(r2), vert = tonumber(vert)}
			end
			local shipName = ""

			local roomDoors = {}
			if blueprint.attrs.name then shipName = blueprint.attrs.name end
			--print(shipName.."TRY")
			for room, roomTable in ipairs(roomList) do
				local wallTop = {}
				local wallBottom = {}
				local wallLeft = {}
				local wallRight = {}
				local airlock = false

				for i = 1, roomTable.w do
					wallTop[i] = 0
					wallBottom[i] = 0
				end
				for i = 1, roomTable.h do
					wallLeft[i] = 0
					wallRight[i] = 0
				end
				--print("ROOM:"..(room-1).." w:"..roomTable.w.." h:"..roomTable.h)
				for idx, doorTable in ipairs(doorList) do
					local x = doorTable.x - roomTable.x
					local y = doorTable.y - roomTable.y
					if doorTable.vert == 0 then
						if y == 0 and x >= 0 and x < roomTable.w then
							wallTop[x+1] = 1
							if doorTable.rl < 0 or doorTable.rr < 0 then
								airlock = true
							end
						elseif y == roomTable.h and x >= 0 and x < roomTable.w then
							wallBottom[x+1] = 1
							if doorTable.rl < 0 or doorTable.rr < 0 then
								airlock = true
							end
						end
					else
						if x == 0 and y >= 0 and y < roomTable.h then
							wallLeft[y+1] = 1
							if doorTable.rl < 0 or doorTable.rr < 0 then
								airlock = true
							end
						elseif x == roomTable.w and y >= 0 and y < roomTable.h then
							wallRight[y+1] = 1
							if doorTable.rl < 0 or doorTable.rr < 0 then
								airlock = true
							end
						end
					end
				end

				local wallTopString = table.concat(wallTop, "")
				local wallBottomString = table.concat(wallBottom, "")
				local wallLeftString = table.concat(wallLeft, "")
				local wallRightString = table.concat(wallRight, "")
				
				--print("ROOM:"..(room-1).." top:"..wallTopString.." bottom:"..wallBottomString.." left:"..wallLeftString.." right:"..wallRightString)
				roomDoors[room-1] = {w = roomTable.w, h = roomTable.h, top = wallTopString, bottom = wallBottomString, left = wallLeftString, right = wallRightString, airlock = airlock}
			end

			local isEnemyShip = true
			local systemListElement = nil
			-- find systemList
			for systemList in blueprint:children() do
				if systemList.name == "name" then
					isEnemyShip = false
				elseif systemList.name == "systemList" then
					systemListElement = systemList
				end
			end


			if not isEnemyShip then
				local takenRooms = {}
				local hasSystems = {}
				for system in systemListElement:children() do
					hasSystems[system.name] = true
					local start = true
					local room = nil
					for name, attribute in system:attrs() do
						if name=="start" then
							start = attribute
						elseif name=="room" then
							room = attribute
							--takenRooms[attribute] = system.name
						end
					end
					if room and (system.name ~= "artillery" or start == true) then
						if not takenRooms[room] then
							takenRooms[room] = {}
						end
						local slotCopy = nil
						for child in system:children() do
							for node in child:children() do
								if node.name == "number" then
									slotCopy = node.textContent
								end
							end
						end
						if slotCopy then
							takenRooms[room][system.name] = slotCopy
						else
							takenRooms[room][system.name] = true
						end
					end
				end
				-- append new systems
				--print("searching ship:"..shipName)
				for system, sysInfo in pairs(systemsToAppend) do
					local avoid = false
					local hasSystem = false
					local targetRoom = nil
					local targetRoomSlot = nil
					local targetRoomSize = nil
					if sysInfo.avoid then
						for _, sysName in ipairs(sysInfo.avoid) do
							if hasSystems[sysName] then
								avoid = true
								--print("avoid:"..sysName.." ship:"..blueprint.attrs.name)
							end
						end
					end
					if sysInfo.replace_sys then
						for room, roomTable in ipairs(roomList) do
							if takenRooms[room-1] and takenRooms[room-1][sysInfo.replace_sys] then
								targetRoom = room-1
								targetRoomSize = roomTable.size
								if takenRooms[room-1][sysInfo.replace_sys] ~= true then
									targetRoomSlot = takenRooms[room-1][sysInfo.replace_sys]
								end
							end
							if takenRooms[room-1] and takenRooms[room-1][system] then
								hasSystem = true
							end
						end
					end
					if not targetRoom and not sysInfo.only_replace then
						for room, roomTable in ipairs(roomList) do
							if not takenRooms[room-1] and not roomDoors[room-1].airlock then 
								if not targetRoom or not targetRoomSize then
									targetRoom = room-1
									targetRoomSize = roomTable.size
								elseif roomTable.size > targetRoomSize then
									targetRoom = room-1
									targetRoomSize = roomTable.size
								end
							elseif takenRooms[room-1] and takenRooms[room-1][system] then
								hasSystem = true
							end
						end
					end
					if not targetRoom and not sysInfo.only_replace then
						for room, roomTable in ipairs(roomList) do
							if not takenRooms[room-1] then 
								if not targetRoom or not targetRoomSize  then
									targetRoom = room-1
									targetRoomSize = roomTable.size
								elseif roomTable.size > targetRoomSize then
									targetRoom = room-1
									targetRoomSize = roomTable.size
								end
							end
						end
					end
					if targetRoom and (not hasSystem) and (not avoid) then
						local newSystem = mod.xml.element(system, sysInfo.attributes)
						newSystem.attrs.room = targetRoom

						local roomTable = roomDoors[targetRoom]
						local roomImage = nil
						local manningSlot = nil
						local manningDirection = nil
						if sysInfo.image_list then
							for idx, roomImageTable in ipairs(sysInfo.image_list) do
								if not (roomImage) and roomImageTable.w <= roomTable.w and roomImageTable.h <= roomTable.h then
									--print("check image")
									local roomTop = roomTable.top
									local roomBottom = roomTable.bottom
									local roomLeft = roomTable.left
									local roomRight = roomTable.right
									local longString = "1111111111111111111111111111111111111111111111111111111111111111"
									if roomImageTable.w < roomTable.w and roomImageTable.h == roomTable.h then
										roomRight = string.sub(longString, 1, roomImageTable.h)
										roomTop = string.sub(roomTable.top, 1, roomImageTable.w)
										roomBottom = string.sub(roomTable.bottom, 1, roomImageTable.w)
									elseif roomImageTable.w == roomTable.w and roomImageTable.h < roomTable.h then
										roomBottom = string.sub(longString, 1, roomImageTable.w)
										roomLeft = string.sub(roomTable.left, 1, roomImageTable.h)
										roomRight = string.sub(roomTable.right, 1, roomImageTable.h)
									elseif roomImageTable.w < roomTable.w and roomImageTable.h < roomTable.h then
										roomRight = string.sub(longString, 1, roomImageTable.h)
										roomBottom = string.sub(longString, 1, roomImageTable.w)
										roomTop = string.sub(roomTable.top, 1, roomImageTable.w)
										roomLeft = string.sub(roomTable.left, 1, roomImageTable.h)
									end
									if noDoorOverlap(roomTop, roomBottom, roomLeft, roomRight, roomImageTable.top, roomImageTable.bottom, roomImageTable.left, roomImageTable.right, shipName) then
										roomImage = roomImageTable.room_image
										--print("image safe")
										if sysInfo.manning == true then
											if roomImageTable.manning_slot >= roomImageTable.w then
												manningSlot = roomImageTable.manning_slot + roomTable.w - roomImageTable.w
											else
												manningSlot = roomImageTable.manning_slot
											end
											manningDirection = roomImageTable.manning_direction
										end
									end
								end
							end
						end
						if roomImage then
							--print("image added")
							newSystem.attrs.img = roomImage
						end
						if manningSlot and manningDirection then
							local slot = mod.xml.element("slot", {})
							local direction = mod.xml.element("direction", {})
							local number = mod.xml.element("number", {})
							direction:append(manningDirection)
							number:append(tostring(manningSlot))
							slot:append(direction)
							slot:append(number)
							newSystem:append(slot)
						elseif sysInfo.manning == true then
							--print("USED BACKUP MANNING IMAGE IN:"..shipName)
							newSystem.attrs.img = "room_computer"
							local slot = mod.xml.element("slot", {})
							local direction = mod.xml.element("direction", {})
							local number = mod.xml.element("number", {})
							direction:append("up")
							number:append("0")
							slot:append(direction)
							slot:append(number)
							newSystem:append(slot)
						elseif sysInfo.copy_slot == true then
							local slot = mod.xml.element("slot", {})
							local number = mod.xml.element("number", {})
							if targetRoomSlot then
								number:append(targetRoomSlot)
							else
								number:append("0")
							end
							slot:append(number)
							newSystem:append(slot)
						end

						systemListElement:append(newSystem)
						for name, attribute in newSystem:attrs() do
							if name=="room" then
								takenRooms[attribute] = newSystem.name
							end
						end
					end

				end
			end
		end

	end
end
