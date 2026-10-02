local QBCore = exports['qb-core']:GetCoreObject()
local placementFile = 'placements.json'
local placements = { garages = {}, bossMenus = {} }

local function notify(source, message, messageType)
    TriggerClientEvent('QBCore:Notify', source, message, messageType or 'error')
end

local function isAdmin(source)
    return QBCore.Functions.HasPermission(source, 'admin')
        or QBCore.Functions.HasPermission(source, 'god')
end

local function validIndex(index, list)
    return type(index) == 'number'
        and index % 1 == 0
        and index >= 1
        and index <= #list
end

local function isFiniteNumber(value)
    return type(value) == 'number'
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function loadPlacements()
    local contents = LoadResourceFile(GetCurrentResourceName(), placementFile)
    if not contents or contents == '' then return end

    local ok, decoded = pcall(json.decode, contents)
    if not ok or type(decoded) ~= 'table' then
        print(('[qb-policehelper] Could not parse %s; using configured ped positions.'):format(placementFile))
        return
    end

    for _, kind in ipairs({ 'garages', 'bossMenus' }) do
        if type(decoded[kind]) == 'table' then
            local targetList = kind == 'garages' and Config.PoliceGarages or Config.BossMenus
            for index, placement in pairs(decoded[kind]) do
                local numericIndex = tonumber(index)
                if validIndex(numericIndex, targetList)
                    and type(placement) == 'table'
                    and isFiniteNumber(placement.x)
                    and isFiniteNumber(placement.y)
                    and isFiniteNumber(placement.z)
                    and isFiniteNumber(placement.heading)
                    and math.abs(placement.x) <= 8000
                    and math.abs(placement.y) <= 8000
                    and math.abs(placement.z) <= 2000
                    and placement.heading >= 0
                    and placement.heading < 360 then
                    placements[kind][tostring(numericIndex)] = placement
                end
            end
        end
    end
end

loadPlacements()

RegisterNetEvent('qb-policehelper:server:requestPlacements', function()
    TriggerClientEvent('qb-policehelper:client:syncPlacements', source, placements)
end)

RegisterNetEvent('qb-policehelper:server:requestPlacementMode', function(kind, index)
    local src = source
    local list = kind == 'garage' and Config.PoliceGarages or kind == 'boss' and Config.BossMenus
    if not list or not validIndex(index, list) then
        notify(src, 'Invalid placement target.')
        return
    end
    if not isAdmin(src) then
        notify(src, 'You do not have permission to place these peds.')
        return
    end

    TriggerClientEvent('qb-policehelper:client:startPlacement', src, kind, index)
end)

RegisterNetEvent('qb-policehelper:server:savePlacement', function(kind, index, placement)
    local src = source
    local list = kind == 'garage' and Config.PoliceGarages or kind == 'boss' and Config.BossMenus
    if not list or not validIndex(index, list) or type(placement) ~= 'table' then return end
    if not isAdmin(src) then return end

    local x, y, z, heading = placement.x, placement.y, placement.z, placement.heading
    for _, field in ipairs({ 'x', 'y', 'z', 'heading' }) do
        local value = placement[field]
        if not isFiniteNumber(value) then
            notify(src, 'Invalid placement coordinates.')
            return
        end
    end
    if math.abs(x) > 8000 or math.abs(y) > 8000 or math.abs(z) > 2000 or heading < 0 or heading >= 360 then
        notify(src, 'Placement coordinates are outside the allowed range.')
        return
    end

    local ped = GetPlayerPed(src)
    if ped == 0 or #(GetEntityCoords(ped) - vector3(x, y, z)) > 100.0 then
        notify(src, 'The placement must be within 100 meters of you.')
        return
    end

    local key = kind == 'garage' and 'garages' or 'bossMenus'
    local previous = placements[key][tostring(index)]
    placements[key][tostring(index)] = { x = x, y = y, z = z, heading = heading }
    local saved = SaveResourceFile(GetCurrentResourceName(), placementFile, json.encode(placements), -1)
    if saved == false then
        placements[key][tostring(index)] = previous
        notify(src, 'Could not save placements.json. Check the resource file permissions.')
        return
    end

    TriggerClientEvent('qb-policehelper:client:syncPlacements', -1, placements)
    notify(src, 'Ped placement saved.', 'success')
end)

RegisterNetEvent('qb-policehelper:server:requestVehicle', function(garageIndex, vehicleIndex)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not validIndex(garageIndex, Config.PoliceGarages) then return end

    local job = Player.PlayerData.job
    local garage = Config.PoliceGarages[garageIndex]
    if not job or job.name ~= (garage.job or 'police') then
        notify(src, 'You are not authorized to use this garage.')
        return
    end

    local grade = job.grade
    local playerRank = type(grade) == 'table' and tonumber(grade.level or grade.grade) or tonumber(grade)
    if type(vehicleIndex) ~= 'number' or vehicleIndex % 1 ~= 0 then
        notify(src, 'Invalid vehicle selection.')
        return
    end
    local vehicle = garage.vehicleList and garage.vehicleList[vehicleIndex]
    local requiredRank = vehicle and tonumber(vehicle.rank)
    if not vehicle or not requiredRank or not playerRank or playerRank < requiredRank
        or type(vehicle.model) ~= 'string' or vehicle.model == '' then
        notify(src, 'You do not have the required rank for that vehicle.')
        return
    end

    local spawnPoint
    local playerPed = GetPlayerPed(src)
    if playerPed == 0 then return end
    local playerCoords = GetEntityCoords(playerPed)
    for _, candidate in ipairs(garage.carSpawns or {}) do
        local occupied = false
        if #(playerCoords - vector3(candidate.x, candidate.y, candidate.z)) <= 25.0 then
            for _, existing in ipairs(GetAllVehicles()) do
                if DoesEntityExist(existing)
                    and #(GetEntityCoords(existing) - vector3(candidate.x, candidate.y, candidate.z)) < 5.0 then
                    occupied = true
                    break
                end
            end
            if not occupied then
                spawnPoint = candidate
                break
            end
        end
    end

    if not spawnPoint then
        notify(src, 'No empty spawn spots available.')
        return
    end

    local spawnedVehicle = CreateVehicleServerSetter(
        joaat(vehicle.model),
        'automobile',
        spawnPoint.x,
        spawnPoint.y,
        spawnPoint.z,
        spawnPoint.w
    )
    if not spawnedVehicle or spawnedVehicle == 0 then
        notify(src, 'The vehicle could not be spawned.')
        return
    end

    TriggerClientEvent(
        'qb-policehelper:client:vehicleSpawned',
        src,
        NetworkGetNetworkIdFromEntity(spawnedVehicle)
    )
end)
