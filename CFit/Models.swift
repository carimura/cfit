import Foundation

enum Equipment: String, CaseIterable, Codable, Identifiable {
    case barbell, dumbbells, bands, rack, pullUpBar, box, wall, kettlebell, jumpRope
    var id: String { rawValue }
    static let initial: Set<Equipment> = [.barbell, .dumbbells, .bands, .rack, .pullUpBar, .box, .wall]

    var name: String {
        switch self {
        case .barbell: "Barbell & plates"
        case .dumbbells: "Dumbbells"
        case .bands: "Resistance bands"
        case .rack: "Squat cage"
        case .pullUpBar: "Pull-up bar"
        case .box: "Jump box"
        case .wall: "Wall"
        case .kettlebell: "Kettlebell"
        case .jumpRope: "Jump rope"
        }
    }

    var symbol: String {
        switch self {
        case .barbell, .dumbbells, .kettlebell: "dumbbell"
        case .bands, .jumpRope: "lasso"
        case .rack, .pullUpBar: "figure.strengthtraining.functional"
        case .box: "cube"
        case .wall: "square.split.2x2"
        }
    }
}

enum Pattern: String, CaseIterable {
    case squat = "Squat / lunge", hinge = "Hinge", push = "Push", pull = "Pull", conditioning = "Conditioning", core = "Core"
    var symbol: String {
        switch self {
        case .core: "figure.core.training"
        case .squat: "figure.strengthtraining.functional"
        case .hinge: "figure.strengthtraining.traditional"
        case .push: "figure.core.training"
        case .pull: "dumbbell"
        case .conditioning: "flame"
        }
    }
}

struct Movement: Identifiable, Equatable {
    let id: String
    let name: String
    let pattern: Pattern
    let equipment: Set<Equipment>
    let advanced: Bool
    let cue: String
    let videoID: String
    let source: String
    /// What the movement is and its proper form; empty for warm-up drills, whose cue covers both.
    var about = ""

    var videoURL: URL { URL(string: "https://www.youtube.com/watch?v=\(videoID)")! }
    var equipmentLabel: String {
        equipment.isEmpty ? "Bodyweight" : equipment.sorted { $0.rawValue < $1.rawValue }.map(\.name).joined(separator: " + ")
    }
}

struct WorkoutSettings: Codable, Equatable {
    var minutes = 20
    var warmupMinutes = 5
    var workSeconds = 40
    var restSeconds = 20
    var equipment = Equipment.initial
    var advancedWall = false
    var sound = true
    var haptics = true

    init() {}

    // Settings saved before warm-up length existed still decode.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        minutes = try c.decode(Int.self, forKey: .minutes)
        warmupMinutes = try c.decodeIfPresent(Int.self, forKey: .warmupMinutes) ?? 5
        workSeconds = try c.decode(Int.self, forKey: .workSeconds)
        restSeconds = try c.decode(Int.self, forKey: .restSeconds)
        equipment = try c.decode(Set<Equipment>.self, forKey: .equipment)
        advancedWall = try c.decode(Bool.self, forKey: .advancedWall)
        sound = try c.decode(Bool.self, forKey: .sound)
        haptics = try c.decode(Bool.self, forKey: .haptics)
    }

    mutating func normalize() {
        minutes = min(60, max(10, (minutes + 5) / 10 * 10))
        warmupMinutes = min(5, max(0, warmupMinutes))
        workSeconds = min(90, max(10, workSeconds))
        restSeconds = min(60, max(5, restSeconds))
    }
}

/// Session order: power while fresh, then strength, then the conditioning circuit, with core last.
enum Block: String {
    case warmup = "Warm-up", power = "Power", strength = "Strength", conditioning = "Conditioning", core = "Core"
}

struct WorkoutBlock: Identifiable {
    let kind: Block
    let movements: [Movement]
    let seconds: Int
    let workSeconds: Int
    let restSeconds: Int
    var id: Block { kind }

    var prescription: String? {
        switch kind {
        case .power: "Every minute: 3–5 fast, explosive reps"
        case .strength: "Each set: 5 heavy reps"
        default: nil
        }
    }

    /// Work/rest pairs cycling through the movements; the last interval is shortened to end exactly on time.
    var intervals: [WorkoutInterval] {
        var result: [WorkoutInterval] = []
        var remaining = seconds
        var station = 0
        guard !movements.isEmpty else { return [] }
        while remaining > 0 {
            let movement = movements[station % movements.count]
            let round = station / movements.count + 1
            let work = min(remaining, workSeconds)
            result.append(WorkoutInterval(movement: movement, block: kind, round: round, isRest: false, seconds: work))
            remaining -= work
            if remaining > 0 {
                let rest = min(remaining, restSeconds)
                result.append(WorkoutInterval(movement: movement, block: kind, round: round, isRest: true, seconds: rest))
                remaining -= rest
            }
            station += 1
        }
        return result
    }
    var rounds: Int { intervals.last?.round ?? 0 }
}

struct Workout: Identifiable {
    let id = UUID()
    let blocks: [WorkoutBlock]
    let settings: WorkoutSettings
    var movements: [Movement] { blocks.flatMap(\.movements) }
    var totalSeconds: Int { settings.minutes * 60 }
    var intervals: [WorkoutInterval] { blocks.flatMap(\.intervals) }
    func block(_ kind: Block) -> WorkoutBlock? { blocks.first { $0.kind == kind } }
    var warmupSteps: [WarmupStep] {
        WarmupPlan.steps(for: blocks.filter { $0.kind != .core }.flatMap(\.movements), minutes: settings.warmupMinutes)
    }
    var warmupSeconds: Int { warmupSteps.reduce(0) { $0 + $1.seconds } }
    var sessionSeconds: Int { warmupSeconds + totalSeconds }
    var sessionIntervals: [WorkoutInterval] {
        warmupSteps.map {
            WorkoutInterval(movement: $0.movement, block: .warmup, round: 0, isRest: false, seconds: $0.seconds)
        } + intervals
    }
}

struct WorkoutInterval: Equatable {
    let movement: Movement
    let block: Block
    let round: Int
    let isRest: Bool
    let seconds: Int
}

enum WorkoutGenerator {
    static func eligible(_ settings: WorkoutSettings) -> [Movement] {
        MovementLibrary.all.filter {
            $0.equipment.isSubset(of: settings.equipment) && (!$0.advanced || settings.advancedWall)
        }
    }

    static let powerIDs: Set = ["power-clean", "dumbbell-power-clean", "dumbbell-power-snatch", "box-jump", "kettlebell-swing"]
    static let strengthIDs: Set = ["back-squat", "front-squat", "deadlift", "shoulder-press"]
    static let dumbbellStrengthIDs: Set = ["dumbbell-front-squat", "dumbbell-deadlift"]

    static func generate<R: RandomNumberGenerator>(settings: WorkoutSettings, using rng: inout R) -> Workout {
        let pool = eligible(settings)
        let minutes = settings.minutes
        // Short sessions skip power and strength and go straight to conditioning.
        let power = minutes >= 20 ? pool.filter { powerIDs.contains($0.id) }.randomElement(using: &rng) : nil
        let barbellLifts = pool.filter { strengthIDs.contains($0.id) }
        let strength = minutes >= 20 ? (barbellLifts.isEmpty ? pool.filter { dumbbellStrengthIDs.contains($0.id) } : barbellLifts).randomElement(using: &rng) : nil
        // One movement per pattern keeps circuits varied and limits inversion to one station.
        let circuit = Pattern.allCases.filter { $0 != .core }.compactMap { pattern in
            pool.filter { $0.pattern == pattern && $0 != power && $0 != strength }.randomElement(using: &rng)
        }.shuffled(using: &rng)
        let core = Array(pool.filter { $0.pattern == .core }.shuffled(using: &rng).prefix(2))

        // About 15% power (1-minute EMOM), 25% strength (whole 2-minute sets), 15% core, the rest conditioning.
        let powerSeconds = power == nil ? 0 : minutes * 15 / 100 * 60
        let strengthSeconds = strength == nil ? 0 : minutes / 4 / 2 * 120
        let coreSeconds = minutes * 15 / 100 * 60
        let conditioningSeconds = minutes * 60 - powerSeconds - strengthSeconds - coreSeconds
        let blocks = [
            WorkoutBlock(kind: .power, movements: power.map { [$0] } ?? [], seconds: powerSeconds, workSeconds: 20, restSeconds: 40),
            WorkoutBlock(kind: .strength, movements: strength.map { [$0] } ?? [], seconds: strengthSeconds, workSeconds: 40, restSeconds: 80),
            WorkoutBlock(kind: .conditioning, movements: circuit, seconds: conditioningSeconds, workSeconds: settings.workSeconds, restSeconds: settings.restSeconds),
            WorkoutBlock(kind: .core, movements: core, seconds: coreSeconds, workSeconds: 30, restSeconds: 15)
        ].filter { $0.seconds > 0 && !$0.movements.isEmpty }
        return Workout(blocks: blocks, settings: settings)
    }

    static func generate(settings: WorkoutSettings) -> Workout {
        var rng = SystemRandomNumberGenerator()
        return generate(settings: settings, using: &rng)
    }
}

/// Monotonic elapsed time; independent of UI refresh frequency.
struct WorkoutClock {
    enum Status { case ready, running, paused, complete }
    private(set) var status: Status = .ready
    private var accumulated: TimeInterval = 0
    private var startedAt: TimeInterval = 0
    let duration: TimeInterval

    init(duration: TimeInterval) { self.duration = duration }

    func elapsed(at now: TimeInterval) -> TimeInterval {
        min(duration, max(0, accumulated + (status == .running ? now - startedAt : 0)))
    }

    mutating func resume(at now: TimeInterval) {
        guard status == .ready || status == .paused else { return }
        startedAt = now
        status = .running
    }

    mutating func pause(at now: TimeInterval) {
        guard status == .running else { return }
        accumulated = elapsed(at: now)
        status = accumulated >= duration ? .complete : .paused
    }

    mutating func update(at now: TimeInterval) {
        if status == .running && elapsed(at: now) >= duration {
            accumulated = duration
            status = .complete
        }
    }

    mutating func advance(to seconds: TimeInterval, at now: TimeInterval) {
        accumulated = min(duration, max(elapsed(at: now), seconds))
        startedAt = now
        if accumulated >= duration { status = .complete }
    }
}

struct IntervalPosition {
    let index: Int
    let remaining: Int
    let progress: Double

    static func resolve(elapsed: TimeInterval, intervals: [WorkoutInterval]) -> IntervalPosition? {
        var start = 0
        for (index, interval) in intervals.enumerated() {
            let end = start + interval.seconds
            if elapsed < Double(end) {
                return IntervalPosition(index: index, remaining: Int(ceil(Double(end) - elapsed)), progress: (elapsed - Double(start)) / Double(interval.seconds))
            }
            start = end
        }
        return nil
    }
}

func timeLabel(_ seconds: Int) -> String {
    String(format: "%02d:%02d", max(0, seconds) / 60, max(0, seconds) % 60)
}

enum IntervalCue: String, CaseIterable {
    case countdown = "countdown"
    case transition = "interval"
}

struct IntervalCueTracker {
    private var lastInterval = 0
    private var lastRemaining: Int?
    private var finished = false

    mutating func cue(elapsed: TimeInterval, intervals: [WorkoutInterval]) -> IntervalCue? {
        guard !finished else { return nil }
        guard let position = IntervalPosition.resolve(elapsed: elapsed, intervals: intervals) else {
            finished = true
            return .transition
        }
        defer {
            lastInterval = position.index
            lastRemaining = position.remaining
        }
        // A late refresh plays only the current cue, never a burst of missed beeps.
        if position.index != lastInterval { return .transition }
        if position.remaining <= 3 && position.remaining != lastRemaining { return .countdown }
        return nil
    }
}
