local QBCore = exports['qb-core']:GetCoreObject()
local Config = Config or {}  -- Load the config

-- Function to print debug messages
local function debugPrint(message)
    if Config.debug then
        print(message)  
    end
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

        RequestModel(`s_m_y_cop_01`)
        while not HasModelLoaded(`s_m_y_cop_01`) do
            Wait(500)
        end

        local ped = CreatePed(4, `s_m_y_cop_01`, garage.pedCoords.x, garage.pedCoords.y, garage.pedCoords.z, garage.pedHeading, false, true)
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


local function setupJobActions()
    if not Config.Actions or type(Config.Actions) ~= "table" then
        debugPrint("Error: Config.Actions is not defined or is not a table!")
        return
    end

    debugPrint("Setting up job actions...")  -- Debug message for setting up actions

    for _, action in ipairs(Config.Actions) do
        exports['qb-target']:AddTargetEntity(GetPlayerPed(-1), {
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
        print("Player Rank (Fixed): ", playerRank)  
    end

    local options = {}
    for i, vehicle in ipairs(vehicleList) do

        print("Vehicle rank for " .. vehicle.label .. ": ", vehicle.rank)

        if type(vehicle.rank) == "number" and playerRank >= vehicle.rank then
            table.insert(options, {
                label = vehicle.label,
                vehicleModel = vehicle.model,
                spawnLocation = carSpawns[i], 
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
                        spawnLocation = option.spawnLocation
                    }
                }
            })
        end

        exports['qb-menu']:openMenu(menuOptions)
    else

        QBCore.Functions.Notify("You do not have the required rank to access any vehicles.", "error")
    end
end)


RegisterNetEvent('qb-policehelper:spawnVehicle', function(data)
    local vehicleModel = data.vehicleModel
    local spawnLocation = data.spawnLocation

    local function isSpawnOccupied(spawnLocation)
        local vehicles = GetGamePool('CVehicle')
        for _, vehicle in ipairs(vehicles) do
            local vehiclePos = GetEntityCoords(vehicle)
            local distance = Vdist(vehiclePos.x, vehiclePos.y, vehiclePos.z, spawnLocation.x, spawnLocation.y, spawnLocation.z)
            if distance < 5.0 then
                return true
            end
        end
        return false
    end

    debugPrint("Available carSpawns: ", json.encode(data.carSpawns))

    if isSpawnOccupied(spawnLocation) then
        debugPrint("Spawn point occupied. Searching for an empty spot...")
        local foundEmptySpot = false
        for _, newSpawn in ipairs(data.carSpawns) do
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

    RequestModel(vehicleModel)
    while not HasModelLoaded(vehicleModel) do
        Wait(500)
    end

    local vehicle = CreateVehicle(vehicleModel, spawnLocation.x, spawnLocation.y, spawnLocation.z, spawnLocation.w, true, false)

    exports['LegacyFuel']:SetFuel(vehicle, 100.0)

    SetEntityAsMissionEntity(vehicle, true, true)
    TaskWarpPedIntoVehicle(GetPlayerPed(-1), vehicle, -1)


    debugPrint("Vehicle spawned with full fuel: " .. vehicleModel)
end)

spawnPedAndGarageInteractions()
setupJobActions()
