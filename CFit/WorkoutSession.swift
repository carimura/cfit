import SwiftUI
import AVFoundation
import UIKit

@MainActor
@Observable
final class WorkoutSession {
    let workout: Workout
    let intervals: [WorkoutInterval]
    private(set) var elapsed: TimeInterval = 0
    private(set) var clock: WorkoutClock
    private(set) var pauseReason: String?
    private(set) var audioError: String?
    private(set) var warmupSkipped = false
    private var ticker: Timer?
    private var players: [IntervalCue: AVAudioPlayer] = [:]
    private var cueTracker = IntervalCueTracker()
    private var previewTask: Task<Void, Never>?

    init(workout: Workout) {
        self.workout = workout
        intervals = workout.sessionIntervals
        clock = WorkoutClock(duration: Double(workout.sessionSeconds))
    }

    var position: IntervalPosition? { .resolve(elapsed: elapsed, intervals: intervals) }
    var current: WorkoutInterval? { position.map { intervals[$0.index] } }
    var movement: Movement? { current?.movement }
    var isWarmingUp: Bool { current?.block == .warmup }
    var phaseElapsed: TimeInterval { isWarmingUp ? elapsed : max(0, elapsed - Double(workout.warmupSeconds)) }
    var phaseSeconds: Int { isWarmingUp ? workout.warmupSeconds : workout.totalSeconds }
    var nextMovement: Movement? {
        guard let position else { return nil }
        return intervals.dropFirst(position.index + 1).first(where: { !$0.isRest })?.movement
    }
    var isRunning: Bool { clock.status == .running }
    var isComplete: Bool { clock.status == .complete }

    func skipWarmup() {
        guard isWarmingUp else { return }
        skip(to: Double(workout.warmupSeconds))
    }

    /// Jumps to the start of the next interval (rest, movement, or completion).
    func skipInterval() {
        guard let position, !isComplete else { return }
        skip(to: Double(intervals.prefix(position.index + 1).reduce(0) { $0 + $1.seconds }))
    }

    private func skip(to seconds: TimeInterval) {
        if isWarmingUp { warmupSkipped = true }
        let now = ProcessInfo.processInfo.systemUptime
        clock.advance(to: seconds, at: now)
        elapsed = clock.elapsed(at: now)
        _ = cueTracker.cue(elapsed: elapsed, intervals: intervals)
        if isRunning { playCue(.transition) }
    }

    func resume() {
        guard !isComplete, !isRunning else { return }
        prepareAudio()
        pauseReason = nil
        clock.resume(at: ProcessInfo.processInfo.systemUptime)
        UIApplication.shared.isIdleTimerDisabled = true
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    func pause(reason: String? = nil) {
        guard isRunning else { return }
        tick()
        clock.pause(at: ProcessInfo.processInfo.systemUptime)
        elapsed = clock.elapsed(at: ProcessInfo.processInfo.systemUptime)
        pauseReason = reason
        stopResources()
    }

    func stop() {
        pause()
        stopResources()
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        clock.update(at: now)
        elapsed = clock.elapsed(at: now)
        if let cue = cueTracker.cue(elapsed: elapsed, intervals: intervals) {
            playCue(cue)
        }
        if isComplete {
            ticker?.invalidate()
            ticker = nil
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private func prepareAudio() {
        guard workout.settings.sound else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: .mixWithOthers)
            try session.setActive(true)
            for cue in IntervalCue.allCases where players[cue] == nil {
                guard let url = Bundle.main.url(forResource: cue.rawValue, withExtension: "wav") else {
                    throw CocoaError(.fileReadNoSuchFile)
                }
                let player = try AVAudioPlayer(contentsOf: url)
                player.volume = 1
                player.prepareToPlay()
                players[cue] = player
            }
            audioError = nil
        } catch {
            audioError = "Audio is unavailable. Check your audio output before continuing."
        }
    }

    func testBeep() {
        stopResources()
        prepareAudio()
        previewTask = Task { @MainActor [weak self] in
            for _ in 0..<3 {
                guard !Task.isCancelled else { return }
                self?.playCue(.countdown)
                do { try await Task.sleep(nanoseconds: 1_000_000_000) }
                catch { return }
            }
            guard !Task.isCancelled else { return }
            self?.playCue(.transition)
        }
    }

    private func playCue(_ cue: IntervalCue) {
        if workout.settings.sound {
            for player in players.values { player.stop() }
            players[cue]?.currentTime = 0
            players[cue]?.play()
        }
        if cue == .transition && workout.settings.haptics {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private func stopResources() {
        ticker?.invalidate()
        ticker = nil
        previewTask?.cancel()
        previewTask = nil
        for player in players.values { player.stop() }
        UIApplication.shared.isIdleTimerDisabled = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
