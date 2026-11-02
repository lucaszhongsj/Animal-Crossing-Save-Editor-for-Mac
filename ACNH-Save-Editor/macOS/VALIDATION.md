# Validation — Mac version 1.4.4 — 29 October 2026

## App icon in Overview — 1.4.4

- The loaded-save and preview Overview headers show the current application icon at 80 points next to the heading. The welcome screen uses the same icon at 128 points. Both read NSApplication.applicationIconImage, so an alternate-icon build displays its own bundled icon without a duplicate PNG resource.
- Universal arm64/x86_64 compilation and strict ad-hoc signing completed. The bundled transparent ICNS is unchanged from v1.4.3. This cosmetic change does not alter save-editing logic; the last full automated save-editor run remains the 55-test v1.4.1 suite below.

# Validation — Mac version 1.4.3 — 29 October 2026

## Transparent Dock icon — 1.4.3

- Replaced the opaque original Inventory Tiles PNG with its transparent-background preparation from the built-in image generator. The chosen design remains concept 6; the original concept and saved concept 1 alternate are preserved. ICON-PROVENANCE.json records original and prepared hashes plus the preparation prompt.
- Added scripts/verify-icon-transparency.swift as a read-only asset regression check. The old opaque concept fails the check; the corrected source passes. Decoded the generated ICNS with iconutil and verified all ten representations, from 16 through 1024 pixels, have transparent exterior corners and opaque centers. The checker requires alpha transparency, preventing the original opaque white canvas from returning.
- Visually inspected the actual decoded 64-pixel ICNS representation against a Dock-colored background beside the old artwork. The white frame is absent from the corrected icon.
- Built universal arm64/x86_64 version 1.4.3 (build 12), verified that its bundled icon exactly matches the corrected ICNS, and checked the app's strict ad-hoc signature. No save-editor logic or save data changed. The last full automated save-editor suite is the 55-test v1.4.1 run documented below.
- Public DMG and ZIP downloads include the corrected app. The app remains ad-hoc signed and not notarized; the existing first-launch guidance still applies.

# Validation — Mac version 1.4.2 — 29 October 2026

## App icon selection — 1.4.2

- Inventory Tiles (concept 6) is the default app icon. Its PNG is byte-identical to the selected original generated concept. Leaf & Pencil (concept 1) is preserved unchanged as the alternate PNG, with a matching ICNS file and a separate test-app package.
- Both ICNS files contain standard macOS representations through 1024 pixels, including Retina sizes. Container lengths and representation records were checked. Icon generation uses the system sips and iconutil tools for format conversion and resizing; no background cleanup or artwork changes are included in the delivered icons. The generation prompts and original checksums are recorded in ICON-PROVENANCE.json.
- The build script accepts ACNH_APP_ICON to choose the alternate without replacing AppIcon.icns. Built universal arm64/x86_64 default and alternate apps, verified each bundled icon against its intended source, and confirmed both have version 1.4.2 (build 11). Strict ad-hoc signature verification passed for both packages.
- This cosmetic release does not change save-editing logic. The last full automated suite remains the 55-test v1.4.1 run documented below. No personal saves were opened or modified for icon verification. Intel was compiled but not run; Switch import remains untested.

# Validation — Mac version 1.4.1 — 28 October 2026

## Multiple-slot inventory editing — 1.4.1

- Pockets and Storage use ordinary Mac selection: a plain click selects one slot, Shift-click selects a range, and Command-click toggles individual slots. Selected checkmarks, a count, and a short text hint explain the behavior. There are no selection toggles or Select All/Empty buttons. Range selection follows visible order.
- The shared item library places the chosen item and per-slot quantity in all selected destinations in one draft operation. It displays the number of occupied destinations that will be replaced. Bulk clearing and placement each use a single undo step. Storage selection is intersected with the visible page and filtered results, preventing hidden destinations from being edited.
- **55 automated tests passed**, zero failures. New tests cover selection/toggle/range behavior, paging/filter reconciliation, atomic batch validation, 30-pocket and 9,000-storage boundaries, and combined batch export with exact decrypted-byte comparison. Locked records, capacity counters, unselected slots, headers, main.dat, and unrelated data remain intact.
- Native UI QA on a generated save: placed gold nugget stacks of two into pockets 2, 3, and 5; verified one-step undo, redo, clear, and undo-clear. Filled thirty slots on the final storage page with stacks of two and verified one-step undo and redo. Paging/filtering removed hidden selections and disabled placement until a new selection was made. Review listed exactly 33 changed records.
- Exported that draft through the native save dialog to a separate QA folder. Independent Python/OpenSSL decryption and Murmur3 verification confirmed exactly three pocket records and thirty storage records plus the required checksums changed; every other byte and sibling file was preserved. The original user save was not opened or changed for these checks.
- Native modifier checks confirmed Command-click adds a destination and Shift-click selects a contiguous range. Modifier keys are read from the triggering event. QA used a separate app identifier to avoid interacting with the user's running editor. The final simplified interface was rechecked after removing selection controls.
- Universal arm64/x86_64 build and strict ad-hoc signature verification passed. Intel was compiled but not run. No Switch/game import round trip was performed. Build and packaging used local temporary folders after iCloud file hydration initially timed out. No personal saves are included in the release archives.

# Validation — Mac version 1.4.0 — 28 October 2026

- Native SwiftUI `.app`, macOS 14+, universal **arm64 and x86_64** executable.
- Ad-hoc signature verified. Not Developer ID signed or notarized.
- **51 automated tests passed**: 14 save-engine tests, 16 map/villager tests, 5 canvas-coordinate regression tests, 6 player/island settings tests, 5 pocket-capacity/loadout tests, and 5 home-storage tests. Zero failures.

## Native home Storage tab — 1.4.0

- Reads the primary resident's saved home-storage capacity at 0x496AC and its eight-byte item records starting at 0x37D6C, following NHSE's Personal.ItemChest and PersonalOffsets30. Supports zero through 9,000 unlocked records; invalid capacities are rejected. Locked records and capacity counters remain unchanged.
- New sidebar tab provides full-color bundled icons, stored-item search by name/hex, occupied-only filtering, fifty-slot pages, first/last page controls, and Find Empty Slot. A pinned inspector supports removing items and updating stack quantities; the existing item library adds/replaces records in the selected storage slot. Quantity-only updates preserve all other record bytes. Paging/filtering clears a hidden selection so placement cannot silently target a different page. No inventory-file import/export was added.
- Storage shares the existing draft, undo/redo, review, whole-save export, save/backup, restore, and rollback flows, and has its own Revert Storage Changes action. Save validation rejects resized arrays, malformed records, and item extension records before a destination is created.
- Five new tests cover literal offsets; 0/80/5,000/9,000-slot reads and no-op byte identity; add/replace/remove/quantity changes; exact decrypted-byte preservation including locked records and capacity; the last physical storage slot; preserved item flags during quantity changes; invalid capacities/layouts/quantities; and storage save/backup/restore plus an injected write failure. All 51 tests passed.

Live interface checks used generated fixtures and a separately verified copy of the supplied real island:

- An eighty-slot fixture rendered its saved gold nugget stack and golden axe with the correct icons and an immediately accessible pinned inspector. Occupied-only filtering showed exactly those two entries. Changed the gold stack from ten to eleven and removed the axe. Find Empty Slot cleared the filter and selected the newly empty slot two.
- Searching stored items for `0x09c9` found the updated stack. This hid the selected empty slot and disabled the library placement action. Clearing the search restored eighty results. Navigated to the last page, selected slot eighty, added the golden axe, and checked undo/redo. Review listed exactly slots one, two, and eighty, including old/new stack counts.
- Exported through the native dialog. `scripts/verify-storage-export.py` independently decrypted the source/export with Python/OpenSSL, checked the three expected eight-byte records and both personal hashes, and compared all remaining bytes and files. Unrelated item flags, locked storage, capacity, pockets, main.dat, headers, and sibling files were preserved. Reopened the export with verified checksums and confirmed quantity eleven, the removal, and the saved axe in slot eighty.
- The copied real ACNH 3.0.3 save displayed fourteen occupied entries and eighty unlocked slots, including its saved wasp nests, branches, clay, fossils, stone, and crop starts. A no-op UI export was byte-identical for every file to the verified QA copy; the independent verifier also passed. No writes targeted the user's original save.
- The final universal build also opened a generated 9,000-slot fixture with the first fifty slots occupied. Verified 180 pages, last-page navigation and selection of slot 9,000. After filtering for the axe, Find Empty Slot cleared the search and selected slot fifty-one on page two. No save changes were made during this large-inventory UI check.

The source was copied into the new ACNH Mac Editor workspace before editing; the earlier workspace and releases were preserved. Build scratch/output and raw app bundles were kept outside the file-provider-managed Documents folder because it automatically adds Finder metadata that signing rejects. Build scripts support `ACNH_BUILD_SCRATCH` for that workflow. The release ZIP was built from a non-synced staging folder; extraction and strict signature verification were checked in a local temporary folder. ZIPs are the deliverables in the project folder. Intel code was compiled but not run on Intel hardware. A Switch import/game round trip remains untested. QA saves are excluded from all app/source archives.

## All unlocked pocket slots — 1.3.1

The old editor hardcoded twenty items in its save reader, writer, grid, review, and loadouts. NHSE stores slots 1–20 and 21–40 in separate, reversed-in-memory blocks. In ACNH 3.0, the first block starts at 0x37CA8 with its unlocked count at 0x37D48; the second starts at 0x37BF0 with its count at 0x37C90. The supplied real save has counts 20 + 10, matching thirty unlocked pockets.

- Reads each block's own unlocked count, combines the unlocked records in game order, and uses their individual offsets when writing. The grid, slot selection, review, and loadouts follow the loaded capacity. Preview mode now demonstrates thirty pockets.
- Preserves all locked item records, both capacity counters, block padding, encryption headers, and unrelated data. Does not unlock upgrades. Rejects invalid counters and drafts that try to grow/shrink the loaded inventory.
- Existing schema-1 twenty-slot loadouts remain readable. New schema-2 loadouts retain their saved size. Applying a smaller loadout preserves remaining target slots; larger loadouts are disabled when the resident lacks space and rejected by the core merger. This avoids either truncating a loadout or replacing the current inventory with a shorter array.
- Five new regression tests cover no-op byte identity and ordering at 20/30/40 slots; simultaneous edits to slots 20, 21, and the final unlocked slot; exact plaintext preservation including locked slots and capacity counters; independent partial-block counts; invalid counters/draft lengths; extra-pocket save/backup/restore; and JSON compatibility, partial application, and rejection of malformed/oversized loadouts.
- All 46 automated tests passed after the change. `scripts/verify-pocket-export.py` provides an independent Python/OpenSSL check for requested slot edits and untouched data; it does not use ACNHCore.

Live QA used a fresh, SHA-256-verified separate copy of the supplied thirty-pocket ACNH 3.0.3 save. The new screen reported thirty unlocked pockets and displayed the saved contents of slots 21–30, including wood in slot 22, a wasp nest in slot 23, and weeds in slot 24. Scrolled to pocket 30, selected the golden axe (item 0x2591), placed it, undid/redid the placement, cleared it, and undid the clear. The slot icon, selected-pocket summary, and review updated correctly; review listed only pocket 30. Exported through the native dialog and independently verified exactly that eight-byte record plus the required personal checksum, with both personal hashes valid. Every other personal byte, all locked records, capacity counters, encryption headers, main.dat, and sibling files were preserved. Reopened the export with verified checksums and confirmed thirty pockets and the saved golden axe in pocket 30. All writes targeted QA folders; the user's original was never edited by these checks. A Switch import remains untested.

## Player and island settings — 1.3.0

- New sidebar screens edit the primary human resident's name/birthday and island name, hemisphere, airport color, island/tour weather seeds and hemispheres, native/sister fruits and flowers. Changes join the existing draft, undo/redo, per-settings revert, review, export, backup, and restore workflows.
- Both birthday locations are updated, including the profile birthday. Calendar validation includes February 29. The day picker follows the selected month; an unset saved month is preserved until a valid month is selected. Names accept at most ten UTF-16 units, reject blank/control-character input, and zero-fill unused name storage.
- NHSE's complete 24-byte ID + name replacement is applied across main.dat and every present supported pair in Villager0–Villager7: personal, postbox, photo_studio_island, profile, and optional wherearen. Numeric IDs and encryption headers stay unchanged. Matching text with a different ID, standalone text, opaque sibling files, and unrelated data are preserved. Supporting those files does not add editing of additional human residents or their appearance.
- All present supported pairs are checked for size, revision, paired header consistency, and every Murmur3 region. Incomplete/corrupt pairs and external changes are rejected. Missing optional pairs are allowed. No-op export remains byte-identical. Backups, restore, and injected multi-file write failures cover all files affected by renames.
- The six new tests check literal NHSE offsets, reading settings, combined Unicode renames across two human residents and every supported auxiliary file type, foreign-identity preservation, every exposed setting's round trip, exact allowed byte changes, native fruit flags/profile synchronization, invalid name/date/enum rejection before export, no-op identity, multi-file save/backup/restore/rollback, corruption, and external-change protection. All 41 tests passed in the final core test run.

Live interface checks used a separately copied ACNH 3.0.3 real island, with a verified SHA-256 copy made before testing. The original save folder was never opened for writing:

- Player Settings displayed the saved primary name and April 1 birthday. An eleven-unit name produced the expected inline validation message; undo restored the name and cleared the error.
- Edited the draft player name and birthday to a valid February 29, and island name to exactly ten UTF-16 units. Changed the island to Southern Hemisphere, airport to Green, weather seed to 123456789, and native fruit to Cherry.
- Revert Island Settings left the two player changes intact; undo restored the island draft. Review showed exactly seven human-readable changes.
- Exported the combined changes through the native save dialog. `scripts/verify-settings-export.py` independently decrypted the source and export with Python/OpenSSL, checked all eight requested scalar/name inputs (birthday has two fields), identity replacement and every hash region, and compared all unrelated bytes, headers, and other files. Exactly three files changed. All checks passed.
- Reopened the exported folder in the app with verified checksums; both settings screens showed the saved names, February 29 birthday, Southern Hemisphere, Green airport, Cherry native fruit, and weather seed. The review button was disabled with no draft changes.

The verifier accepts an expected-settings JSON file and reads both save folders without modifying them. UI QA exports and source save copies stay outside the deliverable/source archives. A Switch import and in-game round trip remain untested.

## Save-engine coverage

NIST AES-128 known-answer vector; ACNH key/counter derivation and AES-CTR independently checked with Python/OpenSSL; Murmur3 known answer; encrypted integers at every shift-byte value; no-op output byte-identical; money and multiple pocket edits; complete backup/save/restore; corruption, version, header and size checks; concurrent-change protection; injected write/rollback failures and recovery markers; untouched plaintext and sibling-file preservation.

## Map and villager coverage

- NHSE 3.0 offsets and column-major terrain/item coordinate indexing checked against literal format values.
- Terrain, paths, elevations, building coordinates and rotation survive export/reopen with valid hashes.
- Only selected records and checksum words change; unrelated island data is byte-identical.
- Outdoor item roots and 2×2 extension footprints, removal through an extension cell, both item layers, and row-major activation-flag bits.
- Occupied/out-of-range drops, invalid models/coordinates, unknown/duplicate villager identities and edits to empty resident slots rejected.
- Unicode catchphrase limits, friendship changes only for existing player memories, and preservation of unrelated moving-state bits.
- Villager house and player memories preserved while editing identity/personality/catchphrase/friendship/state.
- Map and villager edits survive in-place save and verified backup restoration.
- All four terrain corners and valid 2×2 footprints at opposite item-map corners survive export/reopen on both layers. Removing an exported object through its last extension cell preserves objects on the other layer.
- Canvas hit testing selects the first/last cells correctly at all 12 zoom levels, ignores coordinates outside each editable layer, and rejects non-finite coordinates or invalid zoom.

## NHSE pocket item icons — 1.2.0

- Imported 610 inventory PNGs with 15,499 item-ID mappings from the recorded NHSE reference revision. The deterministic import script is `scripts/import-nhse-item-icons.py`; no image service or runtime downloads are used.
- Preserves NHSE's menu-icon mapping, special Leaf1 resource, and held-item remapping for placed field objects. Unknown IDs use the bundled leaf fallback; empty pockets retain the plus symbol. Furniture and clothing can share category icons, as in NHSE's bundled inventory view. Optional external item/variation image packs are not included.
- Full-color icons now appear in all occupied pocket cards, library rows, the selected pocket summary, and the selected catalog-item preview. Names, stack counts, selection outlines, and accessibility labels remain available. Shared images are cached with a bounded cache.
- Asset audit verified all mapping targets exist and have valid PNG signatures/dimensions. Literal checks matched gold nugget → OreGold, golden shovel → Gscoop, golden axe → GAxe, Nook Miles Ticket → PlaneTicket, iron nugget → OreIron, star fragment → StarPiece, apple → Apple, and customization kit → RemakeKit. Field tree ID 60000 matches its held-item icon.
- Launched an isolated QA build in preview mode and visually inspected the icons in the current dark appearance. Ticket, shovel, gold nugget and star fragment displayed distinct icons in the grid; item-library rows and the larger selection preview rendered the corresponding art. Selected an empty fifth pocket, filtered Favorites, selected the golden axe, placed it, undid/redid it, scrolled to the pocket summary, and cleared it. The pocket icon, empty state and summary updated correctly at each step.
- Re-ran all 35 automated tests successfully after adding the icon resources and views. The universal production build and ad-hoc signature verified. This version also includes the 1.1.3 building-coordinate corrections described below.

## Building coordinate correction and real-save test — 1.1.3

A real island exposed a coordinate-scale error missed by the earlier generated-fixture checks. Building records use the full 288×256 half-tile map. The native terrain canvas is 144×128 terrain tiles, but building markers and selection used the raw values directly. This doubled their displacement and hid buildings whose coordinates exceeded the canvas dimensions. The building controls and export validator also incorrectly limited raw coordinates to 144×128.

Confirmed the correct relationship from NHSE's `MapRenderer` (full-map dimensions at item resolution) and `TerrainSprite.GetMapWithBuildings` / `DrawMapBuildings` (terrain upscaled by two, buildings drawn at raw X/Y). The Mac renderer now divides building coordinates by two, with no additional border offset. A house at raw (124, 116) appears at full-map terrain position (62, 58). Rendering and click selection share this conversion. Controls and validation now cover X 0–287, Y 0–255. The inspector labels the half-tile units; the selected building gets its own outline, and the unrelated terrain reticle is hidden in building mode.

New regression tests verify literal marker positions, odd half-tile coordinates, and matching building selection at every zoom level; full-map edge coordinates and rejection beyond those edges; and export/reopen of positions above the old limits while preserving unrelated record bytes. These checks extend the earlier tests, which verified coordinate storage but did not establish building-to-terrain alignment.

Real-save checks used an isolated local copy of the supplied ACNH 3.0.3 save, opened in a separately identified QA app:

- All source checksums verified. All six buildings are now visible in the correct map regions, including the airport and buildings with X/Y above the old limits.
- Clicking the player's house selects its saved coordinates (217, 130). Increasing X to 218 works; undo restores 217.
- Clicking the affected villager house selects (124, 116). Increasing X and Y by two moves its marker one terrain tile right and down, to (126, 118). Selection remains aligned at 60% and 80% zoom, including the neighboring house.
- A no-op export is byte-identical for every file, including encryption headers and personal/sibling files.
- A reviewed export with only the house movement passes the independent Python/OpenSSL verifier: exactly that building's coordinate bytes and the corresponding checksum change. All 19 island checksums verify; the rest of the island and all sibling files remain unchanged.
- Reopened the moved export in the app, verified checksums, and selected the house at its saved (126, 118) position on land.
- Corrected the review text's small-integer multiplication for building angles and verified a 270° rotation displays correctly in the live review sheet. Reverted that rotation-only draft without saving it.
- SHA-256 digests of every file in the user's original source folder still match the pre-test manifest. No in-place save was performed; no real save data is included in the application or source archives.

`scripts/verify-building-export.py ORIGINAL EXPORTED` checks no-op byte identity. Add `--slot 4 --x 126 --y 118 --angle 0` to independently check the movement scenario; the verifier reads both folders without modifying them.

## Dedicated map-editor test — 1.1.1

Found and fixed an item-selection bug: clicking the top/bottom ocean outside the editable item layer clamped the selection to row 0 or 191. Such clicks now leave the selection unchanged. Reproduced the bug in 1.1.0 and verified the fix in the packaged app at 60% and 80% zoom. Terrain drags also stop interpolation when they leave the editable area.

Opened a fresh copy of the generated fixture and tested:

- Grid and zoom controls, terrain selection, and both item layers.
- Ground item placement at (112, 80), expected refusal of an occupied drop, selecting extension cell (113, 81), whole-footprint removal, and undo restoration.
- Upper-layer placement at (113, 81) without disturbing the ground object.
- A 3×3 water brush at terrain (10, 10): exactly nine tiles; undo removes all nine, redo restores them.
- A 5×5 brush at (0, 0): clipped to nine valid tiles without wrapping across map edges.
- A 1×1 water stroke from (20, 20) through (30, 20): all eleven tiles, one undo step. Review after undo showed only the earlier 18 tiles; redo restored the stroke.
- A stone path stroke on the same eleven cells preserves their terrain. A rotated cliff brush at (40, 40) sets elevation 1 and terrain rotation 90° while preserving the original stone path.
- Player 1’s building moved from (40, 60) to (42, 62), with rotation 180°.
- Review showed exactly 30 terrain/path records, eight outdoor cells, and one building. Exported through the native dialog and reopened the export; the app verified checksums and showed the saved cliff/path/elevation/rotation values.

`scripts/verify-map-ui-export.py` independently decrypted that UI export using OpenSSL, checked the exact expected map/item/building bytes, verified all 19 island checksums using a separate Python Murmur3 implementation, and compared every unrelated plaintext byte and sibling file. All checks passed. The original generated fixture remained byte-identical.

To reproduce, generate a fixture with `ACNH_ISLAND_FIXTURE_OUTPUT=/private/tmp/NEW_FOLDER` while running the tests, perform the scenario above, then run `python3 scripts/verify-map-ui-export.py ORIGINAL_FIXTURE UI_EXPORT`. The verifier is specific to this synthetic scenario.

## Dedicated villager-editor test — 1.1.2

Found and fixed a chooser bug: after selecting a search result and changing the search to hide that result, **Use Villager** remained enabled but did nothing. The button now requires a selection in the visible results. Reproduced in 1.1.1 and verified the disabled state in the rebuilt 1.1.2 app.

Live checks with a fresh generated fixture:

- All ten slot cards render; the two occupied slots display portraits. An empty slot shows an explanation and exposes no resident-editing controls.
- Search works by name (including mixed case) and internal ID (`cat23`). Cancelling the chooser leaves the original draft untouched.
- Choosing Lucky for Bob’s slot creates a duplicate draft. Export correctly rejects it, creates no destination, and leaves the original files untouched. **Revert Resident** restores Bob and removes the draft changes.
- A 13-emoji catchphrase shows 26 / 24 UTF-16 units and export is rejected without creating a destination. Undo restores the original phrase.
- Choosing Raymond changes the portrait, identity, default personality (Smug), and default catchphrase (crisp) in one undo step. Undo restores Bob and his original details; redo restores Raymond.
- Independent edits set Raymond to Cranky, catchphrase `Hello 🌴` (8 units), friendship 255, and moving out. The friendship slider also reaches 0.
- Switching to Lucky retains his original identity/details. Set his phrase to twelve palm-tree emoji (exactly 24 units), and friendship to 0. Reverting Lucky leaves Raymond’s edits intact; undo restores Lucky’s complete edit.
- Review lists exactly seven changes across the two residents. Exported through the native dialog, reopened the exported folder with verified checksums, and inspected both residents’ saved identity, personality, Unicode phrase, friendship and moving-out values.

`scripts/verify-villager-ui-export.py` independently decrypted the UI export with OpenSSL, checked the exact expected bytes for the seven reviewed changes, verified all 19 island checksums using Python, and compared every unrelated plaintext byte and sibling file. Houses/furniture, remaining player-memory data, map, other residents and personal files were preserved. The original fixture remained byte-identical.

Four additional automated tests cover all ten occupied slots including the last slot, simultaneous identity swaps without final duplicates, every personality value, first/last player-memory friendship values 0/255, preservation of unrelated moving-state bits, full-length Unicode phrases, clearing trailing phrase storage when shortening/blanking it, malformed friendship arrays, invalid personalities/indices, embedded NUL characters, and rejected exports leaving no destination.

Data/asset audit: all 417 catalog choices uniquely match the core’s valid identity set. Default personalities and catchphrase lengths are valid; all 417 referenced portrait PNG files exist with valid signatures and positive dimensions. Individual portraits were not all visually inspected.

To reproduce the UI export verification, use the fresh generated fixture described above, make the seven edits listed here, and run `python3 scripts/verify-villager-ui-export.py ORIGINAL_FIXTURE UI_EXPORT`. The script uses the independent Python/OpenSSL helpers from `verify-map-ui-export.py`; neither verifier uses ACNHCore.

## Earlier combined native interface checks — 1.1.0

Launched the packaged app and opened a generated island fixture. Inspected the map and villager portraits; selected Raymond by name; edited catchphrase, friendship and moving-out state; changed a terrain elevation; painted a continuous water stroke and verified undo/redo; moved a building; dropped and removed an item with its footprint, then restored it using undo; reviewed the combined edits and exported through the native dialog.

Independently decrypted the UI export using Python/OpenSSL and verified 12 terrain edits, the item root/extension records, building coordinates, Raymond’s identity/personality, custom catchphrase, moving-out bit and friendship value. The personal file and unrelated house data were preserved.

Automated tests and the earlier interface checks used generated fixtures. Version 1.1.3 additionally opened and exported an isolated copy of a supplied real island as described above; the user's original folder was not modified. A real Switch import/game round trip remains untested. Intel code was compiled but not run on Intel hardware. Minimum macOS compatibility was checked from binary metadata; runtime testing was on the local Mac.

The map is schematic and does not automatically solve collisions, terrain adjacency, path edges or bridge/incline connections. Human player appearance editing is not included. Selecting another animal villager preserves the current house and furniture.

## Map zoom controls — 30 October 2026

- Default scale is 100% (five points per terrain tile). The labeled slider has exactly five stops: 100%, 200%, 300%, 400%, and 500%.
- Native SwiftUI magnification on the map scales continuously within the range and settles at the nearest stop after release or cancellation. Pinch state blocks terrain painting and resets brush interpolation.
- Native release build/signature verification passed. All 14 selected zoom, map-coordinate, and building-footprint tests passed. The native interface was checked at the 100% default, a single step to 200%, the 500% limit, and back to 100%. Physical trackpad pinch input was not available to the UI automation tool and remains a manual check.

### Continuous pinch refinement — 30 October 2026

Supersedes the release/cancellation snapping described above. Pinch zoom now retains its fractional scale after release or cancellation, within 100%–500%; the slider alone retains its five presets. The gesture threshold was reduced from 1% to 0.1% for finer motion. All nine selected zoom/coordinate tests passed, including successive fractional pinches and hit testing between presets. Physical trackpad input remains a manual check.

## Bundled Yolo example island — 30 October 2026

The owner-contributed full ACNH 3.0.3 save snapshot replaces the synthetic preview and is intentionally tracked in Git and included in every build. Explore a Preview loads the bundled copy through SaveSession validation, with no live session retained and saving/exporting disabled. The example manifest records hashes for all 11 save files. The owner's original game save is unchanged.

## Map keyboard editing — 31 October 2026

- A focused map accepts arrow keys in Terrain and Items, keeping the selected tile/cell within bounds. Automatic recentering was subsequently removed; see the viewport fix below. Shortcut and continuous-pinch guidance is visible directly below the map heading.
- Items support native ⌘C/⌘V, Copy/Paste/Delete buttons, and the Delete key. Copy resolves extension cells to their root and preserves the exact root/extension records. Paste translates the complete footprint onto empty cells atomically; Delete removes the entire owned footprint. Draft undo/redo applies to each paste or deletion.
- The custom clipboard type is declared in Info.plist and registered as data. Clipboard payloads are validated, size-limited, and cannot contain terrain/building edits. An asynchronous paste is discarded if the user leaves the map or opens a different island while its data loads.
- Native interface checks passed on the bundled Yolo preview: terrain and item arrow navigation; button copy to keyboard paste; keyboard copy, Delete, paste, and undo; normal arrow/Delete/copy/paste in the search field; disabled Copy/Paste/Delete in Buildings. No bundled or original save was changed by these checks.
- All 16 selected tests passed. Coverage includes exact flags/variations/quantity preservation, planted flowers, cross-layer paste, linked-cell deletion, collision/edge rejection without partial edits, malformed clipboard records, and a real-island encrypted export round trip that preserves terrain, buildings, resident data, and the copied source object.
- Building cloning is intentionally unavailable: NHSE's map-editor documentation describes duplicate-facility side effects as unknown and recommends placement-only changes for existing buildings.

### Stable viewport during keyboard selection — 31 October 2026

Removed the ScrollViewReader recentering callback and its invisible selection target. Arrow keys now update only selection coordinates. Native release build/signature verification passed. At 500% zoom, Right/Down changed the selected terrain tile and item cell while both horizontal and vertical scroll-bar values remained unchanged (0.0676541233 and 0.1218983852 in the checked window).

### Centered zoom — 31 October 2026

Maps smaller than the viewport are centered in the available space. A native layout observer records the map point under the viewport center before zoom, waits for the new canvas dimensions, and restores that point at the same screen position. Scroll bounds clamp naturally at map edges; keyboard selection does not invoke this adjustment.

Native release build/signature verification passed. Interface checks covered 100% → 200% → 500% (both scroll positions remained centered at 0.5), a panned 200% → 300% transition (vertical positions 0.6066235864 → 0.5786338364 preserve the same map coordinate), and arrow navigation at 500% with unchanged scroll positions. Continuous pinch uses the same scale update path.

### Item grid snapping — 31 October 2026

The Items inspector has a “Snap to the grid” checkbox enabled by default. Empty-cell clicks align to a full tile, occupied-cell clicks resolve to the actual object root, and keyboard/stepper movement uses two half-tile coordinates per press. Existing odd-coordinate roots retain their phase; switching snapping off restores one-half-tile steps and a smaller selection reticle. These controls only change selection, never the saved positions of existing objects.

All 14 selected coordinate, clipboard and snapping tests passed, including copying a standard 2 × 2 object and successfully pasting after one upward move, fine-mode overlap rejection, map-edge alignment, and odd-root preservation. Native UI checks confirmed the default-on state, one Up changing Y 96 → 94, snapping off changing 94 → 93, and snapping back on realigning to 92 before a stepper decrease to 90. Native build/signature verification passed.

### Tile snapping information popover — 31 October 2026

Renamed the Items checkbox to “Snap to tiles” and replaced the always-visible explanation with an adjacent native `info.circle` button. Clicking it opens a popover containing the approved helper text: “Select object roots and move one full tile per arrow press. Turn off for finer positioning.” Native interface checks confirmed the default-on checkbox, accessible information button, and helper popover appearing on click. Native release build/signature verification passed.


### Native magnification and map toolbar — 31 October 2026

Supersedes the asynchronous layout observer described under Centered zoom. A dedicated `NSScrollView` now keeps its document at 720 × 640 logical points and applies magnification and centering together. The native magnification event handler accepts fractional increments in both directions, clamps to 100%–500%, and leaves the exact scale on release or cancellation. No delayed scroll correction, layout polling, or second gesture recognizer competes with it. The canvas renders at the visible resolution inside the fixed document to keep artwork sharp at 500%.

The Items-only “Snap to tiles” checkbox and information button now sit beside the zoom percentage. Visibility controls wrap onto a second row when space is limited.

All 21 selected tests passed: three new AppKit regression tests cover centering a document smaller than its viewport, hundreds of fractional zoom changes and reversals across the viewport-size thresholds, fixed document dimensions, a panned center, and zoom limits; 18 core tests cover zoom, coordinates, snapping, and clipboard integrity. Native interface checks confirmed 100% centering, both scroll positions staying at 0.5 through 500%, unchanged scroll positions during arrow navigation, panning followed by zoom, sharp artwork at 500%, and the relocated helper popover. Physical trackpad pinch input is unavailable to UI automation; its tactile smoothness remains a manual check.


### Version 2.0 release — 31 October 2026

All 77 automated tests passed: 74 core tests and three native map-viewport tests, with zero failures. The full run includes save validation, encryption, backups and restore, player/island edits, inventory/storage, building plot dimensions, map coordinates, object clipboard integrity, tile snapping, and repeated fractional zoom reversals.

The release app identifies as version 2.0, build 14. Its universal executable contains arm64 and x86_64, both with a macOS 14.0 minimum deployment target. Ad-hoc signature verification passed for the built app and the app inside the read-only mounted DMG. The DMG checksum and ZIP integrity checks passed; both contain the same executable and all 11 contributed example files match their SHA-256 manifest. The app includes 14 building artwork assets. SHA256SUMS.txt accompanies the DMG and ZIP downloads. Developer ID notarization, physical trackpad feel, Intel execution, and importing edits back into the game remain unverified.


### Version 2.0 replacement build: mouse selection — 31 October 2026

The initial 2.0 zoom rewrite regressed ordinary mouse selection. Centering and keyboard tests had passed without exercising pointer delivery through the separately hosted SwiftUI canvas. Native document hit testing now targets the full map bounds independently of the rendered SwiftUI content shape. Mouse down/drag/up are handled by the document view and converted into fixed logical map coordinates; selection, building picking, and painting all use those same coordinates. Clicking clears a stale pinch state, restores map focus, and starts a fresh brush stroke.

Native interface checks confirmed an ordinary click at 100% selecting terrain (59, 30), and a 500% click selecting (60, 44). A drag to (62, 46), followed by Right, selected (63, 46), without changing either centered scroll position. At 500%, clicking a planted object selected its root at (166, 96); keyboard copy and a click at (144, 96) allowed paste, Delete, and undo. Clicking a house selected Villager 4’s house at saved coordinates (142, 124). A terrain brush drag changed its selected cell to Flat grass; a single undo restored the original terrain and removed the draft edit.

All 80 tests passed: 74 core tests and six native viewport/input tests. Three added regressions cover pointer targets independent of SwiftUI content shapes, magnified/panned screen-to-map coordinates at preset and fractional zoom, and mouse-down/drag/up delivery as a single stroke. The replacement remains version 2.0, with internal build number 15, as requested. Earlier physical-trackpad, Intel-execution and in-game verification limitations remain.

The replacement universal DMG and ZIP passed package integrity and signature checks. Both identify as version 2.0 (15), contain identical executables, and preserve all 11 example-save manifest hashes.


### Version 2.1 release — 2 November 2026

Version 2.1 (build 16) adds independent plaza coordinate editing and eight standard bridge styles. Plaza tests verify the separate uint32 fields at 0x32FB40/0x32FB44, coordinate limits, upper-left map selection, and export/reopen with unrelated bytes preserved. Bridge tests cover all 54 NHSE models, geometry-preserving style changes, matching material values, invalid model/target rejection, and combined position/style export with unrelated bytes preserved. The preview controls were checked for plaza movement, undo/redo/revert, and bridge style selection and undo.

All 88 automated tests passed: 82 core tests and six native map viewport/input tests. The universal release executable contains arm64 and x86_64; both have a macOS 14.0 minimum target. Ad-hoc signature verification passed for the app and the app inside the read-only mounted DMG. The DMG checksum and ZIP CRC checks passed. Both downloads identify as 2.1 (16), contain the same executable, and preserve all 11 bundled example-save manifest hashes. The DMG includes an Applications shortcut; SHA256SUMS.txt accompanies both download assets.

Developer ID notarization, execution on Intel hardware, physical trackpad feel, exact in-game plaza/building anchor alignment, and importing edited saves back into the game remain manual checks. The guides do not enforce collision handling or relocate terrain, Resident Services, or outdoor objects automatically.
