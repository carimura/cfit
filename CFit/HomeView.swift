import SwiftUI

struct HomeView: View {
    @Bindable var store: WorkoutStore
    @State private var workout: Workout?
    @State private var activeWorkout: Workout?
    @State private var selectedMovement: Movement?
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    durationCard
                    if let workout { plan(workout) }
                }
                .padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 20)
            }
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                Button { activeWorkout = workout } label: {
                    Text("Start")
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("startWorkout")
                .disabled(workout == nil)
                .padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 8)
                .background(Theme.background)
            }
            .sheet(isPresented: $showSettings) { SettingsView(store: store) }
            .sheet(item: $selectedMovement) { MovementDetailView(movement: $0) }
            .fullScreenCover(item: $activeWorkout) { WorkoutView(workout: $0) }
            .onAppear { if workout == nil { regenerate() } }
            .onChange(of: store.settings) { _, _ in regenerate() }
        }
    }

    private var header: some View {
        HStack {
            Text("Workout").font(.title2.bold()).accessibilityAddTraits(.isHeader)
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "slider.horizontal.3").font(.title3)
                    .frame(width: 48, height: 48).background(Theme.card, in: Circle())
            }
            .accessibilityLabel("Settings").accessibilityIdentifier("settings")
        }
    }

    private var durationCard: some View {
        VStack(spacing: 4) {
            minutePicker("Workout", $store.settings.minutes, Array(stride(from: 10, through: 60, by: 10)))
                .accessibilityIdentifier("workoutMinutes")
            Divider().overlay(.white.opacity(0.05))
            minutePicker("Warm-up", $store.settings.warmupMinutes, Array(0...5))
                .accessibilityIdentifier("warmupMinutes")
        }.card()
    }

    private func minutePicker(_ title: String, _ value: Binding<Int>, _ options: [Int]) -> some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
            Picker(title, selection: value) {
                ForEach(options, id: \.self) { Text("\($0) min").tag($0) }
            }.pickerStyle(.menu)
        }
    }

    private func plan(_ workout: Workout) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Exercises").font(.headline)
                Spacer()
                Button(action: regenerate) { Image(systemName: "shuffle").font(.title3).frame(width: 46, height: 46).background(Theme.card, in: Circle()) }
                    .accessibilityLabel("Generate another workout").accessibilityIdentifier("regenerate")
            }
            ForEach(workout.blocks) { block in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Eyebrow(text: block.kind.rawValue)
                        Spacer()
                        Text("\(block.seconds / 60) min").font(.caption).foregroundStyle(Theme.muted)
                    }
                    ForEach(block.movements) { movement in
                        Button { selectedMovement = movement } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(movement.name).font(.headline).foregroundStyle(.white)
                                Text(movement.equipmentLabel).font(.caption).foregroundStyle(Theme.muted)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }.accessibilityLabel("\(movement.name), form and video")
                    }
                }.card()
            }
        }
    }

    private func regenerate() { workout = WorkoutGenerator.generate(settings: store.settings) }
}
