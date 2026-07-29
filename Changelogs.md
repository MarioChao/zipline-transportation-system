# Changelogs

## Futures plans

- Endpoint reverse direction.

## [v0.1.0] Client pie attributes + Fixed disable collision | 2026/07/29

Added `StartDelay_ClientPies` and `Support_ClientPies` attributes.

Hidden parts (control points & template parts) now have collision properties (`CanCollide`, `CanQuery`, `CanTouch`, `AudioCanCollide`) disabled as well.

## [v0.0.3] Waypoint configurations | 2025/11/13

New configuration `WaypointConfig`:
- Specify whether players can activate the zipline by touching waypoints or triggering a proximity prompt.
    - Through the `Activate_ProximityPrompt` and `Activate_PlayerTouch` attributes.
- Specify whether waypoints will be created at the start, middle, or end of the route.
    - Through the `Create_Start`, `Create_Middle`, and `Create_Stop` attributes.
    - This allows the creation of directional (one-way) ziplines.
- Original `WaypointTouchRadius` attribute is now the `Touch_Radius` attribute of `WaypointConfig`.

Renamed `ZiplineConfigs` (the `Configuration`) into singular form `ZiplineConfig`.

## [v0.0.2] Template part transparency fix | 2025/11/12 (2)

Fixed unexpected template part transparency values when there's multiple `ZiplineGroup`.

Added attributes documentation to `README.md`.

## [v0.0.1] Curved ziplines + moving platform physics + more configs | 2025/11/12 (1)

"Waypoints" vs "Control Points":
- The points used to create a `SegmentedRoute` are referred to as "control points".
- "Waypoints" are points created at whole-number alpha values on the `SegmentedRoute`.
- The number of waypoints <= the number of control points.

Made transported objects carry contacted parts (e.g. moving platforms):
- Achieved by anchoring the part before `RunService:Heartbeat()`, then unanchoring it afterward.

Added some configurations:
- Hide_ControlPoints: whether initial control points will be hidden.
- Support_Objects: whether non-player objects will be transported.
- Support_Players: whether players will be transported.

Other changes:
- Renamed `ZiplineSetup` into `ZiplineTrack`.
- Moved `ZiplineRoute` into its own package [`SegmentedRoute`](https://github.com/MarioChao/segmented-route).
- `VFXBeams` are replaced by `VFXParts`.
- New submodule `ZiplineConfigs` for retrieving zipline configurations.

## [v0.0.0] Initial Zipline System | 2025/10/18

A working zipline system with:
- [`ZiplineRoute`](./src/ReplicatedStorage/ZiplineTransport/ZiplineRoute.luau) class Module for storing routes and calculating positions
- [`ZiplineSetup`](./src/ReplicatedStorage/ZiplineTransport/ZiplineSetup/init.luau) setup Module for handling touched events and traversal
- [`CreateZiplines_Client`](./src/ReplicatedStorage/ZiplineTransport/CreateZiplines_Client.server.luau) client Script for transporting Local Player and client pies
- [`CreateZiplines_Server`](./src/ReplicatedStorage/ZiplineTransport/CreateZiplines_Client.server.luau) server Script for transporting other server objects

Zipline configurations:
- StartDelay_Objects
- StartDelay_Players
- TraverseSpeed
- WaypointTouchRadius
