# Railways (domain)

Part of the `satisfactory-modding` skill. Open this domain only when the mod deals with trains, timetables, stations, platforms, tracks, signals or routes. Markers: no marker = verified in practice, **[source]** = read from SML or game code, not tested, **[?]** = uncertain. Replace the parts in `<...>` with your own.

Most of this domain was first read from game headers (changelist 491125, later checked against 502094) and asset stubs. The parts without a marker were tested in the packaged game 502094 with SML 3.12.0 on a single player host: a test scenario wrote timetables from code and logged the train's delegates next to its state polled every 0.1 s. Check names against the current headers (see `patterns-and-pitfalls.md`).

| Topic | File |
|---|---|
| Where to get data (subsystem, stations, trains, platforms, cargo), events available without hooks | `domains/railroad/data-events.md` |
| Timetables, docking rules in practice | `domains/railroad/timetable-docking.md` |
| Driving a train through its timetable (stops, errors, held trains) | `domains/railroad/driving-timetable.md` |
| The game's route search, route graph and costs | `domains/railroad/route-search.md` |
| What the autopilot does with a route | `domains/railroad/route-autopilot.md` |
| Signals and track connections | `domains/railroad/signals.md` |
| How signals are placed and what the game checks (blocks, valid placement, exits) | `domains/railroad/signal-placement.md` |
| Hook targets in the railway signalling, holding a train at a signal with hooks | `domains/railroad/signal-hooks.md` |
| Giving the autopilot a route of your own, hooking the route search | `domains/railroad/own-routes.md` |
| Routes of your own in use: parking, cutting, switching under a moving train, cost routes | `domains/railroad/own-routes-in-use.md` |
| Push-pull trains, two-way single-track lines | `domains/railroad/push-pull-lines.md` |
| The game's railway windows (station, signal, locomotive), adding a tab to the station window | `domains/railroad/ui-windows.md` |
| Inserting a railway layout from code without the build gun (tracks, switches, stations, signals, vehicles) | `domains/railroad/layouts-from-code.md` |
| Test layouts: popular track layouts to check, the standard for build lists and schematics (template: `domains/railroad/schematic-template.svg`) | `domains/railroad/test-layouts.md` |
| Pitfalls | below |

New findings of this domain go to `learned/railroad.md`.

**[?]** Open-source mods to read for rail work (listed on docs.ficsit.app; sources not opened): Better Train Collision (replaces the locomotive collision at runtime, Blueprint only); Cable Choices+ (holograms that snap to spline rails, a Rail Power Box that reuses the vanilla UI). The docs page predates the Actor Mixin and Blueprint hook systems: see `references/tools.md`. (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)

## Pitfalls

- **Other mods that drive trains.** Dynamic Train Routes (mod reference `DynamicTrainRoutes`, tested 1.3.2) and `DynamicTimeTable` (tested 1.4.2) write timetables and routes themselves. A mod that also writes them can detect them at start with `UModLoadingLibrary::IsModLoaded` (`references/sml-api.md`) and stand aside: with both loaded, the tested mod logged `<Mod> is inactive: DynamicTrainRoutes, DynamicTimeTable loaded`, ran 0 cycles in 5 s and refused a change from its window, in 2 runs. (2026-10-04, game 502094, SML 3.12.0)
- **[source]** Class names suggested by a chatbot, `AFGBuildableRailroadTrackConnection` and `AFGTrainHalt`, do not exist. The right ones are `UFGRailroadTrackConnectionComponent`, `AFGBuildableRailroadStation` and `AFGTrainStationIdentifier`. Always verify game class names in the headers.
- Solid-cargo belts and pipes keep running while a platform waits for its transfer condition and stand still in its 27 s load/unload phase (tested in game 513885 for belts, 502094 for pipes; the mod Uninterrupted Train Belts/Pipes changes that, see `domains/railroad/timetable-docking.md`, "Docking rules in practice").
- **A track hologram's free end takes its direction from where the player looks.** A track started on a free track end and ended on the floor (no end to snap to) gets its end tangent from the player's view, so a line of straight pieces built from code with the player looking down came out as a zigzag (the user's screenshot; later pieces refused with `FGCDTrackTrunToSharp` "Railroad Track turns too sharply!"). Turning the player to look along the piece before each click (from behind its start, along its direction) made every piece straight and joined. Evidence: <scenario>, 8 pieces with the lengths of the description in the layout dump, no "too sharply". (2026-10-25, game 513885, SML 3.12.0)
- **[?] A freight wagon placed after a Buffer Stop at the end of its platform's track is refused** with `FGCDNotEnoughSpaceOnTrack` "Not enough space on track!", the locomotive on the station in front of it placed fine; in a hand-built copy of the same layout the wagon stands there with the Buffer Stop. Not checked yet: placing the train before the Buffer Stop. (2026-10-25, game 513885, SML 3.12.0)
