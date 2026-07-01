local canCallTaxi = true
local task, taxi = {}, {}
local executeAbort

if Config.Framework == 'ESX' then
    pcall(function()
        ESX = exports["es_extended"]:getSharedObject()
    end)
    if not ESX then
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
    end
elseif Config.Framework == 'QBCore' then
    QBCore = exports['qb-core']:GetCoreObject()
end

if Config.Command.enable then
    RegisterCommand(Config.Command.command, function()
        callTaxi()
    end)
end

if Config.AbortTaxiDrive.enable then
    RegisterCommand(Config.AbortTaxiDrive.command, function()
        abortTaxiDrive(true)
    end)
    RegisterKeyMapping(Config.AbortTaxiDrive.command, 'Abort Taxi Drive', 'keyboard', Config.AbortTaxiDrive.hotkey)
end

toggleCanCallTaxi = function(toggle)
    canCallTaxi = toggle
end
exports('toggleCanCallTaxi', toggleCanCallTaxi)
RegisterNetEvent('msk_aitaxi:canCallTaxi', toggleCanCallTaxi)

getStartingLocation = function(coords)
    local found, spawnPos, spawnHeading = GetClosestVehicleNodeWithHeading(coords.x + math.random(-Config.SpawnRadius, Config.SpawnRadius), coords.y + math.random(-Config.SpawnRadius, Config.SpawnRadius), coords.z, 0, 3.0, 0)
    return found, spawnPos, spawnHeading
end

getStoppingLocation = function(coords)
    local _, nCoords = GetClosestVehicleNode(coords.x, coords.y, coords.z, 1, 3.0, 0)
    return nCoords
end

getVehNodeType = function(coords)
    local _, _, flags = GetVehicleNodeProperties(coords.x, coords.y, coords.z)
    return flags
end

getSpeedForCoords = function(coords, multiplier, isSlowingDown)
    if not coords then return 0.0 end
    local speed = (Config.SpeedZones[getVehNodeType(coords)] or Config.SpeedZones[2]) / Config.SpeedType
    if multiplier then speed = speed * multiplier end
    if isSlowingDown then speed = speed / 2 end
    return speed
end

callTaxi = function()
    if not canCallTaxi then return end
    if taxi.onRoad or taxi.calling then
        AdvancedNotification("Bạn đang trong một chuyến đi!", 'Downtown Cab Co.', 'Taxi', 'CHAR_TAXI')
        return
    end
    taxi.calling = true
    TriggerServerEvent('msk_aitaxi:checkCallTaxi', Config.Price.base)
end
exports('callTaxi', callTaxi)

RegisterNetEvent('msk_aitaxi:startSpawnTaxi', function()
    taxi.calling = false
    local npcId, vehId = math.random(#Config.Taxi.pedmodels), math.random(#Config.Taxi.vehicles)
    local npc, veh = Config.Taxi.pedmodels[npcId], Config.Taxi.vehicles[vehId]
    taxi.driverName = npc.name or 'Alex'
    taxi.driverVoice = npc.voice or 'A_M_M_EASTSA_02_LATINO_FULL_01'

    local driverHash = GetHashKey(npc.model)
    local vehHash = GetHashKey(veh)

    loadModel(driverHash)
    loadModel(vehHash)

    local playerCoords = GetEntityCoords(PlayerPedId())
    local found, coords, heading = getStartingLocation(playerCoords)
    if not found then 
        AdvancedNotification(Translation[Config.Locale]['not_available'], 'Downtown Cab Co.', 'Taxi', 'CHAR_TAXI')
        taxi.calling = false
        return 
    end

    task.vehicle = CreateVehicle(vehHash, vector3(coords.x, coords.y, coords.z), heading, true, true)
    SetVehicleOnGroundProperly(task.vehicle)
    SetVehicleEngineOn(task.vehicle, true, true, false)
    SetVehicleUndriveable(task.vehicle, true)
    SetVehicleDoorsLocked(task.vehicle, 1)
    SetVehicleIndividualDoorsLocked(task.vehicle, 0, 2)
    SetVehicleDoorCanBreak(task.vehicle, 0, false)
    SetVehicleFuelLevel(task.vehicle, 100.0)
    DecorSetFloat(task.vehicle, '_FUEL_LEVEL', 100.0)
    SetEntityAsMissionEntity(task.vehicle, true, true)

    taxi.lastSafeCoords = vector3(coords.x, coords.y, coords.z)
    taxi.lastSafeHeading = heading

    task.npc = CreatePedInsideVehicle(task.vehicle, 26, driverHash, -1, true, true)
    SetAmbientVoiceName(task.npc, taxi.driverVoice)
    SetBlockingOfNonTemporaryEvents(task.npc, true)
    SetDriverAbility(task.npc, 1.0)
    SetDriverAggressiveness(task.npc, 0.0)
    SetEntityAsMissionEntity(task.npc, true, true)

    task.blip = AddBlipForEntity(task.vehicle)
    SetBlipSprite(task.blip, 198)
    SetBlipFlashes(task.blip, true)
    SetBlipColour(task.blip, 5)

    startDriveToPlayer(playerCoords)
end)

startDriveToPlayer = function(playerCoords)
    local toCoords = getStoppingLocation(playerCoords)
    task.toCoords = toCoords
    local currentSpeed = getSpeedForCoords(toCoords)

    TaskVehicleDriveToCoordLongrange(task.npc, task.vehicle, toCoords.x, toCoords.y, toCoords.z, currentSpeed, Config.DrivingStyle, 5.0)
    SetPedKeepTask(task.npc, true)
    AdvancedNotification(Translation[Config.Locale]['on_the_way'], 'Downtown Cab Co.', 'Taxi', 'CHAR_TAXI')
    
    taxi.onRoad = true
    taxi.inDriveMode = false
    taxi.entered = false
    taxi.finished = false
    taxi.canceled = false
end

checkWaypoint = function()
    while taxi.onRoad and not IsWaypointActive() do
        Wait(1000)
    end
    Wait(2500)
    if not taxi.onRoad then return end
    if not IsWaypointActive() then return end

    taxi.finished = false
    startDriveToCoords(GetBlipCoords(GetFirstBlipInfoId(8)))
end

startDriveToCoords = function(waypoint)
    local toCoords = getStoppingLocation(waypoint)
    local startCoords = GetEntityCoords(task.vehicle)
    local distance = #(startCoords - toCoords)

    local averageSpeed = 20.0
    local estimatedTimeMs = (distance / averageSpeed) * 1000
    local ticks = estimatedTimeMs / Config.Price.tickTime
    taxi.upfrontPrice = math.ceil(Config.Price.base + (ticks * Config.Price.tick))
    taxi.paidUpfront = true

    TriggerServerEvent('msk_aitaxi:payTaxiPrice', taxi.upfrontPrice)

    task.startTime = GetGameTimer()
    PlayPedAmbientSpeechNative(task.npc, "TAXID_BEGIN_JOURNEY", "SPEECH_PARAMS_FORCE_NORMAL")

    task.toCoords = toCoords
    taxi.speedMultiplier = 1.0
    taxi.speedStatus = "normal"
    taxi.drivingStyle = Config.DrivingStyle

    SendNUIMessage({
        action = "show",
        driver = taxi.driverName,
        price = taxi.upfrontPrice,
        speed = taxi.speedStatus,
        status = "Đang đi đến đích"
    })

    local currentSpeed = getSpeedForCoords(task.toCoords, taxi.speedMultiplier)
    TaskVehicleDriveToCoordLongrange(task.npc, task.vehicle, task.toCoords.x, task.toCoords.y, task.toCoords.z, currentSpeed, taxi.drivingStyle, 5.0)
    SetPedKeepTask(task.npc, true)
    taxi.inDriveMode = true
    CreateThread(drawPrice)
end

abortTaxiDrive = function(keyPressed, isPaymentFailure)
    if not taxi.onRoad then return end
    if taxi.canceled then return end
    if taxi.finished then return end

    if isPaymentFailure then
        taxi.canceled = true
        AdvancedNotification(Translation[Config.Locale]['insufficient_funds'], 'Downtown Cab Co.', taxi.driverName or 'Taxi', 'CHAR_TAXI')
        leaveTarget()
        return
    end

    if keyPressed then
        SendNUIMessage({
            action = "showPopup",
            type = "abort"
        })
        SetNuiFocus(true, true)
    else
        executeAbort()
    end
end

executeAbort = function()
    if not taxi.onRoad then return end
    if taxi.canceled then return end
    if taxi.finished then return end
    taxi.canceled = true

    if taxi.paidUpfront and taxi.upfrontPrice then
        local actualPrice = math.ceil(Config.Price.base + (Config.Price.tick * ((GetGameTimer() - task.startTime) / Config.Price.tickTime)))
        if actualPrice < taxi.upfrontPrice then
            local refundAmount = taxi.upfrontPrice - actualPrice
            TriggerServerEvent('msk_aitaxi:refundTaxiPrice', refundAmount)
        end
    end

    if not taxi.finished then
        AdvancedNotification(Translation[Config.Locale]['abort'], 'Downtown Cab Co.', taxi.driverName or 'Taxi', 'CHAR_TAXI')
        TaskVehicleTempAction(task.npc, task.vehicle, 27, 1000)
    end

    taxi.finished = true
end

leaveTarget = function()
    local blip, vehicle, npc = task.blip, task.vehicle, task.npc

    if npc and vehicle and DoesEntityExist(npc) and DoesEntityExist(vehicle) then
        SetVehicleDoorsLocked(vehicle, 4)
        TaskVehicleDriveWander(npc, vehicle, 20.0, Config.DrivingStyle or 786603)
    end

    taxi = {}
    task = {}
    SendNUIMessage({ action = "hide" })
    if blip then RemoveBlip(blip) end

    CreateThread(function()
        Wait(5000)
        if npc and DoesEntityExist(npc) then 
            SetEntityAsMissionEntity(npc, false, false)
            DeleteEntity(npc) 
        end
        if vehicle and DoesEntityExist(vehicle) then 
            SetEntityAsMissionEntity(vehicle, false, false)
            DeleteEntity(vehicle) 
        end
    end)
end

-- Unified Main Monitoring Thread
CreateThread(function()
    local flipStartTime = 0
    local stuckStartTime = 0
    local lastRecordTime = 0
    local lastRemainingSeconds = -1
    local currentSpeed = 0.0

    while true do
        local sleep = 500
        local playerPed = PlayerPedId()

        if taxi.onRoad and task.vehicle then
            sleep = 100
            SetVehicleDoorsLocked(task.vehicle, 1)
            SetVehicleIndividualDoorsLocked(task.vehicle, 0, 2)
            SetVehicleDoorCanBreak(task.vehicle, 0, false)

            -- Intercept driver seat entry to force passenger seat
            if GetVehiclePedIsTryingToEnter(playerPed) == task.vehicle and GetSeatPedIsTryingToEnter(playerPed) == -1 then
                ClearPedTasks(playerPed)
                TaskEnterVehicle(playerPed, task.vehicle, 10000, 0, 1.0, 1, 0)
            end

            -- Check player inside/outside states
            local playerInside = IsPedInVehicle(playerPed, task.vehicle, false)

            if playerInside then
                taxi.playerWasInside = true

                -- First entry handling
                if not taxi.entered then
                    taxi.entered = true
                    if task.blip then 
                        RemoveBlip(task.blip) 
                        task.blip = nil
                    end
                    PlayPedAmbientSpeechNative(task.npc, "TAXID_WHERE_TO", "SPEECH_PARAMS_FORCE_NORMAL")
                    AdvancedNotification(Translation[Config.Locale]['welcome']:format(taxi.driverName), 'Downtown Cab Co.', taxi.driverName, 'CHAR_TAXI')
                    CreateThread(checkWaypoint)
                end

                -- Resume driving if waiting for player
                if taxi.waitingForPlayer then
                    taxi.waitingForPlayer = false
                    AdvancedNotification("Chào mừng quay trở lại! Tài xế tiếp tục hành trình.", 'Downtown Cab Co.', taxi.driverName or 'Taxi', 'CHAR_TAXI')

                    SendNUIMessage({
                        action = "show",
                        driver = taxi.driverName,
                        price = taxi.upfrontPrice,
                        speed = taxi.speedStatus,
                        status = "Đang đi đến đích"
                    })

                    ClearPedTasks(task.npc)
                    local newSpeed = getSpeedForCoords(task.toCoords, taxi.speedMultiplier)
                    TaskVehicleDriveToCoordLongrange(task.npc, task.vehicle, task.toCoords.x, task.toCoords.y, task.toCoords.z, newSpeed, taxi.drivingStyle or Config.DrivingStyle, 5.0)
                    SetPedKeepTask(task.npc, true)
                end

                -- Keyboard hotkeys check
                if taxi.inDriveMode then
                    sleep = 0
                    if IsControlJustPressed(0, 10) then -- Page Up
                        SendNUIMessage({
                            action = "showPopup",
                            type = taxi.speedStatus == "fast" and "downgrade" or "upgrade",
                            price = taxi.upfrontPrice
                        })
                        SetNuiFocus(true, true)
                    end
                end
            elseif taxi.playerWasInside then
                -- Player left the taxi
                if not taxi.canceled and not taxi.finished then
                    if not taxi.waitingForPlayer then
                        taxi.waitingForPlayer = true
                        taxi.waitingStartTime = GetGameTimer()
                        lastRemainingSeconds = -1
                        taxi.waitingDuration = (IsPlayerDead(PlayerId()) or IsEntityDead(PlayerPedId())) and 90000 or 30000
                        ClearPedTasks(task.npc)
                        TaskVehicleTempAction(task.npc, task.vehicle, 27, 2000)

                        SendNUIMessage({
                            action = "show",
                            driver = taxi.driverName,
                            price = taxi.upfrontPrice,
                            speed = taxi.speedStatus,
                            status = "Đang chờ hành khách..."
                        })

                        local waitSeconds = math.ceil(taxi.waitingDuration / 1000)
                        AdvancedNotification(("Tài xế sẽ dừng lại chờ bạn trong %d giây."):format(waitSeconds), 'Downtown Cab Co.', taxi.driverName or 'Taxi', 'CHAR_TAXI')
                    else
                        if (IsPlayerDead(PlayerId()) or IsEntityDead(PlayerPedId())) and taxi.waitingDuration < 90000 then
                            taxi.waitingDuration = 90000
                            taxi.waitingStartTime = GetGameTimer()
                            lastRemainingSeconds = -1
                            AdvancedNotification("Bạn đã chết. Tài xế sẽ chờ thêm 90 giây kể từ bây giờ.", 'Downtown Cab Co.', taxi.driverName or 'Taxi', 'CHAR_TAXI')
                        end

                        local elapsed = GetGameTimer() - taxi.waitingStartTime
                        if elapsed >= taxi.waitingDuration then
                            AdvancedNotification("Hết thời gian chờ. Hủy chuyến đi.", 'Downtown Cab Co.', taxi.driverName or 'Taxi', 'CHAR_TAXI')
                            abortTaxiDrive()
                            leaveTarget()
                        else
                            local remaining = math.ceil((taxi.waitingDuration - elapsed) / 1000)
                            if remaining ~= lastRemainingSeconds then
                                lastRemainingSeconds = remaining
                                HelpNotification(("Tài xế đang đợi bạn: %d giây"):format(remaining))
                            end
                        end
                    end
                else
                    leaveTarget()
                end
            end

            -- Journey progress monitoring
            if not taxi.waitingForPlayer and task.toCoords then
                local vehicleCoords = GetEntityCoords(task.vehicle)
                local distance = #(task.toCoords - vehicleCoords)

                if taxi.inDriveMode then
                    if distance < 10.0 and not taxi.finished then
                        PlayPedAmbientSpeechNative(task.npc, "TAXID_CLOSE_AS_POSS", "SPEECH_PARAMS_FORCE_NORMAL")
                        AdvancedNotification(Translation[Config.Locale]['end'], 'Downtown Cab Co.', taxi.driverName, 'CHAR_TAXI')
                        SendNUIMessage({ action = "hide" })
                        taxi.finished = true
                        CreateThread(checkWaypoint)
                    else
                        -- Ped/Player detection in front of the vehicle (Only in quái xế/fast mode)
                        local slowingForPed = false
                        if taxi.speedStatus == "fast" then
                            local peds = GetGamePool('CPed')
                            local forwardVector = GetEntityForwardVector(task.vehicle)
                            for _, ped in ipairs(peds) do
                                if ped ~= task.npc and ped ~= playerPed and not IsPedInAnyVehicle(ped) then
                                    local pedCoords = GetEntityCoords(ped)
                                    local toPed = pedCoords - vehicleCoords
                                    local dist = #toPed
                                    if dist < 35.0 then
                                        local toPedNormalized = toPed / dist
                                        local dot = toPedNormalized.x * forwardVector.x + toPedNormalized.y * forwardVector.y + toPedNormalized.z * forwardVector.z
                                        if dot > 0.8 then -- ~36 degree cone in front of the car
                                            slowingForPed = true
                                            break
                                        end
                                    end
                                end
                            end
                        end

                        local targetSpeed = getSpeedForCoords(vehicleCoords, taxi.speedMultiplier, distance <= 20.0)
                        if slowingForPed then
                            targetSpeed = targetSpeed * 0.35 -- Reduce speed to 35% (e.g. 210 kmh -> 73 kmh) to allow the AI to safely steer/swerve around peds
                        end
                        if math.abs(currentSpeed - targetSpeed) > 0.1 then
                            currentSpeed = targetSpeed
                            SetDriveTaskMaxCruiseSpeed(task.npc, currentSpeed)
                        end
                    end
                else
                    -- Driving to pick up the player
                    local targetSpeed = getSpeedForCoords(task.toCoords, nil, distance <= 20.0)
                    if math.abs(currentSpeed - targetSpeed) > 0.1 then
                        currentSpeed = targetSpeed
                        TaskVehicleDriveToCoordLongrange(task.npc, task.vehicle, task.toCoords.x, task.toCoords.y, task.toCoords.z, currentSpeed, Config.DrivingStyle, 5.0)
                        SetPedKeepTask(task.npc, true)
                    end
                end
            end

            -- Flip and Stuck Rescue Checks
            if DoesEntityExist(task.vehicle) and DoesEntityExist(task.npc) then
                local coords = GetEntityCoords(task.vehicle)
                local heading = GetEntityHeading(task.vehicle)
                local vehSpeed = GetEntitySpeed(task.vehicle)
                local gameTimer = GetGameTimer()

                -- Record Safe Points
                if gameTimer - lastRecordTime > 2000 then
                    lastRecordTime = gameTimer
                    if IsVehicleOnAllWheels(task.vehicle) and vehSpeed > 3.0 and IsPointOnRoad(coords.x, coords.y, coords.z, task.vehicle) then
                        taxi.lastSafeCoords = coords
                        taxi.lastSafeHeading = heading
                    end
                end

                -- Rescue trigger checks
                local triggerRescue = false
                if IsEntityInWater(task.vehicle) then
                    triggerRescue = true
                elseif not IsVehicleOnAllWheels(task.vehicle) then
                    if flipStartTime == 0 then flipStartTime = gameTimer
                    elseif gameTimer - flipStartTime > 3000 then triggerRescue = true end
                else
                    flipStartTime = 0
                end

                if vehSpeed < 1.0 and not IsPointOnRoad(coords.x, coords.y, coords.z, task.vehicle) then
                    if stuckStartTime == 0 then stuckStartTime = gameTimer
                    elseif gameTimer - stuckStartTime > 4000 then triggerRescue = true end
                else
                    stuckStartTime = 0
                end

                -- Teleport Rescue
                if triggerRescue and taxi.lastSafeCoords then
                    flipStartTime = 0
                    stuckStartTime = 0
                    DoScreenFadeOut(500)
                    Wait(500)

                    ClearPedTasks(task.npc)
                    SetEntityCoords(task.vehicle, taxi.lastSafeCoords.x, taxi.lastSafeCoords.y, taxi.lastSafeCoords.z, false, false, false, true)
                    SetEntityHeading(task.vehicle, taxi.lastSafeHeading or 0.0)
                    SetVehicleOnGroundProperly(task.vehicle)
                    SetVehicleFixed(task.vehicle)
                    SetVehicleEngineOn(task.vehicle, true, true, false)
                    SetEntityVelocity(task.vehicle, 0.0, 0.0, 0.0)
                    SetVehicleEngineHealth(task.vehicle, 1000.0)

                    local toCoords = task.toCoords or GetEntityCoords(PlayerPedId())
                    local newSpeed = getSpeedForCoords(toCoords, taxi.speedMultiplier)
                    TaskVehicleDriveToCoordLongrange(task.npc, task.vehicle, toCoords.x, toCoords.y, toCoords.z, newSpeed, taxi.drivingStyle or Config.DrivingStyle, 5.0)
                    SetPedKeepTask(task.npc, true)

                    Wait(500)
                    DoScreenFadeIn(500)
                    AdvancedNotification("Tài xế đã đưa xe quay trở lại tuyến đường an toàn.", 'Downtown Cab Co.', taxi.driverName or 'Taxi', 'CHAR_TAXI')
                end
            end
        end

        Wait(sleep)
    end
end)

drawPrice = function()
    while taxi.onRoad and taxi.inDriveMode and not taxi.canceled and not taxi.finished do
        local sleep = 0
        if not taxi.waitingForPlayer then
            HelpNotification(Translation[Config.Locale]['input']:format(Config.AbortTaxiDrive.hotkey))
            DrawGenericText(Translation[Config.Locale]['price']:format(comma(taxi.upfrontPrice or 0)))
        else
            sleep = 100
        end
        Wait(sleep)
    end
end

loadModel = function(modelHash)
    if not HasModelLoaded(modelHash) then
        RequestModel(modelHash)
        while not HasModelLoaded(modelHash) do Wait(1) end
    end
end

comma = function(int, tag)
    if not tag then tag = '.' end
    local newInt = int
    while true do  
        newInt, k = string.gsub(newInt, "^(-?%d+)(%d%d%d)", '%1'..tag..'%2')
        if (k == 0) then break end
    end
    return newInt
end

HelpNotification = function(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

AdvancedNotification = function(text, title, subtitle, icon, flash, icontype)
    if not flash then flash = true end
    if not icontype then icontype = 1 end
    if not icon then icon = 'CHAR_TAXI' end

    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandThefeedPostMessagetext(icon, icon, flash, icontype, title, subtitle)
	EndTextCommandThefeedPostTicker(false, true)
end

DrawGenericText = function(text)
	SetTextColour(Config.Price.color.r, Config.Price.color.g, Config.Price.color.b, Config.Price.color.a)
	SetTextFont(0)
	SetTextScale(0.30, 0.30)
	SetTextWrap(0.0, 1.0)
	SetTextCentre(true)
	SetTextDropshadow(0, 0, 0, 0, 255)
	SetTextEdge(1, 0, 0, 0, 205)
    SetTextOutline()
	BeginTextCommandDisplayText("STRING")
	AddTextComponentSubstringPlayerName(text)
	EndTextCommandDisplayText(Config.Price.position.width, Config.Price.position.height)
end

RegisterNUICallback('crazyDriverResponse', function(data, cb)
    SetNuiFocus(false, false)
    
    if data.type == 'upgrade' then
        if data.agree then
            local additionalPrice = math.ceil(taxi.upfrontPrice * 0.5)
            TriggerServerEvent('msk_aitaxi:payUpgradePrice', additionalPrice)
        else
            AdvancedNotification("Bạn đã từ chối chế độ quái xế.", 'Downtown Cab Co.', taxi.driverName or 'Taxi', 'CHAR_TAXI')
        end
    elseif data.type == 'downgrade' then
        if data.agree then
            taxi.speedMultiplier = 1.0
            taxi.speedStatus = "normal"
            taxi.drivingStyle = Config.DrivingStyle
            if DoesEntityExist(task.npc) then
                SetDriverAggressiveness(task.npc, 0.0)
            end

            SendNUIMessage({
                action = "updateSpeed",
                speed = taxi.speedStatus
            })

            local vehicleCoords = GetEntityCoords(task.vehicle)
            local currentSpeed = getSpeedForCoords(vehicleCoords, taxi.speedMultiplier)
            TaskVehicleDriveToCoordLongrange(task.npc, task.vehicle, task.toCoords.x, task.toCoords.y, task.toCoords.z, currentSpeed, taxi.drivingStyle, 5.0)
            SetPedKeepTask(task.npc, true)
            AdvancedNotification("Đã trở về chế độ lái xe bình thường (Không hoàn lại phụ phí).", 'Downtown Cab Co.', taxi.driverName or 'Taxi', 'CHAR_TAXI')
        else
            AdvancedNotification("Đã hủy yêu cầu hạ tốc độ, tiếp tục chế độ quái xế.", 'Downtown Cab Co.', taxi.driverName or 'Taxi', 'CHAR_TAXI')
        end
    end
    
    cb('ok')
end)

RegisterNUICallback('abortConfirmResponse', function(data, cb)
    SetNuiFocus(false, false)
    if data.agree then
        executeAbort()
    else
        AdvancedNotification("Đã hủy yêu cầu hủy chuyến, tiếp tục hành trình.", 'Downtown Cab Co.', taxi.driverName or 'Taxi', 'CHAR_TAXI')
    end
    cb('ok')
end)

RegisterNetEvent('msk_aitaxi:paymentFailed', function()
    taxi.paidUpfront = false
    abortTaxiDrive(false, true)
end)

RegisterNetEvent('msk_aitaxi:upgradeFailed', function()
    AdvancedNotification("Bạn không đủ tiền để nâng cấp lên chế độ quái xế!", 'Downtown Cab Co.', taxi.driverName or 'Taxi', 'CHAR_TAXI')
end)

RegisterNetEvent('msk_aitaxi:upgradeSuccess', function()
    taxi.speedMultiplier = 1.4
    taxi.speedStatus = "fast"
    taxi.drivingStyle = 787006 -- 787006 (Reckless, Shortest path, wrong way, avoid objects/peds/stationary cars, stop for peds, does NOT stop for cars)
    if DoesEntityExist(task.npc) then
        SetDriverAggressiveness(task.npc, 1.0)
    end

    SendNUIMessage({
        action = "updateSpeed",
        speed = taxi.speedStatus
    })

    local vehicleCoords = GetEntityCoords(task.vehicle)
    local currentSpeed = getSpeedForCoords(vehicleCoords, taxi.speedMultiplier)
    TaskVehicleDriveToCoordLongrange(task.npc, task.vehicle, task.toCoords.x, task.toCoords.y, task.toCoords.z, currentSpeed, taxi.drivingStyle, 5.0)
    SetPedKeepTask(task.npc, true)
    AdvancedNotification("Đã kích hoạt chế độ quái xế lạng lách!", 'Downtown Cab Co.', taxi.driverName or 'Taxi', 'CHAR_TAXI')
end)

RegisterNetEvent('msk_aitaxi:callTaxiFailed', function(basePrice)
    taxi.calling = false
    AdvancedNotification(("Bạn không đủ tiền để gọi taxi! (Tối thiểu $%d)"):format(basePrice), 'Downtown Cab Co.', 'Taxi', 'CHAR_TAXI')
end)