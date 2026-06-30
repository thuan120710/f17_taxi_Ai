Config = {}
----------------------------------------------------------------
Config.Locale = 'de'
Config.VersionChecker = false
----------------------------------------------------------------
-- If set to 'Standalone' then you have to add your own functions in server.lua
Config.Framework = 'QBCore' -- Set to 'ESX', 'QBCore' or 'Standalone'
----------------------------------------------------------------
-- For ESX you'll need esx_addonaccount for that!
-- For QBCore you'll need qb-banking for that!
Config.Society = {
    enable = false, -- Set false if you don't want that the Price will be added to a society account
    account = 'society_taxi'
}
----------------------------------------------------------------
-- If you deactivate the command, you can still use the export: exports.msk_aitaxi:callTaxi()
Config.Command = {
    enable = true,
    command = 'callTaxi'
}

Config.AbortTaxiDrive = {
    enable = true,
    command = 'abortTaxi',
    hotkey = 'X'
}

Config.SpawnRadius = 200.0 -- default: 200.0 meters // Do not set more than 200.0!
Config.DrivingStyle = 786603 -- default: 786603 // Standard road traffic style, works on all roads including mountains
Config.SpeedType = 3.6 -- kmh = 3.6 // mph = 2.236936
Config.SpeedZones = {
    -- Speed of the Taxi in specific zones
    [2] = 100, -- City / main roads
    [10] = 60, -- Slow roads
    [64] = 60, -- Off road
    [66] = 150, -- Freeway
    [82] = 150, -- Freeway tunnels
}

Config.Price = {
    base = 20, -- Price for driving to your position
    tick = 1, -- Price per tick
    tickTime = 50, 

    color = {r = 255, g = 255, b = 255, a = 255},
    position = {height = 0.90, width = 0.50}
}
----------------------------------------------------------------
-- It will use a random vehicle and random pedmodel from the list below
Config.Taxi = {
    vehicles = {
        -- You can set different models
        'taxi',
        'taxi',
    },
    pedmodels = {
        -- You can set different models
        {name = 'Michael Reynold', model = 'ig_claypain', voice = 'A_M_M_EASTSA_02_LATINO_FULL_01'},
        {name = 'John Smith', model = 'ig_claypain', voice = 'A_M_M_EASTSA_02_LATINO_FULL_01'},
    },
}