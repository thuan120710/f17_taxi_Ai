local canCallTaxi = true
local task, taxi = {}, {}

if Config.Framework == 'ESX' then
    pcall(function()
        ESX = exports["es_extended"]:getSharedObject()
    end)
    if not ESX then
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
    end
elseif Config.Framework == 'QBCore' then
    QBCore = exports['qb-core']:GetCoreObject()
elseif Config.Framework == 'Standalone' then
    -- Add your own code here
end

if Config.Command.enable then
    RegisterCommand(Config.Command.command, function(source, args, raw)
        callTaxi()
    end)
end

if Config.AbortTaxiDrive.enable then
    RegisterCommand(Config.AbortTaxiDrive.command, function(source, args, raw)
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
callTaxi = function()
    if not canCallTaxi then return end
    local npcId, vehId = math.random(#Config.Taxi.pedmodels), math.random(#Config.Taxi.vehicles)
    local npc, veh = Config.Taxi.pedmodels[npcId], Config.Taxi.vehicles[vehId]
    taxi.driverName = npc.name or 'Alex'
    taxi.driverVoice = npc.voice or 'A_M_M_EASTSA_02_LATINO_FULL_01'

    local driverHash = GetHashKey(npc.model)
    local vehHash = GetHashKey(veh)

    loadModel(driverHash)
    loadModel(vehHash)

    local playerCoords = GetEntityCoords(PlayerPedId())
    local vehicleSpawned = spawnVehicle(playerCoords, driverHash, vehHash)

    if not vehicleSpawned then 
        AdvancedNotification(Translation[Config.Locale]['not_available'], 'Downtown Cab Co.', 'Taxi', 'CHAR_TAXI')
        return 
    end

    startDriveToPlayer(playerCoords)
end
exports('callTaxi', callTaxi)

spawnVehicle = function(playerCoords, driverHash, vehHash)
    local found, coords, heading = getStartingLocation(playerCoords)
    if not found then return false end

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

    -- Initialize safe coordinates
    taxi.lastSafeCoords = vector3(coords.x, coords.y, coords.z)
    taxi.lastSafeHeading = heading

    task.npc = CreatePedInsideVehicle(task.vehicle, 26, driverHash, -1, true, true)
    SetAmbientVoiceName(task.npc, taxi.driverVoice)
    SetBlockingOfNonTemporaryEvents(task.npc, true)
    SetDriverAbility(task.npc, 1.0)
    SetEntityAsMissionEntity(task.npc, true, true)

    task.blip = AddBlipForEntity(task.vehicle)
    SetBlipSprite(task.blip, 198)
    SetBlipFlashes(task.blip, true)
    SetBlipColour(task.blip, 5)

    return true
end
startDriveToPlayer = function(playerCoords)
    local toCoords = getStoppingLocation(playerCoords)
    task.toCoords = toCoords
    local speed = (Config.SpeedZones[getVehNodeType(toCoords)] or Config.SpeedZones[2]) / Config.SpeedType
    local currentSpeed = speed

    TaskVehicleDriveToCoordLongrange(task.npc, task.vehicle, toCoords.x, toCoords.y, toCoords.z, currentSpeed, Config.DrivingStyle, 5.0)
    SetPedKeepTask(task.npc, true)
    AdvancedNotification(Translation[Config.Locale]['on_the_way'], 'Downtown Cab Co.', 'Taxi', 'CHAR_TAXI')
    taxi.onRoad = true

    while taxi.onRoad and not taxi.inDriveMode do
        Wait(500)
        if taxi.onRoad and task.vehicle then
            local vehicleCoords = GetEntityCoords(task.vehicle)
            local distance = #(toCoords - vehicleCoords)

            if distance <= 20.0 then
                local newSpeed = ((Config.SpeedZones[getVehNodeType(toCoords)] or Config.SpeedZones[2]) / Config.SpeedType) / 2
                if currentSpeed ~= newSpeed then
                    currentSpeed = newSpeed
                    TaskVehicleDriveToCoordLongrange(task.npc, task.vehicle, toCoords.x, toCoords.y, toCoords.z, currentSpeed, Config.DrivingStyle, 5.0)
                    SetPedKeepTask(task.npc, true)
                end
                break
            end

            local newSpeed = (Config.SpeedZones[getVehNodeType(vehicleCoords)] or Config.SpeedZones[2]) / Config.SpeedType
            if currentSpeed ~= newSpeed then
                currentSpeed = newSpeed
                TaskVehicleDriveToCoordLongrange(task.npc, task.vehicle, toCoords.x, toCoords.y, toCoords.z, currentSpeed, Config.DrivingStyle, 5.0)
                SetPedKeepTask(task.npc, true)
            end
        end
    end
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

    -- Estimate price based on distance
    local averageSpeed = 20.0 -- estimated average speed in m/s (72 km/h)
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

    local speed = (Config.SpeedZones[getVehNodeType(task.toCoords)] or Config.SpeedZones[2]) / Config.SpeedType
    local currentSpeed = speed * taxi.speedMultiplier
    TaskVehicleDriveToCoordLongrange(task.npc, task.vehicle, task.toCoords.x, task.toCoords.y, task.toCoords.z, currentSpeed, taxi.drivingStyle, 5.0)
    SetPedKeepTask(task.npc, true)
    taxi.inDriveMode = true
    CreateThread(drawPrice)

    while taxi.onRoad and taxi.inDriveMode and not taxi.canceled and not taxi.finished do
        Wait(500)
        if taxi.onRoad and not taxi.waitingForPlayer and task.toCoords and task.vehicle then
            local vehicleCoords = GetEntityCoords(task.vehicle)
            local distance = #(task.toCoords - vehicleCoords)

            if distance < 10.0 then
                PlayPedAmbientSpeechNative(task.npc, "TAXID_CLOSE_AS_POSS", "SPEECH_PARAMS_FORCE_NORMAL")
                AdvancedNotification(Translation[Config.Locale]['end'], 'Downtown Cab Co.', taxi.driverName, 'CHAR_TAXI')
                Config.Notification(nil, Translation[Config.Locale]['end'], 'success')
                SendNUIMessage({ action = "hide" })
                taxi.finished = true
                break
            end

            if distance <= 20.0 then
                local newSpeed = (((Config.SpeedZones[getVehNodeType(vehicleCoords)] or Config.SpeedZones[2]) / Config.SpeedType) / 2) * taxi.speedMultiplier
                if currentSpeed ~= newSpeed then
                    currentSpeed = newSpeed
                    TaskVehicleDriveToCoordLongrange(task.npc, task.vehicle, task.toCoords.x, task.toCoords.y, task.toCoords.z, currentSpeed, taxi.drivingStyle, 5.0)
                    SetPedKeepTask(task.npc, true)
                end
            else
                local newSpeed = ((Config.SpeedZones[getVehNodeType(vehicleCoords)] or Config.SpeedZones[2]) / Config.SpeedType) * taxi.speedMultiplier
                if currentSpeed ~= newSpeed then
                    currentSpeed = newSpeed
                    TaskVehicleDriveToCoordLongrange(task.npc, task.vehicle, task.toCoords.x, task.toCoords.y, task.toCoords.z, currentSpeed, taxi.drivingStyle, 5.0)
                    SetPedKeepTask(task.npc, true)
                end
            end
        end
    end

    if taxi.canceled then return end
    checkWaypoint()
end

abortTaxiDrive = function(keyPressed)
    if not taxi.onRoad then return end
    if taxi.canceled then return end
    if taxi.finished then return end
    taxi.canceled = true

    if not taxi.inDriveMode then
        AdvancedNotification(Translation[Config.Locale]['abort'], 'Downtown Cab Co.', taxi.driverName, 'CHAR_TAXI')
        Config.Notification(nil, Translation[Config.Locale]['abort'], 'error')
        leaveTarget()
        return
    end

    -- Refund logic
    if taxi.paidUpfront and taxi.upfrontPrice then
        local actualPrice = math.ceil(Config.Price.base + (Config.Price.tick * ((GetGameTimer() - task.startTime) / Config.Price.tickTime)))
        if actualPrice < taxi.upfrontPrice then
            local refundAmount = taxi.upfrontPrice - actualPrice
            TriggerServerEvent('msk_aitaxi:refundTaxiPrice', refundAmount)
        end
    end

    if not taxi.finished and not keyPressed then
        AdvancedNotification(Translation[Config.Locale]['abort'], 'Downtown Cab Co.', taxi.driverName, 'CHAR_TAXI')
        Config.Notification(nil, Translation[Config.Locale]['abort'], 'error')
        leaveTarget()
        return
    end

    if not taxi.finished and keyPressed then
        AdvancedNotification(Translation[Config.Locale]['abort'], 'Downtown Cab Co.', taxi.driverName, 'CHAR_TAXI')
        Config.Notification(nil, Translation[Config.Locale]['abort'], 'error')
        TaskVehicleTempAction(task.npc, task.vehicle, 27, 1000)
    end

    taxi.finished = true
end

leaveTarget = function()
    local blip, vehicle, npc = task.blip, task.vehicle, task.npc

    if npc and vehicle and DoesEntityExist(npc) and DoesEntityExist(vehicle) then
        SetVehicleDoorsLocked(vehicle, 4) -- Lock doors so player cannot enter
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

enteringVehicle = function(vehicle, plate, seat)
    if not taxi.onRoad then return end
    if vehicle ~= task.vehicle then return end
    if seat ~= 0 and seat ~= -1 then return end

    while true and vehicle == task.vehicle do
        if IsPedInVehicle(PlayerPedId(), vehicle, false) then
            SetPedIntoVehicle(PlayerPedId(), vehicle, 0)
            break
        end
        Wait(0)
    end
end
AddEventHandler('msk_enginetoggle:enteringVehicle', enteringVehicle)

enteredVehicle = function(vehicle, plate, seat)
    if not taxi.onRoad then return end
    
    if vehicle ~= task.vehicle then 
        abortTaxiDrive() 
        return
    end

    if task.blip then 
        RemoveBlip(task.blip) 
        task.blip = nil
    end

    SetVehicleDoorsShut(vehicle, false)
    SetPedIntoVehicle(PlayerPedId(), task.vehicle, seat)

    if taxi.waitingForPlayer then
        taxi.waitingForPlayer = false
        Config.Notification(nil, "Chào mừng quay trở lại! Tài xế tiếp tục hành trình.", "success")
        
        SendNUIMessage({
            action = "show",
            driver = taxi.driverName,
            price = taxi.upfrontPrice,
            speed = taxi.speedStatus,
            status = "Đang đi đến đích"
        })

        CreateThread(function()
            ClearPedTasks(task.npc)
            Wait(1000) -- Đợi 1 giây để người chơi ổn định và cửa xe đóng hẳn
            local speed = (Config.SpeedZones[getVehNodeType(task.toCoords)] or Config.SpeedZones[2]) / Config.SpeedType
            local currentSpeed = speed * (taxi.speedMultiplier or 1.0)
            TaskVehicleDriveToCoordLongrange(task.npc, task.vehicle, task.toCoords.x, task.toCoords.y, task.toCoords.z, currentSpeed, taxi.drivingStyle or Config.DrivingStyle, 5.0)
            SetPedKeepTask(task.npc, true)
        end)
        return
    end

    PlayPedAmbientSpeechNative(task.npc, "TAXID_WHERE_TO", "SPEECH_PARAMS_FORCE_NORMAL")
    AdvancedNotification(Translation[Config.Locale]['welcome']:format(taxi.driverName), 'Downtown Cab Co.', taxi.driverName, 'CHAR_TAXI')
    Config.Notification(nil, Translation[Config.Locale]['welcome']:format(taxi.driverName), 'info')

    if taxi.entered then return end
    taxi.entered = true
    checkWaypoint()
end
AddEventHandler('msk_enginetoggle:enteredVehicle', enteredVehicle)

exitedVehicle = function(vehicle, plate, seat)
    if not taxi.onRoad then return end
    if not taxi.inDriveMode then return end
    if vehicle ~= task.vehicle then return end

    if not taxi.canceled and not taxi.finished then
        if not taxi.waitingForPlayer then
            taxi.waitingForPlayer = true
            taxi.waitingStartTime = GetGameTimer()
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
            Config.Notification(nil, ("Tài xế sẽ dừng lại chờ bạn trong %d giây."):format(waitSeconds), "info")
        end
        return
    end

    leaveTarget()
end
AddEventHandler('msk_enginetoggle:exitedVehicle', exitedVehicle)

enteringVehicleAborted = function()
    -- Nothing to add here...
end
AddEventHandler('msk_enginetoggle:enteringVehicleAborted', enteringVehicleAborted)

if GetResourceState("msk_enginetoggle") == "missing" or GetResourceState("msk_enginetoggle") == "stopped" then
    -- Credits to ESX Legacy (https://github.com/esx-framework/esx_core/blob/main/%5Bcore%5D/es_extended/client/modules/actions.lua)
    local isEnteringVehicle, isInVehicle = false, false
    local currentVehicle = {}
    CreateThread(function()
        while true do
            local sleep = 200
            local playerPed = PlayerPedId()

            if not isInVehicle and not IsPlayerDead(PlayerId()) then
                if DoesEntityExist(GetVehiclePedIsTryingToEnter(playerPed)) and not isEnteringVehicle then
                    local vehicle = GetVehiclePedIsTryingToEnter(playerPed)
                    local plate = GetVehicleNumberPlateText(vehicle)
                    local seat = GetSeatPedIsTryingToEnter(playerPed)
                    isEnteringVehicle = true
                    enteringVehicle(vehicle, plate, seat)
                elseif not DoesEntityExist(GetVehiclePedIsTryingToEnter(playerPed)) and not IsPedInAnyVehicle(playerPed, true) and isEnteringVehicle then
                    enteringVehicleAborted()
                    isEnteringVehicle = false
                elseif IsPedInAnyVehicle(playerPed, false) then
                    isEnteringVehicle = false
                    isInVehicle = true
                    currentVehicle.vehicle = GetVehiclePedIsIn(playerPed)
                    currentVehicle.plate = GetVehicleNumberPlateText(currentVehicle.vehicle)
                    currentVehicle.seat = GetPedVehicleSeat(playerPed, currentVehicle.vehicle)
                    enteredVehicle(currentVehicle.vehicle, currentVehicle.plate, currentVehicle.seat)
                end
            elseif isInVehicle then
                if not IsPedInAnyVehicle(playerPed, false) or IsPlayerDead(PlayerId()) then
                    isInVehicle = false
                    exitedVehicle(currentVehicle.vehicle, currentVehicle.plate, currentVehicle.seat)
                    currentVehicle = {}
                end
            end

            Wait(sleep)
        end
    end)
end

CreateThread(function()
    local flipStartTime = 0
    local stuckStartTime = 0
    local lastRecordTime = 0
    local lastRemainingSeconds = -1

    while true do
        local sleep = 500
        local playerPed = PlayerPedId()

        if taxi.onRoad and task.vehicle then
            sleep = 100
            SetVehicleDoorsLocked(task.vehicle, 1)
            SetVehicleIndividualDoorsLocked(task.vehicle, 0, 2)
            SetVehicleDoorCanBreak(task.vehicle, 0, false)

            if GetVehiclePedIsTryingToEnter(playerPed) == task.vehicle and GetSeatPedIsTryingToEnter(playerPed) == -1 then
                ClearPedTasks(playerPed)
                TaskEnterVehicle(playerPed, task.vehicle, 10000, 0, 1.0, 1, 0)
            end

            -- Automatically detect if the player exited the taxi
            if IsPedInVehicle(playerPed, task.vehicle, false) then
                taxi.playerWasInside = true

                -- If we were waiting for the player, resume the journey!
                if taxi.waitingForPlayer then
                    taxi.waitingForPlayer = false
                    Config.Notification(nil, "Chào mừng quay trở lại! Tài xế tiếp tục hành trình.", "success")

                    SendNUIMessage({
                        action = "show",
                        driver = taxi.driverName,
                        price = taxi.upfrontPrice,
                        speed = taxi.speedStatus,
                        status = "Đang đi đến đích"
                    })

                    ClearPedTasks(task.npc)
                    local speed = (Config.SpeedZones[getVehNodeType(task.toCoords)] or Config.SpeedZones[2]) / Config.SpeedType
                    local currentSpeed = speed * (taxi.speedMultiplier or 1.0)
                    TaskVehicleDriveToCoordLongrange(task.npc, task.vehicle, task.toCoords.x, task.toCoords.y, task.toCoords.z, currentSpeed, taxi.drivingStyle or Config.DrivingStyle, 5.0)
                    SetPedKeepTask(task.npc, true)
                end

                -- Check hotkeys for speed control when inside the vehicle and taxi is in drive mode
                if taxi.inDriveMode then
                    sleep = 0 -- Run every frame to capture controls perfectly when in taxi

                    -- Page Up (Control 10)
                    if IsControlJustPressed(0, 10) then
                        if taxi.speedStatus == "fast" then
                            taxi.speedMultiplier = 1.0
                            taxi.speedStatus = "normal"
                            taxi.drivingStyle = Config.DrivingStyle
                            Config.Notification(nil, "Đã bảo tài xế chạy tốc độ bình thường.", "primary")
                        else
                            taxi.speedMultiplier = 1.4
                            taxi.speedStatus = "fast"
                            taxi.drivingStyle = 786475 -- Fast driving style (runs red lights, follows GPS road, works on all roads including mountains)
                            Config.Notification(nil, "Đã bảo tài xế chạy nhanh lên!", "success")
                        end

                        SendNUIMessage({
                            action = "updateSpeed",
                            speed = taxi.speedStatus
                        })

                        -- Update speed task immediately
                        local vehicleCoords = GetEntityCoords(task.vehicle)
                        local baseSpeed = (Config.SpeedZones[getVehNodeType(vehicleCoords)] or Config.SpeedZones[2]) / Config.SpeedType
                        local currentSpeed = baseSpeed * taxi.speedMultiplier
                        TaskVehicleDriveToCoordLongrange(task.npc, task.vehicle, task.toCoords.x, task.toCoords.y, task.toCoords.z, currentSpeed, taxi.drivingStyle, 5.0)
                        SetPedKeepTask(task.npc, true)
                    end
                end
            elseif taxi.playerWasInside then
                -- Player was inside but is now outside
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
                        Config.Notification(nil, ("Tài xế sẽ dừng lại chờ bạn trong %d giây."):format(waitSeconds), "info")
                    else
                        -- Check if player died during wait to increase timer to 90s
                        if (IsPlayerDead(PlayerId()) or IsEntityDead(PlayerPedId())) and taxi.waitingDuration < 90000 then
                            taxi.waitingDuration = 90000
                            taxi.waitingStartTime = GetGameTimer() -- Reset to give full 90s from death
                            lastRemainingSeconds = -1
                            Config.Notification(nil, "Bạn đã chết. Tài xế sẽ chờ thêm 90 giây kể từ bây giờ.", "info")
                        end

                        local elapsed = GetGameTimer() - taxi.waitingStartTime
                        if elapsed >= taxi.waitingDuration then
                            Config.Notification(nil, "Hết thời gian chờ. Hủy chuyến đi.", "error")
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

            -- --- RESPAWN RECOVERY LOGIC ---
            if DoesEntityExist(task.vehicle) and DoesEntityExist(task.npc) then
                local coords = GetEntityCoords(task.vehicle)
                local heading = GetEntityHeading(task.vehicle)
                local speed = GetEntitySpeed(task.vehicle)
                local gameTimer = GetGameTimer()

                -- 1. Record Safe Points every 2 seconds
                if gameTimer - lastRecordTime > 2000 then
                    lastRecordTime = gameTimer
                    if IsVehicleOnAllWheels(task.vehicle) and speed > 3.0 and IsPointOnRoad(coords.x, coords.y, coords.z, task.vehicle) then
                        taxi.lastSafeCoords = coords
                        taxi.lastSafeHeading = heading
                    end
                end

                -- 2. Check Rescue Conditions
                local triggerRescue = false

                -- A. Water check (immediate)
                if IsEntityInWater(task.vehicle) then
                    triggerRescue = true
                end

                -- B. Flip check (3 seconds)
                local roll = math.abs(GetEntityRoll(task.vehicle))
                local pitch = math.abs(GetEntityPitch(task.vehicle))
                if not IsVehicleOnAllWheels(task.vehicle) or roll > 70.0 or pitch > 70.0 then
                    if flipStartTime == 0 then
                        flipStartTime = gameTimer
                    elseif gameTimer - flipStartTime > 3000 then -- 3.0s
                        triggerRescue = true
                    end
                else
                    flipStartTime = 0
                end

                -- C. Off-road stuck check (4 seconds)
                if speed < 1.0 and not IsPointOnRoad(coords.x, coords.y, coords.z, task.vehicle) then
                    if stuckStartTime == 0 then
                        stuckStartTime = gameTimer
                    elseif gameTimer - stuckStartTime > 4000 then -- 4.0s
                        triggerRescue = true
                    end
                else
                    stuckStartTime = 0
                end

                -- Execute Rescue
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

                    -- Resume driving task to destination
                    local toCoords = task.toCoords or GetEntityCoords(PlayerPedId())
                    local baseSpeed = (Config.SpeedZones[getVehNodeType(toCoords)] or Config.SpeedZones[2]) / Config.SpeedType
                    local currentSpeed = baseSpeed * (taxi.speedMultiplier or 1.0)
                    TaskVehicleDriveToCoordLongrange(task.npc, task.vehicle, toCoords.x, toCoords.y, toCoords.z, currentSpeed, taxi.drivingStyle or Config.DrivingStyle, 5.0)
                    SetPedKeepTask(task.npc, true)

                    Wait(500)
                    DoScreenFadeIn(500)

                    Config.Notification(nil, "Tài xế đã đưa xe quay trở lại tuyến đường an toàn.", "success")
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
    
        while not HasModelLoaded(modelHash) do
            Wait(1)
        end
    end
end

GetPedVehicleSeat = function(ped, vehicle)
    for i = -1, 16 do
        if (GetPedInVehicleSeat(vehicle, i) == ped) then return i end
    end
    return -1
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

HelpNotification = function(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

AdvancedNotification = function(text, title, subtitle, icon, flash, icontype)
    if not flash then flash = true end
    if not icontype then icontype = 1 end
    if not icon then icon = 'CHAR_HUMANDEFAULT' end

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