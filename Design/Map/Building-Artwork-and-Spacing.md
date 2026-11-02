# Building artwork and spacing

Created 30 October 2026 for the native Mac editor. These are original AI-generated fan illustrations in an Animal Crossing-inspired style, made with the built-in imagegen tool. They are not official Nintendo/NHSE artwork. The existing inventory icons retain their separate attribution.

The 14 transparent PNGs are bundled as `building-icon-*.png` in `ACNH-Save-Editor/macOS/Sources/ACNHMac/Resources/`. Full prompts are in `building-icon-prompts.json`. Each category has its own icon; the eight player slots and ten villager slots share their respective house icon. No resident portraits are used.

## Placement dimensions

All measurements below are full terrain tiles. Two saved building-coordinate steps equal one tile. The solid outline is a placement-plot size guide, not the rendered building's physical collision shape. A dashed outline around the selected plot extends one tile in every direction as a spacing aid. This margin is drawn once; two neighboring buildings do not each require an additional independent tile of clearance.

| Building | Plot width × depth | Status |
|---|---|---|
| Player house | 5 × 4 | Measured community plot dimensions |
| Villager house | 4 × 4 | Includes front plot row, unlike the smaller visible model |
| Nook's Cranny | 7 × 4 | Measured plot |
| Resident Services building | 6 × 4 | Building only; plaza is separate |
| Plaza | 12 × 10 | Upper-left anchor, edited separately from Resident Services |
| Museum | 7 × 4 | Measured plot |
| Airport | Not shown | Terminal, dock and acre boundaries need separate verification |
| Resident Services tent | Not shown | Tent plot not independently verified |
| Able Sisters | 5 × 4 | Measured plot |
| Campsite | 4 × 4 | Measured plot |
| Straight bridge | 4 × (water span + 2) | Water span 3/4/5 comes from saved NHSE subtype; includes bank ends |
| Diagonal bridge | Not shown | Needs rotated collision geometry and verified anchor |
| Incline | 2 × 4, swapped for quarter turns | Includes upper landing |
| Redd's trawler | Not shown | Vessel and shoreline connection not verified |
| Studio | Not shown | Harv's Island structure, plot not verified |
| Hotel | Not shown | 3.0 structure, plot not verified |

## Accuracy boundary

**This does not complete exact spacing for every building.** Existing NHSE marker coordinates are preserved. Size guides are centered on those markers; the per-model offset between the saved anchor, placement plot, entrance and physical collision mask has not been verified in game. The inspector explicitly calls out this limitation. Do not interpret an outline or lack of overlap as a valid in-game placement.

Infrastructure artwork uses the editor's existing quarter-turn angle convention; diagonal bridge models add a 45-degree illustration turn. The correspondence of these illustration angles and per-model anchors to real game geometry still needs in-game validation. Unknown bridge types and diagonal bridges deliberately receive no invented rectangle. The icon's size is illustrative when a measured plot is unavailable.

The plot guide does not alter saves, enforce collisions, repair bridge connections, or automatically move buildings. Bridge subtype bytes are read for visualization and remain unchanged when positions are edited. The Bridge style selector explicitly edits the subtype and matching material while preserving geometry. No inaccurate generic 2 × 2 footprint is advertised as exact.

## Sources

- [First-hand community plot measurements](https://www.reddit.com/r/ac_newhorizons/comments/fy39xu/buildingroom_dimensions_and_layout_tips/): plot sizes, one-tile separation, 6 × 4 Resident Services building, 12 × 10 plaza, straight bridge spans and incline size.
- [Happy Island Designer structure definitions](https://github.com/eugeneration/HappyIslandDesigner/blob/master/app/tools/structure.ts) and [amenities](https://github.com/eugeneration/HappyIslandDesigner/blob/master/app/tools/amenities.ts): corroborating planner dimensions. No artwork or implementation copied from this project.
- [NHSE Building record](https://github.com/kwsch/NHSE/blob/master/NHSE.Core/Structures/Building/Building.cs): subtype at byte 8; coordinates at bytes 2 and 4; angle at byte 6.
- [NHSE bridge models](https://github.com/kwsch/NHSE/blob/master/NHSE.Core/Structures/Building/BridgeType.cs): explicit mapping of subtype IDs to 03/04/05 water spans and diagonal variants.
- [Datamined bridge table](https://wuffs.org/acnh/bcsv_160/html/StructureBridgeParam.html): corroborates the bridge model suffixes. Historical 1.6 data; not used to claim new 3.0 building dimensions.

## Verification

Native release build and signature verification passed. All 26 selected tests passed (building dimensions/subtypes, map coordinates, and island editing/export). The native example map was visually checked with all 14 categories, a selected house and its plot/spacing guides, and a selected hotel correctly labeled as having unverified dimensions. All PNGs have alpha channels; two generated originals have negligible 1/255 corner alpha. App icons are 256-pixel derivatives; full-resolution originals remain in `Icons/`.

## Plaza save support

The plaza is listed in the Buildings selector but is not inserted into the 46 saved building records. Original NHSE revision `cb0745415945776f73375bf0a434a8babf059307` stores `EventPlazaLeftUpX` and `EventPlazaLeftUpZ` as two little-endian uint32 values at `OutsideField + 9*8*2 + 4` and `+8`. For the supported 3.0 save layout these are absolute offsets `0x32FB40` and `0x32FB44`. The UI labels Z as Y, matching NHSE, and accepts 0–1024, matching its numeric controls. No rotation field exists. Moving the plaza leaves Resident Services and all building records untouched.

The map shows a 12 × 10 tile rectangle from the saved upper-left anchor, using the half-tile map coordinate scale. Buildings take precedence when selecting overlapping markers; the Plaza selector always remains available. The rectangle is a guide, with in-game anchor alignment still requiring verification. It does not paint terrain or relocate objects. Positions outside the visible island remain editable through the inspector.

Upstream references: [MainSave plaza fields](https://github.com/kwsch/NHSE/blob/cb0745415945776f73375bf0a434a8babf059307/NHSE.Core/Save/Files/MainSave.cs), [FieldItemEditor controls](https://github.com/kwsch/NHSE/blob/cb0745415945776f73375bf0a434a8babf059307/NHSE.WinForms/Subforms/Map/FieldItemEditor.cs), and [control limits](https://github.com/kwsch/NHSE/blob/cb0745415945776f73375bf0a434a8babf059307/NHSE.WinForms/Subforms/Map/FieldItemEditor.Designer.cs).

## Bridge style editing

`BridgeType.swift` maps NHSE's 54 defined bridge models to nine material families and six geometries (three straight spans and three diagonal model lengths). The eight standard families are offered for style changes; NHSE's reserved family is shown only when already present. Undefined types 50/51 and unknown models remain readable but cannot be restyled. A style change writes only `Building.Type` (record +8, uint16) and `Building.TypeArg` (+10, byte material), preserving position, angle, flags, padding, unique ID, and other records. Moving a bridge alone does not normalize its material. The existing generic bridge artwork remains illustrative; the map guide follows the edited model.

References at the same NHSE revision: [BridgeType](https://github.com/kwsch/NHSE/blob/cb0745415945776f73375bf0a434a8babf059307/NHSE.Core/Structures/Building/BridgeType.cs), [BridgeMaterial](https://github.com/kwsch/NHSE/blob/cb0745415945776f73375bf0a434a8babf059307/NHSE.Core/Structures/Building/BridgeMaterial.cs), and [Building record](https://github.com/kwsch/NHSE/blob/cb0745415945776f73375bf0a434a8babf059307/NHSE.Core/Structures/Building/Building.cs).
