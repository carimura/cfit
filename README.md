# CFit

A personal native iPhone app for randomized, equipment-aware functional fitness workouts with guided work/rest timers and optional YouTube form demonstrations. Built with SwiftUI for iOS 17+, with no third-party dependencies or backend.

Each session starts with a guided warm-up (0–5 minutes, default 5), followed by a workout that defaults to 20 minutes. Initial equipment includes a barbell and plates, dumbbells, resistance bands, a squat cage with a pull-up bar, a jump box, and a wall.

## Run on iPhone or simulator

1. Open `CFit.xcodeproj` in Xcode.
2. Choose the **CFit** scheme and an iPhone simulator, then Run.
3. For a physical iPhone, select your signing team under **CFit → Signing & Capabilities**, choose a unique bundle identifier if needed, connect the phone, and Run. Device installation requires your Apple signing identity and Developer Mode on the phone.

The checked-in project opens directly. If changing project configuration, edit `project.yml` and run `xcodegen generate`.

## First version

- Workout length: 10–60 minutes in 10-minute steps (default 20). Warm-up length: 0–5 minutes (default 5).
- Warm-up: one minute each of easy marching, arm circles, and lunge & reach, then light practice of the day's movements. Shorter warm-ups drop steps from the end. Optional form guides and a skip control are included.
- Workouts follow a fixed order: **power** (1-minute EMOM of an explosive lift or jump, ~15%), **strength** (one heavy lift in 2-minute sets, ~25%), **conditioning** (a circuit, remaining time), and **core** (two movements, ~15%). Workouts under 20 minutes skip power and strength.
- The conditioning circuit selects one movement per pattern (squat, hinge, push, pull, conditioning); its work/rest (default 40s/20s) is configurable in settings. Regenerate the whole workout before starting.
- 32 movements with equipment requirements, short form cues, descriptions, and direct YouTube demonstrations. See [VIDEO_SOURCES.md](VIDEO_SOURCES.md).
- Inventory starts with the requested equipment and wall. Enable additional supported gear, including a kettlebell and jump rope, in settings.
- Wall sits are available by default. Turn on **Advanced wall movements** to include wall walks, wall handstand holds, and strict handstand push-ups. At most one advanced movement appears per circuit.
- Automatic work/rest transitions, countdown beeps, haptic cues, pause/resume, and completion summary.
- Settings persist locally. Workout generation and timing work offline; demonstrations require internet.

## Timing and audio behavior

The selected WOD time includes rest, including the final rest interval when present. The five-minute warm-up is additional and has its own progress indicator; completing or skipping it starts the full selected WOD. The last interval is shortened if needed to finish at the selected duration. Rounds may be partial. The timer measures monotonic elapsed time instead of counting UI ticks.

Workouts run in the foreground and keep the screen awake. Leaving the app, locking the phone, receiving an audio interruption, or opening a form guide pauses the session. Returning never automatically resumes it. The workout must remain open for automatic transitions; this version does not run lock-screen/background workouts or restore a session after the app is terminated.

Each warm-up step, work interval, and rest interval plays short beeps at 3, 2, and 1 second remaining, then a higher-pitched long beep at zero (including workout completion). Pausing stops audio; resuming does not replay an already-triggered cue. Delayed timer updates skip missed cues instead of playing a backlog.

Beeps use the playback audio category and the current media volume/output. Use **Test countdown beeps** in settings to preview the full sequence and adjust the phone’s volume before training. CFit does not override the system volume. Physical-device speaker volume, Bluetooth routing, haptics, and phone-call interruptions still need hands-on validation.

This first version provides interval circuits, not AMRAP/rep-counted benchmark programming. It does not prescribe personalized loads, record workout history, or accept custom movement definitions.

## Development and tests

```sh
xcodebuild -project CFit.xcodeproj -scheme CFit \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath build -parallel-testing-enabled NO test CODE_SIGNING_ALLOWED=NO
```

Choose an available simulator name if yours differs. Unit tests cover inventory filtering, advanced wall opt-in, interval accounting, exact boundaries, pause/resume, movement replacements, and persisted settings. UI tests exercise workout controls, form guides, background pausing, and live work/rest/next-movement transitions.

## Files

- `CFit/Models.swift`: equipment, generation, interval schedule, and clock.
- `CFit/MovementLibrary.swift`: curated movement definitions.
- `CFit/WarmupPlan.swift`: general mobility and WOD-specific preparation.
- `CFit/WorkoutStore.swift`: local preferences.
- `CFit/WorkoutSession.swift`: timer, audio, haptics, and wake state.
- `CFit/*View.swift`: native screens.
- `CFitTests/`, `CFitUITests/`: automated validation.
