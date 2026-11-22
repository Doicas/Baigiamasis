import AVFoundation
import Foundation
import Observation
import Speech

/// Kalbos atpažinimas realiu laiku. Klausymas automatiškai baigiamas, kai nutylate.
@MainActor
@Observable
final class SpeechRecognizer {
    private(set) var transcript = ""
    private(set) var isListening = false
    private(set) var errorMessage: String?
    /// Garso lygis 0…1 animacijai.
    private(set) var level: Double = 0

    private(set) var localeIdentifier: String

    /// Iškviečiama su galutiniu tekstu, kai klausymas baigiasi.
    @ObservationIgnored var onFinish: ((String) -> Void)?

    @ObservationIgnored private let audioEngine = AVAudioEngine()
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    @ObservationIgnored private var silenceTask: Task<Void, Never>?
    private static let localeKey = "speechLocale"

    /// Kalbos, kurias siūlome (jei įrenginys jas palaiko).
    static let preferredLocales = ["lt-LT", "en-US", "en-GB"]

    static var availableLocales: [String] {
        let supported = Set(SFSpeechRecognizer.supportedLocales().map { $0.identifier.replacingOccurrences(of: "_", with: "-") })
        let available = preferredLocales.filter { supported.contains($0) }
        return available.isEmpty ? ["en-US"] : available
    }

    static func displayName(for identifier: String) -> String {
        Locale(identifier: "lt-LT").localizedString(forIdentifier: identifier)?.capitalized ?? identifier
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: Self.localeKey)
        let available = Self.availableLocales
        localeIdentifier = saved.flatMap { available.contains($0) ? $0 : nil } ?? available[0]
    }

    func setLocale(_ identifier: String) {
        localeIdentifier = identifier
        UserDefaults.standard.set(identifier, forKey: Self.localeKey)
    }

    var isLithuanianSupported: Bool {
        Self.availableLocales.contains("lt-LT")
    }

    // MARK: Leidimai

    private func requestPermissions() async -> Bool {
        let speechStatus = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard speechStatus == .authorized else {
            errorMessage = "Leiskite kalbos atpažinimą: Nustatymai → Šviesos → Kalbos atpažinimas."
            return false
        }
        guard await AVAudioApplication.requestRecordPermission() else {
            errorMessage = "Leiskite naudoti mikrofoną: Nustatymai → Šviesos → Mikrofonas."
            return false
        }
        return true
    }

    // MARK: Klausymas

    func start(contextualStrings: [String] = []) async {
        guard !isListening else { return }
        errorMessage = nil
        guard await requestPermissions() else { return }

        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)),
              recognizer.isAvailable else {
            errorMessage = "Kalbos atpažinimas šiuo metu nepasiekiamas. Patikrinkite interneto ryšį."
            return
        }

        transcript = ""
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement,
                                    options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.taskHint = .confirmation
            request.contextualStrings = contextualStrings
            self.request = request

            Self.installTap(on: audioEngine.inputNode, request: request) { [weak self] level in
                Task { @MainActor in self?.level = level }
            }
            audioEngine.prepare()
            try audioEngine.start()

            isListening = true
            task = Self.makeTask(recognizer: recognizer, request: request) { [weak self] text, isFinal, failed in
                Task { @MainActor in self?.handle(text: text, isFinal: isFinal, failed: failed) }
            }
            // Jei nieko nepasakoma – po 6 s sustojame.
            scheduleSilenceTimeout(seconds: 6)
        } catch {
            errorMessage = "Nepavyko įjungti mikrofono: \(error.localizedDescription)"
            cleanUp()
        }
    }

    /// Sustabdo klausymą ir perduoda išgirstą tekstą.
    func stop() {
        guard isListening else { return }
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        cleanUp()
        if !text.isEmpty { onFinish?(text) }
    }

    func cancel() {
        transcript = ""
        cleanUp()
    }

    private func handle(text: String?, isFinal: Bool, failed: Bool) {
        guard isListening else { return }
        if let text, !text.isEmpty {
            transcript = text
            // Po trumpos tylos laikome, kad komanda baigta.
            scheduleSilenceTimeout(seconds: 1.3)
        }
        if isFinal || failed { stop() }
    }

    private func scheduleSilenceTimeout(seconds: Double) {
        silenceTask?.cancel()
        silenceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.stop()
        }
    }

    private func cleanUp() {
        silenceTask?.cancel()
        silenceTask = nil
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isListening = false
        level = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: Garso gijos pagalbinės (ne pagrindinėje gijoje)

    nonisolated private static func installTap(on input: AVAudioInputNode,
                                               request: SFSpeechAudioBufferRecognitionRequest,
                                               onLevel: @escaping @Sendable (Double) -> Void) {
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
            guard let samples = buffer.floatChannelData?[0] else { return }
            let count = Int(buffer.frameLength)
            guard count > 0 else { return }
            var sum: Float = 0
            for index in 0..<count { sum += samples[index] * samples[index] }
            let rms = sqrt(sum / Float(count))
            onLevel(min(1, Double(rms) * 12))
        }
    }

    nonisolated private static func makeTask(recognizer: SFSpeechRecognizer,
                                             request: SFSpeechAudioBufferRecognitionRequest,
                                             handler: @escaping @Sendable (String?, Bool, Bool) -> Void)
        -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { result, error in
            handler(result?.bestTranscription.formattedString, result?.isFinal ?? false, error != nil)
        }
    }
}
