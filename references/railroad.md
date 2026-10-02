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
- `AFGBuildableRailroadStation::GetStationIdentifier()` leads from a station building to the identifier used in timetables. **[source]** `AFGTrainStationIdentifier::GetStation()` goes back. `GetStationOutputConnection`. To walk from a station along its platforms, go through `UFGTrainPlatformConnection` (`GetConnectedTo`, `GetPlatformOwner`).
- `AFGBuildableTrainPlatformCargo`: `GetInventory`, `GetIsInLoadMode`, `GetDockingStatus` (`ETrainPlatformDockingStatus`). **[source]** The fields `mFreightCargoType` and `mIsFullUnload` are protected, so they need AccessTransformers.
- A freight wagon is a single class, `AFGFreightWagon`, with `GetFreightInventory`. One wagon holds 32 stacks (3200 iron ore). **[source]** The cargo kind is `EFreightCargoType` (none, solid, liquid). There are no separate wagons for liquids.
- **[?]** Cargo counts read with `UFGInventoryComponent::GetNumItems` on the platform and the wagon do not match a simple transfer at the end of docking. After a full load the wagon held 3126 at `TDS_None` and reached 3200 only about 28 s later, while driving. The loading platform's count dropped by more than the wagon gained. Test the transfer timing before relying on these counts.

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
  - **[?]** That the 15 s "or" timer let it leave is inferred, not tested. For a real "wait until full", set `IsDurationAndRule = true` with a short duration, and test it.
- A timetable written from code is shown correctly in the train window, and the player can edit it there.
- **[?]** `UFGNoneDescriptor` (`FGNoneDescriptor.h`) as a "nothing" filter: a stop without loading. Not tested yet.
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
- **[?]** While docking, the game pauses the platform's belts and pipes. This is suggested by the existence of the mod Uninterrupted Train Belts/Pipes, which turns that off. Still to be measured.
