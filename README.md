# QBPoliceHelperScript

This resource provides configurable helpers for law-enforcement focused servers using the QBCore framework. It supports:

* Spawnable police garage peds that open rank-gated vehicle menus.
* Server-validated vehicle spawning based on the player's police grade.
* Job-specific target options powered by **qb-target** and **qb-menu**.
* Admin-only in-game editing of garages, boss menus, duty points, armories, evidence and personal lockers, clothing rooms, impounds, and helicopter/boat garages. Changes are saved to `placements.json`.
* Configurable car, bike, helicopter, and boat fleets with grade restrictions, appearance, plate, fuel, damage, and loadout settings.
* Debug logging that can be toggled through the configuration file.

## Configuration

All configuration lives in [`config.lua`](config.lua). You can enable/disable verbose debugging, adjust garage locations, and specify per-garage job requirements, ped models, spawn points, and vehicle unlock ranks. Garages and generic interaction points default to the `police` job when `job` is omitted. The default department names are `police`, `bcso`, `sasp`, `fib`, and `ranger`, and any custom job name can be used. Set `jobs = { "police", "bcso" }` on a location to share it with selected departments; `Config.SharedGarageJobs` grants listed jobs access to every vehicle garage.

```lua
Config.debug = true

Config.PoliceGarages = {
    {
        name = "Police Garage 1",
        job = "police",
        pedModel = `s_m_y_cop_01`,
        pedCoords = vector3(441.9710, -1013.5137, 28.6264),
        pedHeading = 186.8343,
        carSpawns = {
            vector4(446.5480, -1025.7572, 28.2394, 359.8884),
            -- ...
        },
        vehicleList = {
            {
                model = "police",
                label = "Police Cruiser",
                job = "police",           -- Optional department-only vehicle
                minimumGrade = 1,         -- `rank` is also supported
                type = "car",             -- car, bike, helicopter, or boat
                livery = 0,
                extras = { [1] = true },
                primaryColor = 0,
                secondaryColor = 0,
                callsignPlate = true,
                fuel = 100,
                engine = 1000,
                body = 1000,
                loadout = {},             -- Stored on the vehicle state as qbPoliceHelperLoadout
            },
            -- ...
        }
    }
}
```

Configure vehicles in each garage's `vehicleList`. `minimumGrade` takes precedence over `rank`. Use `Config.HelicopterGarages` and `Config.BoatGarages` for aircraft and boats; each garage uses `carSpawns` and `vehicleList` just like a road-vehicle garage. Vehicle appearance and health values are applied on checkout. A vehicle's `loadout` is replicated in its `qbPoliceHelperLoadout` entity state for use by a server's trunk/inventory integration.

Duty points, armories, evidence lockers, personal lockers, clothing rooms, and impounds are configurable in `Config.DutyPoints`, `Config.Armories`, `Config.EvidenceLockers`, `Config.PersonalLockers`, `Config.ClothingRooms`, and `Config.Impounds`. Configure `coords`, `job` or `jobs`, and an optional `event` plus `eventType = "server"` for your server's existing integration. Without an event, the target displays a configuration reminder.

### Optional ped model per garage

The new `pedModel` field lets you change the NPC spawned at each garage. If it is omitted the script falls back to the default `s_m_y_cop_01` model.

## Usage

Start the resource on your server. Peds are spawned automatically on resource start and display the configured target options. `qb-core`, `qb-target`, and `qb-menu` are required; `qb-management` is needed for boss menus, and `LegacyFuel` and `qb-vehiclekeys` are optional. When `qb-vehiclekeys` is started, players automatically receive keys for vehicles they check out from a garage, and those keys are removed when the vehicle is returned.

## In-game ped placement

An administrator or god can open the full editor using:

```
/qbph_edit
```

Choose a location category to add, move, duplicate, or delete its points. Garage entries also let you manage spawn points and add, move, or delete a return point. During placement, use **W/A/S/D** to move, **Q/E** to rotate, **Up/Down arrows** to adjust height, **Enter** to save, or **Backspace** to cancel. `/qbph_place garage 1` and `/qbph_place boss 1` remain available for direct ped placement. Changes are persisted in `placements.json`; ensure the resource directory is writable by FXServer.

Vehicle menus provide a camera preview before checkout, along with return, repair, and clean actions. Return requires the player to be driving near the garage; configure `returnCoords` when the return area should differ from the garage ped.

The default police boss ped matches qb-management's default police boss-menu location. For each job, ensure its ped coordinate is also configured in that job's `Config.BossMenus` in qb-management; qb-management checks that location before opening the boss stash. This includes the BCSO Paleto boss menu.
