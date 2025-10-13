local QBCore = exports['qb-core']:GetCoreObject()
local Config = Config or {}  -- Load the config

--- Simple helper that only prints when debugging is enabled.
---@param ... any
local function debugPrint(...)
    if not Config.debug then return end
    print(...)
end

-- Function to spawn the ped and garage interactions
local function spawnPedAndGarageInteractions()
    if not Config.PoliceGarages or type(Config.PoliceGarages) ~= "table" then
        debugPrint("Error: Config.PoliceGarages is not defined or is not a table!")
        return
    end

    debugPrint("Spawning peds for garages...")  -- Debug message before spawning peds

    for _, garage in ipairs(Config.PoliceGarages) do
        debugPrint("Creating ped for garage: " .. garage.name)  -- Debug message for each garage

        local pedModel = garage.pedModel or `s_m_y_cop_01`

        RequestModel(pedModel)
        while not HasModelLoaded(pedModel) do
            Wait(500)
        end

        local ped = CreatePed(4, pedModel, garage.pedCoords.x, garage.pedCoords.y, garage.pedCoords.z, garage.pedHeading, false, true)
        SetEntityInvincible(ped, true)
        SetEntityVisible(ped, true)
        FreezeEntityPosition(ped, true)

        exports['qb-target']:AddTargetEntity(ped, {
            options = {
                {
                    type = "client",
                    event = "qb-policehelper:openGarageMenu",  
                    icon = "fas fa-car",
                    label = "Access Police Garage",
                    jobType = "leo",
                    garage_name = garage.name,
                    carSpawns = garage.carSpawns,
                    vehicleList = garage.vehicleList
                }
            },
            distance = 3.0
        })

        debugPrint("Ped created for garage: " .. garage.name)  -- Debug print for ped creation
    end
end


local function spawnBossMenuPeds()
    if not Config.BossMenus or type(Config.BossMenus) ~= "table" then
        debugPrint("Config.BossMenus is not defined or is not a table, skipping boss menu ped setup.")
        return
    end

    debugPrint("Spawning peds for boss menus...")

    for _, bossMenu in ipairs(Config.BossMenus) do
        if not bossMenu.pedCoords then
            debugPrint("Boss menu entry missing pedCoords, skipping.")
        else
            local pedModel = bossMenu.pedModel or `s_m_m_security_01`

            RequestModel(pedModel)
            while not HasModelLoaded(pedModel) do
                Wait(500)
            end

            local ped = CreatePed(4, pedModel, bossMenu.pedCoords.x, bossMenu.pedCoords.y, bossMenu.pedCoords.z, bossMenu.pedHeading or 0.0, false, true)
            SetEntityInvincible(ped, true)
            SetEntityVisible(ped, true)
            FreezeEntityPosition(ped, true)

            exports['qb-target']:AddTargetEntity(ped, {
                options = {
                    {
                        type = "client",
                        event = "qb-policehelper:openBossMenu",
                        icon = bossMenu.icon or "fas fa-briefcase",
                        label = bossMenu.label or "Open Boss Menu",
                        job = bossMenu.job,
                        jobType = bossMenu.jobType,
                        args = {
                            job = bossMenu.job,
                            minimumGrade = bossMenu.minimumGrade,
                            requireBoss = bossMenu.requireBoss,
                        }
                    }
                },
                distance = bossMenu.distance or 2.0
            })

            debugPrint("Boss menu ped created for job: " .. (bossMenu.job or "unknown"))
        end
    end
end


local function setupJobActions()
    if not Config.Actions or type(Config.Actions) ~= "table" then
        debugPrint("Error: Config.Actions is not defined or is not a table!")
        return
    end

    debugPrint("Setting up job actions...")  -- Debug message for setting up actions

    for _, action in ipairs(Config.Actions) do
        exports['qb-target']:AddTargetEntity(PlayerPedId(), {
            options = {
                {
                    type = action.type,
                    event = action.event,
                    icon = action.icon,
                    label = action.label,
                    job = action.job,
                    item = action.item
                }
            },
            distance = 2.0
        })

        debugPrint("Job action added: " .. action.label)
    end
end

RegisterNetEvent('qb-policehelper:openGarageMenu', function(data)
    debugPrint("Received data:", json.encode(data)) 
    local garageName = data.garage_name
    local carSpawns = data.carSpawns
    local vehicleList = data.vehicleList
    local PlayerData = QBCore.Functions.GetPlayerData()
    local playerJob = PlayerData.job.name 
    local playerRank = PlayerData.job.grade 


    if garageName then
        debugPrint("Opening garage menu for:", garageName)
    end

    if not carSpawns then
        debugPrint("Error: carSpawns is not available in the received data!")
        QBCore.Functions.Notify("Error: carSpawns is missing!", "error")
        return
    end


    if type(carSpawns) ~= "table" then
        debugPrint("Error: carSpawns is not a valid table!")
        QBCore.Functions.Notify("Error: carSpawns is not a valid table!", "error")
        return
    end

    if type(vehicleList) ~= "table" then
        debugPrint("Error: vehicleList is not a valid table!")
        QBCore.Functions.Notify("Error: vehicle list is missing!", "error")
        return
    end


    debugPrint("Player Rank (Raw): ", json.encode(playerRank))


    if playerJob ~= "police" then
        QBCore.Functions.Notify("You are not a Law Enforcement Officer, you cannot access this garage.", "error")
        return
    end

    if type(playerRank) == "table" then
        if playerRank.grade then
            playerRank = playerRank.grade  
        elseif playerRank.level then
            playerRank = playerRank.level  
        else
            playerRank = 0  
        end
        debugPrint("Player Rank (Fixed):", playerRank)
    end

    local sanitizedSpawns = {}
    for index, spawn in ipairs(carSpawns) do
        if spawn and spawn.x and spawn.y and spawn.z and spawn.w then
            sanitizedSpawns[index] = { x = spawn.x, y = spawn.y, z = spawn.z, w = spawn.w }
        end
    end

    local options = {}
    for i, vehicle in ipairs(vehicleList) do
        debugPrint("Vehicle rank for", vehicle.label, ":", vehicle.rank)

        local spawnLocation = sanitizedSpawns[i]
        local hasRequiredRank = type(vehicle.rank) == "number" and playerRank >= vehicle.rank
        local hasModel = type(vehicle.model) == "string" and vehicle.model ~= ""

        if hasRequiredRank and hasModel and spawnLocation then
            table.insert(options, {
                label = vehicle.label,
                vehicleModel = vehicle.model,
                spawnLocation = spawnLocation,
                requiredRank = vehicle.rank
            })
        end
    end

    if #options > 0 then
        local menuOptions = {}
        for _, option in ipairs(options) do
            table.insert(menuOptions, {
                header = option.label,
                txt = "Rank required: " .. option.requiredRank,
                params = {
                    event = 'qb-policehelper:spawnVehicle',
                    args = {
                        vehicleModel = option.vehicleModel,
                        spawnLocation = option.spawnLocation,
                        carSpawns = sanitizedSpawns
                    }
                }
            })
        end

        exports['qb-menu']:openMenu(menuOptions)
    else

        QBCore.Functions.Notify("You do not have the required rank to access any vehicles.", "error")
    end
end)


RegisterNetEvent('qb-policehelper:openBossMenu', function(optionData)
    local args = nil
    if optionData then
        if optionData.args then
            args = optionData.args
        elseif optionData.option and optionData.option.args then
            args = optionData.option.args
        end
    end

    local data = args or optionData or {}
    local PlayerData = QBCore.Functions.GetPlayerData()
    local jobData = PlayerData and PlayerData.job or {}
    local playerJob = jobData.name
    local playerGrade = jobData.grade
    local requiredJob = data and data.job or nil
    local minimumGrade = data and data.minimumGrade or 0
    local requireBoss = data and data.requireBoss

    if not requiredJob then
        debugPrint("Boss menu interaction missing job requirement, aborting.")
        QBCore.Functions.Notify("Boss menu not configured correctly.", "error")
        return
    end

    if playerJob ~= requiredJob then
        QBCore.Functions.Notify("You are not employed here.", "error")
        return
    end

    if type(playerGrade) == "table" then
        if playerGrade.grade then
            playerGrade = playerGrade.grade
        elseif playerGrade.level then
            playerGrade = playerGrade.level
        else
            playerGrade = 0
        end
    end

    playerGrade = tonumber(playerGrade) or 0

    if requireBoss ~= false and not jobData.isboss then
        QBCore.Functions.Notify("Only bosses can access this menu.", "error")
        return
    end

    if minimumGrade and playerGrade < minimumGrade then
        QBCore.Functions.Notify("You do not have the required rank.", "error")
        return
    end

    TriggerServerEvent('qb-bossmenu:server:openMenu')
end)


RegisterNetEvent('qb-policehelper:spawnVehicle', function(data)
    local vehicleModel = data.vehicleModel
    local spawnLocation = data.spawnLocation
    local carSpawns = data.carSpawns or {}

    local function isSpawnOccupied(location)
        if not location then return true end
        local vehicles = GetGamePool('CVehicle')
        for _, vehicle in ipairs(vehicles) do
            local vehiclePos = GetEntityCoords(vehicle)
            local distance = Vdist(vehiclePos.x, vehiclePos.y, vehiclePos.z, location.x, location.y, location.z)
            if distance < 5.0 then
                return true
            end
        end
        return false
    end

    debugPrint("Requested vehicle model: ", vehicleModel)
    debugPrint("Primary spawn location: ", json.encode(spawnLocation or {}))
    debugPrint("Available carSpawns: ", json.encode(carSpawns))

    if isSpawnOccupied(spawnLocation) then
        debugPrint("Spawn point occupied. Searching for an empty spot...")
        local foundEmptySpot = false
        for _, newSpawn in ipairs(carSpawns) do
            if not isSpawnOccupied(newSpawn) then
                spawnLocation = newSpawn
                debugPrint("Found an available spawn point.")
                foundEmptySpot = true
                break
            end
        end

        if not foundEmptySpot then
            debugPrint("No empty spawn spots available.")
            QBCore.Functions.Notify("No empty spawn spots available!", "error")
            return
        end
    end

    if not vehicleModel or not spawnLocation then
        debugPrint("Vehicle model or spawn location missing, aborting spawn.")
        QBCore.Functions.Notify("Invalid vehicle information received!", "error")
        return
    end

    RequestModel(vehicleModel)
    while not HasModelLoaded(vehicleModel) do
        Wait(500)
    end

    local vehicle = CreateVehicle(vehicleModel, spawnLocation.x, spawnLocation.y, spawnLocation.z, spawnLocation.w, true, false)

    exports['LegacyFuel']:SetFuel(vehicle, 100.0)

    SetEntityAsMissionEntity(vehicle, true, true)
    local playerPed = PlayerPedId()
    TaskWarpPedIntoVehicle(playerPed, vehicle, -1)


    debugPrint("Vehicle spawned with full fuel: " .. vehicleModel)
end)

spawnPedAndGarageInteractions()
spawnBossMenuPeds()
setupJobActions()
