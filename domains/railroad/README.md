# Railways (domain)

Part of the `satisfactory-modding` skill. Open this domain only when the mod deals with trains, timetables, stations, platforms, tracks, signals or routes. Markers: no marker = verified in practice, **[source]** = read from SML or game code, not tested, **[?]** = uncertain. Replace the parts in `<...>` with your own.

Most of this domain was first read from game headers (changelist 491125, later checked against 502094) and asset stubs. The parts without a marker were tested in the packaged game 502094 with SML 3.12.0 on a single player host: a test scenario wrote timetables from code and logged the train's delegates next to its state polled every 0.1 s. Check names against the current headers (see `patterns-and-pitfalls.md`).

| Topic | File |
|---|---|
| Where to get data (subsystem, stations, trains, platforms, cargo), events available without hooks | `domains/railroad/data-events.md` |
| Timetables, docking rules in practice, driving a train through its timetable | `domains/railroad/timetable-docking.md` |
| The game's route search, route graph and costs, what the autopilot does with a route | `domains/railroad/route-search.md` |
| Signals and track connections, how signals are placed, holding a train at a signal with hooks | `domains/railroad/signals.md` |
| Giving the autopilot a route of your own, push-pull trains, two-way single-track lines | `domains/railroad/own-routes.md` |
| Pitfalls | below |

New findings of this domain go to `learned/railroad.md`.

## Pitfalls

- **[source]** The name `FTrackGraph` is taken by a game struct (`FGRailroadSubsystem.h`). Custom track graph types must use a different name or a prefix.
- **[source]** Class names suggested by a chatbot, `AFGBuildableRailroadTrackConnection` and `AFGTrainHalt`, do not exist. The right ones are `UFGRailroadTrackConnectionComponent`, `AFGBuildableRailroadStation` and `AFGTrainStationIdentifier`. Always verify game class names in the headers.
- Solid-cargo belts keep running while a platform waits for its transfer condition in game 502094 (see `domains/railroad/timetable-docking.md`, "Docking rules in practice"), although the mod Uninterrupted Train Belts/Pipes suggests that they once paused for the whole docking. **[?]** Whether belts pause in the 27 s load/unload phase depends on the layout. Pipes on fluid platforms were measured: they stop in that phase and run while the platform waits (see `domains/railroad/timetable-docking.md`, "Docking rules in practice").
