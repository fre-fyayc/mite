import Foundation

@MainActor
final class PresetStore: ObservableObject {
    @Published private(set) var presets: [MitePreset] = []

    private let storage: FileStoring
    private let fileName = "presets.json"

    init(storage: FileStoring = FileStorage()) {
        self.storage = storage
    }

    func load() {
        do {
            presets = try storage.load([MitePreset].self, from: fileName) ?? []
        } catch {
            presets = []
        }
    }

    func add(_ preset: MitePreset) throws {
        presets.append(preset)
        try persist()
    }

    func update(_ preset: MitePreset) throws {
        guard let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[index] = preset
        try persist()
    }

    func remove(_ id: UUID) throws {
        presets.removeAll { $0.id == id }
        try persist()
    }

    func move(fromOffsets: IndexSet, toOffset: Int) throws {
        presets.move(fromOffsets: fromOffsets, toOffset: toOffset)
        try persist()
    }

    private func persist() throws {
        do {
            try storage.save(presets, to: fileName)
        } catch {
            throw AppError.persistence(message: "Could not save presets.")
        }
    }
}
