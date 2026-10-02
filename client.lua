local QBCore = exports['qb-core']:GetCoreObject()
local Config = Config or {}  -- Load the config
local spawnedPeds = {}
local placementModeActive = false

local function locationAllowsJob(location, jobName)
    if type(location.jobs) == "table" then
        for _, allowedJob in ipairs(location.jobs) do
            if allowedJob == jobName then return true end
        end
        return false
    end
    return jobName == (location.job or "police")
end

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
                    job = garage.jobs or garage.job or "police",
                    garageIndex = garageIndex,
                    category = "garages"
                }
            },
            distance = 3.0
        })
        spawnedPeds["garage:" .. garageIndex] = ped

        debugPrint("Ped created for garage: " .. garage.name)  -- Debug print for ped creation
    end
end

local function spawnOtherLocationPeds()
    local categories = Config.LocationCategories or {}
    for category, locations in pairs(categories) do
        if category ~= "garages" and category ~= "bosses" then
            for index, location in ipairs(locations) do
                local coords = location.coords or location.pedCoords
                if coords then
                    local model = location.pedModel or `s_m_m_security_01`
                    RequestModel(model)
                    local timeout = GetGameTimer() + 10000
                    while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(50) end
                    if HasModelLoaded(model) then
                        local ped = CreatePed(4, model, coords.x, coords.y, coords.z, location.heading or location.pedHeading or 0.0, false, true)
                        SetEntityInvincible(ped, true)
                        FreezeEntityPosition(ped, true)
                        exports['qb-target']:AddTargetEntity(ped, {
                            options = {{
                                type = "client",
                                event = (category == "helicopters" or category == "boats")
                                    and "qb-policehelper:openGarageMenu" or "qb-policehelper:useLocation",
                                icon = location.icon or "fas fa-briefcase",
                                label = location.label or location.name or category,
                                job = location.jobs or location.job or "police",
                                category = category,
                                locationIndex = index,
                                garageIndex = index,
                            }},
                            distance = location.distance or 2.0
                        })
                        spawnedPeds[category .. ":" .. index] = ped
                        SetModelAsNoLongerNeeded(model)
                    end
                end
            end
        end
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
    local args = data.args or data
    local category = args.category or "garages"
    local garageIndex = tonumber(args.garageIndex)
    local garage = Config.LocationCategories[category] and Config.LocationCategories[category][garageIndex]
    local garageName = garage and garage.name
    local vehicleList = garage and garage.vehicleList
    local PlayerData = QBCore.Functions.GetPlayerData()
    local playerJob = PlayerData and PlayerData.job and PlayerData.job.name
    local playerRank = PlayerData and PlayerData.job and PlayerData.job.grade


    if garageName then
        debugPrint("Opening garage menu for:", garageName)
    end

    if type(vehicleList) ~= "table" then
        debugPrint("Error: vehicleList is not a valid table!")
        QBCore.Functions.Notify("Error: vehicle list is missing!", "error")
        return
    end


    debugPrint("Player Rank (Raw): ", json.encode(playerRank))


    local sharedJob = false
    for _, job in ipairs(Config.SharedGarageJobs or {}) do
        if job == playerJob then sharedJob = true break end
    end
    if not garage or (not locationAllowsJob(garage, playerJob) and not sharedJob) then
        QBCore.Functions.Notify("You are not a Law Enforcement Officer, you cannot access this garage.", "error")
        return
    end

    if type(playerRank) == "table" then
        playerRank = playerRank.level or playerRank.grade or 0
        debugPrint("Player Rank (Fixed):", playerRank)
    end
    playerRank = tonumber(playerRank) or 0

    local options = {}
    for i, vehicle in ipairs(vehicleList) do
        local requiredRank = tonumber(vehicle.minimumGrade or vehicle.rank or 0)
        local hasRequiredRank = requiredRank and playerRank >= requiredRank
        local hasModel = type(vehicle.model) == "string" and vehicle.model ~= ""

        if hasRequiredRank and hasModel and (not vehicle.job or vehicle.job == playerJob) then
            table.insert(options, {
                label = vehicle.label or vehicle.model,
                vehicleIndex = i,
                requiredRank = requiredRank,
                vehicle = vehicle,
            })
        end
    end

    do
        local menuOptions = {}
        for _, option in ipairs(options) do
            table.insert(menuOptions, {
                header = option.label,
                txt = ("Grade %s+ | %s"):format(option.requiredRank, option.vehicle.type or "car"),
                params = {
                    event = 'qb-policehelper:previewVehicle',
                    args = {
                        garageIndex = garageIndex, vehicleIndex = option.vehicleIndex,
                        category = category
                    }
                }
            })
        end
        menuOptions[#menuOptions + 1] = { header = "Return current vehicle", params = { event = "qb-policehelper:returnVehicle", args = { garageIndex = garageIndex, category = category } } }
        menuOptions[#menuOptions + 1] = { header = "Repair current vehicle", params = { event = "qb-policehelper:serviceVehicle", args = { action = "repair" } } }
        menuOptions[#menuOptions + 1] = { header = "Clean current vehicle", params = { event = "qb-policehelper:serviceVehicle", args = { action = "clean" } } }
        exports['qb-menu']:openMenu(menuOptions)
    end
end)

RegisterNetEvent('qb-policehelper:useLocation', function(data)
    local args = data and (data.args or data) or {}
    local category = args.category
    local point = Config.LocationCategories[category] and Config.LocationCategories[category][tonumber(args.locationIndex)]
    if not point then return end
    local job = QBCore.Functions.GetPlayerData().job
    if not job or not locationAllowsJob(point, job.name) then
        QBCore.Functions.Notify("You are not authorized to use this location.", "error")
        return
    end
    if point.event and type(point.event) == "string" then
        if point.eventType == "server" then
            TriggerServerEvent(point.event)
        else
            TriggerEvent(point.event)
        end
    else
        QBCore.Functions.Notify(("Configure an event for this %s location."):format(category), "primary")
    end
end)

RegisterNetEvent('qb-policehelper:requestEditor', function()
    TriggerServerEvent('qb-policehelper:server:requestEditor')
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


local previewVehicleEntity
local previewCamera

local function clearVehiclePreview()
    if previewCamera then
        RenderScriptCams(false, true, 300, true, true)
        DestroyCam(previewCamera, false)
        previewCamera = nil
    end
    if previewVehicleEntity and DoesEntityExist(previewVehicleEntity) then DeleteEntity(previewVehicleEntity) end
    previewVehicleEntity = nil
end

RegisterNetEvent('qb-policehelper:previewVehicle', function(data)
    data = data and (data.args or data)
    if not data then return end
    local category = data.category or "garages"
    local garage = Config.LocationCategories[category] and Config.LocationCategories[category][tonumber(data.garageIndex)]
    local vehicle = garage and garage.vehicleList and garage.vehicleList[tonumber(data.vehicleIndex)]
    if not vehicle then return end

    clearVehiclePreview()
    local model = joaat(vehicle.model)
    RequestModel(model)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(50) end
    if not HasModelLoaded(model) then
        QBCore.Functions.Notify("Could not load this vehicle for preview.", "error")
        return
    end
    local playerCoords = GetEntityCoords(PlayerPedId())
    previewVehicleEntity = CreateVehicle(model, playerCoords.x + 2.0, playerCoords.y, playerCoords.z, GetEntityHeading(PlayerPedId()), false, false)
    if previewVehicleEntity == 0 then
        previewVehicleEntity = nil
        QBCore.Functions.Notify("Could not create a vehicle preview.", "error")
        return
    end
    SetEntityCollision(previewVehicleEntity, false, false)
    FreezeEntityPosition(previewVehicleEntity, true)
    SetEntityInvincible(previewVehicleEntity, true)
    SetVehicleDoorsLocked(previewVehicleEntity, 2)
    if vehicle.livery then SetVehicleLivery(previewVehicleEntity, vehicle.livery) end
    for extra, enabled in pairs(vehicle.extras or {}) do
        SetVehicleExtra(previewVehicleEntity, tonumber(extra), not enabled)
    end
    if vehicle.primaryColor then
        SetVehicleColours(previewVehicleEntity, vehicle.primaryColor, vehicle.secondaryColor or vehicle.primaryColor)
    end
    if vehicle.plate then SetVehicleNumberPlateText(previewVehicleEntity, tostring(vehicle.plate):sub(1, 8)) end
    SetModelAsNoLongerNeeded(model)

    local position = GetEntityCoords(previewVehicleEntity)
    previewCamera = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(previewCamera, position.x + 4.0, position.y + 5.0, position.z + 2.0)
    PointCamAtEntity(previewCamera, previewVehicleEntity, 0.0, 0.0, 0.5, true)
    SetCamActive(previewCamera, true)
    RenderScriptCams(true, true, 300, true, true)

    exports['qb-menu']:openMenu({
        { header = vehicle.label or vehicle.model, txt = "Vehicle preview", isMenuHeader = true },
        { header = "Checkout vehicle", params = { event = "qb-policehelper:checkoutVehicle", args = data } },
        { header = "Cancel preview", params = { event = "qb-policehelper:cancelVehiclePreview" } },
    })
end)

RegisterNetEvent('qb-policehelper:cancelVehiclePreview', clearVehiclePreview)
RegisterNetEvent('qb-policehelper:checkoutVehicle', function(data)
    clearVehiclePreview()
    data = data and (data.args or data)
    if data then
        TriggerServerEvent('qb-policehelper:server:requestVehicle', data.garageIndex, data.vehicleIndex, data.category)
    end
end)

RegisterNetEvent('qb-policehelper:client:vehicleSpawned', function(netId, properties)
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
    properties = properties or {}
    if properties.plate then SetVehicleNumberPlateText(vehicle, tostring(properties.plate):sub(1, 8)) end
    if properties.livery then SetVehicleLivery(vehicle, properties.livery) end
    for extra, enabled in pairs(properties.extras or {}) do
        SetVehicleExtra(vehicle, tonumber(extra), not enabled)
    end
    if properties.primaryColor then SetVehicleColours(vehicle, properties.primaryColor, properties.secondaryColor or properties.primaryColor) end
    SetVehicleEngineHealth(vehicle, properties.engine or 1000.0)
    SetVehicleBodyHealth(vehicle, properties.body or 1000.0)
    if GetResourceState('LegacyFuel') == 'started' then
        exports['LegacyFuel']:SetFuel(vehicle, properties.fuel or 100.0)
    end
    TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
end)

RegisterNetEvent('qb-policehelper:returnVehicle', function(data)
    data = data and (data.args or data)
    if data then TriggerServerEvent('qb-policehelper:server:returnVehicle', data.garageIndex, data.category) end
end)

RegisterNetEvent('qb-policehelper:serviceVehicle', function(data)
    data = data and (data.args or data)
    if not data or (data.action ~= "repair" and data.action ~= "clean") then return end
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if vehicle == 0 then
        QBCore.Functions.Notify("You must be in a vehicle.", "error")
        return
    end
    if data.action == "repair" then
        SetVehicleFixed(vehicle)
        SetVehicleDeformationFixed(vehicle)
        SetVehicleEngineHealth(vehicle, 1000.0)
        SetVehicleBodyHealth(vehicle, 1000.0)
    elseif data.action == "clean" then
        SetVehicleDirtLevel(vehicle, 0.0)
    end
end)

local function applyLocations(locations)
    if type(locations) ~= "table" then return end
    Config.LocationCategories = locations
    Config.PoliceGarages = locations.garages or {}
    Config.BossMenus = locations.bosses or {}
    Config.DutyPoints = locations.duty or {}
    Config.Armories = locations.armories or {}
    Config.EvidenceLockers = locations.evidence or {}
    Config.PersonalLockers = locations.personal or {}
    Config.ClothingRooms = locations.clothing or {}
    Config.Impounds = locations.impounds or {}
    Config.HelicopterGarages = locations.helicopters or {}
    Config.BoatGarages = locations.boats or {}
    for _, list in pairs(Config.LocationCategories) do
        for _, point in ipairs(list) do
            if point.pedCoords then point.pedCoords = vector3(point.pedCoords.x, point.pedCoords.y, point.pedCoords.z) end
            if point.coords then point.coords = vector3(point.coords.x, point.coords.y, point.coords.z) end
            for index, spawn in ipairs(point.carSpawns or {}) do
                point.carSpawns[index] = vector4(spawn.x, spawn.y, spawn.z, spawn.w or 0.0)
            end
        end
    end
end

RegisterNetEvent('qb-policehelper:client:syncPlacements', function(placements, locations)
    if locations then applyLocations(locations) end
    for index, placement in pairs((placements or {}).garages or {}) do
        local garage = Config.PoliceGarages[tonumber(index)]
        if garage then
            garage.pedCoords = vector3(placement.x, placement.y, placement.z)
            garage.pedHeading = placement.heading
        end
    end
    for index, placement in pairs((placements or {}).bossMenus or {}) do
        local bossMenu = Config.BossMenus[tonumber(index)]
        if bossMenu then
            bossMenu.pedCoords = vector3(placement.x, placement.y, placement.z)
            bossMenu.pedHeading = placement.heading
        end
    end
    removeSpawnedPeds()
    spawnPedAndGarageInteractions()
    spawnBossMenuPeds()
    spawnOtherLocationPeds()
end)

local function beginPlacement(kind, index)
    local spawnCategory, spawnIndexText
    if type(kind) == "string" then
        spawnCategory, spawnIndexText = kind:match("^locationSpawn:(.+):(%d+)$")
    end
    local returnCategory = type(kind) == "string" and kind:match("^locationReturn:(.+)$")
    local category = spawnCategory or returnCategory or (type(kind) == "string" and kind:match("^location:(.+)$"))
    local targetList = category and Config.LocationCategories[category]
        or kind == "garage" and Config.PoliceGarages
        or Config.BossMenus
    local target = targetList and targetList[index]
    if target and spawnCategory then target = target.carSpawns and target.carSpawns[tonumber(spawnIndexText)] end
    if not target then
        QBCore.Functions.Notify("That placement does not exist.", "error")
        return
    end
    if placementModeActive then return end
    placementModeActive = true

    local model = target.pedModel or ((kind == "garage" or category == "garages") and `s_m_y_cop_01` or `s_m_m_security_01`)
    RequestModel(model)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(50) end
    if not HasModelLoaded(model) then
        placementModeActive = false
        QBCore.Functions.Notify("Could not load the placement ped model.", "error")
        return
    end

    local startCoords = target.pedCoords or target.coords or GetEntityCoords(PlayerPedId())
    if spawnCategory then
        startCoords = vector3(target.x, target.y, target.z)
    elseif returnCategory then
        startCoords = target.returnCoords
    end
    local coords = vector3(startCoords.x, startCoords.y, startCoords.z)
    local heading = target.w or target.returnHeading or target.pedHeading or target.heading or GetEntityHeading(PlayerPedId())
    local ghost = CreatePed(4, model, coords.x, coords.y, coords.z, heading, false, false)
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

local editorCategoryLabels = {
    garages = "Vehicle garages",
    bosses = "Boss menus",
    duty = "Duty points",
    armories = "Armories",
    evidence = "Evidence lockers",
    personal = "Personal lockers",
    clothing = "Clothing rooms",
    impounds = "Impounds",
    helicopters = "Helicopter garages",
    boats = "Boat garages",
}

local function openEditorCategory(category, locations)
    local list = locations[category] or {}
    local options = {
        { header = editorCategoryLabels[category] or category, isMenuHeader = true },
        { header = "+ Add at my position", params = { event = "qb-policehelper:editorAction", args = { category = category, action = "add" } } },
    }
    for index, point in ipairs(list) do
        options[#options + 1] = {
            header = ("%d. %s"):format(index, point.name or point.label or category),
            txt = point.job or "police",
            params = { event = "qb-policehelper:openEditorPoint", args = { category = category, index = index, hasReturn = point.returnCoords ~= nil } }
        }
    end
    options[#options + 1] = { header = "Close", params = { event = "qb-menu:closeMenu" } }
    exports['qb-menu']:openMenu(options)
end

RegisterNetEvent('qb-policehelper:client:openEditor', function(locations)
    local options = { { header = "QB Police Helper Editor", isMenuHeader = true } }
    for category, label in pairs(editorCategoryLabels) do
        options[#options + 1] = {
            header = label,
            txt = ("%d configured"):format(#(locations[category] or {})),
            params = { event = "qb-policehelper:openEditorCategory", args = { category = category, locations = locations } }
        }
    end
    options[#options + 1] = { header = "Close", params = { event = "qb-menu:closeMenu" } }
    exports['qb-menu']:openMenu(options)
end)

RegisterNetEvent('qb-policehelper:openEditorCategory', function(data)
    data = data and (data.args or data)
    if data then openEditorCategory(data.category, data.locations or {}) end
end)

RegisterNetEvent('qb-policehelper:openEditorPoint', function(data)
    data = data and (data.args or data)
    if not data then return end
    local options = {
        { header = "Edit " .. data.category .. " #" .. data.index, isMenuHeader = true },
        { header = "Move", params = { event = "qb-policehelper:editorAction", args = { category = data.category, action = "move", index = data.index } } },
        { header = "Duplicate", params = { event = "qb-policehelper:editorAction", args = { category = data.category, action = "duplicate", index = data.index } } },
        { header = "Delete", params = { event = "qb-policehelper:editorAction", args = { category = data.category, action = "delete", index = data.index } } },
        { header = "Back", params = { event = "qb-policehelper:requestEditor" } },
    }
    if data.category == "garages" or data.category == "helicopters" or data.category == "boats" then
        options[#options + 1] = { header = "Manage vehicle spawn positions", params = { event = "qb-policehelper:openEditorSpawns", args = data } }
    end
    if data.category == "garages" then
        options[#options + 1] = {
            header = data.hasReturn and "Move return point" or "Add return point",
            params = { event = "qb-policehelper:editorAction", args = { category = "garages", action = data.hasReturn and "moveReturn" or "addReturn", index = data.index } }
        }
        if data.hasReturn then
            options[#options + 1] = { header = "Delete return point", params = { event = "qb-policehelper:editorAction", args = { category = "garages", action = "deleteReturn", index = data.index } } }
        end
    end
    exports['qb-menu']:openMenu(options)
end)

RegisterNetEvent('qb-policehelper:openEditorSpawns', function(data)
    data = data and (data.args or data)
    if not data then return end
    local garage = Config.LocationCategories[data.category] and Config.LocationCategories[data.category][tonumber(data.index)]
    local options = {
        { header = "Vehicle spawn positions", isMenuHeader = true },
        { header = "+ Add at my position", params = { event = "qb-policehelper:editorAction", args = { category = "garages", action = "addSpawn", index = data.index } } },
    }
    for spawnIndex, _ in ipairs(garage.carSpawns or {}) do
        options[#options + 1] = {
            header = ("Spawn point %d"):format(spawnIndex),
            params = { event = "qb-policehelper:openEditorSpawn", args = { category = data.category, garageIndex = data.index, spawnIndex = spawnIndex } }
        }
    end
    options[#options + 1] = { header = "Back", params = { event = "qb-policehelper:requestEditor" } }
    exports['qb-menu']:openMenu(options)
end)

RegisterNetEvent('qb-policehelper:openEditorSpawn', function(data)
    data = data and (data.args or data)
    if not data then return end
    exports['qb-menu']:openMenu({
        { header = "Vehicle spawn point " .. data.spawnIndex, isMenuHeader = true },
        { header = "Move", params = { event = "qb-policehelper:editorAction", args = { category = data.category, action = "moveSpawn", index = data.garageIndex, spawnIndex = data.spawnIndex } } },
        { header = "Duplicate", params = { event = "qb-policehelper:editorAction", args = { category = data.category, action = "duplicateSpawn", index = data.garageIndex, spawnIndex = data.spawnIndex } } },
        { header = "Delete", params = { event = "qb-policehelper:editorAction", args = { category = data.category, action = "deleteSpawn", index = data.garageIndex, spawnIndex = data.spawnIndex } } },
    })
end)

RegisterNetEvent('qb-policehelper:editorAction', function(data)
    data = data and (data.args or data)
    if data then TriggerServerEvent('qb-policehelper:server:editorAction', data.category, data.action, data.index, data.spawnIndex) end
end)

RegisterCommand('qbph_edit', function()
    TriggerServerEvent('qb-policehelper:server:requestEditor')
end, false)

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
