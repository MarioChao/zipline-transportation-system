# Zipline Transporation System

A simple zipline/conduit system that carries objects through a series of waypoints.

Objects that can be transported:
- Unanchored parts created on server.
- Players.
- Client pies thrown from the [HeartPie](https://github.com/MarioChao/HeartPie) tool.
- Objects with certain [tags](https://create.roblox.com/docs/studio/properties#instance-tags).

## Configurations

### Zipline Configurations

Each zipline (ZiplineGroup) have the following [configurations](./src/TestPlace/Workspace/ZiplineGroup/ZiplineConfig/init.meta.json).

ZiplineConfig:

| Config | Type | Description | Default |
|:---:|:---:|:---|:---:|
| Hide_ControlPoints | boolean | Whether control points are hidden. | true |
| IsLooped | boolean | Whether the whole zipline forms a loop. | false |
| TraverseSpeed | number | Maximum speed when traversing the zipline. | 20 |
| UserControl_Acceleration | number | Acceleration when traversing the zipline using user control. | 32 |

RidersConfig:

| Config | Type | Description | Default |
|:---:|:---:|:---|:---:|
| Allow_UserControl | boolean | Whether the player controls the movement on the zipline. | false |
| Connect_RopeLength | number | The length of the `RopeConstraint` connection. If using weld, this is the offset of guide bars below guide parts. | 5 |
| Connect_UseWeld | boolean | Whether objects are connected to the zipline through `WeldConstraint` instead of a `RopeConstraint`. | false |
| Dismount_ByBackwardsEnd | boolean | Whether objects detach from the zipline when reaching the backwards end. | false |
| Dismount_ByForwardsEnd | boolean | Whether objects detach from the zipline when reaching the forwards end. | true |
| Dismount_ByJump | boolean | Whether jumping detaches the player from the zipline. | false |
| Dismount_KeepMomentum | boolean | Whether objects keep their momentum when detached. | false |
| Dismount_WillJump | boolean | Whether the player will jump when dismounting. | true |
| End_ReverseDirection | boolean | Whether objects reverse direction when reaching an end. Only works if the end doesn't cause dismount. | false |
| Offset_ClientPies | Vector3 | Offset of guide bar relative to client pies. | 0, 0, 0 |
| Offset_Players | Vector3 | Offset of guide bar relative to players. | 0, 2, 0 |
| Offset_Tagged | Vector3 | Offset of guide bar relative to tagged objects. | 0, 0, 0 |
| Offset_Objects | Vector3 | Offset of guide bar relative to other (server) objects. | 0, 0, 0 |
| StartDelay_ClientPies | number | Delay before client pies start traversing the zipline. | 0 |
| StartDelay_Players | number | Delay before players start traversing the zipline. | 0 |
| StartDelay_Tagged | number | Delay before tagged objects start traversing the zipline. | 0 |
| StartDelay_Objects | number | Delay before other (server) objects start traversing the zipline. | 0 |
| Support_ClientPies | boolean | Whether client pies will be transported. | true |
| Support_Players | boolean | Whether players will be transported. | true |
| Support_Tagged | boolean | Whether tagged objects will be transported. | true |
| Support_Objects | boolean | Whether other (server) objects will be transported. | false |
| TagName_Client | string | The tag for client objects. | "ZiplineRider_Client" |
| TagName_Server | string | The tag for server objects. | "ZiplineRider_Server" |

WaypointsConfig:

| Config | Type | Description | Default |
|:---:|:---:|:---:|:---:|
| Activate_ProximityPrompt | boolean | Whether players can activate the zipline using a proximity prompt. | false |
| Activate_PlayerTouch | boolean | Whether players can activate the zipline by being within touch radius. | true |
| Create_Middle | boolean | Whether waypoints will be created between the route endpoints. | false |
| Create_Start | boolean | Whether to create a waypoint at the beginning of the route. | true |
| Create_Stop | boolean | Whether to create a waypoint at the end of the route. | true |
| Touch_Radius | number | How close a part's hitbox needs to be from a waypoint to activate the zipline. | 1 |

FXInfo:

| Config | Type | Description |
|:---:|:---:|:---:|
| GuideParticles | Folder | The template folder containing particle emitters used when traversing. |
| GuideTemplate | Folder | The template folder containing the guide bar & the guide part. |
| Sounds | Folder | The template folder containing sounds effects. |
| SegmentPart | Part | The template part used when visualizing the zipline. |
| WaypointPart | Part | The template part used when visualizing waypoints. |
| WaypointProximityPrompt | ProximityPrompt | The template proximity prompt used for activating waypoints. |

### Control Point Configurations

Each control point have their own configurations.

ControlPointConfig:

| Config | Type | Description | Default |
|:---:|:---:|:---:|:---:|
| IsBezierControlPoint | boolean | Whether the part is an intermediate control point for a Bézier curve. | false |

## Credits

Inspired by:
- yemlow's pie conduit.
- Super Mario Galaxy's [launch star](https://www.mariowiki.com/Launch_Star).
- Super Mario Odyssey's [spark pylon](https://www.mariowiki.com/Spark_pylon).
- [The Hatch](https://www.roblox.com/games/98209635344835/The-Hatch)'s power lines.
- [Stars Align](https://www.roblox.com/games/15837460390/Stars-Align-Engine-Demo)'s warp pad.
- EToH Kit's [ziplines](https://etohgame.github.io/kit/docs/client-objects/ziplines).
