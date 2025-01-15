
Config = {}

Config.debug = true  -- Set to false to disable debug prints

Config.PoliceGarages = {
    {
        name = "Police Garage 1",
        pedCoords = vector3(441.9710, -1013.5137, 28.6264),
        pedHeading = 186.8343,
        carSpawns = {
            vector4(446.5480, -1025.7572, 28.2394, 359.8884),
            vector4(438.5597, -1026.1335, 28.3805, 4.5868),
            vector4(431.3347, -1027.7228, 28.5253, 2.9451),
        },
        vehicleList = {
            {model = "police", label = "Police Cruiser", rank = 1},
            {model = "police2", label = "Police Interceptor", rank = 2},
            {model = "sheriff", label = "Sheriff Vehicle", rank = 3},
        }
    },--[[
    {
        name = "Police Garage 2",
        pedCoords = vector3(450.12, -975.56, 30.68),
        pedHeading = 180.0,
        carSpawns = {
            vector4(446.5480, -1025.7572, 28.2394, 359.8884),
            vector4(438.5597, -1026.1335, 28.3805, 4.5868),
            vector4(431.3347, -1027.7228, 28.5253, 2.9451),
        },
        vehicleList = {
            {model = "police", label = "Police Cruiser", rank = 1},
            {model = "police2", label = "Police Interceptor", rank = 2},
            {model = "sheriff", label = "Sheriff Vehicle", rank = 3}
        }
    }--]]
}

Config.Actions = {
    -- Police actions
    { type = "client", event = "police:client:CuffPlayer", icon = "fas fa-hands", label = "Handfängsla", job = "police", item = 'Handcuff Person' },
    { type = "client", event = "police:client:EscortPlayer", icon = "fas fa-key", label = "Escort Person", job = "police" },
    { type = "client", event = "police:client:PutPlayerInVehicle", icon = "fas fa-chevron-circle-left", label = "Put Person In Vehicle", job = "police" },
    { type = "client", event = "police:client:SetPlayerOutVehicle", icon = "fas fa-chevron-circle-right", label = "Set Person Out Of Vehicle", job = "police" },
    { type = "client", event = "police:client:SeizeDriverLicense", icon = "fas fa-chevron-circle-right", label = "Seize Driver License Of Person", job = "police" },
    { type = "client", event = "police:client:JailPlayer", icon = "fas fa-chevron-circle-right", label = "Send Person To Jail", job = "police" },
    { type = "server", event = "police:server:SearchPlayer", icon = "fas fa-chevron-circle-right", label = "Search Person", job = "police" },

    -- Ambulance actions
    { type = "client", event = "hospital:client:RevivePlayer", icon = "fas fa-chevron-circle-right", label = "Revive Person", job = "ambulance" },
    { type = "client", event = "hospital:client:CheckStatus", icon = "fas fa-chevron-circle-right", label = "Check Person Health", job = "ambulance" },
    { type = "client", event = "hospital:client:TreatWounds", icon = "fas fa-chevron-circle-right", label = "Treat Wounds", job = "ambulance" },
}
