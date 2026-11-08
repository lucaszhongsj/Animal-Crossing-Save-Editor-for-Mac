import SwiftUI
import AppKit
import ACNHCore

extension Color {
    static let island = Color(red: 0.12, green: 0.46, blue: 0.37)
    static let sand = Color(red: 0.97, green: 0.96, blue: 0.92)
}

struct EditorView: View {
    @EnvironmentObject var model: EditorModel
    @State private var showLivePockets = false
    @State private var dropTargeted = false
    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "leaf.fill").font(.title).foregroundStyle(Color.island)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ACNH").font(.headline)
                        Text("Save Editor").font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(20)
                List(EditorPage.allCases, selection: $model.page) { page in
                    Label(page.rawValue, systemImage: page.symbol).tag(page)
                }.listStyle(.sidebar)
                VStack(alignment: .leading, spacing: 8) {
                    Label(model.demo ? "Preview mode" : model.session == nil ? "No save open" : "Save verified", systemImage: model.demo ? "eye" : "checkmark.shield")
                        .font(.caption.weight(.semibold)).foregroundStyle(model.session == nil ? Color.secondary : .island)
                    Text(model.demo ? "Explore · \(model.previewDescription)" : model.session?.folder.lastPathComponent ?? "Your next island adventure.")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    Button("Open Save Folder…", action: model.chooseFolder).controlSize(.small)
                }.padding(18)
            }.navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 260)
        } detail: {
            VStack(spacing: 0) {
                Group {
                    if !model.isLoaded && model.page != .backups && model.page != .pockets { welcome }
                    else {
                        switch model.page ?? .overview {
                        case .overview: overview
                        case .playerSettings: PlayerSettingsView()
                        case .islandSettings: IslandSettingsView()
                        case .map: IslandMapView()
                        case .villagers: VillagersView()
                        case .pockets: pocketPage
                        case .storage: StorageView()
                        case .loadouts: loadouts
                        case .backups: backups
                        }
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                HStack(spacing: 8) {
                    if model.busy { ProgressView().controlSize(.small) }
                    else { Image(systemName: model.hasChanges ? "circle.fill" : "checkmark.circle").font(.caption).foregroundStyle(model.hasChanges ? .orange : .secondary) }
                    Text(model.status).font(.caption).foregroundStyle(.secondary).lineLimit(1).help(model.status)
                    Spacer(minLength: 0)
                    if model.hasChanges { Text("\(model.changes.count) changes").font(.caption.monospacedDigit()).foregroundStyle(Color.island) }
                }.padding(.horizontal, 20).padding(.vertical, 11)
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .navigationTitle(model.page?.rawValue ?? "ACNH Save Editor")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: model.chooseFolder) { Label("Open Save Folder", systemImage: "folder") }.help("Open an exported save folder (⌘O)")
                    if model.isLoaded {
                        Button { model.reviewing = true } label: { Label("Review Changes", systemImage: "checklist") }
                            .disabled(!model.hasChanges).help("Review changes before exporting or saving")
                        Button(action: model.export) { Label("Export Copy", systemImage: "square.and.arrow.up") }
                            .disabled(model.session == nil).help("Export a complete edited save folder (⇧⌘S)")
                    }
                }
            }
        }
        .tint(.island)
        .disabled(model.busy)
        .overlay { if dropTargeted { RoundedRectangle(cornerRadius: 12).stroke(Color.island, style: StrokeStyle(lineWidth: 4, dash: [12])).padding(8).allowsHitTesting(false) } }
        .dropDestination(for: URL.self) { urls, _ in
            guard !model.busy, let url = urls.first, model.confirmDiscard() else { return false }
            model.open(url); return true
        } isTargeted: { dropTargeted = $0 }
        .alert("Couldn’t Complete the Operation", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("OK") { model.error = nil }
        } message: { Text(model.error ?? "") }
        .sheet(isPresented: $model.reviewing) { reviewSheet }
        .sheet(isPresented: $model.showGuide) { guide }
        .background(WindowGuard(model: model))
    }

    private var welcome: some View {
        VStack(spacing: 24) {
            Spacer()
            appIcon(size: 128)
            VStack(spacing: 10) {
                Text("A little more island time.").font(.system(size: 32, weight: .semibold, design: .rounded))
                Text("Shape your island, edit villagers, and organize your items\nfrom an exported Animal Crossing save.")
                    .font(.title3).foregroundStyle(.secondary).multilineTextAlignment(.center).lineSpacing(4)
            }
            VStack(spacing: 12) {
                Button("Open Save Folder…", action: model.chooseFolder).buttonStyle(.borderedProminent).controlSize(.large).keyboardShortcut("o")
                Text("or drop your save folder here").font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 32) {
                Label("Native on Mac", systemImage: "macwindow")
                Label("Verified backups", systemImage: "checkmark.shield")
                Label("Works offline", systemImage: "wifi.slash")
            }.font(.caption).foregroundStyle(.secondary).padding(.top, 8)
            HStack {
                Button("Explore a Preview", action: model.openDemo)
                Text("·").foregroundStyle(.tertiary)
                Button("How to Prepare a Save") { model.showGuide = true }
            }.buttonStyle(.link).font(.callout)
            Spacer()
            Text("ACNH 3.0.0–3.0.3 · Primary resident · Up to 40 unlocked pockets")
                .font(.caption).foregroundStyle(.secondary).padding(.bottom, 20)
        }.frame(maxWidth: .infinity).padding(32)
    }

    private func heading(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 28, weight: .semibold, design: .rounded))
            Text(subtitle).font(.callout).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func appIcon(size: CGFloat) -> some View {
        Image(nsImage: NSApp.applicationIconImage ?? NSImage(named: NSImage.applicationIconName) ?? NSImage())
            .resizable().interpolation(.high).scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel("NHSE for Mac app icon")
    }
    private var demoBanner: some View {
        Label("Preview · \(model.previewDescription). Open your save to export or save edits.", systemImage: "eye")
            .font(.callout).padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.island.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
    private var overview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 20) {
                    appIcon(size: 80)
                    heading("Make yourself at home.", model.session.map { "\($0.folder.lastPathComponent) · ACNH \($0.version) · Resident 1" } ?? "A preview of your island’s essentials.")
                }
                if model.demo { demoBanner }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    economyCard(0, symbol: "bag", color: .orange, subtitle: "Bells on hand")
                    economyCard(1, symbol: "building.columns", color: .island, subtitle: "Your savings balance")
                    economyCard(2, symbol: "airplane.circle", color: .blue, subtitle: "Ready for your next getaway")
                    economyCard(3, symbol: "house", color: .brown, subtitle: "Remaining home loan")
                }
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "checkmark.shield.fill").font(.title2).foregroundStyle(Color.island)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your original stays within reach.").font(.headline)
                        Text("Export a complete edited copy, or save to the opened folder with an automatic, verified backup. Every edit stays in your draft until then.")
                            .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Color.island.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                HStack {
                    Button { model.page = .pockets } label: { Label("Edit Pockets", systemImage: "square.grid.2x2") }
                    Spacer()
                    if model.hasChanges { Button("Revert Draft", action: model.revert) }
                    Button("Review Changes") { model.reviewing = true }.disabled(!model.hasChanges)
                }
            }.padding(30).frame(maxWidth: 1000)
        }
    }
    private func economyCard(_ index: Int, symbol: String, color: Color, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: symbol).font(.title3).foregroundStyle(color).frame(width: 36, height: 36).background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                Text(SaveDraft.labels[index]).font(.headline)
                Spacer()
                if let session = model.session, model.draft?.economy[index] != session.initial.economy[index] { Image(systemName: "circle.fill").font(.system(size: 7)).foregroundStyle(.orange).help("Changed in draft") }
            }
            TextField(SaveDraft.labels[index], value: model.economyBinding(index), format: .number.grouping(.never))
                .textFieldStyle(.plain).font(.system(size: 30, weight: .medium, design: .rounded)).monospacedDigit()
                .accessibilityLabel(SaveDraft.labels[index])
            HStack {
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(index == 3 ? "Pay Off" : "Max") { model.change { $0.economy[index] = index == 3 ? 0 : SaveDraft.limits[index] } }
                    .buttonStyle(.bordered).controlSize(.small)
            }
            Text("Limit: \(SaveDraft.limits[index].formatted())").font(.caption2).foregroundStyle(.tertiary)
        }.padding(20).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.primary.opacity(0.07)))
    }
    private var pocketPage: some View {
        VStack(spacing: 0) {
            if model.isLoaded {
                Picker("Pocket source", selection: $showLivePockets) {
                    Text("Save Draft").tag(false)
                    Text("Live Game").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 290)
                .padding(12)
                Divider()
            }
            if showLivePockets || !model.isLoaded { LivePocketsView() }
            else { pockets }
        }
    }

    private var pockets: some View {
        PocketInventoryView(live: false)
    }
    private var loadouts: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                heading("Ready for whatever’s next.", "Keep five pocket setups on this Mac and apply them to any supported save.")
                ForEach(0..<5, id: \.self) { index in
                    HStack(spacing: 16) {
                        Image(systemName: ["hammer", "fish", "mountain.2", "tray", "tray"][index]).font(.title2).foregroundStyle(Color.island).frame(width: 44)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(model.loadoutNames[index]).font(.headline)
                            Text(model.loadouts[index].map { "\($0.pockets.filter { !$0.isEmpty }.count) of \($0.pockets.count) pockets filled" } ?? "No loadout saved yet").font(.caption).foregroundStyle(.secondary)
                            if let saved = model.loadouts[index], saved.pockets.count > (model.draft?.pockets.count ?? 0) {
                                Text("Needs \(saved.pockets.count) unlocked pockets").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button(model.loadouts[index] == nil ? "Save Current Pockets" : "Replace with Current") {
                            if model.loadouts[index] != nil {
                                let alert = NSAlert(); alert.messageText = "Replace \(model.loadoutNames[index]) loadout?"; alert.informativeText = "This replaces the setup stored on this Mac."; alert.addButton(withTitle: "Cancel"); alert.addButton(withTitle: "Replace")
                                guard alert.runModal() == .alertSecondButtonReturn else { return }
                            }
                            model.saveLoadout(index)
                        }
                        Button("Apply") { model.applyLoadout(index) }.disabled(model.loadouts[index] == nil || (model.loadouts[index]?.pockets.count ?? 0) > (model.draft?.pockets.count ?? 0))
                    }.padding(20).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
                }
                Text("Applying a loadout changes your draft. Smaller loadouts preserve the remaining pockets. Larger loadouts require enough unlocked space. Export or save after reviewing the changes.").font(.callout).foregroundStyle(.secondary)
            }.padding(30).frame(maxWidth: 1000)
        }
    }
    private var backups: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                heading("A way back, whenever you need it.", "Complete, verified snapshots are created before every save and restore.")
                if model.backups.isEmpty {
                    ContentUnavailableView("No Backups Yet", systemImage: "clock.arrow.circlepath", description: Text("Save changes to an opened folder to create your first backup. Exported copies leave the original intact."))
                        .frame(minHeight: 280)
                }
                ForEach(model.backups) { backup in
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Image(systemName: "archivebox").font(.title2).foregroundStyle(Color.island)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(URL(fileURLWithPath: backup.sourcePath).lastPathComponent).font(.headline)
                                Text(backup.created.formatted(date: .abbreviated, time: .standard)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(backup.hashes.count) files").font(.caption).foregroundStyle(.secondary)
                        }
                        HStack {
                            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([backup.saveFolder]) }
                            Button("Open Backup") { model.openBackup(backup) }
                            Spacer()
                            Button("Restore") { model.restore(backup) }.disabled(model.session?.folder.path != backup.sourcePath)
                        }
                    }.padding(20).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
                }
                Button("Show Backups Folder") {
                    do { try FileManager.default.createDirectory(at: model.backupRoot, withIntermediateDirectories: true); NSWorkspace.shared.open(model.backupRoot) }
                    catch { model.error = error.localizedDescription }
                }
            }.padding(30).frame(maxWidth: 1000)
        }.onAppear { model.reloadBackups() }
    }
    private var reviewSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("Review your changes", "\(model.changes.count) changes. Renames also update matching identity records across the save.")
            List(model.changes, id: \.self) { Text($0).font(.callout).padding(.vertical, 4) }.listStyle(.bordered)
            Label("Save checksums are recalculated and the result is verified.", systemImage: "checkmark.shield").font(.callout).foregroundStyle(Color.island)
            Text("Export Copy creates a complete edited folder for your save manager. Save to Original creates a verified backup, then updates the opened folder.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Keep Editing") { model.reviewing = false }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save to Original", action: model.saveInPlace).disabled(!model.hasChanges)
                Button("Export Copy…", action: model.export).buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }
        }.padding(28).frame(width: 650, height: 490)
    }
    private var guide: some View {
        VStack(alignment: .leading, spacing: 22) {
            heading("Bring your island to your Mac.", "This app edits an exported save folder from ACNH 3.0.0–3.0.3.")
            ForEach(Array([
                ("1", "Export your save", "Fully close Animal Crossing. Use a save manager on your own Switch to export a complete save, then copy that folder to your Mac."),
                ("2", "Open the whole folder", "Choose the folder containing main.dat, mainHeader.dat, and the Villager0 folder with personal.dat and personalHeader.dat. Keep all other files in place."),
                ("3", "Edit and export a copy", "Adjust player and island settings, money, pockets, home storage, map, or villagers. Review your changes and export the complete edited folder."),
                ("4", "Import on your Switch", "Copy the edited folder back and restore it with your save manager while the game is closed. Keep a separate original backup.")
            ].enumerated()), id: \.offset) { _, step in
                HStack(alignment: .top, spacing: 16) {
                    Text(step.0).font(.headline).foregroundStyle(Color.island).frame(width: 32, height: 32).background(Color.island.opacity(0.1), in: Circle())
                    VStack(alignment: .leading, spacing: 5) { Text(step.1).font(.headline); Text(step.2).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
                }
            }
            Text("Player Settings edits Resident 1. Renaming a player or island updates matching identity references in all supported resident files. Pockets and Storage show the primary resident’s unlocked slots. Other features include money, the island map, and animal villagers. Not affiliated with Nintendo.")
                .font(.caption).foregroundStyle(.secondary)
            HStack { Spacer(); Button("Got It") { model.showGuide = false }.keyboardShortcut(.defaultAction) }
        }.padding(30).frame(width: 640)
    }
}

private struct WindowGuard: NSViewRepresentable {
    let model: EditorModel
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { view.window?.delegate = context.coordinator }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(model) }
    final class Coordinator: NSObject, NSWindowDelegate {
        let model: EditorModel
        init(_ model: EditorModel) { self.model = model }
        func windowDidBecomeKey(_ notification: Notification) {
            model.refreshLivePocketsOnFocus()
        }
        func windowShouldClose(_ sender: NSWindow) -> Bool { !model.busy && model.confirmDiscard() }
    }
}


struct PocketCell: View {
    @EnvironmentObject var model: EditorModel
    let index: Int
    let slot: PocketItem
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            VStack(spacing: 7) {
                HStack {
                    Text("\(index + 1)").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                    if selected { Image(systemName: "checkmark.circle.fill").font(.caption2).foregroundStyle(Color.island) }
                    Spacer()
                    Text(model.catalog.quantity(slot)).font(.caption2.weight(.semibold)).foregroundStyle(Color.island)
                }
                ItemIcon(id: slot.id, size: 40)
                Text(slot.isEmpty ? "Empty" : model.catalog.name(slot)).font(.system(size: 10, weight: .medium)).lineLimit(2).multilineTextAlignment(.center).frame(height: 28)
            }.padding(9).frame(maxWidth: .infinity, minHeight: 94)
                .background(selected ? Color.island.opacity(0.1) : Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? Color.island : Color.primary.opacity(0.08), lineWidth: selected ? 2 : 1))
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : []).accessibilityLabel("Pocket \(index + 1), \(model.catalog.name(slot)) \(model.catalog.quantity(slot))")
    }
}
