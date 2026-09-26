# CFit — app plan

## Purpose

A personal native mobile app that generates varied, CrossFit-style workouts using the equipment available at home, then guides each workout with exercise and rest timers.

## Requested behavior

- Default WOD duration: 20 minutes; user can select another duration.
- Begin with a five-minute guided warm-up: easy movement, dynamic mobility, then light WOD-specific practice.
- Generate a random but coherent workout from compatible exercises.
- Maintain equipment inventory in settings.
- Start a timer for each exercise interval, play short beeps at 3, 2, and 1 second remaining and a long beep at zero, automatically run the rest timer with the same cues, then advance to the next exercise or round.
- Provide an optional YouTube form demonstration for every exercise.
- Include wall-based exercises.

## Starting equipment

- Barbell and weight plates
- Dumbbells
- Resistance/tension bands
- Squat cage
- Pull-up bar on the cage
- Jump box
- Wall
- Bodyweight exercises available without equipment

## First version

### Workout setup

- Plain, functional interface: duration, warm-up, exercises, and start controls. No slogans or motivational copy.

- Duration picker defaults to 20 minutes.
- Work/rest settings have a proposed default of 40 seconds work / 20 seconds rest.
- Preview shows movements, work/rest intervals, and total elapsed workout duration. The active workout shows the current round.
- Regenerate a workout or replace one movement before starting.
- Selected WOD duration includes rest. The five-minute warm-up is additional; default total session time is 25 minutes.

### Workout generation

- Build circuits from a curated movement library with equipment requirements, movement patterns, difficulty, form cues, and a YouTube demonstration URL.
- Mix squat/lunge, hinge, push, pull, and conditioning/core movements rather than selecting every movement independently.
- Use only equipment enabled in settings.
- Make advanced movements such as wall walks or handstand push-ups opt-in.
- Offer load guidance without inventing personalized weights or requiring max-effort lifting.
- Begin with timed circuits, which directly support automatic exercise/rest transitions. Other WOD formats can be considered later.

### Active workout

- Large countdown, current movement, work/rest state, round, and next movement.
- Automatic transitions with an audible cue and supported device haptics.
- Pause/resume and end-workout controls. Warm-up can be skipped when already prepared; skipping preserves a paused state and the full WOD duration.
- Optional form video access pauses an active workout; returning does not resume without an explicit action.
- Use elapsed-time-based timing to avoid accumulated timer drift.
- Keep the screen awake during an active workout. Confirm background/lock-screen behavior and audio limitations for the selected platform before implementation.
- End with a simple completed-workout summary.

### Settings and storage

- Persist equipment inventory, duration, interval settings, and advanced-movement preference locally.
- Equipment additions enable movements already supported by the library; unknown custom equipment needs associated movements before it affects generation.
- No account or backend needed for the first version.

## Confirmed decisions

- Native iPhone app using SwiftUI, targeting iOS 17 or later.
- Include wall walks, wall-supported handstands, and strict handstand push-ups. Advanced wall movements are individually described and enabled together through an opt-in setting.
- First version runs workouts in the foreground, keeps the screen awake, and pauses automatically on backgrounding or interruptions. Returning requires explicit resume, avoiding missed transitions while iOS suspends the app.
- Local storage only; no third-party packages or backend.

## Implementation status

- SwiftUI iPhone app and Xcode project implemented.
- 23-movement library, equipment filtering, pattern-balanced generator, and same-pattern movement replacement implemented.
- Local settings, workout preview, guided warm-up, form guides, timer, audio/haptic cues, pause/resume, and completion summary implemented.
- Direct demonstration URLs checked against YouTube metadata; provenance recorded in `VIDEO_SOURCES.md`.
- Unit coverage includes all 512 supported inventory combinations and 11,424 duration/work/rest combinations, plus clock boundaries and preference persistence.
- Simulator UI coverage includes pausing, opening a form guide, returning from the background, and automatic interval advancement.
- Physical iPhone installation requires selecting a signing team in Xcode. Device audio loudness/routing, haptics, and phone-call interruptions remain hands-on checks.

## Deliberate first-version boundaries

- Foreground workouts only; leaving or locking the app pauses training.
- Inventory supports the listed equipment plus kettlebell and jump rope. Custom equipment/movement authoring is not included.
- No accounts, history, workout restoration after process termination, or rep-counted WOD modes.
