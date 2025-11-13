# Zipline Transporation System

A simple zipline/conduit system that moves objects through a series of waypoints.

Objects that can be transported:
- Unanchored parts created on server
- Players
- Client pies thrown from the [HeartPie](https://github.com/MarioChao/HeartPie) tool

## Zipline Configurations

Each Zipline (ZiplineGroup) have the following [configurations](./src/Workspace/ZiplineGroup/ZiplineConfigs.model.json):

| Config | Type | Description | Default |
|:---:|:---:|:---|:---:|
| Hide_ControlPoints | boolean | Whether initial control points are hidden. | false |
| StartDelay_Objects | number | Delay before non-player objects start traversing the Zipline. | 0 |
| StartDelay_Players | number | Delay before players start traversing the Zipline. | 0.5 |
| Support_Objects | boolean | Whether non-player objects will be transported. | false |
| Support_Players | boolean | Whether players will be transported. | false |
| TraverseSpeed | number | Speed of traversing the Zipline. | 16 |
| WaypointTouchRadius | number | How close a part's hitbox needs to be from a waypoint to activate the Zipline. | 1 |

## Credits

Inspired by:
- yemlow's pie conduit
- Super Mario Galaxy's [launch star](https://www.mariowiki.com/Launch_Star)
- Super Mario Odyssey's [spark pylon](https://www.mariowiki.com/Spark_pylon)
- [The Hatch](https://www.roblox.com/games/98209635344835/The-Hatch)'s power lines
- [Stars Align](https://www.roblox.com/games/15837460390/Stars-Align-Engine-Demo)'s warp pad
