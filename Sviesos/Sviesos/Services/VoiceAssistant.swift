import AVFoundation
import Foundation
import Observation

/// Sujungia kalbos atpažinimą, komandų vykdymą ir balso atsakymą.
@MainActor
@Observable
final class VoiceAssistant {
    static let shared = VoiceAssistant(store: .shared)

    struct HistoryEntry: Identifiable {
        let id = UUID()
        let command: String
        let outcome: CommandOutcome
    }

    let store: LightStore
    let speech = SpeechRecognizer()

    private(set) var lastOutcome: CommandOutcome?
    private(set) var history: [HistoryEntry] = []
    private(set) var isProcessing = false
    /// Didėja po kiekvienos komandos – naudojama vibracijai (haptic) paleisti.
    private(set) var feedbackCount = 0

    private(set) var speaksResponses: Bool
    private static let speakKey = "speakResponses"

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()

    init(store: LightStore) {
        self.store = store
        speaksResponses = UserDefaults.standard.object(forKey: Self.speakKey) as? Bool ?? true
        speech.onFinish = { [weak self] text in
            Task { await self?.handle(text) }
        }
    }

    func setSpeaksResponses(_ value: Bool) {
        speaksResponses = value
        UserDefaults.standard.set(value, forKey: Self.speakKey)
    }

    var isListening: Bool { speech.isListening }

    func toggleListening() {
        if speech.isListening {
            speech.stop()
        } else {
            startListening()
        }
    }

    func startListening() {
        synthesizer.stopSpeaking(at: .immediate)
        Task {
            await store.ensureLoaded()
            await speech.start(contextualStrings: store.vocabulary)
        }
    }

    /// Vykdo tekstinę komandą (išgirstą arba įvestą klaviatūra).
    func handle(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isProcessing = true
        let outcome = await store.run(trimmed)
        isProcessing = false
        lastOutcome = outcome
        history.insert(HistoryEntry(command: trimmed, outcome: outcome), at: 0)
        if history.count > 20 { history.removeLast() }
        feedbackCount += 1
        speak(outcome.message)
    }

    private func speak(_ text: String) {
        guard speaksResponses else { return }
        // Atsakymai lietuviški, todėl reikia lietuviško balso. Jei jo įrenginyje nėra – tylime
        // (balsą galima atsisiųsti: Nustatymai → Pritaikymas neįgaliesiems → Įgarsintas turinys → Balsai).
        guard let voice = AVSpeechSynthesisVoice(language: "lt-LT") else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .voicePrompt, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        synthesizer.speak(utterance)
    }
}
