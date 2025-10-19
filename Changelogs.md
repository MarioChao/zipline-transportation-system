# Changelogs

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
