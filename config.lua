Config = {}

Config.debug = true  -- Set to false to disable debug prints
Config.Departments = { 'police', 'bcso', 'sasp', 'fib', 'ranger' }
Config.SharedGarageJobs = {} -- Add job names here to allow those jobs to use any garage.

Config.PoliceGarages = {
    {
        name = "Police Garage 1",
        pedModel = `s_m_y_cop_01`,
        pedCoords = vector3(441.9710, -1013.5137, 28.6264),
        pedHeading = 186.8343,
        carSpawns = {
            vector4(446.5480, -1025.7572, 28.2394, 359.8884),
            vector4(438.5597, -1026.1335, 28.3805, 4.5868),
            vector4(431.3347, -1027.7228, 28.5253, 2.9451),
        },
        vehicleList = {
            {model = "police", label = "Police Cruiser", rank = 1, type = "car", fuel = 100},
            {model = "police2", label = "Police Interceptor", rank = 2, type = "car", fuel = 100},
            {model = "sheriff", label = "Sheriff Vehicle", rank = 3, type = "car", fuel = 100},
        }
    },
    {
        name = "BCSO Paleto Garage",
        job = "bcso",
        pedModel = `s_m_y_sheriff_01`,
        pedCoords = vector3(-449.0, 6013.2, 31.7),
        pedHeading = 45.0,
        carSpawns = {
            vector4(-461.6, 6021.5, 31.3, 45.0),
            vector4(-466.1, 6025.5, 31.3, 45.0),
            vector4(-470.6, 6029.5, 31.3, 45.0),
        },
        vehicleList = {
            {model = "sheriff", label = "BCSO Sheriff Cruiser", rank = 1, type = "car", fuel = 100},
            {model = "sheriff2", label = "BCSO Sheriff SUV", rank = 2, type = "car", fuel = 100},
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

Config.BossMenus = {
    {
        job = "police",
        label = "Police Boss Menu",
        pedModel = `s_m_y_cop_01`,
        pedCoords = vector3(447.16, -974.31, 30.47),
        pedHeading = 180.0,
        minimumGrade = 4, -- Minimum grade allowed to open (set nil to skip)
        requireBoss = true -- Set to false if non-boss grades should be able to use the menu
    },
    {
        job = "bcso",
        label = "BCSO Boss Menu",
        pedModel = `s_m_y_sheriff_01`,
        pedCoords = vector3(-443.5, 6012.7, 31.7),
        pedHeading = 45.0,
        minimumGrade = 4,
        requireBoss = true
    }
}

-- Generic job-target locations. Configure an event for integrations supplied by
-- your server; locations without an event display a helpful notification.
Config.DutyPoints = {}
Config.Armories = {}
Config.EvidenceLockers = {}
Config.PersonalLockers = {}
Config.ClothingRooms = {}
Config.Impounds = {}
Config.HelicopterGarages = {}
Config.BoatGarages = {}

Config.LocationCategories = {
    garages = Config.PoliceGarages,
    bosses = Config.BossMenus,
    duty = Config.DutyPoints,
    armories = Config.Armories,
    evidence = Config.EvidenceLockers,
    personal = Config.PersonalLockers,
    clothing = Config.ClothingRooms,
    impounds = Config.Impounds,
    helicopters = Config.HelicopterGarages,
    boats = Config.BoatGarages,
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
