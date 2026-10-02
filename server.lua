local QBCore = exports['qb-core']:GetCoreObject()
local placementFile = 'placements.json'
local placements = { garages = {}, bossMenus = {}, locations = {} }
local locationCategories = Config.LocationCategories or {}

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

local function locationAllowsJob(location, jobName)
    if type(location.jobs) == 'table' then
        for _, allowedJob in ipairs(location.jobs) do
            if allowedJob == jobName then return true end
        end
        return false
    end
    return jobName == (location.job or 'police')
end

local function isFiniteNumber(value)
    return type(value) == 'number'
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function serialize(value)
    local valueType = type(value)
    if valueType == 'vector3' then
        return { x = value.x, y = value.y, z = value.z }
    elseif valueType == 'vector4' then
        return { x = value.x, y = value.y, z = value.z, w = value.w }
    elseif valueType ~= 'table' then
        return value
    end

    local copy = {}
    for key, item in pairs(value) do copy[key] = serialize(item) end
    return copy
end

local function restoreLocation(category, point)
    if type(point) ~= 'table' then return point end
    if point.pedCoords and type(point.pedCoords) == 'table' then
        point.pedCoords = vector3(point.pedCoords.x, point.pedCoords.y, point.pedCoords.z)
    end
    if point.coords and type(point.coords) == 'table' then
        point.coords = vector3(point.coords.x, point.coords.y, point.coords.z)
    end
    for _, spawn in ipairs(point.carSpawns or {}) do
        if type(spawn) == 'table' then
            point.carSpawns[_] = vector4(spawn.x, spawn.y, spawn.z, spawn.w or 0.0)
        end
    end
    return point
end

local function syncLocationAliases()
    Config.PoliceGarages = locationCategories.garages or {}
    Config.BossMenus = locationCategories.bosses or {}
    Config.DutyPoints = locationCategories.duty or {}
    Config.Armories = locationCategories.armories or {}
    Config.EvidenceLockers = locationCategories.evidence or {}
    Config.PersonalLockers = locationCategories.personal or {}
    Config.ClothingRooms = locationCategories.clothing or {}
    Config.Impounds = locationCategories.impounds or {}
    Config.HelicopterGarages = locationCategories.helicopters or {}
    Config.BoatGarages = locationCategories.boats or {}
end

local function persistLocations()
    local serialized = {}
    for category, list in pairs(locationCategories) do serialized[category] = serialize(list) end
    placements.locations = serialized
    SaveResourceFile(GetCurrentResourceName(), placementFile, json.encode(placements), -1)
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
                    targetList[numericIndex].pedCoords = vector3(placement.x, placement.y, placement.z)
                    targetList[numericIndex].pedHeading = placement.heading
                end
            end
        end
    end
    if type(decoded.locations) == 'table' then
        for category, list in pairs(decoded.locations) do
            if type(locationCategories[category]) == 'table' and type(list) == 'table' then
                local restored = {}
                for _, point in ipairs(list) do
                    if type(point) == 'table' then
                        restored[#restored + 1] = restoreLocation(category, point)
                    end
                end
                locationCategories[category] = restored
            end
        end
        syncLocationAliases()
    end
end

loadPlacements()

RegisterNetEvent('qb-policehelper:server:requestPlacements', function()
    TriggerClientEvent('qb-policehelper:client:syncPlacements', source, placements, serialize(locationCategories))
end)

RegisterNetEvent('qb-policehelper:server:requestPlacementMode', function(kind, index)
    local src = source
    local category = type(kind) == 'string' and kind:match('^location:(.+)$')
    local list = category and locationCategories[category]
        or kind == 'garage' and Config.PoliceGarages
        or kind == 'boss' and Config.BossMenus
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

RegisterNetEvent('qb-policehelper:server:requestEditor', function()
    local src = source
    if not isAdmin(src) then
        notify(src, 'You do not have permission to edit locations.')
        return
    end
    TriggerClientEvent('qb-policehelper:client:openEditor', src, serialize(locationCategories))
end)

RegisterNetEvent('qb-policehelper:server:editorAction', function(category, action, index, spawnIndex)
    local src = source
    if not isAdmin(src) then return end
    if type(category) ~= 'string' or type(action) ~= 'string' then return end
    local list = locationCategories[category]
    if type(list) ~= 'table' then
        notify(src, 'Unknown location category.')
        return
    end

    index = tonumber(index)
    spawnIndex = tonumber(spawnIndex)
    if (category == 'garages' or category == 'helicopters' or category == 'boats') and action:match('Spawn$') then
        if not validIndex(index, list) then return end
        local garage = list[index]
        garage.carSpawns = garage.carSpawns or {}
        if action == 'moveSpawn' then
            if not validIndex(spawnIndex, garage.carSpawns) then return end
            TriggerClientEvent('qb-policehelper:client:startPlacement', src, 'locationSpawn:' .. category .. ':' .. spawnIndex, index)
            return
        elseif action == 'addSpawn' then
            local ped = GetPlayerPed(src)
            if ped == 0 then return end
            local coords = GetEntityCoords(ped)
            table.insert(garage.carSpawns, vector4(coords.x + 3.0, coords.y, coords.z, GetEntityHeading(ped)))
        elseif action == 'duplicateSpawn' then
            if not validIndex(spawnIndex, garage.carSpawns) then return end
            local spawn = garage.carSpawns[spawnIndex]
            table.insert(garage.carSpawns, spawnIndex + 1, vector4(spawn.x, spawn.y, spawn.z, spawn.w))
        elseif action == 'deleteSpawn' then
            if not validIndex(spawnIndex, garage.carSpawns) then return end
            table.remove(garage.carSpawns, spawnIndex)
        end
        persistLocations()
        TriggerClientEvent('qb-policehelper:client:syncPlacements', -1, placements, serialize(locationCategories))
        notify(src, 'Vehicle position updated.', 'success')
        return
    end
    if category == 'garages' and (action == 'moveReturn' or action == 'addReturn' or action == 'deleteReturn') then
        if not validIndex(index, list) then return end
        local garage = list[index]
        if action == 'moveReturn' then
            if not garage.returnCoords then return end
            TriggerClientEvent('qb-policehelper:client:startPlacement', src, 'locationReturn:garages', index)
            return
        elseif action == 'addReturn' then
            local ped = GetPlayerPed(src)
            if ped == 0 then return end
            local coords = GetEntityCoords(ped)
            garage.returnCoords = vector3(coords.x, coords.y, coords.z)
        else
            garage.returnCoords = nil
        end
        persistLocations()
        TriggerClientEvent('qb-policehelper:client:syncPlacements', -1, placements, serialize(locationCategories))
        notify(src, 'Vehicle return point updated.', 'success')
        return
    end
    if action == 'move' then
        if not validIndex(index, list) then return end
        TriggerClientEvent('qb-policehelper:client:startPlacement', src, 'location:' .. category, index)
        return
    end

    if action == 'add' then
        local ped = GetPlayerPed(src)
        if ped == 0 then return end
        local coords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)
        local point = {
            name = category:gsub('^%l', string.upper) .. ' ' .. (#list + 1),
            job = 'police',
            coords = vector3(coords.x, coords.y, coords.z),
            heading = heading,
        }
        if category == 'garages' or category == 'helicopters' or category == 'boats' then
            point.pedModel = category == 'boats' and `s_m_y_cop_01` or `s_m_y_cop_01`
            point.pedCoords = vector3(coords.x, coords.y, coords.z)
            point.pedHeading = heading
            point.carSpawns = { vector4(coords.x + 3.0, coords.y, coords.z, heading) }
            point.vehicleList = {}
        elseif category == 'bosses' then
            point.label = point.name
            point.pedModel = `s_m_y_cop_01`
            point.pedCoords = vector3(coords.x, coords.y, coords.z)
            point.pedHeading = heading
            point.minimumGrade = 0
            point.requireBoss = true
        end
        list[#list + 1] = point
    elseif action == 'duplicate' then
        if not validIndex(index, list) then return end
        local copy = restoreLocation(category, serialize(list[index]))
        copy.name = (list[index].name or category) .. ' Copy'
        table.insert(list, index + 1, copy)
    elseif action == 'delete' then
        if not validIndex(index, list) then return end
        table.remove(list, index)
    else
        return
    end

    syncLocationAliases()
    if category == 'garages' then placements.garages = {} end
    if category == 'bosses' then placements.bossMenus = {} end
    persistLocations()
    TriggerClientEvent('qb-policehelper:client:syncPlacements', -1, placements, serialize(locationCategories))
    notify(src, 'Location updated.', 'success')
end)

RegisterNetEvent('qb-policehelper:server:savePlacement', function(kind, index, placement)
    local src = source
    local spawnCategory, spawnIndexText
    local returnCategory
    if type(kind) == 'string' then
        spawnCategory, spawnIndexText = kind:match('^locationSpawn:(.+):(%d+)$')
        returnCategory = kind:match('^locationReturn:(.+)$')
    end
    local spawnIndex = tonumber(spawnIndexText)
    local category = type(kind) == 'string' and kind:match('^location:(.+)$')
    if spawnCategory then category = spawnCategory elseif returnCategory then category = returnCategory end
    local list = category and locationCategories[category]
        or kind == 'garage' and Config.PoliceGarages
        or kind == 'boss' and Config.BossMenus
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

    if category then
        local point = list[index]
        if spawnCategory then
            if not validIndex(spawnIndex, point.carSpawns or {}) then return end
            point.carSpawns[spawnIndex] = vector4(x, y, z, heading)
            persistLocations()
            TriggerClientEvent('qb-policehelper:client:syncPlacements', -1, placements, serialize(locationCategories))
            notify(src, 'Vehicle position saved.', 'success')
            return
        end
        if returnCategory then
            point.returnCoords = vector3(x, y, z)
            point.returnHeading = heading
            persistLocations()
            TriggerClientEvent('qb-policehelper:client:syncPlacements', -1, placements, serialize(locationCategories))
            notify(src, 'Vehicle return point saved.', 'success')
            return
        end
        local coords = vector3(x, y, z)
        local usesPedCoords = category == 'garages' or category == 'bosses'
            or category == 'helicopters' or category == 'boats'
        local coordsKey = usesPedCoords and 'pedCoords' or 'coords'
        point[coordsKey] = coords
        if category == 'helicopters' or category == 'boats' then point.coords = coords end
        if usesPedCoords then point.pedHeading = heading else point.heading = heading end
        if category == 'garages' then placements.garages[tostring(index)] = nil end
        if category == 'bosses' then placements.bossMenus[tostring(index)] = nil end
        persistLocations()
        TriggerClientEvent('qb-policehelper:client:syncPlacements', -1, placements, serialize(locationCategories))
        notify(src, 'Location saved.', 'success')
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

RegisterNetEvent('qb-policehelper:server:requestVehicle', function(garageIndex, vehicleIndex, category)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    category = category or 'garages'
    local garages = locationCategories[category]
    if not Player or (category ~= 'garages' and category ~= 'helicopters' and category ~= 'boats')
        or not validIndex(garageIndex, garages or {}) then return end

    local job = Player.PlayerData.job
    local garage = garages[garageIndex]
    local sharedJob = false
    for _, shared in ipairs(Config.SharedGarageJobs or {}) do
        if job and shared == job.name then sharedJob = true break end
    end
    if not job or (not locationAllowsJob(garage, job.name) and not sharedJob) then
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
    local requiredRank = vehicle and tonumber(vehicle.minimumGrade or vehicle.rank or 0)
    if not vehicle or not requiredRank or not playerRank or playerRank < requiredRank
        or type(vehicle.model) ~= 'string' or vehicle.model == '' then
        notify(src, 'You do not have the required rank for that vehicle.')
        return
    end
    if vehicle.job and vehicle.job ~= job.name then
        notify(src, 'This vehicle is restricted to another department.')
        return
    end

    local spawnPoint
    local playerPed = GetPlayerPed(src)
    if playerPed == 0 then return end
    local playerCoords = GetEntityCoords(playerPed)
    for _, candidate in ipairs(garage.carSpawns or {}) do
        local occupied = false
        if candidate and candidate.x and candidate.y and candidate.z and candidate.w
            and #(playerCoords - vector3(candidate.x, candidate.y, candidate.z)) <= 25.0 then
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
        ({ car = 'automobile', automobile = 'automobile', bike = 'bike', helicopter = 'heli', heli = 'heli', boat = 'boat' })[vehicle.type or 'car'] or 'automobile',
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
        NetworkGetNetworkIdFromEntity(spawnedVehicle),
        {
            fuel = tonumber(vehicle.fuel) or 100.0,
            engine = tonumber(vehicle.engine) or 1000.0,
            body = tonumber(vehicle.body) or 1000.0,
            livery = tonumber(vehicle.livery),
            extras = vehicle.extras or {},
            primaryColor = vehicle.primaryColor,
            secondaryColor = vehicle.secondaryColor,
            plate = vehicle.callsignPlate and ((Player.PlayerData.metadata or {}).callsign or job.name) or vehicle.plate,
            loadout = vehicle.loadout or {},
        }
    )
    Entity(spawnedVehicle).state:set('qbPoliceHelperLoadout', vehicle.loadout or {}, true)
end)

RegisterNetEvent('qb-policehelper:server:returnVehicle', function(garageIndex, category)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    category = category or 'garages'
    local garages = locationCategories[category]
    if not Player or (category ~= 'garages' and category ~= 'helicopters' and category ~= 'boats')
        or not validIndex(garageIndex, garages or {}) then return end
    local job = Player.PlayerData.job
    local garage = garages[garageIndex]
    local sharedJob = false
    for _, shared in ipairs(Config.SharedGarageJobs or {}) do
        if job and shared == job.name then sharedJob = true break end
    end
    if not job or (not locationAllowsJob(garage, job.name) and not sharedJob) then
        notify(src, 'You are not authorized to return vehicles here.')
        return
    end
    local ped = GetPlayerPed(src)
    if ped == 0 then return end
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then
        notify(src, 'You must be driving a vehicle to return it.')
        return
    end
    local garageCoords = garage.returnCoords or garage.pedCoords or garage.coords
    local coords = GetEntityCoords(ped)
    if not garageCoords or #(coords - vector3(garageCoords.x, garageCoords.y, garageCoords.z)) > 30.0 then
        notify(src, 'Return the vehicle at the garage.')
        return
    end
    DeleteEntity(vehicle)
    notify(src, 'Vehicle returned.', 'success')
end)
