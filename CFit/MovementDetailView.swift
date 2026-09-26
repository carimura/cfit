import SwiftUI
import WebKit

struct MovementDetailView: View {
    let movement: Movement
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    YouTubePlayer(videoID: movement.videoID)
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .background(Theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .accessibilityIdentifier("videoPlayer")
                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow(text: movement.advanced ? "Advanced · \(movement.pattern.rawValue)" : movement.pattern.rawValue)
                        Text(movement.name).font(.largeTitle.bold())
                        Text(movement.equipmentLabel).foregroundStyle(Theme.muted)
                    }
                    if !movement.about.isEmpty {
                        Text(movement.about).font(.title3).lineSpacing(5)
                    }
                    Text(movement.cue).font(movement.about.isEmpty ? .title3 : .body).lineSpacing(5)
                    Link(destination: movement.videoURL) {
                        Label("Open in YouTube", systemImage: "arrow.up.right.square")
                    }.font(.footnote).accessibilityIdentifier("watchVideo")
                }.padding(24)
            }
            .background(Theme.background)
            .navigationTitle("Movement guide").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

/// Plays a YouTube demonstration inline instead of leaving the app.
struct YouTubePlayer: UIViewRepresentable {
    let videoID: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.isScrollEnabled = false
        // YouTube's embed player requires an identifying HTTPS origin/referrer.
        let html = """
        <!doctype html><meta name="viewport" content="width=device-width,initial-scale=1">
        <style>html,body{margin:0;height:100%;background:transparent}iframe{border:0;width:100%;height:100%}</style>
        <iframe src="https://www.youtube.com/embed/\(videoID)?playsinline=1&rel=0&modestbranding=1"
          allow="autoplay; encrypted-media; picture-in-picture; fullscreen" allowfullscreen
          referrerpolicy="strict-origin-when-cross-origin"></iframe>
        """
        view.loadHTMLString(html, baseURL: URL(string: "https://\(Bundle.main.bundleIdentifier ?? "com.chad.cfit")"))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {}
}

