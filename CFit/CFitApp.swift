import SwiftUI

@main
struct CFitApp: App {
    @State private var store = WorkoutStore()

    var body: some Scene {
        WindowGroup {
            HomeView(store: store)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
    }
}

enum Theme {
    static let background = Color(red: 0.075, green: 0.063, blue: 0.055)
    static let card = Color(red: 0.145, green: 0.122, blue: 0.106)
    static let accent = Color(red: 0.89, green: 0.40, blue: 0.09)
    static let muted = Color(red: 0.73, green: 0.68, blue: 0.64)
    static let rest = Color(red: 0.51, green: 0.80, blue: 0.96)
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 19)
            .foregroundStyle(Theme.background)
            .background(Theme.accent.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 18))
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased()).font(.system(.caption, design: .monospaced, weight: .semibold))
            .tracking(2).foregroundStyle(Theme.muted)
    }
}

extension View {
    func card() -> some View {
        padding(20).background(Theme.card, in: RoundedRectangle(cornerRadius: 22))
    }
}
