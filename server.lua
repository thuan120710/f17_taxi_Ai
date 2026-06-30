ESX = nil

local function GetESX()
    if Config.Framework ~= 'ESX' then return nil end
    if not ESX then
        pcall(function()
            ESX = exports["es_extended"]:getSharedObject()
        end)
        if not ESX then
            TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        end
        local timeout = 0
        while not ESX and timeout < 100 do
            Wait(10)
            timeout = timeout + 1
        end
    end
    return ESX
end

if Config.Framework == 'ESX' then
    CreateThread(function()
        GetESX()
    end)
elseif Config.Framework == 'QBCore' then
    QBCore = exports['qb-core']:GetCoreObject()
elseif Config.Framework == 'Standalone' then
    -- Add your own code here
end

round = function(num, decimal)
    return tonumber(string.format("%." .. (decimal or 0) .. "f", num))
end

comma = function(int, tag)
    if not tag then tag = '.' end
    local newInt = int

    while true do  
        newInt, k = string.gsub(newInt, "^(-?%d+)(%d%d%d)", '%1'..tag..'%2')

        if (k == 0) then
            break
        end
    end

    return newInt
end

RegisterNetEvent('msk_aitaxi:payTaxiPrice', function(payAmount)
    local src = source
    if not payAmount or type(payAmount) ~= 'number' or payAmount <= 0 then
        return
    end
    payAmount = round(payAmount)

    -- Check if player has enough money
    local totalMoney = 0
    if Config.Framework == 'ESX' then
        local ESX = GetESX()
        if not ESX then return end
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            local tienkhoaObj = xPlayer.getAccount('tienkhoa')
            local tienkhoaMoney = tienkhoaObj and tienkhoaObj.money or 0
            local bankMoney = xPlayer.getAccount('bank') and xPlayer.getAccount('bank').money or 0
            totalMoney = tienkhoaMoney + bankMoney
        end
    elseif Config.Framework == 'QBCore' then
        local Player = QBCore.Functions.GetPlayer(src)
        if Player then
            local tienkhoaMoney = Player.Functions.GetMoney('tienkhoa') or 0
            local bankMoney = Player.Functions.GetMoney('bank') or 0
            totalMoney = tienkhoaMoney + bankMoney
        end
    elseif Config.Framework == 'Standalone' then
        totalMoney = 999999
    end

    if totalMoney < payAmount then
        TriggerClientEvent('msk_aitaxi:paymentFailed', src)
        return
    end

    if Config.Framework == 'ESX' then
        local ESX = GetESX()
        local xPlayer = ESX.GetPlayerFromId(src)
        local tienkhoaObj = xPlayer.getAccount('tienkhoa')
        local tienkhoaMoney = tienkhoaObj and tienkhoaObj.money or 0

        if tienkhoaMoney >= payAmount then
            xPlayer.removeAccountMoney('tienkhoa', payAmount)
        else
            if tienkhoaMoney > 0 then
                xPlayer.removeAccountMoney('tienkhoa', tienkhoaMoney)
                xPlayer.removeAccountMoney('bank', payAmount - tienkhoaMoney)
            else
                xPlayer.removeAccountMoney('bank', payAmount)
            end
        end
    elseif Config.Framework == 'QBCore' then
        local Player = QBCore.Functions.GetPlayer(src)
        local tienkhoaMoney = Player.Functions.GetMoney('tienkhoa') or 0

        if tienkhoaMoney >= payAmount then
            Player.Functions.RemoveMoney('tienkhoa', payAmount)
        else
            if tienkhoaMoney > 0 then
                Player.Functions.RemoveMoney('tienkhoa', tienkhoaMoney)
                Player.Functions.RemoveMoney('bank', payAmount - tienkhoaMoney)
            else
                Player.Functions.RemoveMoney('bank', payAmount)
            end
        end
    elseif Config.Framework == 'Standalone' then
        -- Add your own code here
    end

    Config.Notification(src, Translation[Config.Locale]['paid']:format(comma(payAmount)))
    
    if Config.Society.enable then
        if Config.Framework == 'ESX' then
            TriggerEvent('esx_addonaccount:getSharedAccount', Config.Society.account, function(account)
                if not account then return print(('^1Society %s not found on Event ^2 msk_aitaxi:payTaxiPrice ^0'):format(Config.Society.account)) end
                
                account.addMoney(payAmount)
            end)
        elseif Config.Framework == 'QBCore' then
            local account = exports['qb-banking']:GetAccount(Config.Society.account)
            if not account then return print(('^1Society %s not found on Event ^2 msk_aitaxi:payTaxiPrice ^0'):format(Config.Society.account)) end
            
            exports['qb-banking']:AddMoney(Config.Society.account, payAmount, 'Taxi')
        elseif Config.Framework == 'Standalone' then
            -- Add your own code here
        end
    end
end)

RegisterNetEvent('msk_aitaxi:payUpgradePrice', function(payAmount)
    local src = source
    if not payAmount or type(payAmount) ~= 'number' or payAmount <= 0 then
        return
    end
    payAmount = round(payAmount)

    -- Check if player has enough money
    local totalMoney = 0
    if Config.Framework == 'ESX' then
        local ESX = GetESX()
        if not ESX then return end
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            local tienkhoaObj = xPlayer.getAccount('tienkhoa')
            local tienkhoaMoney = tienkhoaObj and tienkhoaObj.money or 0
            local bankMoney = xPlayer.getAccount('bank') and xPlayer.getAccount('bank').money or 0
            totalMoney = tienkhoaMoney + bankMoney
        end
    elseif Config.Framework == 'QBCore' then
        local Player = QBCore.Functions.GetPlayer(src)
        if Player then
            local tienkhoaMoney = Player.Functions.GetMoney('tienkhoa') or 0
            local bankMoney = Player.Functions.GetMoney('bank') or 0
            totalMoney = tienkhoaMoney + bankMoney
        end
    elseif Config.Framework == 'Standalone' then
        totalMoney = 999999
    end

    if totalMoney < payAmount then
        TriggerClientEvent('msk_aitaxi:upgradeFailed', src)
        return
    end

    if Config.Framework == 'ESX' then
        local ESX = GetESX()
        local xPlayer = ESX.GetPlayerFromId(src)
        local tienkhoaObj = xPlayer.getAccount('tienkhoa')
        local tienkhoaMoney = tienkhoaObj and tienkhoaObj.money or 0

        if tienkhoaMoney >= payAmount then
            xPlayer.removeAccountMoney('tienkhoa', payAmount)
        else
            if tienkhoaMoney > 0 then
                xPlayer.removeAccountMoney('tienkhoa', tienkhoaMoney)
                xPlayer.removeAccountMoney('bank', payAmount - tienkhoaMoney)
            else
                xPlayer.removeAccountMoney('bank', payAmount)
            end
        end
    elseif Config.Framework == 'QBCore' then
        local Player = QBCore.Functions.GetPlayer(src)
        local tienkhoaMoney = Player.Functions.GetMoney('tienkhoa') or 0

        if tienkhoaMoney >= payAmount then
            Player.Functions.RemoveMoney('tienkhoa', payAmount)
        else
            if tienkhoaMoney > 0 then
                Player.Functions.RemoveMoney('tienkhoa', tienkhoaMoney)
                Player.Functions.RemoveMoney('bank', payAmount - tienkhoaMoney)
            else
                Player.Functions.RemoveMoney('bank', payAmount)
            end
        end
    elseif Config.Framework == 'Standalone' then
        -- Add your own code here
    end

    Config.Notification(src, "Đã thanh toán phụ phí nâng cấp: $" .. comma(payAmount))
    TriggerClientEvent('msk_aitaxi:upgradeSuccess', src)
end)


RegisterNetEvent('msk_aitaxi:refundTaxiPrice', function(refundAmount)
    local src = source
    if not refundAmount or type(refundAmount) ~= 'number' or refundAmount <= 0 then
        return
    end
    refundAmount = round(refundAmount)

    if Config.Framework == 'ESX' then
        local ESX = GetESX()
        if not ESX then return end
        local xPlayer = ESX.GetPlayerFromId(src)
        local account = 'tienkhoa'
        local tienkhoaObj = xPlayer.getAccount('tienkhoa')
        if not tienkhoaObj then account = 'bank' end
        xPlayer.addAccountMoney(account, refundAmount)
    elseif Config.Framework == 'QBCore' then
        local Player = QBCore.Functions.GetPlayer(src)
        Player.Functions.AddMoney('tienkhoa', refundAmount)
    elseif Config.Framework == 'Standalone' then
        -- Add your own code here
    end

    Config.Notification(src, "Bạn đã được hoàn lại $" .. comma(refundAmount) .. " cho đoạn đường chưa đi.")
end)

RegisterNetEvent('msk_aitaxi:checkCallTaxi', function(basePrice)
    local src = source
    if not basePrice or type(basePrice) ~= 'number' or basePrice <= 0 then
        return
    end
    basePrice = round(basePrice)

    local totalMoney = 0
    if Config.Framework == 'ESX' then
        local ESX = GetESX()
        if not ESX then return end
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            local tienkhoaObj = xPlayer.getAccount('tienkhoa')
            local tienkhoaMoney = tienkhoaObj and tienkhoaObj.money or 0
            local bankMoney = xPlayer.getAccount('bank') and xPlayer.getAccount('bank').money or 0
            totalMoney = tienkhoaMoney + bankMoney
        end
    elseif Config.Framework == 'QBCore' then
        local Player = QBCore.Functions.GetPlayer(src)
        if Player then
            local tienkhoaMoney = Player.Functions.GetMoney('tienkhoa') or 0
            local bankMoney = Player.Functions.GetMoney('bank') or 0
            totalMoney = tienkhoaMoney + bankMoney
        end
    elseif Config.Framework == 'Standalone' then
        totalMoney = 999999
    end

    if totalMoney < basePrice then
        if Config.Framework == 'QBCore' then
            TriggerClientEvent('QBCore:Notify', src, "Bạn không đủ tiền để gọi taxi! (Tối thiểu $" .. basePrice .. ")", "error", 5000)
        else
            TriggerClientEvent('msk_aitaxi:callTaxiFailed', src, basePrice)
        end
        return
    end

    TriggerClientEvent('msk_aitaxi:startSpawnTaxi', src)
end)