# Animal Crossing Save Editor for Mac

Make your island feel more like you. Edit your Animal Crossing: New Horizons save on your Mac: find items for your pockets and home storage, adjust Bells and Nook Miles, customize your residents, and rearrange your island map.

Browse an example island to explore the app, or open your own exported save folder. Review your changes before saving, with automatic backups and restore tools to help you keep your original island.

Built for Mac, with a familiar interface and no extra software to install.

Current Mac version: **2.1**. Requires **macOS 14 or later**. Universal builds support Apple silicon and Intel. Supported save revisions: **ACNH 3.0.0–3.0.3**.

## Download and install

**[Download for Mac (.dmg)](https://github.com/marcsphd/Animal-Crossing-Save-Editor-for-Mac/releases/latest/download/NHSE-for-Mac.dmg)** · [ZIP download](https://github.com/marcsphd/Animal-Crossing-Save-Editor-for-Mac/releases/latest/download/NHSE-for-Mac.zip) · [All releases](https://github.com/marcsphd/Animal-Crossing-Save-Editor-for-Mac/releases)

1. Download and open the DMG.
2. Drag **ACNH Save Editor.app** onto the **Applications** shortcut.
3. Eject the disk image, then open the app from **Applications**.

Requires macOS 14 or later. One download supports both Apple silicon and Intel. No Xcode, Homebrew, terminal commands, or separate runtime is needed to use the app.

**First launch:** this build is ad-hoc signed and has not been notarized by Apple. If macOS blocks it and you trust this download, open **System Settings → Privacy & Security → Open Anyway** after attempting to launch it. See [Apple's first-launch instructions](https://support.apple.com/102445). A launch without this approval requires Developer ID signing and notarization, which are not yet available for this project.

## New in 2.1

- Select **Plaza** in the map’s Buildings tab to move it independently of Resident Services, with an upper-left anchor and size guide.
- Change existing bridges between eight styles while preserving their span, straight/diagonal geometry, position, and rotation. The matching bridge material updates automatically.
- Plaza and bridge-style edits support review, undo/redo, revert, save, and export.

## Also included from 2.0

- Recognizable outdoor objects using bundled NHSE inventory artwork, plus 14 illustrated building categories and size guides where dimensions are verified.
- Centered, continuous pinch zoom from 100% to 500%, with five slider presets and sharp artwork at high zoom.
- Arrow-key tile selection without scrolling the map; item-only copy, paste, delete, and undo with complete object footprints.
- Default-on **Snap to tiles** beside zoom, with an information popover and on-screen keyboard guidance.

## What can you change?

- Player settings: primary resident name and birthday.
- Island settings: island name, hemisphere, airport, weather, fruit, and flowers.
- Pockets and home storage with bundled item icons, item search, quantities, and multiple-slot placement. Shift-click selects a range; Command-click adds or removes individual slots.
- Island map editing with NHSE object artwork, distinct building icons and size guides, continuous centered pinch zoom, keyboard navigation, and item copy/paste/delete.
- Animal-villager identities, personality, catchphrases, moving-out state, and basic friendship.
- Money editing, saved pocket loadouts, undo/redo, change review, full-save exports, verified backups, and restore.

## Before you start

You need an exported Animal Crossing: New Horizons save folder. This app edits that folder; you will need a separate way to export your save and import it back into your game.

Editing currently supports the primary player. Some features, including house interiors, DIY recipes, and custom designs, are not available yet. See the detailed comparison below for the full list.

Keep a separate copy of your original save and close the game before importing changes. Importing an edited save back into the game has not yet been tested for this release.

<details>
<summary>Detailed feature comparison with NHSE</summary>

### Feature comparison

This compares NHSE with **Animal Crossing Save Editor for Mac 2.1**. “Limited” means the Mac app implements only the scope described below.

| Feature | NHSE | Animal Crossing Save Editor for Mac |
| --- | --- | --- |
| Native desktop interface | Windows / .NET Windows Forms | macOS 14+ / SwiftUI; Apple silicon and Intel |
| Choose which human resident to edit | Select any resident present in the save | **Limited:** primary resident only |
| Player name and birthday | Available | Available for the primary resident |
| Bells, Nook Miles, and house loan | Available | Available; wallet, bank, current Miles, and loan |
| Island name, hemisphere, airport, weather, fruit, and flowers | Available | Available for the supported settings |
| Pocket item editing | Available | Available for all saved unlocked slots, up to 40 |
| Home storage editing | Available | Available for saved unlocked slots, with search, paging, and quantity editing |
| Item icons, search, and stack quantities | Available | Available; bundled menu icons and item-specific stack limits |
| Change pocket and storage capacity | Editable capacity counters | **Not implemented:** existing capacity is preserved |
| Advanced item variations and record fields | Item record editor | **Limited:** placement uses default variations; storage quantity changes preserve other details |
| Inventory-file import and export | Available | **Limited:** local pocket loadouts; no NHSE inventory-file import/export |
| Terrain, elevation, and paths | Map and terrain editors | **Limited:** schematic map, brushes, tile models, elevation, and rotation; manual edge/adjacency checking |
| Shoreline and base-acre editing | Available | **Not implemented:** existing shoreline and acres are preserved |
| Outdoor item placement and removal | Available | Available, including both item layers, linked item footprints, keyboard copy/paste/delete, and tile snapping |
| Building positions | Building editor | **Limited:** distinct building artwork and available size guides; move and rotate existing buildings; collision and bridge/incline connections need manual checking |
| Plaza position | Separate plaza coordinates | Available in the Buildings tab; moves independently of Resident Services |
| Bridge styles | Bridge model and material fields | Eight standard styles; preserves span and geometry, and updates matching material |
| Animal-villager identity and basic details | Available | **Limited:** existing villagers; identity, personality, catchphrase, moving-out state, and basic friendship |
| Villager-file import/export, flags, and detailed memories | Available | **Not implemented:** no full villager/preset replacement or advanced flag/memory editor |
| Player and villager house interiors | House and room editors | **Not implemented:** existing interiors are preserved |
| DIY recipes | Recipe editor | **Not implemented** |
| Reactions | Reaction editor | **Not implemented** |
| Progression flags and achievements | Player/island flags and achievement editors | **Not implemented** |
| Custom designs, PRO designs, and island flag design | Design editors | **Not implemented** |
| Museum donations | Museum editor | **Not implemented** |
| Turnip prices, visitors, and campsite | Dedicated editing tools | **Not implemented** |
| Recycle bin and mail | Recycle-bin and post-box editors | **Not implemented** |
| Live RAM editing / sys-botbase tools | Available | **Not implemented:** exported save folders only |

Checked on **29 October 2026** against NHSE revision [`cb07454`](https://github.com/kwsch/NHSE/tree/cb0745415945776f73375bf0a434a8babf059307), including its [main editor](https://github.com/kwsch/NHSE/blob/cb0745415945776f73375bf0a434a8babf059307/NHSE.WinForms/Editor.cs), [map editor](https://github.com/kwsch/NHSE/blob/cb0745415945776f73375bf0a434a8babf059307/NHSE.WinForms/Subforms/Map/FieldItemEditor.cs), [inventory editor](https://github.com/kwsch/NHSE/blob/cb0745415945776f73375bf0a434a8babf059307/NHSE.WinForms/Subforms/PlayerItemEditor.cs), and [villager editor](https://github.com/kwsch/NHSE/blob/cb0745415945776f73375bf0a434a8babf059307/NHSE.WinForms/Controls/VillagerEditor.cs). Mac details are documented in the [Mac guide](ACNH-Save-Editor/macOS/README.md).

This is a partial NHSE port. Read the [Mac guide](ACNH-Save-Editor/macOS/README.md) for supported settings and limitations. Edits target the primary resident; unlocked inventory capacity and locked records are preserved.


</details>

## Build and test

The Mac app uses Swift Package Manager and Xcode's Swift toolchain. No third-party runtime is required.

```sh
cd ACNH-Save-Editor/macOS
swift test --scratch-path /private/tmp/NHSE-Mac-Tests --disable-sandbox
ACNH_BUILD_SCRATCH=/private/tmp/NHSE-Mac-Build ACNH_BUILD_OUTPUT=/private/tmp/NHSE-Mac-App ./scripts/build-app.sh
open "/private/tmp/NHSE-Mac-App/ACNH Save Editor.app"
```

Using a local build folder avoids file-provider metadata interfering with app signing in cloud-synced workspaces. Builds are ad-hoc signed, not notarized.

## Save files and validation

Open a complete exported save folder containing `main.dat`, `mainHeader.dat`, and the resident files. Review your draft, then export an edited copy or save with an automatic backup. Keep a separate original backup and import saves with the game closed.

**80 automated tests passed** for version 2.0, alongside native interface and independent export checks. See the [validation report](ACNH-Save-Editor/macOS/VALIDATION.md). Importing the edited save back into the game remains untested.

Personal save files, build caches, and packaged application bundles are excluded from this repository, except for the owner-contributed Yolo save included as the default example island.

## Source and credits

[NHSE](https://github.com/kwsch/NHSE) is the primary reference for save structures, player and island settings, map and villager editing, home storage, item metadata, and bundled inventory artwork. [ACNH-Save-Editor](https://github.com/cbreezy210/ACNH-Save-Editor) provided the original foundation and reused encryption and hashing routines. The Mac interface and save-management workflows are implemented natively in SwiftUI.

- [Native Mac source and guide](ACNH-Save-Editor/macOS/README.md)
- [Original Switch source](ACNH-Save-Editor/README.md)
- [Third-party notices and provenance](ACNH-Save-Editor/macOS/THIRD-PARTY-NOTICES.md)

The native Mac port is **GPL-3.0**; see [LICENSE](LICENSE). Original MIT portions retain their [upstream license](ACNH-Save-Editor/LICENSE). Nintendo artwork and trademarks belong to their respective rights holders. This project is unaffiliated with Nintendo and is not an official NHSE release.
