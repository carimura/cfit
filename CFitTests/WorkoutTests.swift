import XCTest
import AVFoundation
@testable import CFit

final class WorkoutTests: XCTestCase {
    func testCountdownCuesForWorkRestAndCompletion() {
        let intervals = [
            WorkoutInterval(movement: MovementLibrary.all[0], block: .conditioning, round: 1, isRest: false, seconds: 10),
            WorkoutInterval(movement: MovementLibrary.all[0], block: .conditioning, round: 1, isRest: true, seconds: 5)
        ]
        var tracker = IntervalCueTracker()
        var cues: [(Double, IntervalCue)] = []
        for tick in 0...160 {
            let elapsed = Double(tick) / 10
            if let cue = tracker.cue(elapsed: elapsed, intervals: intervals) { cues.append((elapsed, cue)) }
        }
        XCTAssertEqual(cues.map(\.0), [7, 8, 9, 10, 12, 13, 14, 15])
        XCTAssertEqual(cues.map(\.1), [.countdown, .countdown, .countdown, .transition, .countdown, .countdown, .countdown, .transition])
    }

    func testCountdownDoesNotRepeatAfterPauseOrPlayMissedCues() {
        let intervals = [WorkoutInterval(movement: MovementLibrary.all[0], block: .conditioning, round: 1, isRest: false, seconds: 10)]
        var tracker = IntervalCueTracker()
        var clock = WorkoutClock(duration: 10)
        clock.resume(at: 100)
        XCTAssertEqual(tracker.cue(elapsed: clock.elapsed(at: 107), intervals: intervals), .countdown)
        clock.pause(at: 107.2)
        clock.resume(at: 200)
        XCTAssertNil(tracker.cue(elapsed: clock.elapsed(at: 200), intervals: intervals))
        XCTAssertEqual(tracker.cue(elapsed: clock.elapsed(at: 202), intervals: intervals), .countdown)
        XCTAssertNil(tracker.cue(elapsed: clock.elapsed(at: 202.1), intervals: intervals))
        XCTAssertEqual(tracker.cue(elapsed: clock.elapsed(at: 204), intervals: intervals), .transition)
        XCTAssertNil(tracker.cue(elapsed: clock.elapsed(at: 205), intervals: intervals))
    }

    func testTransitionTakesPriorityForShortenedFinalInterval() {
        let intervals = [
            WorkoutInterval(movement: MovementLibrary.all[0], block: .conditioning, round: 1, isRest: false, seconds: 10),
            WorkoutInterval(movement: MovementLibrary.all[0], block: .conditioning, round: 1, isRest: true, seconds: 2)
        ]
        var tracker = IntervalCueTracker()
        XCTAssertEqual(tracker.cue(elapsed: 9, intervals: intervals), .countdown)
        XCTAssertEqual(tracker.cue(elapsed: 10, intervals: intervals), .transition)
        XCTAssertNil(tracker.cue(elapsed: 10.1, intervals: intervals))
        XCTAssertEqual(tracker.cue(elapsed: 11, intervals: intervals), .countdown)
        XCTAssertEqual(tracker.cue(elapsed: 12, intervals: intervals), .transition)
    }

    func testBundledCountdownAndLongBeepDurations() throws {
        for (cue, duration) in [(IntervalCue.countdown, 0.15), (.transition, 0.8)] {
            let url = try XCTUnwrap(Bundle.main.url(forResource: cue.rawValue, withExtension: "wav"))
            let player = try AVAudioPlayer(contentsOf: url)
            XCTAssertEqual(player.duration, duration, accuracy: 0.001)
            XCTAssertTrue(player.prepareToPlay())
        }
    }

    func testEquipmentFilteringAcrossEveryInventory() {
        let equipment = Equipment.allCases
        for mask in 0..<(1 << equipment.count) {
            var settings = WorkoutSettings()
            settings.equipment = Set(equipment.enumerated().compactMap { mask & (1 << $0.offset) != 0 ? $0.element : nil })
            settings.advancedWall = mask % 2 == 0
            let workout = WorkoutGenerator.generate(settings: settings)
            let circuit = try! XCTUnwrap(workout.block(.conditioning)).movements
            XCTAssertGreaterThanOrEqual(circuit.count, 4)
            XCTAssertEqual(Set(circuit.map(\.pattern)).count, circuit.count)
            XCTAssertEqual(Set(workout.movements.map(\.id)).count, workout.movements.count)
            XCTAssertEqual(workout.blocks.reduce(0) { $0 + $1.seconds }, workout.totalSeconds)
            XCTAssertEqual(workout.blocks.map(\.kind), [Block.power, .strength, .conditioning, .core].filter { workout.block($0) != nil })
            XCTAssertNotNil(workout.block(.core))
            XCTAssertTrue(workout.movements.allSatisfy { $0.equipment.isSubset(of: settings.equipment) })
            XCTAssertTrue(workout.movements.allSatisfy { !$0.advanced || settings.advancedWall })
            XCTAssertLessThanOrEqual(workout.movements.filter(\.advanced).count, 1)
            XCTAssertEqual(workout.warmupSeconds, 300)
            for minutes in 0...5 {
                XCTAssertEqual(WarmupPlan.steps(for: workout.movements, minutes: minutes).reduce(0) { $0 + $1.seconds }, minutes * 60)
            }
            XCTAssertTrue(workout.warmupSteps.allSatisfy { $0.seconds > 0 && !$0.movement.advanced && $0.movement.equipment.isSubset(of: settings.equipment) })
        }
    }

    func testWallMovementsRequireWallAndOptIn() {
        var settings = WorkoutSettings()
        XCTAssertTrue(WorkoutGenerator.eligible(settings).allSatisfy { !$0.advanced })
        settings.advancedWall = true
        XCTAssertEqual(WorkoutGenerator.eligible(settings).filter(\.advanced).count, 3)
        settings.equipment.remove(.wall)
        XCTAssertTrue(WorkoutGenerator.eligible(settings).allSatisfy { !$0.advanced })
    }

    func testExactDurationAndAlternationForAllSupportedIntervals() {
        for minutes in 5...60 {
            for work in stride(from: 10, through: 90, by: 5) {
                for rest in stride(from: 5, through: 60, by: 5) {
                    var settings = WorkoutSettings()
                    settings.minutes = minutes
                    settings.workSeconds = work
                    settings.restSeconds = rest
                    let block = WorkoutBlock(kind: .conditioning, movements: Array(MovementLibrary.all.prefix(5)), seconds: minutes * 60, workSeconds: work, restSeconds: rest)
                    let intervals = block.intervals
                    XCTAssertEqual(intervals.reduce(0) { $0 + $1.seconds }, minutes * 60)
                    XCTAssertTrue(intervals.allSatisfy { $0.seconds > 0 })
                    for (index, interval) in intervals.enumerated() {
                        XCTAssertEqual(interval.isRest, index % 2 == 1)
                        XCTAssertEqual(interval.movement, MovementLibrary.all[(index / 2) % 5])
                        XCTAssertEqual(interval.round, index / 10 + 1)
                    }
                }
            }
        }
    }

    func testClockPauseResumeAndDelayedTick() {
        var clock = WorkoutClock(duration: 120)
        clock.resume(at: 1000)
        XCTAssertEqual(clock.elapsed(at: 1040), 40)
        clock.pause(at: 1042)
        XCTAssertEqual(clock.elapsed(at: 5000), 42)
        clock.resume(at: 5000)
        XCTAssertEqual(clock.elapsed(at: 5010), 52)
        clock.update(at: 5200)
        XCTAssertEqual(clock.status, .complete)
        XCTAssertEqual(clock.elapsed(at: 5300), 120)
        clock.resume(at: 5400)
        XCTAssertEqual(clock.status, .complete)
    }

    func testWarmupTransitionsIntoFullWODWithCountdown() throws {
        let workout = WorkoutGenerator.generate(settings: WorkoutSettings())
        let intervals = workout.sessionIntervals
        XCTAssertEqual(workout.sessionSeconds, 1500)
        XCTAssertEqual(intervals.reduce(0) { $0 + $1.seconds }, 1500)
        XCTAssertEqual(Array(intervals.dropFirst(workout.warmupSteps.count)), workout.intervals)
        var tracker = IntervalCueTracker()
        _ = tracker.cue(elapsed: 296, intervals: intervals)
        for second in 297...299 {
            XCTAssertEqual(tracker.cue(elapsed: Double(second), intervals: intervals), .countdown)
        }
        XCTAssertEqual(tracker.cue(elapsed: 300, intervals: intervals), .transition)
        let start = try XCTUnwrap(IntervalPosition.resolve(elapsed: 300, intervals: intervals))
        XCTAssertEqual(intervals[start.index].block, .power)
        XCTAssertEqual(intervals[start.index].round, 1)
        XCTAssertEqual(intervals[start.index].movement, workout.movements[0])
        XCTAssertEqual(start.remaining, 20)
        XCTAssertNil(IntervalPosition.resolve(elapsed: 1500, intervals: intervals))
    }

    func testSkipWarmupClockPreservesPauseAndWODDuration() {
        var clock = WorkoutClock(duration: 1500)
        clock.resume(at: 100)
        clock.pause(at: 110)
        clock.advance(to: 300, at: 200)
        XCTAssertEqual(clock.status, .paused)
        XCTAssertEqual(clock.elapsed(at: 1000), 300)
        clock.resume(at: 1000)
        XCTAssertEqual(clock.elapsed(at: 1040), 340)
        clock.advance(to: 300, at: 1040)
        XCTAssertEqual(clock.elapsed(at: 1041), 341)
        clock.update(at: 2200)
        XCTAssertEqual(clock.status, .complete)
    }

    @MainActor
    func testSkippingWarmupKeepsPausedSessionAtFirstWODMovement() {
        var settings = WorkoutSettings()
        settings.sound = false
        settings.haptics = false
        let workout = WorkoutGenerator.generate(settings: settings)
        let session = WorkoutSession(workout: workout)
        defer { session.stop() }
        session.resume()
        session.pause()
        session.skipWarmup()
        XCTAssertFalse(session.isWarmingUp)
        XCTAssertFalse(session.isRunning)
        XCTAssertTrue(session.warmupSkipped)
        XCTAssertEqual(session.movement, workout.movements.first)
        XCTAssertEqual(session.phaseElapsed, 0)
        XCTAssertEqual(session.phaseSeconds, 1200)
        XCTAssertEqual(session.position?.remaining, 20)
        session.resume()
        XCTAssertTrue(session.isRunning)
    }

    @MainActor
    func testSkipIntervalAdvancesToRestThenNextMovement() {
        var settings = WorkoutSettings()
        settings.sound = false
        settings.haptics = false
        let workout = WorkoutGenerator.generate(settings: settings)
        let session = WorkoutSession(workout: workout)
        defer { session.stop() }
        session.skipInterval()
        XCTAssertTrue(session.isWarmingUp)
        XCTAssertTrue(session.warmupSkipped)
        XCTAssertEqual(session.position?.index, 1)
        session.skipWarmup()
        session.skipInterval()
        XCTAssertEqual(session.current?.isRest, true)
        XCTAssertEqual(session.phaseElapsed, Double(workout.intervals[0].seconds))
        session.skipInterval()
        XCTAssertEqual(session.current?.isRest, false)
        XCTAssertEqual(session.movement, workout.intervals[2].movement)
        XCTAssertFalse(session.isRunning)
    }

    func testBoundaryTransitionsAndPartialFinalInterval() {
        var settings = WorkoutSettings()
        settings.minutes = 5
        settings.workSeconds = 45
        settings.restSeconds = 20
        let workout = WorkoutGenerator.generate(settings: settings)
        let intervals = workout.intervals
        XCTAssertEqual(IntervalPosition.resolve(elapsed: 44.9, intervals: intervals)?.remaining, 1)
        XCTAssertEqual(IntervalPosition.resolve(elapsed: 45, intervals: intervals)?.index, 1)
        XCTAssertEqual(IntervalPosition.resolve(elapsed: 65, intervals: intervals)?.index, 2)
        XCTAssertEqual(intervals.last?.seconds, 40)
        XCTAssertNil(IntervalPosition.resolve(elapsed: 300, intervals: intervals))
    }

    @MainActor
    func testSettingsPersistIncludingEmptyInventory() {
        let name = "CFitTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = WorkoutStore(defaults: defaults)
        XCTAssertEqual(store.settings.minutes, 20)
        XCTAssertEqual(store.settings.equipment, Equipment.initial)
        store.settings.equipment = []
        store.settings.minutes = 30
        store.settings.warmupMinutes = 2
        store.settings.advancedWall = true
        let restored = WorkoutStore(defaults: defaults)
        XCTAssertEqual(restored.settings, store.settings)
        XCTAssertEqual(restored.settings.equipment, [])
    }

    func testEveryMovementHasUniqueIDAndDirectVideo() {
        XCTAssertEqual(Set(MovementLibrary.all.map(\.id)).count, MovementLibrary.all.count)
        for movement in MovementLibrary.all {
            XCTAssertEqual(movement.videoID.count, 11)
            XCTAssertEqual(movement.videoURL.host, "www.youtube.com")
            XCTAssertFalse(movement.cue.isEmpty)
            XCTAssertFalse(movement.about.isEmpty)
        }
    }
}
