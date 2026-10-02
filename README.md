# QBPoliceHelperScript

This resource provides configurable helpers for law-enforcement focused servers using the QBCore framework. It supports:

* Spawnable police garage peds that open rank-gated vehicle menus.
* Server-validated vehicle spawning based on the player's police grade.
* Job-specific target options powered by **qb-target** and **qb-menu**.
* Admin-only in-game placement for garage and boss peds, saved to `placements.json`.
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

Start the resource on your server. Peds are spawned automatically on resource start and display the configured target options. Ensure that the required dependencies (`qb-core`, `qb-target`, `qb-menu`, `qb-management`, and `LegacyFuel`) are running.

## In-game ped placement

An administrator or god can place a garage or boss ped using:

```
/qbph_place garage 1
/qbph_place boss 1
```

The selected ped appears at your current position. Use **W/A/S/D** to move, **Q/E** to rotate, **Page Up/Page Down** to adjust height, **Enter** to save, or **Backspace** to cancel. Placements are persisted in `placements.json`; ensure the resource directory is writable by the FXServer process.

The default police boss ped matches qb-management's default police boss-menu location. If you save it at another location, also add the same coordinate to that job's `Config.BossMenus` in qb-management; qb-management checks that location before opening the boss stash.
