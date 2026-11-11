import SwiftUI
import ACNHCore

struct VillagersView: View {
    @EnvironmentObject var model: EditorModel
    @State private var selected = 0
    @State private var phraseLanguage = VillagerPhraseLanguage.current
    @State private var choosing = false
    var body: some View {
        ScrollView {
            if let world = model.world, let edits = model.draft?.island {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Your island neighbors.").font(.system(size: 28, weight: .semibold, design: .rounded))
                    Text("Edit animal villagers using NHSE’s resident records. Changes stay in your draft until you export or save.")
                        .font(.callout).foregroundStyle(.secondary)
                    if model.demo { Label("Preview · Example villagers · Saving disabled", systemImage: "eye").font(.callout).foregroundStyle(Color.island) }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                        ForEach(0..<10, id: \.self) { index in
                            let record = world.villager(index, edits: edits)
                            Button { selected = index } label: {
                                VStack(spacing: 5) {
                                    VillagerPortrait(record: record, size: 62)
                                    Text(IslandMetadata.shared.name(record)).font(.callout.weight(.semibold)).lineLimit(1)
                                    Text("Slot \(index + 1)").font(.caption2).foregroundStyle(.secondary)
                                }.frame(maxWidth: .infinity).padding(12)
                                    .background(index == selected ? Color.island.opacity(0.09) : Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(index == selected ? Color.island : Color.clear, lineWidth: 2))
                            }.buttonStyle(.plain).accessibilityLabel("Villager \(index + 1), \(IslandMetadata.shared.name(record))")
                        }
                    }
                    let record = world.villager(selected, edits: edits)
                    if record.isEmpty {
                        ContentUnavailableView("Empty Resident Slot", systemImage: "pawprint", description: Text("Choose an existing resident to edit. Adding a new resident requires move-in and house data."))
                    } else { residentEditor(record, world: world, edits: edits) }
                }.padding(28).frame(maxWidth: 1060)
            }
        }
        .sheet(isPresented: $choosing) { chooseResident }
    }
    private func residentEditor(_ record: VillagerEdit, world: IslandSnapshot, edits: IslandEdits) -> some View {
        let phrase = world.catchphrase(villager: selected, language: phraseLanguage, edits: edits)
        return VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 16) {
                VillagerPortrait(record: record, size: 88)
                VStack(alignment: .leading, spacing: 6) {
                    Text(IslandMetadata.shared.name(record)).font(.title2.weight(.semibold))
                    Text(IslandMetadata.shared.villager(record)?.id ?? "Species \(record.species), variant \(record.variant)").font(.caption.monospaced()).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Choose Villager…") { choosing = true }
                if model.draft?.island.villagers[selected] != nil {
                    Button("Revert Resident") { model.change { $0.island.villagers.removeValue(forKey: selected) } }
                }
            }
            Text("Changing identity keeps the current house, furniture, and player memories. Personality and catchphrase can also be edited separately.")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("Personality", selection: Binding(get: { Int(record.personality) }, set: { value in model.editVillager(selected) { $0.personality = UInt8(value) } })) {
                        ForEach(Array(VillagerEdit.personalities.enumerated()), id: \.offset) { index, label in Text(label).tag(index) }
                    }
                    HStack {
                        TextField("Catchphrase", text: Binding(get: { phrase }, set: { text in model.editPhrase(selected, language: phraseLanguage, text: text) }))
                            .textFieldStyle(.roundedBorder).accessibilityLabel("Villager catchphrase")
                        Picker("Catchphrase language", selection: $phraseLanguage) {
                            ForEach(0..<VillagerPhraseLanguage.names.count, id: \.self) { index in Text(VillagerPhraseLanguage.name(index)).tag(index) }
                        }.labelsHidden().frame(width: 170).accessibilityLabel("Catchphrase language")
                    }
                    Text("\(phrase.utf16.count) / \(VillagerPhraseLanguage.maxUnits) UTF-16 units").font(.caption).foregroundStyle(phrase.utf16.count > VillagerPhraseLanguage.maxUnits ? .red : .secondary)
                    Toggle("Moving out", isOn: Binding(get: { record.movingOut }, set: { value in model.editVillager(selected) { $0.movingOut = value } }))
                    Text("This changes the moving-out state flag. The villager’s other progress and memories are preserved.").font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .topLeading)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Friendship with players").font(.headline)
                    ForEach(0..<8, id: \.self) { index in
                        let name = world.memoryName(villager: selected, memory: index)
                        if !name.isEmpty {
                            HStack {
                                Text(name).frame(width: 84, alignment: .leading).lineLimit(1)
                                Slider(value: Binding(get: { Double(record.friendship[index]) }, set: { value in model.editVillager(selected) { $0.friendship[index] = UInt8(value) } }), in: 0...255, step: 1)
                                    .accessibilityLabel("Friendship with \(name)")
                                Text("\(record.friendship[index])").monospacedDigit().frame(width: 30)
                            }.font(.callout)
                        }
                    }
                    if (0..<8).allSatisfy({ world.memoryName(villager: selected, memory: $0).isEmpty }) {
                        Text("No player memories are recorded for this resident.").font(.callout).foregroundStyle(.secondary)
                    }
                }.frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }.padding(22).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
    }
    private var chooseResident: some View {
        VillagerChooser { choice in
            model.editVillager(selected) { record in
                record.species = choice.species; record.variant = choice.variant
                record.personality = choice.personality
            }
            model.editPhrase(selected, language: phraseLanguage, text: choice.phrase)
            model.status = "\(choice.name) selected. Existing house and player memories preserved."
            choosing = false
        }
    }
}

private struct VillagerChooser: View {
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var selected: String?
    let apply: (VillagerChoice) -> Void
    var choices: [VillagerChoice] {
        IslandMetadata.shared.villagers.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0.id.localizedCaseInsensitiveContains(search) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    private var selectedChoice: VillagerChoice? { choices.first { $0.id == selected } }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose a villager").font(.title2.weight(.semibold))
            TextField("Search by name", text: $search).textFieldStyle(.roundedBorder).accessibilityLabel("Search villagers")
            List(choices, selection: $selected) { choice in
                HStack(spacing: 12) {
                    VillagerPortrait(record: VillagerEdit(species: choice.species, variant: choice.variant, personality: choice.personality, movingOut: false, friendship: []), size: 42)
                    VStack(alignment: .leading, spacing: 3) { Text(choice.name).font(.headline); Text(choice.id).font(.caption.monospaced()).foregroundStyle(.secondary) }
                    Spacer()
                    Text(VillagerEdit.personalities[Int(choice.personality)]).font(.caption).foregroundStyle(.secondary)
                }.tag(choice.id)
            }.listStyle(.bordered)
            Text("The existing house and memories stay in place. Selecting a resident also applies their default personality and catchphrase.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Use Villager") { if let choice = selectedChoice { apply(choice) } }
                    .buttonStyle(.borderedProminent).disabled(selectedChoice == nil).keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 530, height: 580)
    }
}
