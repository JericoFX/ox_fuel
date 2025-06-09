local EmergencySystem = {}

function EmergencySystem.getPlayerJob()
    local config = require 'config'

    if config.framework == 'qb' then
        local PlayerData = exports['qb-core']:GetCoreObject().Functions.GetPlayerData()
        return PlayerData and PlayerData.job and PlayerData.job.name
    elseif config.framework == 'esx' then
        local PlayerData = exports['es_extended']:getSharedObject().GetPlayerData()
        return PlayerData and PlayerData.job and PlayerData.job.name
    end

    return nil
end

function EmergencySystem.isEmergencyJob(job)
    local config = require 'config'
    if not config.emergencyDiscount.enabled or not job then return false end

    for _, emergencyJob in ipairs(config.emergencyDiscount.jobs) do
        if job == emergencyJob then return true end
    end

    return false
end

function EmergencySystem.calculateDiscountedPrice(basePrice)
    local config = require 'config'
    local job = EmergencySystem.getPlayerJob()

    if EmergencySystem.isEmergencyJob(job) then
        local discountedPrice = math.ceil(basePrice * config.emergencyDiscount.discount)
        return discountedPrice, true, job
    end

    return basePrice, false, job
end

return EmergencySystem
