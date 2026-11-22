import SwiftUI

/// Didelis mikrofono mygtukas. Paspaudus – klausomasi, dar kartą paspaudus – sustabdoma.
struct MicButton: View {
    @Environment(VoiceAssistant.self) private var assistant

    var body: some View {
        let listening = assistant.speech.isListening
        let level = assistant.speech.level

        Button {
            assistant.toggleListening()
        } label: {
            ZStack {
                Circle()
                    .fill(listening ? Color.red.opacity(0.25) : Color.accentColor.opacity(0.18))
                    .frame(width: 96, height: 96)
                    .scaleEffect(listening ? 1 + level * 0.35 : 1)
                    .animation(.easeOut(duration: 0.12), value: level)

                Circle()
                    .fill(listening ? Color.red : Color.accentColor)
                    .frame(width: 76, height: 76)
                    .shadow(color: (listening ? Color.red : Color.accentColor).opacity(0.4), radius: 10, y: 4)

                Image(systemName: listening ? "stop.fill" : "mic.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(listening ? "Sustabdyti klausymą" : "Pradėti klausytis")
        .sensoryFeedback(.impact(weight: .medium), trigger: listening)
    }
}
