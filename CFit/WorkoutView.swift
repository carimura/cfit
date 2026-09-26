import SwiftUI
import AVFoundation

struct WorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var session: WorkoutSession
    @State private var showGuide = false
    @State private var confirmEnd = false

    init(workout: Workout) {
        _session = State(initialValue: WorkoutSession(workout: workout))
    }

    private var block: WorkoutBlock? { session.current.flatMap { session.workout.block($0.block) } }
    private var accent: Color { session.current?.isRest == true ? Theme.rest : Theme.accent }

    var body: some View {
        ScrollView {
            if session.isComplete { completion }
            else { active }
        }
        .background(Theme.background)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                if session.isComplete {
                    Button("DONE") { dismiss() }.buttonStyle(PrimaryButtonStyle())
                } else {
                    Button {
                        if session.isRunning { session.pause() }
                        else { session.resume() }
                    } label: {
                        Label(session.isRunning ? "PAUSE" : "RESUME", systemImage: session.isRunning ? "pause.fill" : "play.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("pauseResume")
                    Button("End workout", role: .destructive) {
                        session.pause()
                        confirmEnd = true
                    }
                    .font(.subheadline).foregroundStyle(Theme.muted).frame(minHeight: 44)
                }
            }
            .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 8)
            .background(Theme.background)
        }
        .sheet(isPresented: $showGuide) {
            if let movement = session.movement { MovementDetailView(movement: movement) }
        }
        .confirmationDialog("End this workout?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("End workout", role: .destructive) { dismiss() }
                .accessibilityIdentifier("confirmEndWorkout")
            Button("Keep training", role: .cancel) { }
        } message: {
            Text("Your workout is paused. Ending it discards this session.")
        }
        .onAppear { session.resume() }
        .onDisappear { session.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { session.pause(reason: "You left the app. Resume when you’re ready.") }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { notification in
            if let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
               type == AVAudioSession.InterruptionType.began.rawValue {
                session.pause(reason: "Workout paused for an audio interruption.")
            }
        }
    }

    private var active: some View {
        VStack(spacing: 24) {
            HStack {
                Eyebrow(text: session.isWarmingUp ? "Warm-up · \((session.position?.index ?? 0) + 1)/\(session.workout.warmupSteps.count)" : "\(block?.kind.rawValue ?? "") · \(session.current?.round ?? 1)/\(block?.rounds ?? 1)")
                Spacer()
                Text("\(timeLabel(Int(ceil(Double(session.phaseSeconds) - session.phaseElapsed)))) LEFT")
                    .font(.system(.caption, design: .monospaced, weight: .medium)).foregroundStyle(Theme.muted)
            }
            ProgressView(value: session.phaseElapsed, total: Double(session.phaseSeconds)).tint(accent)
                .accessibilityLabel(session.isWarmingUp ? "Warm-up progress" : "WOD progress")
            Text(session.current?.isRest == true ? "Rest" : session.movement?.name ?? "Workout")
                .font(.system(size: 32, weight: .bold, design: .rounded)).multilineTextAlignment(.center)
                .padding(.vertical, -8)
                .accessibilityIdentifier("currentMovement")
            if session.current?.isRest == false, let prescription = block?.prescription {
                Text(prescription).font(.subheadline.weight(.semibold)).foregroundStyle(accent)
            }
            ZStack {
                Circle().stroke(Theme.card, lineWidth: 12)
                Circle().trim(from: 0, to: max(0, 1 - (session.position?.progress ?? 0)))
                    .stroke(accent, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 6) {
                    Text(timeLabel(session.position?.remaining ?? 0))
                        .font(.system(size: 64, weight: .bold, design: .rounded)).monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                        .accessibilityIdentifier("intervalCountdown")
                    Eyebrow(text: session.isWarmingUp ? "Step remaining" : (session.current?.isRest == true ? "Rest remaining" : "Work remaining"))
                }
            }
            .frame(maxWidth: session.isWarmingUp ? 250 : 300).aspectRatio(1, contentMode: .fit).padding(.horizontal, 12)
            if let reason = session.pauseReason {
                Text(reason).font(.footnote).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            }
            if let error = session.audioError {
                Text(error).font(.footnote).foregroundStyle(.orange).multilineTextAlignment(.center)
            }
            Button { session.skipInterval() } label: {
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(text: "Up next · tap to skip")
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.up.right")
                            .font(.title2).foregroundStyle(accent)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(session.nextMovement?.name ?? "Workout complete")
                                .font(.headline)
                            if let next = session.nextMovement {
                                Text(next.equipmentLabel)
                                    .font(.caption).foregroundStyle(Theme.muted)
                            }
                        }
                        Spacer()
                        Image(systemName: "forward.end.fill").foregroundStyle(Theme.muted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading).card()
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("skipToNext")
            .accessibilityHint("Skips the current interval")
            if session.isWarmingUp, let movement = session.movement {
                Text(movement.cue).font(.subheadline).foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
            } else if session.current?.isRest == false, let movement = session.movement {
                Text(movement.about).font(.subheadline).foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
            }
            if let movement = session.movement, session.current?.isRest == false {
                Button {
                    session.pause(reason: "Form guide opened. Resume when you’re ready.")
                    showGuide = true
                } label: {
                    Label("Form guide · \(movement.name)", systemImage: "play.circle")
                        .font(.subheadline).multilineTextAlignment(.center).frame(minHeight: 44)
                }.accessibilityIdentifier("workoutGuide")
            }
            if session.isWarmingUp {
                Button("Skip warm-up") { session.skipWarmup() }
                    .font(.subheadline).frame(minHeight: 44)
                    .accessibilityIdentifier("skipWarmup")
            }
        }.padding(24)
    }

    private var completion: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 50)
            Image(systemName: "checkmark").font(.system(size: 60, weight: .bold))
                .foregroundStyle(Theme.background).frame(width: 136, height: 136)
                .background(Theme.accent, in: Circle())
            VStack(spacing: 12) {
                Text("Workout complete").font(.title.bold())
                    .multilineTextAlignment(.center)
            }
            HStack {
                summaryValue("\(session.workout.settings.minutes)", "WOD MINUTES")
                Spacer()
                summaryValue("\(session.workout.movements.count)", "MOVEMENTS")
                Spacer()
                summaryValue("\(session.workout.intervals.filter { !$0.isRest }.count)", "WORK SETS")
            }.card()
            if session.workout.warmupSeconds > 0 {
                Text(session.warmupSkipped ? "Warm-up skipped or shortened" : "\(session.workout.settings.warmupMinutes)-minute warm-up completed")
                    .font(.subheadline).foregroundStyle(Theme.muted)
            }
        }.padding(24)
    }

    private func summaryValue(_ value: String, _ label: String) -> some View {
        VStack(spacing: 8) {
            Text(value).font(.system(.title, design: .rounded, weight: .bold)).foregroundStyle(Theme.accent)
            Text(label).font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(Theme.muted)
        }
    }
}
