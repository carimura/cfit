import SwiftUI

@MainActor
@Observable
final class WorkoutStore {
    var settings: WorkoutSettings {
        didSet {
            if let data = try? JSONEncoder().encode(settings) {
                defaults.set(data, forKey: "settings.v1")
            }
        }
    }
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: "settings.v1"),
           var saved = try? JSONDecoder().decode(WorkoutSettings.self, from: data) {
            saved.normalize()
            settings = saved
        } else {
            settings = WorkoutSettings()
        }
    }

    func setEquipment(_ equipment: Equipment, enabled: Bool) {
        if enabled { settings.equipment.insert(equipment) }
        else { settings.equipment.remove(equipment) }
    }
}
