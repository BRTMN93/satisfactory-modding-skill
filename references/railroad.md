# Railways

Part of the `satisfactory-modding` skill. Markers: no marker = verified in practice, **[source]** = read from SML or game code, not tested, **[?]** = uncertain. Replace the parts in `<...>` with your own.

Everything here was read from game headers (changelist 491125) and asset stubs; the game was 502094, SML 3.12.0. None of it has been run in the game yet. The headers were older than the game, so check names against the current headers (see `patterns-and-pitfalls.md`).

## Where to get data

- **[source]** `AFGRailroadSubsystem` (`FGRailroadSubsystem.h`): `GetAllTrains`, `GetAllTrainStations`. Connected track networks have an identifier that `GetTrackGraphID` returns on a track, a platform and a vehicle.
- **[source]** `AFGTrain` (`FGTrain.h`): `GetTimeTable`, `NewTimeTable`, `SetSelfDrivingEnabled`, `IsPlayerDriven`, `IsDerailed`. Public fields `mConsistData` (vehicles, length, maximum speed, `MaxBrakeDeceleration`) and `mAtcData` (driving supervision data, including the autopilot's current route).
- **[source]** `AFGBuildableRailroadTrack`: `GetLength`, `GetConnection(0/1)`, `GetVehicles`, `GetSignalBlock`. `UFGRailroadTrackConnectionComponent` (`FGRailroadTrackConnectionComponent.h`): connections, switch position, signals, station, `GetSignalBlock`.
- **[source]** `AFGBuildableRailroadStation`: `GetStationIdentifier`, `GetStationOutputConnection`. To walk from a station along its platforms, go through `UFGTrainPlatformConnection` (`GetConnectedTo`, `GetPlatformOwner`).
- **[source]** `AFGBuildableTrainPlatformCargo`: `GetInventory`, `GetIsInLoadMode`, `GetDockingStatus`. The fields `mFreightCargoType` and `mIsFullUnload` are protected, so they need AccessTransformers.
- **[source]** A freight wagon is a single class, `AFGFreightWagon`, with `GetFreightInventory`. The cargo kind is `EFreightCargoType` (none, solid, liquid). There are no separate wagons for liquids.

## Events available without hooks

- **[source]** `AFGTrain`: delegates `mOnDockingStateChanged`, `mOnSelfDrivingErrorChanged`, `mOnTrainStatusChanged`.
- **[source]** `ESelfDrivingLocomotiveError` includes, among others, `SDLE_NoPower`, `SDLE_NoPath`, `SDLE_StationUnreachable`, `SDLE_LongWaitAtSignal`.
- **[source]** `AFGBuildableRailroadSignal`: delegate `mOnAspectChangedDelegate`, `IsPathSignal`. A signal block has `OnBlockChanged`.

## Timetable and docking

- **[source]** `AFGRailroadTimeTable` (`FGRailroadTimeTable.h`): `SetStops` (returns `bool`), `SetCurrentStop`, `AddStop`, `GetStops`. The limit is 100 stops (`MAX_STOPS`).
- **[source]** A stop is an `FTimeTableStop`: a station (`AFGTrainStationIdentifier`) and docking rules.
- **[source]** `FTrainDockingRuleSet` (`FGTrainDockingRules.h`), all fields are saved in the save game:
  - `DockingDefinition`: `ETrainDockingDefinition::TDD_LoadUnloadOnce` (default) or `TDD_FullyLoadUnload`,
  - `DockForDuration` (default 15 s) and `IsDurationAndRule`,
  - `IgnoreFullLoadUnloadIfTransferBlockedByFilters`,
  - `LoadFilterDescriptors` and `UnloadFilterDescriptors`: lists of item classes.
- **[?]** `UFGNoneDescriptor` (`FGNoneDescriptor.h`) as a "nothing" filter: a stop without loading. The behaviour still needs to be tested. Not tested yet.
- **[source]** FicsIt-Networks exposes the same timetable API in Lua, so controlling a train through its timetable has a precedent.

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
