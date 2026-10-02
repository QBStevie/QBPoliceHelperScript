local QBCore = exports['qb-core']:GetCoreObject()
local Config = Config or {}  -- Load the config
local spawnedPeds = {}
local placementModeActive = false

--- Simple helper that only prints when debugging is enabled.
---@param ... any
local function debugPrint(...)
    if not Config.debug then return end
    print(...)
end

local function removeSpawnedPeds()
    for _, ped in pairs(spawnedPeds) do
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end
    spawnedPeds = {}
end

-- Function to spawn the ped and garage interactions
local function spawnPedAndGarageInteractions()
    if not Config.PoliceGarages or type(Config.PoliceGarages) ~= "table" then
        debugPrint("Error: Config.PoliceGarages is not defined or is not a table!")
        return
    end

    debugPrint("Spawning peds for garages...")  -- Debug message before spawning peds

    for garageIndex, garage in ipairs(Config.PoliceGarages) do
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
                    garageIndex = garageIndex,
                    garage_name = garage.name,
                    carSpawns = garage.carSpawns,
                    vehicleList = garage.vehicleList
                }
            },
            distance = 3.0
        })
        spawnedPeds["garage:" .. garageIndex] = ped

        debugPrint("Ped created for garage: " .. garage.name)  -- Debug print for ped creation
    end
end


local function spawnBossMenuPeds()
    if not Config.BossMenus or type(Config.BossMenus) ~= "table" then
        debugPrint("Config.BossMenus is not defined or is not a table, skipping boss menu ped setup.")
        return
    end

    debugPrint("Spawning peds for boss menus...")

    for bossIndex, bossMenu in ipairs(Config.BossMenus) do
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
                            bossIndex = bossIndex,
                            job = bossMenu.job,
                            minimumGrade = bossMenu.minimumGrade,
                            requireBoss = bossMenu.requireBoss,
                        }
                    }
                },
                distance = bossMenu.distance or 2.0
            })
            spawnedPeds["boss:" .. bossIndex] = ped

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
    if type(data) ~= "table" then return end
    debugPrint("Received data:", json.encode(data)) 
    local garageName = data.garage_name
    local garageIndex = tonumber(data.garageIndex)
    local garage = garageIndex and Config.PoliceGarages[garageIndex]
    local carSpawns = data.carSpawns
    local vehicleList = data.vehicleList
    local PlayerData = QBCore.Functions.GetPlayerData()
    local playerJob = PlayerData and PlayerData.job and PlayerData.job.name
    local playerRank = PlayerData and PlayerData.job and PlayerData.job.grade


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


    if not garage or playerJob ~= (garage.job or "police") then
        QBCore.Functions.Notify("You are not a Law Enforcement Officer, you cannot access this garage.", "error")
        return
    end

    if type(playerRank) == "table" then
        playerRank = playerRank.level or playerRank.grade or 0
        debugPrint("Player Rank (Fixed):", playerRank)
    end
    playerRank = tonumber(playerRank) or 0

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
                vehicleIndex = i,
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
                        garageIndex = garageIndex,
                        vehicleIndex = option.vehicleIndex
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

    TriggerEvent('qb-bossmenu:client:OpenMenu')
end)


RegisterNetEvent('qb-policehelper:spawnVehicle', function(data)
    if not data or not data.garageIndex or not data.vehicleIndex then return end
    TriggerServerEvent('qb-policehelper:server:requestVehicle', data.garageIndex, data.vehicleIndex)
end)

RegisterNetEvent('qb-policehelper:client:vehicleSpawned', function(netId)
    local timeout = GetGameTimer() + 5000
    local vehicle = NetToVeh(netId)
    while vehicle == 0 and GetGameTimer() < timeout do
        Wait(50)
        vehicle = NetToVeh(netId)
    end
    if vehicle == 0 then
        QBCore.Functions.Notify("The vehicle could not be loaded.", "error")
        return
    end

    SetEntityAsMissionEntity(vehicle, true, true)
    exports['LegacyFuel']:SetFuel(vehicle, 100.0)
    TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
end)

local function applyPlacements(placements)
    for index, placement in pairs(placements.garages or {}) do
        local garage = Config.PoliceGarages[tonumber(index)]
        if garage then
            garage.pedCoords = vector3(placement.x, placement.y, placement.z)
            garage.pedHeading = placement.heading
        end
    end
    for index, placement in pairs(placements.bossMenus or {}) do
        local bossMenu = Config.BossMenus[tonumber(index)]
        if bossMenu then
            bossMenu.pedCoords = vector3(placement.x, placement.y, placement.z)
            bossMenu.pedHeading = placement.heading
        end
    end
end

RegisterNetEvent('qb-policehelper:client:syncPlacements', function(placements)
    applyPlacements(placements or {})
    removeSpawnedPeds()
    spawnPedAndGarageInteractions()
    spawnBossMenuPeds()
end)

local function beginPlacement(kind, index)
    local targetList = kind == "garage" and Config.PoliceGarages or Config.BossMenus
    local target = targetList[index]
    if not target then
        QBCore.Functions.Notify("That placement does not exist.", "error")
        return
    end
    if placementModeActive then return end
    placementModeActive = true

    local model = target.pedModel or (kind == "garage" and `s_m_y_cop_01` or `s_m_m_security_01`)
    RequestModel(model)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(50) end
    if not HasModelLoaded(model) then
        placementModeActive = false
        QBCore.Functions.Notify("Could not load the placement ped model.", "error")
        return
    end

    local coords = GetEntityCoords(PlayerPedId())
    local ghost = CreatePed(4, model, coords.x, coords.y, coords.z, GetEntityHeading(PlayerPedId()), false, false)
    SetEntityAlpha(ghost, 150, false)
    SetEntityCollision(ghost, false, false)
    FreezeEntityPosition(ghost, true)
    SetEntityInvincible(ghost, true)
    SetModelAsNoLongerNeeded(model)

    QBCore.Functions.Notify("Placement: WASD move, Q/E rotate, Up/Down arrows adjust height, Enter save, Backspace cancel.", "primary", 8000)
    CreateThread(function()
        local confirmed = false
        while placementModeActive do
            Wait(0)
            DisableControlAction(0, 32, true)
            DisableControlAction(0, 33, true)
            DisableControlAction(0, 34, true)
            DisableControlAction(0, 35, true)
            DisableControlAction(0, 38, true)
            DisableControlAction(0, 44, true)
            DisableControlAction(0, 172, true)
            DisableControlAction(0, 173, true)
            DisableControlAction(0, 191, true)
            DisableControlAction(0, 177, true)

            BeginTextCommandDisplayHelp("STRING")
            AddTextComponentSubstringPlayerName("W/A/S/D move | Q/E rotate | Arrow Up/Down adjust height | Enter save | Backspace cancel")
            EndTextCommandDisplayHelp(0, false, true, -1)

            local position = GetEntityCoords(ghost)
            local heading = GetEntityHeading(ghost)
            local step = GetFrameTime() * (IsControlPressed(0, 21) and 8.0 or 2.0)
            local radians = math.rad(heading)
            local forwardX, forwardY = -math.sin(radians), math.cos(radians)
            local rightX, rightY = math.cos(radians), math.sin(radians)

            if IsDisabledControlPressed(0, 32) then position = position + vector3(forwardX * step, forwardY * step, 0.0) end
            if IsDisabledControlPressed(0, 33) then position = position - vector3(forwardX * step, forwardY * step, 0.0) end
            if IsDisabledControlPressed(0, 34) then position = position - vector3(rightX * step, rightY * step, 0.0) end
            if IsDisabledControlPressed(0, 35) then position = position + vector3(rightX * step, rightY * step, 0.0) end
            if IsDisabledControlPressed(0, 172) then position = position + vector3(0.0, 0.0, step) end
            if IsDisabledControlPressed(0, 173) then position = position - vector3(0.0, 0.0, step) end
            if IsDisabledControlPressed(0, 44) then heading = heading - 90.0 * GetFrameTime() end
            if IsDisabledControlPressed(0, 38) then heading = heading + 90.0 * GetFrameTime() end
            SetEntityCoordsNoOffset(ghost, position.x, position.y, position.z, false, false, false)
            SetEntityHeading(ghost, heading)

            if IsDisabledControlJustReleased(0, 191) then
                confirmed = true
                local finalCoords = GetEntityCoords(ghost)
                TriggerServerEvent('qb-policehelper:server:savePlacement', kind, index, {
                    x = finalCoords.x,
                    y = finalCoords.y,
                    z = finalCoords.z,
                    heading = (GetEntityHeading(ghost) % 360.0 + 360.0) % 360.0
                })
                break
            elseif IsDisabledControlJustReleased(0, 177) then
                break
            end
        end

        if DoesEntityExist(ghost) then DeleteEntity(ghost) end
        placementModeActive = false
        if not confirmed then QBCore.Functions.Notify("Placement cancelled.", "error") end
    end)
end

RegisterNetEvent('qb-policehelper:client:startPlacement', function(kind, index)
    beginPlacement(kind, index)
end)

RegisterCommand('qbph_place', function(_, args)
    local kind = args[1]
    local index = tonumber(args[2])
    if (kind ~= "garage" and kind ~= "boss") or not index or index < 1 or index % 1 ~= 0 then
        QBCore.Functions.Notify("Usage: /qbph_place <garage|boss> <index>", "error")
        return
    end
    TriggerServerEvent('qb-policehelper:server:requestPlacementMode', kind, index)
end, false)

setupJobActions()
TriggerServerEvent('qb-policehelper:server:requestPlacements')
