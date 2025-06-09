# ox_fuel - Multi-Framework Support

Basic fuel resource and alternative to LegacyFuel, originally designed for ox_inventory.

## Credits

**Original code belongs entirely to Ox and Cox from the Community Ox team.**

-   Original repository: https://github.com/communityox/ox_fuel
-   All core functionality and design is their work

**Framework Integration Addition:**
This fork only adds easier integration for QBCore and ESX frameworks for money handling, while maintaining all original functionality and design principles.

## Framework Support

This version supports three frameworks:

-   **ox** (default): Uses ox_inventory for money handling
-   **qb**: Uses QBCore for money handling
-   **esx**: Uses ESX for money handling

### Configuration

Set your framework in `config.lua`:

```lua
framework = 'qb', -- 'ox' or 'qb' or 'esx'
```

## Get vehicle fuel level

This is an incredibly complicated task for some people, and they often ask for exports to do it.
You use the native function [GetVehicleFuelLevel](https://docs.fivem.net/natives/?_0x5F739BB8), or you can use a statebag.

```lua
Entity(entity).state.fuel
```

## Set vehicle fuel level

```lua
Entity(entity).state.fuel = fuelAmount
```

## Framework Examples

### QBCore Example

The framework automatically handles QBCore money when `framework = 'qb'` is set. Money is taken from player's cash.

If you need custom payment method:

```lua
-- Server-side custom payment
exports.ox_fuel:setPaymentMethod(function(playerId, amount)
    local Player = QBCore.Functions.GetPlayer(playerId)
    local bankAmount = Player.PlayerData.money.bank

    if bankAmount >= amount then
        Player.Functions.RemoveMoney('bank', amount)
        return true
    end

    TriggerClientEvent('ox_lib:notify', playerId, {
        type = 'error',
        description = 'Not enough money in bank: $' .. (amount - bankAmount) .. ' needed'
    })
end)

-- Client-side custom money check
exports.ox_fuel:setMoneyCheck(function()
    local PlayerData = QBCore.Functions.GetPlayerData()
    return PlayerData.money.bank or 0
end)
```

### ESX Example

The framework automatically handles ESX money when `framework = 'esx'` is set. Money is taken from player's cash.

If you need custom payment method:

```lua
-- Server-side custom payment
exports.ox_fuel:setPaymentMethod(function(playerId, amount)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    local bankAmount = xPlayer.getAccount('bank').money

    if bankAmount >= amount then
        xPlayer.removeAccountMoney('bank', amount)
        return true
    end

    TriggerClientEvent('ox_lib:notify', playerId, {
        type = 'error',
        description = 'Not enough money in bank: $' .. (amount - bankAmount) .. ' needed'
    })
end)

-- Client-side custom money check
exports.ox_fuel:setMoneyCheck(function()
    local accounts = ESX.GetPlayerData().accounts

    for i = 1, #accounts do
        if accounts[i].name == 'bank' then
            return accounts[i].money
        end
    end

    return 0
end)
```

### ox_inventory Example (Original)

```lua
-- This is handled automatically when framework = 'ox'
-- But you can override if needed:

exports.ox_fuel:setPaymentMethod(function(playerId, amount)
    local success = exports.ox_inventory:RemoveItem(playerId, 'money', amount)

    if success then
        return true
    end

    local money = exports.ox_inventory:GetItemCount(playerId, 'money')
    TriggerClientEvent('ox_lib:notify', playerId, {
        type = 'error',
        description = 'Not enough money: $' .. (amount - money) .. ' needed'
    })
end)
```
