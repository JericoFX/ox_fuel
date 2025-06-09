local config = require 'config'
local state = require 'client.state'
local utils = require 'client.utils'
local EmergencySystem = require 'shared.emergency_system'

local NPCService = {}
NPCService.stationAttendants = {}
NPCService.currentAttendant = nil
NPCService.activeStation = nil

local attendantModels = {
    'a_m_m_hillbilly_01',
    'a_m_y_business_01',
    'a_m_m_business_01',
    'a_f_y_business_01',
    'a_f_m_business_02'
}

function NPCService.createAttendant(stationCoords)
    if not config.npcService.enabled then return end

    if NPCService.stationAttendants[stationCoords] then
        NPCService.deleteAttendant(stationCoords)
    end

    local model = attendantModels[math.random(#attendantModels)]
    lib.requestModel(model)

    local spawnCoords = vector3(
        stationCoords.x + math.random(-8, 8),
        stationCoords.y + math.random(-8, 8),
        stationCoords.z
    )

    local attendant = CreatePed(4, model, spawnCoords.x, spawnCoords.y, spawnCoords.z, 0.0, false, true)

    SetEntityAsMissionEntity(attendant, true, true)
    SetPedDefaultComponentVariation(attendant)
    SetBlockingOfNonTemporaryEvents(attendant, true)
    SetEntityInvincible(attendant, true)
    FreezeEntityPosition(attendant, false)

    TaskWanderStandard(attendant, 10.0, 10)

    NPCService.stationAttendants[stationCoords] = attendant

    lib.notify({
        type = 'info',
        description = '¡Un empleado está disponible para ayudarte!'
    })

    return attendant
end

function NPCService.deleteAttendant(stationCoords)
    local attendant = NPCService.stationAttendants[stationCoords]
    if attendant and DoesEntityExist(attendant) then
        DeleteEntity(attendant)
        NPCService.stationAttendants[stationCoords] = nil

        if NPCService.currentAttendant == attendant then
            NPCService.currentAttendant = nil
        end
    end
end

function NPCService.onEnterStation(stationCoords)
    if not config.npcService.enabled then return end

    NPCService.activeStation = stationCoords
    NPCService.createAttendant(stationCoords)
end

function NPCService.onExitStation(stationCoords)
    if not config.npcService.enabled then return end

    if NPCService.activeStation == stationCoords then
        NPCService.activeStation = nil

        CreateThread(function()
            Wait(5000)
            if NPCService.activeStation ~= stationCoords then
                NPCService.deleteAttendant(stationCoords)
            end
        end)
    end
end

function NPCService.findNearestAttendant()
    local playerCoords = GetEntityCoords(cache.ped)
    local nearest = nil
    local nearestDist = math.huge

    for stationCoords, attendant in pairs(NPCService.stationAttendants) do
        if DoesEntityExist(attendant) then
            local attendantCoords = GetEntityCoords(attendant)
            local dist = #(playerCoords - attendantCoords)

            if dist < nearestDist and dist < 15.0 then
                nearest = attendant
                nearestDist = dist
            end
        end
    end

    NPCService.currentAttendant = nearest
    return nearest
end

function NPCService.showServiceMenu(vehicle)
    if not config.npcService.enabled then return false end

    local attendant = NPCService.findNearestAttendant()

    if not attendant then
        lib.notify({
            type = 'error',
            description = 'No hay empleado disponible en este momento'
        })
        return false
    end

    local services = config.npcService.services
    local options = {}

    if services.fullService.enabled then
        local servicePrice = services.fullService.price
        if services.fullService.includesCleaning then
            servicePrice = servicePrice + services.windshieldCleaning.price
        end

        local finalPrice, hasDiscount = EmergencySystem.calculateDiscountedPrice(servicePrice)
        local priceText = hasDiscount and ('$%s (Descuento aplicado)'):format(finalPrice) or ('$%s'):format(servicePrice)
        local description = services.fullService.includesCleaning and
            ('Servicio completo: combustible + limpieza - %s'):format(priceText) or
            ('El empleado cargará combustible - %s'):format(priceText)

        options[#options + 1] = {
            title = 'Servicio Completo',
            description = description,
            icon = 'fa-solid fa-gas-pump',
            onSelect = function()
                NPCService.startFullService(vehicle)
            end
        }
    end

    if services.windshieldCleaning.enabled then
        local finalPrice, hasDiscount = EmergencySystem.calculateDiscountedPrice(services.windshieldCleaning.price)
        local priceText = hasDiscount and ('$%s (Descuento aplicado)'):format(finalPrice) or ('$%s'):format(finalPrice)

        options[#options + 1] = {
            title = 'Solo Limpiar Parabrisas',
            description = ('Limpieza profesional del parabrisas - %s'):format(priceText),
            icon = 'fa-solid fa-spray-can',
            onSelect = function()
                NPCService.startWindshieldCleaning(vehicle)
            end
        }
    end

    options[#options + 1] = {
        title = 'Cargar Yo Mismo',
        description = 'Realizar el servicio sin ayuda del empleado',
        icon = 'fa-solid fa-hand',
        onSelect = function()
            NPCService.startSelfService(vehicle)
        end
    }

    lib.registerContext({
        id = 'npc_service_menu',
        title = 'Servicios de Estación',
        options = options
    })

    lib.showContext('npc_service_menu')
    return true
end

function NPCService.startSelfService(vehicle)
    lib.hideContext()
    local fuel = require 'client.fuel'
    fuel.startFueling(vehicle, true)
end

function NPCService.startFullService(vehicle)
    if not NPCService.currentAttendant or not DoesEntityExist(NPCService.currentAttendant) then
        lib.notify({
            type = 'error',
            description = 'El empleado no está disponible'
        })
        return
    end

    lib.hideContext()

    local boneIndex = utils.getVehiclePetrolCapBoneIndex(vehicle)
    local fuelCapCoords = boneIndex and GetWorldPositionOfEntityBone(vehicle, boneIndex) or GetEntityCoords(vehicle)

    lib.notify({
        type = 'info',
        description = 'El empleado se dirige al vehículo...'
    })

    CreateThread(function()
        TaskGoToCoord(NPCService.currentAttendant, fuelCapCoords.x, fuelCapCoords.y, fuelCapCoords.z, 1.0, -1, 1.5, 0.0)

        local timeout = 0
        while #(GetEntityCoords(NPCService.currentAttendant) - fuelCapCoords) > 2.0 and timeout < 150 do
            Wait(100)
            timeout = timeout + 1
        end

        if timeout >= 150 then
            lib.notify({
                type = 'error',
                description = 'El empleado no pudo llegar al vehículo'
            })
            return
        end

        TaskTurnPedToFaceEntity(NPCService.currentAttendant, vehicle, 2000)
        Wait(1000)

        lib.notify({
            type = 'success',
            description = 'Iniciando servicio de combustible...'
        })

        TaskStartScenarioInPlace(NPCService.currentAttendant, 'WORLD_HUMAN_JANITOR', 0, true)

        local servicePrice = config.npcService.services.fullService.price
        local fuel = require 'client.fuel'
        fuel.startFueling(vehicle, true, servicePrice)

        while state.isFueling do
            Wait(1000)
        end

        ClearPedTasks(NPCService.currentAttendant)

        if config.npcService.services.fullService.includesCleaning then
            Wait(1000)

            local frontCoords = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, 2.5, 0.5)
            TaskGoToCoord(NPCService.currentAttendant, frontCoords.x, frontCoords.y, frontCoords.z, 1.0, -1, 1.5, 0.0)

            timeout = 0
            while #(GetEntityCoords(NPCService.currentAttendant) - frontCoords) > 2.0 and timeout < 100 do
                Wait(100)
                timeout = timeout + 1
            end

            if timeout < 100 then
                lib.notify({
                    type = 'info',
                    description = 'Limpiando parabrisas...'
                })

                TaskTurnPedToFaceEntity(NPCService.currentAttendant, vehicle, 2000)
                Wait(500)
                TaskStartScenarioInPlace(NPCService.currentAttendant, 'WORLD_HUMAN_MAID_CLEAN', 0, true)

                Wait(config.npcService.services.windshieldCleaning.duration)

                SetVehicleDirtLevel(vehicle, 0.0)
                WashDecalsFromVehicle(vehicle, 1.0)

                lib.notify({
                    type = 'success',
                    description = '¡Parabrisas limpio!'
                })
            end
        end

        ClearPedTasks(NPCService.currentAttendant)
        TaskWanderStandard(NPCService.currentAttendant, 10.0, 10)

        lib.notify({
            type = 'success',
            description = '¡Gracias por elegir nuestro servicio!'
        })
    end)
end

function NPCService.startWindshieldCleaning(vehicle)
    if not NPCService.currentAttendant then
        return lib.notify({
            type = 'error',
            description = 'No hay empleado disponible'
        })
    end

    lib.hideContext()

    local basePrice = config.npcService.services.windshieldCleaning.price
    local finalPrice, hasDiscount = EmergencySystem.calculateDiscountedPrice(basePrice)
    local moneyAmount = utils.getMoney()

    if moneyAmount < finalPrice then
        return lib.notify({
            type = 'error',
            description = ('No tienes suficiente dinero ($%s)'):format(finalPrice)
        })
    end

    local frontCoords = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, 2.5, 0.5)
    TaskGoToCoord(NPCService.currentAttendant, frontCoords.x, frontCoords.y, frontCoords.z, 1.0, -1, 1.5, 0.0)

    CreateThread(function()
        local timeout = 0
        while #(GetEntityCoords(NPCService.currentAttendant) - frontCoords) > 2.0 and timeout < 100 do
            Wait(100)
            timeout = timeout + 1
        end

        if timeout >= 100 then
            lib.notify({
                type = 'error',
                description = 'El empleado no pudo llegar al vehículo'
            })
            return
        end

        TaskTurnPedToFaceEntity(NPCService.currentAttendant, vehicle, 2000)
        Wait(500)
        TaskStartScenarioInPlace(NPCService.currentAttendant, 'WORLD_HUMAN_MAID_CLEAN', 0, true)

        if lib.progressCircle({
                duration = config.npcService.services.windshieldCleaning.duration,
                useWhileDead = false,
                canCancel = true,
                label = 'Limpiando parabrisas...',
                disable = {
                    move = true,
                    car = true,
                    combat = true,
                }
            }) then
            TriggerServerEvent('ox_fuel:payService', finalPrice, 'windshield_cleaning', hasDiscount)

            SetVehicleDirtLevel(vehicle, 0.0)
            WashDecalsFromVehicle(vehicle, 1.0)

            if hasDiscount then
                lib.notify({
                    type = 'success',
                    description = ('¡Parabrisas limpio! Descuento aplicado: $%s → $%s'):format(basePrice, finalPrice)
                })
            else
                lib.notify({
                    type = 'success',
                    description = '¡Parabrisas limpio!'
                })
            end
        end

        ClearPedTasks(NPCService.currentAttendant)
        TaskWanderStandard(NPCService.currentAttendant, 10.0, 10)
    end)
end

return NPCService
