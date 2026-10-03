# Railways

Part of the `satisfactory-modding` skill. Markers: no marker = verified in practice, **[source]** = read from SML or game code, not tested, **[?]** = uncertain. Replace the parts in `<...>` with your own.

Most of this file was first read from game headers (changelist 491125, later checked against 502094) and asset stubs. The parts without a marker were tested in the packaged game 502094 with SML 3.12.0 on a single player host: a test scenario wrote timetables from code and logged the train's delegates next to its state polled every 0.1 s. Check names against the current headers (see `patterns-and-pitfalls.md`).

## Where to get data

- `AFGRailroadSubsystem` (`FGRailroadSubsystem.h`): `GetAllTrains`, `GetAllTrainStations` return the save's trains and station identifiers (with `GetStationName()`). **[source]** Connected track networks have an identifier that `GetTrackGraphID` returns on a track, a platform and a vehicle.
- `AFGTrain` (`FGTrain.h`): `GetTimeTable`, `NewTimeTable`, `HasTimeTable`, `SetSelfDrivingEnabled`, `IsSelfDrivingEnabled`, `GetDockingState`, `GetTrainStatus`, `GetSelfDrivingError`. **[source]** `IsPlayerDriven`, `IsDerailed`.
- `AFGTrain::mConsistData` matches the world. For a locomotive plus one freight wagon:
  - `Vehicles.Num() == 2`, the same as counting `AFGRailroadVehicle` actors whose `GetTrain()` is the train,
  - `Length` 32.0 m, equal to the sum of `AFGRailroadVehicle::GetLength()`,
  - `MaxSpeed` 200 km/h (5555 cm/s),
  - `Mass` 330 t with the wagon empty.
  **[source]** It also has `MaxBrakeDeceleration` and `MaxBrakeDistance`.
- `AFGTrain::mAtcData.Path` is the autopilot's current route. `Path->Station` is the target station. The path is cleared while the train is docked, and a save does not keep it (see "A train's route is not saved" below). `mSimulationData.Velocity` is the signed speed in cm/s.
  - **Format of the points (`FRailroadPath::PathPoints`):** one point per track on the route. A point's `TrackConnection` is the connection at the far end of that track in the driving direction.
    - Point 0 is the far end of the track under the locomotive's front. For a train docked at a station, that is the station's own stop connection.
    - The last point is the stop connection of the target station, the one whose `GetStation()` returns it. `FRailroadPathFindingResult::Goal` is the same connection.
    - Consecutive points are linked like this: the next point is `X->GetOpposite()` for one `X` in `Previous->GetConnections()`.
    - Signals do not appear as points. A signal is found through `GetFacingSignal()` of a point's connection.
  - `Distance` (cm) of a point is the sum of the lengths of the tracks of all later points. The last point has 0. So `Path->PathPoints[0].Distance` is the route length in cm, measured from the first path point, and it leaves out the first point's own track (a 680.0 m route started 85 m before the end of a 152 m track):
    - started at a station, it equals the distance driven (a 536 m path and 536 m driven, a 632 m path and 632 m driven),
    - started between stations, the train's front is behind the first point (a 32 m path, 55 m driven).
  - Evidence (game 502094): three native routes of 19, 14 and 16 points were checked point by point. All links matched and the worst distance error was 0.0 cm.
- `AFGTrain::mSelfDrivingData.State` is the AI state (`SDLS_Idle`, `SDLS_FollowPath`, `SDLS_Docking`, `SDLS_DockingCompleted`). `mDockedAtStation` is the station building the train is docked at.
- **[source]** `AFGBuildableRailroadTrack`: `GetLength`, `GetConnection(0/1)`, `GetVehicles`, `GetSignalBlock`. `UFGRailroadTrackConnectionComponent` (`FGRailroadTrackConnectionComponent.h`): connections, switch position, signals, station, `GetSignalBlock`.
- `AFGBuildableRailroadStation::GetStationIdentifier()` leads from a station building to the identifier used in timetables, and `AFGTrainStationIdentifier::GetStation()` goes back.
- **Walking a station's platforms without a train:** start at `Station->GetStationOutputConnection()`, then repeat `Next = Connection->GetConnectedTo()`, `Platform = Next->GetPlatformOwner()`, `Connection = Platform->GetConnectionInOppositeDirection(Next)`. Stop when `GetConnectedTo()` is null or the owner is another `AFGBuildableRailroadStation`.
  - On five test stations all platforms were on the output side, in order from the station. The other side (`Station->GetConnectionInOppositeDirection(output)`) was empty.
  - `IsOrientationReversed()` differs between platforms of one station, depending on how they were built, so it says nothing about the order.
- Platform classes and capacities:

  | Class | Kind | Inventory |
  |---|---|---|
  | `Build_TrainDockingStation_C` (`AFGBuildableTrainPlatformCargo`) | `FCT_Standard` | 48 slots, 4800 iron ore |
  | `Build_TrainDockingStationLiquid_C` (`AFGBuildableTrainPlatformCargo`) | `FCT_Liquid` | 1 slot of 3 200 000 fluid units = 3200 m³ (1000 units per m³; water's stack size is 50 000). Takes no solid items. |
  | `Build_TrainPlatformEmpty_C` (`AFGBuildableTrainPlatformEmpty`) | empty | none |

- `AFGBuildableTrainPlatformCargo`: `GetInventory`, `GetIsInLoadMode`, `GetDockingStatus` (`ETrainPlatformDockingStatus`), `GetDockedActor`, `IsFullLoad`, `IsFullUnload`. The cargo kind `mFreightCargoType` is protected. Two reads gave the same value on 7 platforms of both kinds:
  - the getter that the AccessTransformers line `Accessor=(Class="AFGBuildableTrainPlatformCargo", Property="mFreightCargoType")` generates, `GetmFreightCargoType()`,
  - reflection, which needs no AccessTransformers: `FindFProperty<FEnumProperty>(AFGBuildableTrainPlatformCargo::StaticClass(), TEXT("mFreightCargoType"))`.
- **Polling platform stock is cheap.** `GetInventory()->GetNumItems(Item)` plus `GetDockingStatus()` through a `TWeakObjectPtr` costs 0.10–0.20 µs per call in a hot loop on a 48-slot freight platform, empty or full, and 0.01 µs on a 1-slot fluid platform. Taken the way a sampler takes it, one call per platform per frame, the median is 0.9 µs, p99 3.6 µs, max 21 µs (cold cache, 4800 calls over 600 frames, i9-12900H, Shipping build). 1000 platforms sampled once a second cost about 15 µs per frame at 60 fps, so a sampler needs no inventory change delegates.
- **Which vehicle stands on which platform:** the lead locomotive stops at the station building. Vehicle *n* of `mConsistData.Vehicles`, counted from 1 at the lead locomotive, stands on platform *n − 1* along the output side. Vehicles beyond the last platform stand outside the station and get nothing.
  - A second locomotive right behind the first takes platform 1, so `GetDockedActor()` of that cargo platform returns the locomotive, and every wagon moves one platform back.
  - A wagon's `IsOrientationReversed()` does not matter. `GetDockedVehicleOffset()` was 0 every time.
  - Tested in two runs: locomotive + 1 wagon at 1 and 2 platforms (the second platform stays empty, `GetDockedActor()` null), locomotive + 2 wagons at 1 and 2 platforms, two locomotives + 2 wagons at 1 and 2 platforms. **[?]** A locomotive at the rear was not tested.
- A freight wagon is a single class, `AFGFreightWagon`, with `GetFreightInventory`. One wagon holds 32 stacks (3200 iron ore). **[source]** The cargo kind is `EFreightCargoType` (none, solid, liquid). There are no separate wagons for liquids.
- **Cargo counts during docking:** the transfer happens in one step at the end of the load/unload phase, and the platform hands over whatever it holds at that moment, belt input included. In two runs of constant setups the wagon held exactly 3200 at `TDS_None`. **[?]** One earlier run saw 3126 at `TDS_None` and 3200 about 28 s later, while driving. Its loading platform's count also dropped by more than the wagon gained. That was not reproduced and is not explained.

## Events available without hooks

- `AFGTrain` has the dynamic delegates `mOnSelfDrivingChanged`, `mOnDockingStateChanged`, `mOnSelfDrivingErrorChanged` and `mOnTrainStatusChanged`. All four fire on the host. Bind them from a `UObject` with `UFUNCTION` handlers (`AddDynamic`), and keep that object alive (`AddToRoot` or a `UPROPERTY`).
  - `mOnTrainStatusChanged` also fires with an unchanged status (`TS_SelfDriving` again) on sub events. Compare it with the previous value.
  - When the player enters the cab or turns the autopilot off, `mOnSelfDrivingChanged(false)` and the status `TS_ManualDriving` arrive.
  - There is **no delegate for timetable changes**. A change the player makes in the train window lands in the timetable at once. To notice it, poll `GetStops` and compare.
  - After a save is loaded, every train with the autopilot on reports `SDLE_NoPower` in the second tick (seen in the test saves, which have the No Power game rule on), cleared 0.2–0.3 s later. A mod that reacts to autopilot errors must ignore the first second after a load (see "A train's route is not saved" below).
- `ESelfDrivingLocomotiveError` values seen in the game: `SDLE_NoError`, `SDLE_NoTimeTable`, `SDLE_NoPower`, `SDLE_StationUnreachable`. **[source]** Also `SDLE_InvalidNextStop`, `SDLE_InvalidLocomotivePlacement`, `SDLE_NoPath`, `SDLE_StationUnreachableWithSignals`, `SDLE_LongWaitAtSignal`.
- **[source]** `AFGBuildableRailroadSignal`: delegate `mOnAspectChangedDelegate`, `IsPathSignal`. A signal block has `OnBlockChanged`.

## Timetable and docking

- `AFGRailroadTimeTable` (`FGRailroadTimeTable.h`): `SetStops` (returns `bool`), `SetCurrentStop`, `GetStops`, `GetCurrentStop`, `GetNumStops`. `SetStops({})` clears it (returns `true`). **[source]** `AddStop`, `RemoveStop`, `IncrementCurrentStop`. The limit is 100 stops (`MAX_STOPS`).
- A stop is an `FTimeTableStop`: a station (`AFGTrainStationIdentifier`) and docking rules (`FTrainDockingRuleSet` in `FGTrainDockingRules.h`, all fields saved in the save game):
  - `DockingDefinition`: `ETrainDockingDefinition::TDD_LoadUnloadOnce` (default) or `TDD_FullyLoadUnload`,
  - `DockForDuration` (default 15 s) and `IsDurationAndRule` (default `false`),
  - `IgnoreFullLoadUnloadIfTransferBlockedByFilters`,
  - `LoadFilterDescriptors` and `UnloadFilterDescriptors`: lists of item classes.
- **A default rule set with only `DockingDefinition = TDD_FullyLoadUnload` means "full or 15 s", not "full".** The train window's Stop Settings show it as "Freight Wagon is fully loaded/unloaded" **or** "wait for (seconds): 15", with the filters under Load Only / Unload Only.
  - With that rule and an unloading platform that was nearly full, the train left with 100–200 ore still in the wagon, in three runs. The docking took 27–30 s: the platform was in `ETPDS_WaitForTransferCondition` for 2.5 s, then in `ETPDS_Unloading`.
  - The 15 s "or" timer is what lets it leave. Measured below.
- A timetable written from code is shown correctly in the train window, and the player can edit it there.

### Docking rules in practice

Measured on a freight platform with one wagon (3200 iron ore, platform 4800), rules written from code, each case run twice with the same result.

- **Timeline:** when the transfer can start at once, the platform goes straight to `ETPDS_Loading` or `ETPDS_Unloading` for exactly **27.0 s**. The whole transfer then happens in one step at the end: the platform count falls once and the wagon jumps from 0 to 3200. `TDS_None` follows in the same frame.
  - When the transfer cannot start, the platform waits in `ETPDS_WaitForTransferCondition` and checks again every **2.5 s**.
  - A rule with a timer that cannot transfer goes to `ETPDS_IdleWaitForTime`.
- **Belts keep running while the platform waits** in `ETPDS_WaitForTransferCondition` (solid cargo; fluid platforms not tested): 1200 decreases in 120 s on one layout, 2599 in 868 s on another.
  - **[?] During the 27 s load/unload phase it depends on the layout.** A loading platform kept receiving from its input belt (+1080 ore, about 10 changes a second), and a 1-platform unloading station with one output belt into storage kept emptying (269 decreases in 27 s). A 2-platform unloading station whose two Mk.2 output belts were backed up to six Smelters did not change once in its 27 s `ETPDS_Unloading` phase: the transfer added exactly 3200 (1600 -> 4800) and the Smelters' input buffers dropped (600 -> 566). Which difference decides this is not known.
  - After that phase the belts pulled at their full speed (240/min on two Mk.2 belts, against 180/min consumption) for about 2 minutes, until the belts and buffers had refilled.
  - Code that measures a platform's outflow should treat the load/unload phase and about 2 minutes after it as invalid, but not the waiting.
- **Each platform of a multi-platform station transfers on its own.** A train with 2 wagons at a station with 2 unloading platforms, "fully unload and 0 s": the platform with room unloaded its wagon 27 s after docking (`ETPDS_Unloading` -> `ETPDS_WaitingForTransfer` -> `ETPDS_Complete`, 0 -> 3200), while the other stayed in `ETPDS_WaitForTransferCondition` for 14 more minutes until it had room. The docking (`TDS_None`) ended only when the last platform finished, with both wagons empty. One blocked platform holds the whole train.
- **What a backed-up belt line takes from a platform:** six Smelters (Iron Ingot, 30/min each) fed from one platform by two Mk.2 belts took one item at a time, 2 or 4 items in any 1 s window and exactly 6 in any 2 s window (the Smelters' 2 s cycle), 179.7/min over 700 s. With full input buffers but empty belts at the start, the same layout took 238/min in the first minute, 205/min in the second and 180/min from the third. A Smelter's input buffer holds 100 iron ore: `GetInputInventory()->AddStack(FInventoryStack(1000, Ore))` added 100.
- **"Wait until full":** `TDD_FullyLoadUnload` + `IsDurationAndRule = true` + `DockForDuration = 0`.
  - Loading with 1000 ore on the platform: the train stayed in `ETPDS_WaitForTransferCondition` for 45 s. Once the platform held a wagon's worth, it loaded 3200 in one 27 s step.
  - Unloading: it waits until the platform has **room for the whole wagon**. With 4000 on the platform it waited 120 s while the output belt drained it to 1598, then unloaded 3200 at once. It never unloads part of a wagon.
- **The game default** (`TDD_FullyLoadUnload`, `DockForDuration = 15`, `IsDurationAndRule = false`) means "full **or** 15 s":
  - with 1000 ore it loaded what was on the platform at the end of the 27 s phase (2182, because the input belt kept feeding) and left after 29.6 s,
  - at a full unloading platform it waited 2.5 s + 12.5 s idle and left after 15.0 s with the wagon untouched.
- `TDD_FullyLoadUnload` with `DockForDuration = 0` and `IsDurationAndRule = false` ("full or 0 s") behaves like load once: it loaded 1000 and left after 29.6 s.
- **Items the filter blocks:** a wagon with 1600 ore and 1600 coal stopped at a full unload that unloads only ore.
  - The ore went out in one 27 s step. Then the train stayed docked in `ETPDS_IdleWaitForTime` indefinitely, because the coal can never leave.
  - With `IgnoreFullLoadUnloadIfTransferBlockedByFilters = true` it unloaded the ore and left after 27.0 s.
- **The "nothing" filter**, `UFGNoneDescriptor::StaticClass()` (`FGNoneDescriptor.h`) as the only load filter:
  - With `TDD_LoadUnloadOnce` the train docks and the docking ends in the same frame: `TDS_Docked` and `TDS_None` together, nothing moved. Turning the autopilot off inside the `TDS_Docked` handler leaves the train parked at the station (`TS_Parked`, 0 m moved).
  - With `TDD_FullyLoadUnload` + `IsDurationAndRule = true` it never ends. The platform stays in `ETPDS_WaitForTransferCondition` with `IsFullLoad() == 0`.
  - **Exception:** a stop with "fully load/unload AND 0 s" and the "nothing" filter holds a locomotive-plus-wagon train docked for good. It ended at once for a train of two locomotives and two wagons at a station with one freight platform: `TDS_ReadyToDock`, `TDS_Docked` and `TDS_None` came in the same tick.
    - **[?]** The likely reason is that none of its wagons stands on a platform there (the second locomotive takes the only platform, see "Which vehicle stands on which platform"), so the station has nothing to wait for. Not checked further.
    - A test that needs a train stuck in a docking has to pick a train whose wagon really stands on a platform.
- **[source]** FicsIt-Networks exposes the same timetable API in Lua.

## Driving a train through its timetable

This works without hooks:

```cpp
AFGRailroadTimeTable* TimeTable = Train->GetTimeTable();
if (!TimeTable) TimeTable = Train->NewTimeTable();      // a train that never had a timetable returns nullptr
TArray<FTimeTableStop> Stops;
FTimeTableStop& Load = Stops.AddDefaulted_GetRef();
Load.Station = SupplierIdentifier;
Load.DockingRuleSet.DockingDefinition = ETrainDockingDefinition::TDD_FullyLoadUnload;  // still "or 15 s", see above
Load.DockingRuleSet.LoadFilterDescriptors.Add(ItemClass);
// ... the unloading stop the same way, with UnloadFilterDescriptors
TimeTable->SetStops(Stops);
TimeTable->SetCurrentStop(0);
Train->SetSelfDrivingEnabled(true);
```

- **Without stops:** with no timetable, or with 0 stops, `SetSelfDrivingEnabled(true)` broadcasts the autopilot and `TS_SelfDriving`. Within about 0.3 s `SDLE_NoTimeTable` follows. The AI stays `SDLS_Idle` and the train does not move.
- **After `SetStops`, `SetCurrentStop(0)` and autopilot on:** on the next tick the error clears to `SDLE_NoError`, the AI goes to `SDLS_FollowPath` and `mAtcData.Path` is set. Turning the autopilot off and on in the same frame broadcasts off/on and `TS_Parked`/`TS_SelfDriving` each time.
- **Arrival, all in one frame:**
  1. `mOnDockingStateChanged(TDS_ReadyToDock)`,
  2. `mOnDockingStateChanged(TDS_Docked)`,
  3. the current stop already moves to the **next** stop (0 → 1), the path is cleared, the AI is `SDLS_Docking` and the platform is `ETPDS_Loading` or `ETPDS_WaitForTransferCondition`.
- **When the `TDS_Docked` delegate fires, `mDockedAtStation` is still null.** It is set later in the same frame. To know the station inside the delegate, remember `mAtcData.Path->Station` before docking.
- **End of the transfer:** `mOnDockingStateChanged(TDS_None)`. Then a brief `TDS_ReadyToDock` → `TDS_None` as the train looks for the path to the next stop, `mDockedAtStation` becomes null, and the AI goes back to `SDLS_FollowPath`.
- **Timing:** loading or unloading one wagon took 27–30 s from `TDS_Docked` to `TDS_None`.
- **Stopping after the last stop works from inside the `TDS_None` handler:** call `SetSelfDrivingEnabled(false)` and `SetStops({})`.
  - The train stays at the station: 0 m moved in 15 s, status `TS_Parked`, AI `SDLS_DockingCompleted`, platform `ETPDS_None`.
  - A new order from that state finds its path at once and the train leaves. Because it stands at a station, a brief `TDS_ReadyToDock` → `TDS_None` comes first.
- **An order whose first stop is the station the train stands at is served in place.** `TDS_ReadyToDock`, `TDS_Docked` and `TDS_None` came in the frame after the autopilot was turned on, with 0 m driven. This was tested only with an empty wagon on a full-unload stop.
- **A docking that cannot finish is not released by turning the autopilot off and clearing the timetable.** The train stays `TDS_Docked` and the platform stays in `ETPDS_WaitForTransferCondition`. The game itself switches the status to `TS_ManualDriving` 3 s later and then back to `TS_Parked`. A new timetable with the autopilot on does nothing: no docking events and no movement for 4 minutes.
  - `AFGTrain::CancelDockingSequence()` releases it. `IsDockingCancelRequested()` turns 1, and `TDS_None` follows on the platform's next check: after 2.5 s in `ETPDS_WaitForTransferCondition`, 0.2 s in `ETPDS_IdleWaitForTime`. After that a new order works.
- **An order written to a train standing at station X, with X as its second stop:** `SDLE_NoPath` for 1.9 s, then `SDLE_NoError`, a brief `TDS_ReadyToDock` → `TDS_None` at X, and the train drives off normally.
- **An unreachable next station:** for example, a track piece is missing. The train reports `SDLE_StationUnreachable` right after the previous docking ends and waits with the autopilot on. It retries by itself: once the track and power were rebuilt, the error went through `SDLE_NoPower` to `SDLE_NoError` and the train drove on.

## Routes, signals, blocks

- `FRailroadNavigation::FindPathSync(AFGLocomotive*, AFGBuildableRailroadStation*, FRailroadGraphAStarFilter)` (`RailroadNavigation.h`): native A*, synchronous. A mod can call it, and the target is a station. **[source]** The locomotive does not turn around.
  - Called from mod code for a parked train with the autopilot off and no timetable, it returned `RPFR_Success` with a 4-point, 48.0 m route to a station the train had never been sent to. The train stayed untouched: `mAtcData.Path` was still empty afterwards.
  - It gives the exact route the autopilot would take on any leg, so there is no need to rebuild the game's cost function. Evidence (game 502094): `asked the game directly for a route …: RPFR_Success, 4 points, 48.0 m …; route on the train afterwards: no path`.
  - A route handed to the autopilot may end on plain track in front of a signal, not only at a station (see "A route may end on plain track" below).
- **[source]** The private `FindPathSyncInternal(start, end, filter, out_pathPoints)` finds a route between any two track connections. It is a candidate for building custom routes (access via AccessTransformers). Still to be checked. A route of your own can also be given to the autopilot without it (see "Giving the autopilot a route of your own" below).
- **[source]** The edge cost is computed by `FRailroadGraphAStarFilter::GetTraversalCost`.
- **The game's pathfinding avoids a track through a station the train does not stop at.**
  - A 144.0 m track ran through a station (entry signal, three platform tracks, exit signal) and a 167.6 m bypass ran next to it, from a switch before the station to a merge behind it. Every train whose timetable did not name that station was routed over the bypass, although it is 23.6 m longer: the game's route between the two neighbouring stations was 559.5 m, against 536.0 m through the station before the bypass was built.
  - Where neither branch has a station the game takes the shorter one (128 m against 153 m, 228 m against 320 m on the same loop).
  - So passing through a foreign station costs more than 23.6 m of track in the route cost; the exact value was not measured. A mod that predicts the game's route from track lengths alone gets this wrong; asking the game (`FindPathSync`) does not.
  - Evidence (game 502094): `the game itself routes … over the longer branch at T36.1 (167.6 m, the other branch 144.0 m)`, `route on …: the game's, 14 points, 559.5 m`. (2026-10-03, game 502094, SML 3.12.0)
- **[source]** `AFGTrainScheduler` (`FGTrainScheduler.h`): native block reservations, priorities and starvation protection. The game itself resolves conflicts at junctions.
- **[source]** `FFGRailroadSignalBlock` (`FGRailroadSignalBlock.h`): `GetAspectFor(signal)`, `IsOccupied`, `CreatePathReservation`, `CreateExclusiveReservation`. An ordinary block is exclusive. In a path block several trains run at once if their routes do not cross.
- **[source]** Aspects: `ERailroadSignalAspect` (none, clear, stop, docking).
- **[source]** Driving control: `UFGLocomotiveMovementComponent` has `SetThrottleInput`, `SetAirBrakeInput`, `SetEmergencyBrake`.

### Signals and track connections

- **A signal between two tracks, seen from the connections.** Take a one-way block signal at the joint between track A (before the signal) and track B (behind it):
  - `GetGuardedConnections()` is A's connection at the joint. `GetObservedConnections()` is B's connection at the joint.
  - A's connection returns the signal from `GetFacingSignal()`. B's connection returns it from `GetTrailingSignal()`.
  - `GetObservedBlock()` is B's block (`AFGBuildableRailroadTrack::GetSignalBlock()` of B has the same `ID`).
  - A connection with a trailing signal and no facing signal cannot be entered from that side. This is how a walk over the track graph sees a one-way signal from behind.
  - Evidence: a dump of 12 block signals and 37 tracks, for example `signal S03 … guards [T10.1], observes [T09.0], observed block 3`.
- **Path signals as a train sees them.** A path signal shows `RSA_Stop` until an approaching train gets its reservation, so the autopilot brakes for it.
  - A train doing 100 km/h slowed to 51 km/h. The signal turned `RSA_Clear` when the train was 48 m in front of it, and the train accelerated again (same numbers on two laps).
  - At a path signal whose block was busy, the train stood 10.0 m in front of it and left when the signal cleared.
  - Evidence (game 502094): `T34.1 segment 7 48 m … RSA_Stop` and `… RSA_Clear` in the same tick.
- **Block signals and path signals open the same window.** `mInteractWidgetSoftClass` read from instances of `Build_RailroadBlockSignal_C` and `Build_RailroadPathSignal_C` is the same class, `/Game/FactoryGame/Buildable/Factory/Train/Signal/Widget_RailroadSignal.Widget_RailroadSignal_C`. So one widget hook on that class covers both kinds (hooks: `references/sml-api.md`, section 5; the window's widget tree: `references/rendering-ui.md`). A path signal with no train near it shows `RSA_Stop` with `RBV_Valid`. Evidence: a dump of 9 block and 3 path signals.
- **After a save is loaded, the signals on the track connections are known in the first tick; the signal blocks and the trains' graph id are not.**
  - In the first tick every signal's guarded connection already returned that signal from `GetFacingSignal()` (and the observed one from `GetTrailingSignal()`), so a walk over tracks, switches and one-way signals works at once. A scenario found both sidings of a 46-track loop in its first tick, while all signals still showed `RSA_Stop` without a block.
  - In the first frame of the loaded world every signal reported `HasObservedBlock() == false`, `GetAspect() == RSA_Stop` and `GetBlockValidation() == RBV_Unvalidated`. `AFGTrain::GetTrackGraphID()` returned -1, while the track under the train's first vehicle already returned its graph id.
  - The block signals turned `RSA_Clear` one frame later (0.4 s on that load), so the wait for the blocks is about one frame, not two seconds. The first test saw all 12 signals with a block and `RBV_Valid`, and the trains returning the graph id, at frame 62 (about two seconds) without looking more finely; when exactly the trains' graph id comes was not measured.
  - Code that only needs the layout does not have to wait. Code that needs block ids or aspects waits for `HasObservedBlock()`, for example until every signal with `HasValidConnections()` has it. In the first frames it should take the graph id from a track, not from the train.
  - Evidence (game 502094): test log, frame 0: `12 of 12 signals observe no block yet`, `track graph -1, its first vehicle's track is in graph 2`. Frame 62: all valid. Second test: `[frame 0] t=0.0 sidings read 0.00 s after the load, in tick 1`, `[frame 0] signal S07 shows RSA_Stop`, `[frame 1] t=0.4 signal S07 shows RSA_Clear`. (2026-10-03, game 502094, SML 3.12.0)
- **Replacing signals changed the track graph.** A player replaced three block signals with path signals, and the track graph came back with 38 tracks instead of 37. One 56.43 m track had become two, with the same summed length, and the new joint carried one of the new signals (game 502094).
  - **[?]** The likely cause is that a signal placed in the middle of a track piece makes the game split that piece into two track buildables (a players' tutorial for 1.0 says free placement "creates new segments"). Not reproduced from code.
  - If so, a mod's own track graph and any stored reference to a track must be refreshed when a signal is built, not only when tracks are.

### What the autopilot does with a route

- **What the autopilot looks at: `mAtcData.TargetPoints`.** One point per signal on the route (with its current aspect), one per switch (aspect `RSA_None`) and one for the goal (`IsGoal`, aspect `RSA_Dock` when the goal is a station). Each point has `PathSegment` (the index of the route point) and `Distance` from the train.
  - `CurrentPathSegment` is the index of the route point at the far end of the track under the train's front. `CurrentConnection` is that point's connection.
  - A train stops 10.0 m before a signal at stop (`NextRestrictiveSignalStopOffset` 1000). The stop offset for docking is 8.0 m.
  - With no route (docked, or autopilot idle) the points have `PathSegment` -1 and list the signals along the track ahead.
  - Evidence (game 502094): control data logged at every tick in which it changed, for example `T24.0 segment 15 10 m … RSA_Stop`, `ahead T24.0 10.0 m, speed 0 km/h`, `restrictive T31.1 RSA_Dock … stop offset 8.0 m`.
- **When the game looks for a route by itself (trains running undisturbed).** `FRailroadNavigation::FindPathSync` was called:
  - once for a train when its autopilot was switched on (on the next tick),
  - once after each docking ended: docking state `TDS_None`, then `TDS_ReadyToDock` one frame later, the call in the frame after that, then `TDS_None` again.
  - Nothing else: 11 calls for three trains in 190 s, although they followed each other from signal to signal.
  - Every call came on the game thread with the default filter (`AcceptsPartialSolution` 0, `IgnoreSignals` 0).
  - Evidence (game 502094): a test log with a hook on `FindPathSync` that only logs.
- **What makes the game look for a route again while a train is on its way.** Each action was done to a train cruising on its route with the autopilot on, and the `FindPathSync` calls for that train were counted for the next 8 s:
  - `AFGRailroadTimeTable::SetCurrentStop(<the same index>)`: no call, route kept.
  - `SetStops(<the same stops>)` (the current stop index stayed): no call, route kept.
  - `SetSelfDrivingEnabled(false)` followed by `SetSelfDrivingEnabled(true)` in one frame: the route was cleared and one call came at once, for a route from where the train was.
  - `SetCurrentStop(<another stop>)`: the route was cleared and one call came at once, to the new stop. The train kept rolling.
  - Dismantling a block signal on the route ahead of the train: no call in 44 s, route kept, no autopilot error.
  - Standing at a signal at stop: no call. `mSelfDrivingData.TimeWaitingAtSignal` counts the seconds. At 300 s (`mLongWaitAtSignalThreshold`, game 502094) the train's error becomes `SDLE_LongWaitAtSignal` and the status delegate fires with `TS_SelfDriving`. The game still does not look for another route (watched for 20 s after the error, on two trains). A train held at the exit signal of the station it just docked at keeps the docking state `TDS_ReadyToDock` while it waits.
  - So a mod that wants the game to ask for a route again (to answer in a `FindPathSync` hook) can toggle the autopilot or change the current stop. A mod that writes routes itself must expect the game to replace them after exactly these actions, after every docking and after every load of a save (see "A train's route is not saved" below).
  - Evidence (game 502094): `current stop changed to the other station: 1 pathfinding calls for the test train and 2 route changes on it in the 8 s after, error SDLE_NoError`.

### Giving the autopilot a route of your own

- **The autopilot drives a route given by a mod, and signals follow that route.** A hook on `FindPathSync` (`references/sml-api.md`, section 5) replaced the result for one train with a route through a 320 m siding instead of the game's 228 m main line. The new route had the same first and last points as the game's route, with the siding's connections spliced in and `Distance` recomputed. It was a new `FRailroadPath` in `Result.Path` (`Goal` and `Path->Station` unchanged).
  - The train took the siding five times out of five, on a layout with block signals only and on one with path signals at the junction entrances. There was no autopilot error, and it docked normally.
  - The train kept the very `FRailroadPath` object the hook returned (`mAtcData.Path` compared equal to it) until the next docking.
  - The autopilot set the switch itself, and the path signal in front of the switch cleared for the mod's diverging route.
  - Other trains, whose results were left alone, kept to the main line.
  - Evidence (game 502094): two test runs, `autopilot errors 0`.
- **A route can be given to a train without any hook: `AFGTrain::mAtcData.SetPath(Result)`.** `mAtcData` is a public member and `FTrainAtcData::SetPath(const FRailroadPathFindingResult&)` is exported.
  - A ticker noticed a new route of the game on the train (`mAtcData.Path` was not the mod's object). It built a `FRailroadPathFindingResult` (`Locomotive`, `Goal` = the last point's connection, `Path` = a new `FRailroadPath` with the same `Station`, `Result = RPFR_Success`) and called `SetPath`.
  - `SetPath` returned true and `CurrentPathSegment` went back to 0. The train kept the mod's `FRailroadPath` object and drove it: three trips out of three through the siding, no autopilot error.
  - It works right at departure (train standing, the frame after the game's own `FindPathSync`) and on the way: at 14 km/h and at 104 km/h, three tracks into the route. The mod's route started at the far end of the track the train was on (the game's points from `CurrentPathSegment` on), the way the game's own routes start.
  - A route whose first point lies behind the train works too (see "A route can be changed under a moving train" below).
  - Evidence (game 502094): `route written into the control data on the way, at 104 km/h: SetPath 1, segment 3 -> 0, on the train now the mod's: 18 points, 568.1 m`.
  - **The game's own pathfinding can be noticed without a hook.** `AFGTrain::mSelfDrivingData.TimeOfLastFindPath` holds the world time (seconds) of the train's last pathfinding, and a new route is a new `FRailroadPath` object, so comparing `mAtcData.Path` with the object the mod wrote tells whose route the train has (this is what the ticker above compared). Evidence: `route on …: the game's, 14 points …, game's pathfinding clock 35.5` logged at t=35.5 s. (2026-10-03, game 502094, SML 3.12.0)
- **A route can be changed under a moving train in both directions with `SetPath`.**
  - Made whole on the way: a route that ended at a signal was replaced by the whole route 100 m and 15 m before the stop point (at 56–91 km/h and at 13–16 km/h). The train did not stop.
  - Cut on the way: a whole route was cut at a signal ahead. The train stopped before that signal in every try: with 59 m and 9 m more room up to the stop point than `mAtcData.BrakeDistance` at that moment, and with 20 m, 60 m and 100 m less.
  - With room to spare, or 20 m short, it braked normally: from 111 km/h it stopped in 112 m and 6.3 s, 4.2–4.9 m/s² on average (`BrakeDistance` matches about 3.6 m/s², so it is on the safe side).
  - The end of a route is enforced, not only braked for. Cut 60 m and 100 m too late, the train still stood at the stop point, 8.0 m before the signal: from 76 km/h with 2.1 m of room and from 115 km/h with 41.9 m of room (about 12 m/s²). When the cut came with the front already 1.8 m past the stop point, the train stood still within one frame from 96 km/h, 5.7 m before the signal. No cut made a train pass the signal and none raised an autopilot error. So a late cut is safe and only looks unnatural; cut no later than `BrakeDistance` before the stop point to get a normal braking. A cut after the front has passed the signal was not tried.
  - If the game had already approved the train's path reservation through the junction behind that signal (the path signal showed `RSA_Clear`), the signal went back to `RSA_Stop` after the cut: the game drops the reservation when the route changes.
  - A route may start behind the train: the same remaining route written with two extra points for the two tracks already passed was accepted (`SetPath` 1), `CurrentPathSegment` went to 0 and was at the right point again on the next ticks, and the train drove on.
  - Evidence (game 502094): `route cut 120.0 m before the parking signal at 111 km/h, braking distance 132.1 m, so -20.1 m to spare …: SetPath 1`, `stopped 8.0 m before parking signal … 8.3 s after its route was cut`, `route cut 6.2 m before the parking signal at 96 km/h, braking distance 98.5 m, so -100.4 m to spare before the stop point: SetPath 1`, `stopped 5.7 m before parking signal …, 2.0 s after its route was cut` (the scenario reports a stop after 2 s without movement), `route starting two tracks behind the train written at 30 km/h: SetPath 1, segment 2 -> 0`, `5 s after …: still the mod's 1, segment 5, 66 km/h`. (2026-10-03, game 502094, SML 3.12.0)
- **A route may end on plain track, in front of a signal, not only at a station.** The hook returned a route cut off at the connection guarded by a siding's exit path signal (last point = that connection, `Goal` = the same, `Path->Station` left as the real target).
  - The autopilot treated the last point as its goal: a target point with `IsGoal` and aspect `RSA_Dock`. It braked to a stop 8.0 m before that connection, like for docking.
  - The train then stood there in `SDLS_FollowPath`, docking state `TDS_None`, error `SDLE_NoError`, `TimeWaitingAtSignal` 0. The game made no further `FindPathSync` call for it for 90 s, while two other trains passed on the neighbouring track. The game does not look for a new route by itself in this state.
  - Switching the autopilot off and on makes it look: `FindPathSync` came on the next tick with a route starting where the train stood. The train then waited at the path signal (`TimeWaitingAtSignal` now counted up) and left when it cleared.
  - The same happened with a block signal in that place: the train stopped 8.0 m before the connection the signal guards and did not pass it, although nothing held the signal at stop.
  - So `FindPathSync` itself still takes a station, but the route handed to the autopilot can stop short.
  - Evidence (game 502094): `targets 1: T24.0 segment 18 8 m … RSA_Dock goal`, `held for 60 s: 0 pathfinding calls for the test train meanwhile, error SDLE_NoError, ai SDLS_FollowPath`.
- **Parking a train at the end of a route, without touching the signals.** This extends "A route may end on plain track" above with a cycle that needs no hook, tested more than 40 times. A route written with `mAtcData.SetPath` that ends at the connection guarded by a siding's exit signal stops the train 8.0 m before that connection every time, with a path signal or a block signal there, also when the siding's entry signal is a path signal (the route then ends inside a path block).
  - The approach is like docking: from about 29 m before the end the target speed is 15 km/h, so the last 21 m take about 10 s.
  - No reservation is made behind the route's end. The path signal stays `RSA_Stop`, a block signal stays `RSA_Clear`, and trains on the neighbouring track passed the junction behind it without stopping (20 passes next to a held train, standstill 0.0 s, the same lowest speed as with no train held).
  - Held with the autopilot on: nothing happens for 330 s. No pathfinding, `mSelfDrivingData.TimeWaitingAtSignal` stays 0 and `SDLE_LongWaitAtSignal` does not come (a train waiting at a signal gets it after 300 s, see above), because the train is not waiting at a signal. Writing the rest of the route with `SetPath` releases it: it moved 1.0 s later.
  - Parked with the autopilot off: `SetSelfDrivingEnabled(false)` after the stop gives `TS_Parked`, clears the route and leaves the train exactly in place (0.00 m in every hold, the longest 330 s). `SetStops` + `SetCurrentStop` + `SetSelfDrivingEnabled(true)` releases it: the game finds a route from where it stands on the next tick, and the train moves 0.6–1.0 s later when the signal ahead is clear, or waits at it like any train (up to 36 s seen) and then leaves.
  - Only the parked variant survives a save: see "A train's route is not saved" below.
  - Evidence (game 502094): `stopped 8.0 m before parking signal …, whole train in the siding's block 1, … waiting at signal 0 s`, `stood 330 s with the autopilot on: routes found by the game meanwhile 0, … waiting at signal 0 s, error SDLE_NoError`, `left siding … 13.9 s after the release, moving after 7.7 s`. (2026-10-03, game 502094, SML 3.12.0)
- **A train's route is not saved; after a load the game finds a new one in the second tick.** `AFGTrain::mAtcData` has no `SaveGame` flag, and the test agrees: a train saved while it drove at 95 km/h on a route written by a mod came back with `mAtcData.Path` empty, the same position (0.43 m off) and the same speed in the first tick. In the second tick (0.4 s later) every train with the autopilot on had a new route from the game's own pathfinding, to its timetable's current stop. A mod that gave a train a route of its own has to write it again after every load; doing it in the tick the game's route appears worked (`SetPath` 1, the train took the mod's siding).
  - In that second tick every train with the autopilot on also reported `SDLE_NoPower` (the test saves have the No Power game rule on), cleared 0.2–0.3 s later. A mod that reacts to autopilot errors must ignore the first second after a load. The moving train lost speed in these frames: 95 km/h when loaded, 61 km/h in the second tick, 58 km/h in the third, then it accelerated again.
  - A train saved with the autopilot off came back parked in exactly the same place (0.00 m off), status `TS_Parked`, no route, and stayed there.
  - Evidence (game 502094): `loaded …: train …, autopilot 1, … speed 95 km/h (saved at 95), 0.43 m from where it was saved, route no path`, `[frame 1] t=0.4 event … error SDLE_NoPower`, `[frame 1] route on …: the game's, 14 points … at 61 km/h, tick 2`, `[frame 3] t=0.7 event … error SDLE_NoError`. (2026-10-03, game 502094, SML 3.12.0)

## Pitfalls

- **[source]** The name `FTrackGraph` is taken by a game struct (`FGRailroadSubsystem.h`). Custom track graph types must use a different name or a prefix.
- **[source]** Class names suggested by a chatbot, `AFGBuildableRailroadTrackConnection` and `AFGTrainHalt`, do not exist. The right ones are `UFGRailroadTrackConnectionComponent`, `AFGBuildableRailroadStation` and `AFGTrainStationIdentifier`. Always verify game class names in the headers.
- Solid-cargo belts keep running while a platform waits for its transfer condition in game 502094 (see "Docking rules in practice"), although the mod Uninterrupted Train Belts/Pipes suggests that they once paused for the whole docking. **[?]** Whether they pause in the 27 s load/unload phase depends on the layout, and pipes on fluid platforms have not been measured.
