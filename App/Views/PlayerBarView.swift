import SwiftUI

/// Read-Aloud transport bar shared by the EPUB and PDF readers.
/// A "unit" is the reader's coarse step: a section for EPUB, a page for PDF.
struct PlayerBarView: View {
    struct Speed: Identifiable {
        let label: String
        let rate: Double
        var id: Double { rate }
    }

    static let speeds = [
        Speed(label: "Slow", rate: 0.42), Speed(label: "Normal", rate: 0.5),
        Speed(label: "Fast", rate: 0.55), Speed(label: "Faster", rate: 0.6)
    ]

    let speech: SpeechEngine
    let positionLabel: String
    let unitName: String          // "Section" or "Page"
    @Binding var rate: Double
    let canGoBack: Bool
    let canGoForward: Bool
    let onPreviousUnit: () -> Void
    let onNextUnit: () -> Void
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(positionLabel)
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Menu {
                    Picker("Speed", selection: $rate) {
                        ForEach(Self.speeds) { Text($0.label).tag($0.rate) }
                    }
                } label: {
                    Label(Self.speeds.first { $0.rate == rate }?.label ?? "Speed", systemImage: "speedometer")
                        .font(.footnote)
                }
            }
            HStack(spacing: 32) {
                Button("Previous \(unitName)", systemImage: "backward.end.fill", action: onPreviousUnit)
                    .disabled(!canGoBack)
                Button("Previous Sentence", systemImage: "gobackward") { speech.skipSentence(-1) }
                    .disabled(speech.state == .idle)
                Button(speech.state == .playing ? "Pause" : "Play",
                       systemImage: speech.state == .playing ? "pause.circle.fill" : "play.circle.fill",
                       action: onToggle)
                    .font(.system(size: 44))
                Button("Next Sentence", systemImage: "goforward") { speech.skipSentence(1) }
                    .disabled(speech.state == .idle)
                Button("Next \(unitName)", systemImage: "forward.end.fill", action: onNextUnit)
                    .disabled(!canGoForward)
            }
            .labelStyle(.iconOnly)
            .font(.title3)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }
}
