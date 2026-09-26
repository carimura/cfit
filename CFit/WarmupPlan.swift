import Foundation

struct WarmupStep: Identifiable {
    let movement: Movement
    let seconds: Int
    var id: String { movement.id }
}

enum WarmupPlan {
    static let general: [Movement] = [
        drill("march", "Easy marching", .conditioning, "March in place and let your arms swing. Start gently and gradually pick up the pace; you should be able to talk comfortably.", "u1gmWFvEluM"),
        drill("arm-circles", "Arm circles", .push, "Make gentle circles with your arms, gradually opening the range. Reverse direction halfway through. Keep it comfortable.", "P3dzI9opLGE"),
        drill("lunge-reach", "Lunge & reach", .squat, "Alternate shallow forward lunges with a gentle overhead reach. Return to standing between reps; move smoothly without holding the stretch.", "faGH-tlwd_w")
    ]

    /// One minute per general drill first, then any remaining minutes of WOD-specific practice.
    static func steps(for movements: [Movement], minutes: Int = 5) -> [WarmupStep] {
        guard !movements.isEmpty, minutes > 0 else { return [] }
        let generalSteps = general.prefix(minutes).map { WarmupStep(movement: $0, seconds: 60) }
        let practiceSeconds = max(0, minutes - general.count) * 60
        guard practiceSeconds > 0 else { return generalSteps }
        // Easy rehearsal, shared across the actual WOD movements.
        let practice = movements.enumerated().map { index, movement in
            WarmupStep(movement: preparation(for: movement), seconds: practiceSeconds / movements.count + (index < practiceSeconds % movements.count ? 1 : 0))
        }
        return generalSteps + practice
    }

    private static func preparation(for movement: Movement) -> Movement {
        let reference: Movement
        let cue: String
        if movement.advanced {
            reference = MovementLibrary.all.first { $0.id == "push-up" }!
            cue = "Prepare for \(movement.name.lowercased()) with a few easy knee push-ups. Stay out of inversion here. Pause for extra wrist and skill preparation before the WOD if needed."
        } else if movement.id == "box-jump" {
            reference = MovementLibrary.all.first { $0.id == "box-step-up" }!
            cue = "Prepare for box jumps with slow step-ups. Alternate the leading leg and step down with control."
        } else {
            reference = movement
            let load = movement.equipment.isDisjoint(with: [.barbell, .dumbbells, .kettlebell])
                ? "Keep the effort easy and the range comfortable."
                : "Use an empty bar or a very light weight."
            cue = "Rehearse a few controlled reps, then rest. \(load) For holds, use a brief easy hold. Take extra preparation time if needed."
        }
        return Movement(id: "warmup-\(movement.id)", name: "Practice: \(reference.name.lowercased())", pattern: reference.pattern, equipment: reference.equipment, advanced: false, cue: cue, videoID: reference.videoID, source: reference.source)
    }

    private static func drill(_ id: String, _ name: String, _ pattern: Pattern, _ cue: String, _ videoID: String) -> Movement {
        Movement(id: "warmup-\(id)", name: name, pattern: pattern, equipment: [], advanced: false, cue: cue, videoID: videoID, source: "https://www.youtube.com/watch?v=\(videoID)")
    }
}
