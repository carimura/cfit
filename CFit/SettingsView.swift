import SwiftUI

struct SettingsView: View {
    @Bindable var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    @State private var soundTest: WorkoutSession?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("Work: \(store.settings.workSeconds) seconds", value: $store.settings.workSeconds, in: 10...90, step: 5)
                        .accessibilityIdentifier("workInterval")
                    Stepper("Rest: \(store.settings.restSeconds) seconds", value: $store.settings.restSeconds, in: 5...60, step: 5)
                        .accessibilityIdentifier("restInterval")
                } header: { Text("Intervals") } footer: {
                    Text("Work and rest apply to the conditioning circuit. The final interval is shortened when needed to finish exactly on time.")
                }
                Section {
                    ForEach(Equipment.allCases) { equipment in
                        Toggle(isOn: Binding(get: { store.settings.equipment.contains(equipment) }, set: { store.setEquipment(equipment, enabled: $0) })) {
                            Label(equipment.name, systemImage: equipment.symbol)
                        }.accessibilityIdentifier("equipment.\(equipment.rawValue)")
                    }
                } header: { Text("Equipment") } footer: {
                    Text("Enable what you have. Bodyweight movements are always available. The cage and its pull-up bar can be enabled separately.")
                }
                Section {
                    Toggle("Advanced wall movements", isOn: $store.settings.advancedWall)
                        .accessibilityIdentifier("advancedWall")
                    ForEach(MovementLibrary.all.filter(\.advanced)) { movement in
                        NavigationLink(movement.name) { MovementDetailView(movement: movement) }
                    }
                } header: { Text("Wall skills") } footer: {
                    Text("Adds wall walks, supported handstands, and strict handstand push-ups when your wall is enabled. Use movements you can enter and exit with control.")
                }
                Section {
                    Toggle("Countdown beeps", isOn: $store.settings.sound)
                    Toggle("Haptic cues", isOn: $store.settings.haptics)
                    Button("Test countdown beeps") {
                        soundTest?.stop()
                        let session = WorkoutSession(workout: WorkoutGenerator.generate(settings: store.settings))
                        soundTest = session
                        session.testBeep()
                    }
                    if let error = soundTest?.audioError { Text(error).foregroundStyle(.orange) }
                } header: { Text("Sound & haptics") } footer: {
                    Text("Short beeps at 3, 2, and 1 second remaining; a long beep at zero. Beeps use your iPhone’s media volume and current audio output. The screen stays awake during training; leaving the app pauses your workout.")
                }
                Section {
                    Text("Your equipment and preferences stay on this iPhone. Workouts work offline; YouTube videos need internet.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden).background(Theme.background)
            .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .onDisappear { soundTest?.stop() }
        }
    }
}
