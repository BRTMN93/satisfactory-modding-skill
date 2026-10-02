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
- `AFGTrain::mAtcData.Path` is the autopilot's current route. `Path->Station` is the target station. `Path->PathPoints[0].Distance` is the route length in cm, measured from the first path point:
  - started at a station, it equals the distance driven (a 536 m path and 536 m driven, a 632 m path and 632 m driven),
  - started between stations, the train's front is behind the first point (a 32 m path, 55 m driven).
  The path is cleared while the train is docked. `mSimulationData.Velocity` is the signed speed in cm/s.
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
- **Belts keep running during docking** (solid cargo; fluid platforms not tested). A loading platform kept receiving from its input belt through the whole 27 s phase: +1080 ore, about 10 changes a second. An unloading platform kept emptying into its output belt both while waiting (1200 decreases in 120 s) and during the unloading phase (269 decreases in 27 s).
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

- **[source]** `FRailroadNavigation::FindPathSync(AFGLocomotive*, AFGBuildableRailroadStation*, FRailroadGraphAStarFilter)` (`RailroadNavigation.h`): native A*, synchronous. The target can only be a station, and the locomotive does not turn around.
- **[source]** The private `FindPathSyncInternal(start, end, filter, out_pathPoints)` finds a route between any two track connections. It is a candidate for building custom routes (access via AccessTransformers). Still to be checked.
- **[source]** The edge cost is computed by `FRailroadGraphAStarFilter::GetTraversalCost`.
- **[source]** `AFGTrainScheduler` (`FGTrainScheduler.h`): native block reservations, priorities and starvation protection. The game itself resolves conflicts at junctions.
- **[source]** `FFGRailroadSignalBlock` (`FGRailroadSignalBlock.h`): `GetAspectFor(signal)`, `IsOccupied`, `CreatePathReservation`, `CreateExclusiveReservation`. An ordinary block is exclusive. In a path block several trains run at once if their routes do not cross.
- **[source]** Aspects: `ERailroadSignalAspect` (none, clear, stop, docking).
- **[source]** Driving control: `UFGLocomotiveMovementComponent` has `SetThrottleInput`, `SetAirBrakeInput`, `SetEmergencyBrake`.

## Pitfalls

- **[source]** The name `FTrackGraph` is taken by a game struct (`FGRailroadSubsystem.h`). Custom track graph types must use a different name or a prefix.
- **[source]** Class names suggested by a chatbot, `AFGBuildableRailroadTrackConnection` and `AFGTrainHalt`, do not exist. The right ones are `UFGRailroadTrackConnectionComponent`, `AFGBuildableRailroadStation` and `AFGTrainStationIdentifier`. Always verify game class names in the headers.
- Solid-cargo belts do **not** pause during docking in game 502094 (see "Docking rules in practice"), although the mod Uninterrupted Train Belts/Pipes suggests that they once did. **[?]** Pipes on fluid platforms have not been measured.
