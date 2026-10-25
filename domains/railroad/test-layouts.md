# Railways: test layouts and build lists

Part of the `satisfactory-modding` skill, railroad domain (index: `domains/railroad/README.md`). The general rule is in `references/test-automation.md`. Markers: no marker = verified in practice, **[source]** = read from SML or game code, not tested, **[?]** = uncertain. Replace the parts in `<...>` with your own.

- **A mechanism checked on one track layout is not verified.** For a mechanism that depends on the tracks, list the popular layouts where it may behave differently (passing loop, siding, junction, two-way single track, dead end, station with several platforms), test those that fit in the session, build the rest from code where the mod's test harness can insert layouts (`domains/railroad/layouts-from-code.md`), give the user a build list only for what code cannot build, and write the rest into the backlog with the session that will check it.
- **Build test layouts from code when the mod has a test harness that can insert them** (`domains/railroad/layouts-from-code.md`): write the layout as a description in Foundations, insert it, check it against the description, then dump the signals and compare before any scenario. A build list for the user is only for:
  - layouts that test the game's build limits (ramps, the tightest curves, stacked tracks, hologram refusals as the result; insertion from code does not check them);
  - elements the code cannot insert (refused in the log, no shape to copy);
  - a request from the user.
  The user looks once in the game, up close and from far away, at every kind of element the code has not inserted before, because a data dump does not show drawing errors (tracks spawned with a turned actor looked turned 90 degrees from far away while every dump matched).
- **Build lists for test layouts** (and descriptions of layouts built from code). Give lengths and gaps in Foundations (one Foundation is 8 m) with positions along the line, not in metres, and add a schematic for every rebuild, drawn and written to the standard below. A small change such as one more signal needs no schematic. Use the game's English names for buildings and ports. Check the signals against the placement rules in `domains/railroad/signals.md` instead of composing them from memory. After the build, first dump the signals from the save (type, direction, block error) and compare the dump with the list, and only then run the scenarios.

## Layout facts for build lists

- **The Railway build limits are fields of the track hologram, not the docs' numbers.** `AFGRailroadTrackHologram` (`Hologram/FGRailroadTrackHologram.h`: `mMinLength`, `mMaxLength`, `mMinBendRadius`, `mMaxGrade` in degrees, `mSnapDistance`), read by reflection from the class default object of `Holo_RailroadTrack_C` (the recipe descriptor's `UFGBuildDescriptor::GetHologramClass`). Game 513885: max grade 25°, min bend radius 15 m, max length 100 m per piece, snap distance 5 m; texts "Railroad Track is too steep!", "… turns too sharply!", "… is too long!", "… is too short!". So for build lists:
  - Ramps: Ramp 8 m x 1 m rises 7.1°, 8 m x 2 m 14.0° (both within), 8 m x 4 m 26.6° (too steep for track). Trains climb what a track can be built on (the docs' "nothing steeper than a 2 m ramp" is wrong): on humps of one Railway piece shaped as an S in the vertical, 14.0°, 20.6° and 24.2° at the steepest, the game's autopilot took an Electric Locomotive alone (300 t) and one with a Freight Car of 3200 iron ore (330 t) up every slope in 7.1–7.9 s, slowing only from about 20 to 18.3–19.6 m/s, 2 runs, 6 of 6 lanes. `UFGRailroadVehicleMovementComponent::GetTrackGrade` is a rise-over-run ratio, not degrees (0.24 / 0.36 / 0.42 there). Evidence: `<scenario> CLIMB <station>: 2 vehicles, 1 Freight Cars loaded with 3200 iron ore, mass 330 t, the top 9.6 m above the start` and the arrival at the top in both runs. **[?]** Not tested: a start from standstill on the slope, longer trains, slopes longer than 4 Foundations.
  - Curves: a 90° curve in a 2x2 Foundation square (16 m radius) is within the 15 m limit; the docs' "smallest curve 3x3" is a player's rule. **[?]** Not built.
  - Stacked rails: a track keeps one clearance box free, `CT_Soft`, 0–1 m above the rail and 2.4 m wide, so the game has no 12 m rule; the docs' three 4 m Foundations (12 m) is a margin for the train's height. **[?]** Whether a Foundation hologram over a track is refused, and the train's real height, not tried.
  - Evidence: `<scenario> LIMITS Holo_RailroadTrack_C mMaxGrade = 25.00`, `mMinBendRadius = 1500.00`, `mMaxLength = 10000.00`, `ramp 8 m x 4 m: 26.57 degrees, max grade 25.00: too steep`, `track clearance (…): type CT_Soft, from 0.00 m to 1.00 m above the rail, 2.40 m wide`, `1 clearance boxes`. (2026-10-25, game 513885, SML 3.12.0)
- **[?]** Facts from the docs signal guide (docs.ficsit.app), not tested: 4x4 Foundation curves recommended; a block counts as occupied while any part of a train, the tail included, is inside it; trains look one block ahead and stop at the signal; the platform order must match the wagon order, and Empty Platforms fill the gaps. The guide counts in normal Foundations (8 m x 8 m, as the build lists in this file); "4-meter foundation" there means a foundation 4 m high. (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)

## Standard for schematics and build lists

One standard for every layout, so the lists and drawings of different sessions read the same. The template to copy is `domains/railroad/schematic-template.svg`: change its content and translate its texts into the user's language, never change its legend's structure.

**Schematic (SVG)**
1. **Canvas:** `viewBox="0 0 900 H"`, `width="900" height="H"`, `font-family="sans-serif" font-size="12"`, background `<rect fill="#fafafa">`. Attributes only, no CSS classes, no `var()`. The height is free; wider is not, the drawing has to fit in a chat window.
2. **Text:** every text of the drawing, the legend and the title included, in the language the user talks to you in, with its diacritics (the diagram widget and the file take them as they are). The template is in English: translate its texts, keep its layout. A bold 15 px title `<layout>: <what it shows>` and under it one line about the scale.
3. **Scale:** along the line always **1 Foundation = 10 px** (8 m), with a position axis in Foundations under the drawing (ticks every 20), counted from a named building. Across the line not to scale, and the scale line says so. A drawing entirely out of scale (a network of loops) has "(not to scale)" in the title and the lengths in the list.
4. **Colours, the only ones allowed:** existing track `#333` solid 2 px; **new track `#333` dashed `6 4`**; to dismantle or correct `#c0392b` solid; Path Signal a 10 px square `#7b3fa0`; Block Signal a circle r=5 `#1f9e8e`; Train Station a rectangle `#bbb` with a `#333` outline; Freight Platform `#eee` with a `#333` outline; train `#e8c14a`; text `#222`, helper text `#555`, axis `#999`.
5. **Station:** the building (30 px) with the platform (40 px) behind it in the driving direction (the lead locomotive stops at the building, the wagons stand behind it on the platforms), its name in bold above. A station without a platform is the building alone.
6. **Direction:** a chevron `>` on one-way tracks (at least one per track); two-way tracks have no arrows and the word "two-way".
7. **Labels:** signals **A, B, C…** (a 14 px letter above the symbol), switches **J1, J2…**, the same letters in the build list. Two signals at one joint (a pair) are `A1`/`A2`.
8. **Legend:** always the same block at the bottom, copied from the template with its texts translated into the user's language (the names of the game's buildings, Train Station and Freight Platform, Path Signal and Block Signal, stay as the game shows them in that language): Train Station, Freight Platform, Path Signal, Block Signal, existing track, new track, to dismantle, train, driving direction. Items the drawing does not use stay.
9. **Before it goes to the user:** check that no label overlaps another label, a track or a signal (estimate each text box at about 6.5 px per character at 12 px and 7.5 px at 14 px, anchored as written; move or shorten a label when two boxes touch; widen the canvas rather than squeeze labels), open the saved `.svg` in the browser pane and look at it, and only then show the widget in the chat.
10. **Files:** `schematic_<layout>.svg` and `build_list_<layout>.md` side by side. The drawing is shown in the chat with the inline diagram widget and the same file is saved. A text or ASCII drawing does not count.
11. **A drawing read from the game** (a save's layout) uses the same style; its scale follows from the data and is written in the scale line.

**Build list (Markdown):** the sections in this order, **points numbered in one run 1–N through the whole file** so that "point 7" is unambiguous. Sections without content are left out, the order stays.

```
# Build list: `<layout>`

Starting point: save `<…>`. Save the result as `<layout>`.
Schematic: `schematic_<layout>.svg` (<scale>). Lengths in Foundations (1 = 8 m), positions along the line from <building>.
What it checks: <one sentence: which backlog item or test>.

## 1. Tracks and switches     (J1, J2… as on the schematic)
## 2. Stations and platforms  (name, mode Load/Unload, direction)
## 3. Signals                 (A, B, C… as on the schematic; type, track, direction; checked against domains/railroad/signals.md)
## 4. Trains                  (consist, place, autopilot)
## 5. After the build         (save as…, copy of the save, what the session does: signal dump, then the scenario)
```

Every signal in the list has its letter on the schematic and every letter on the schematic is in the list; checking this is the last step before the list goes out.
