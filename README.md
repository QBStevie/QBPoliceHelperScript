# QBPoliceHelperScript

This resource provides configurable helpers for law-enforcement focused servers using the QBCore framework. It supports:

* Spawnable police garage peds that open rank-gated vehicle menus.
* Job-specific target options powered by **qb-target** and **qb-menu**.
* Debug logging that can be toggled through the configuration file.

## Configuration

All configuration lives in [`config.lua`](config.lua). You can enable/disable verbose debugging, adjust garage locations, and specify per-garage ped models, spawn points, and vehicle unlock ranks.

```lua
Config.debug = true

Config.PoliceGarages = {
    {
        name = "Police Garage 1",
        pedModel = `s_m_y_cop_01`,
        pedCoords = vector3(441.9710, -1013.5137, 28.6264),
        pedHeading = 186.8343,
        carSpawns = {
            vector4(446.5480, -1025.7572, 28.2394, 359.8884),
            -- ...
        },
        vehicleList = {
            { model = "police", label = "Police Cruiser", rank = 1 },
            -- ...
        }
    }
}
```

### Optional ped model per garage

The new `pedModel` field lets you change the NPC spawned at each garage. If it is omitted the script falls back to the default `s_m_y_cop_01` model.

## Usage

Start the resource on your server. Peds are spawned automatically on resource start and display the configured target options. Ensure that the required dependencies (`qb-core`, `qb-target`, `qb-menu`, and `LegacyFuel`) are running.
