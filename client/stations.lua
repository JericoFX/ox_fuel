local config = require 'config'
local state = require 'client.state'
local utils = require 'client.utils'
local stations = lib.load 'data.stations'
local NPCService = require 'client.npc_service'

if config.showBlips == 2 then
	for station in pairs(stations) do utils.createBlip(station) end
end

if config.ox_target and config.showBlips ~= 1 then return end

---@param point CPoint
local function onEnterStation(point)
	if config.showBlips == 1 and not point.blip then
		point.blip = utils.createBlip(point.coords)
	end

	NPCService.onEnterStation(point.coords)
end

---@param point CPoint
local function nearbyStation(point)
	if point.currentDistance > 15 then return end

	local pumps = point.pumps
	local playerCoords = cache.coords
	local pumpDistance

	for i = 1, #pumps do
		local pump = pumps[i]
		pumpDistance = #(playerCoords - pump)

		if pumpDistance <= 3 then
			state.nearestPump = pump

			repeat
				playerCoords = GetEntityCoords(cache.ped)
				pumpDistance = #(playerCoords - pump)

				if cache.vehicle then
					DisplayHelpTextThisFrame('fuelLeaveVehicleText', false)
				elseif not state.isFueling then
					local vehicleInRange = state.lastVehicle ~= 0 and
						#(GetEntityCoords(state.lastVehicle) - playerCoords) <= 3

					if vehicleInRange then
						DisplayHelpTextThisFrame('fuelHelpText', false)
					elseif config.petrolCan.enabled then
						DisplayHelpTextThisFrame('petrolcanHelpText', false)
					end
				end

				Wait(100)
			until pumpDistance > 3

			state.nearestPump = nil

			return
		end
	end
end

---@param point CPoint
local function onExitStation(point)
	if point.blip then
		point.blip = RemoveBlip(point.blip)
	end

	NPCService.onExitStation(point.coords)
end

for station, pumps in pairs(stations) do
	lib.points.new({
		coords = station,
		distance = 60,
		onEnter = onEnterStation,
		onExit = onExitStation,
		nearby = nearbyStation,
		pumps = pumps,
	})
end
