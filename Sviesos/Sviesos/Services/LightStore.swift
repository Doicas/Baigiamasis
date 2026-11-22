import Foundation
import Observation

/// Pagrindinė programėlės būsena: šviestuvų sąrašas ir komandų vykdymas.
/// Naudojama ir ekrane, ir Siri / Shortcuts / Action Button komandose.
@MainActor
@Observable
final class LightStore {
    static let shared = LightStore()

    enum Source: String, CaseIterable, Identifiable {
        case homeKit
        case demo

        var id: String { rawValue }
        var title: String {
            switch self {
            case .homeKit: return "HomeKit (tikri šviestuvai)"
            case .demo: return "Demonstracinis režimas"
            }
        }
    }

    private(set) var lights: [Light] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var statusMessage: String?
    private(set) var source: Source

    @ObservationIgnored private var homeKit: HomeKitLightBackend?
    @ObservationIgnored private let demo = DemoLightBackend()
    private static let sourceKey = "lightSource"

    init() {
        #if targetEnvironment(simulator)
        let fallback = Source.demo
        #else
        let fallback = Source.homeKit
        #endif
        let saved = UserDefaults.standard.string(forKey: Self.sourceKey).flatMap(Source.init(rawValue:))
        source = saved ?? fallback
    }

    var rooms: [String] {
        var seen = Set<String>()
        return lights.map(\.room).filter { seen.insert($0).inserted }
    }

    func lights(in room: String) -> [Light] {
        lights.filter { $0.room == room }
    }

    /// Žodžiai, padedantys kalbos atpažinimui (kambarių ir šviestuvų pavadinimai).
    var vocabulary: [String] {
        Array(Set(lights.map(\.name) + lights.map(\.room)))
    }

    // MARK: Šaltinis ir įkėlimas

    private var backend: LightBackend {
        switch source {
        case .demo:
            return demo
        case .homeKit:
            if let homeKit { return homeKit }
            let created = HomeKitLightBackend()
            attach(created)
            homeKit = created
            return created
        }
    }

    func setSource(_ newValue: Source) {
        guard newValue != source else { return }
        source = newValue
        UserDefaults.standard.set(newValue.rawValue, forKey: Self.sourceKey)
        lights = []
        hasLoaded = false
        Task { await reload() }
    }

    @ObservationIgnored private var loadTask: Task<Void, Never>?

    /// Įkelia šviestuvus iš naujo. Jei įkėlimas jau vyksta – palaukia jo pabaigos ir įkelia dar kartą.
    func reload() async {
        while let running = loadTask { await running.value }
        let task = Task {
            await performReload()
            loadTask = nil
        }
        loadTask = task
        await task.value
    }

    private func performReload() async {
        let current = backend
        if current === demo { attach(demo) }
        isLoading = true
        defer { isLoading = false }
        await current.load()
        // Kol kraunama, vartotojas galėjo perjungti šaltinį.
        guard current === backend else { return }
        lights = current.snapshot()
        statusMessage = current.statusMessage
        hasLoaded = true
    }

    func ensureLoaded() async {
        if !hasLoaded { await reload() }
    }

    private func attach(_ backend: LightBackend) {
        backend.onChange = { [weak self, weak backend] needsReload in
            guard let self, let backend, backend === self.backend else { return }
            if needsReload {
                Task { await self.reload() }
            } else {
                self.lights = backend.snapshot()
            }
        }
    }

    // MARK: Tiesioginis valdymas (iš ekrano)

    func setPower(_ isOn: Bool, for light: Light) async {
        await perform(ParsedCommand(action: isOn ? .turnOn : .turnOff,
                                    lightIDs: [light.id], targetDescription: light.name))
    }

    func setBrightness(_ value: Int, for light: Light) async {
        await perform(ParsedCommand(action: .setBrightness(value),
                                    lightIDs: [light.id], targetDescription: light.name))
    }

    @discardableResult
    func setAll(_ isOn: Bool) async -> CommandOutcome {
        await ensureLoaded()
        return await perform(ParsedCommand(action: isOn ? .turnOn : .turnOff,
                                           lightIDs: lights.map(\.id), targetDescription: "visos šviesos"))
    }

    // MARK: Balso / teksto komandos

    /// Atpažįsta ir įvykdo komandą, pvz., „įjunk šviesą svetainėje“.
    func run(_ text: String) async -> CommandOutcome {
        await ensureLoaded()
        switch CommandParser.parse(text, lights: lights) {
        case .success(let command):
            return await perform(command)
        case .failure(let error):
            return CommandOutcome(message: error.message, success: false)
        }
    }

    @discardableResult
    func perform(_ command: ParsedCommand) async -> CommandOutcome {
        let targets = lights.filter { command.lightIDs.contains($0.id) }
        guard !targets.isEmpty else {
            return CommandOutcome(message: CommandError.noLights.message, success: false)
        }

        var failures: [String] = []
        var unsupported = 0
        let current = backend

        for light in targets {
            do {
                switch command.action {
                case .turnOn:
                    try await current.setPower(true, for: light.id)
                case .turnOff:
                    try await current.setPower(false, for: light.id)
                case .setBrightness(let value):
                    try await applyBrightness(value, to: light, using: current)
                case .brighter:
                    let base = light.isOn ? (light.brightness ?? 50) : 0
                    try await applyBrightness(min(100, base + 25), to: light, using: current)
                case .dimmer:
                    let base = light.isOn ? (light.brightness ?? 50) : 50
                    try await applyBrightness(max(5, base - 25), to: light, using: current)
                case .setColor(let color):
                    guard light.supportsColor else { unsupported += 1; continue }
                    try await current.setColor(hue: color.hue, saturation: color.saturation, for: light.id)
                    if !light.isOn { try await current.setPower(true, for: light.id) }
                }
            } catch LightBackendError.unsupported {
                unsupported += 1
            } catch {
                failures.append(light.name)
            }
        }

        lights = current.snapshot()
        return outcome(for: command, total: targets.count, failures: failures, unsupported: unsupported)
    }

    private func applyBrightness(_ value: Int, to light: Light, using backend: LightBackend) async throws {
        if light.supportsBrightness {
            try await backend.setBrightness(value, for: light.id)
        }
        if !light.isOn { try await backend.setPower(true, for: light.id) }
    }

    private func outcome(for command: ParsedCommand, total: Int,
                         failures: [String], unsupported: Int) -> CommandOutcome {
        if failures.count == total {
            return CommandOutcome(message: "Nepavyko valdyti: \(failures.joined(separator: ", ")).", success: false)
        }
        if unsupported == total {
            return CommandOutcome(message: "\(command.targetDescription): šviestuvas šios funkcijos nepalaiko.",
                                  success: false)
        }

        let target = command.targetDescription
        var message: String
        switch command.action {
        case .turnOn: message = "Įjungta: \(target)."
        case .turnOff: message = "Išjungta: \(target)."
        case .setBrightness(let value): message = "Ryškumas \(value) %: \(target)."
        case .brighter: message = "Pašviesinta: \(target)."
        case .dimmer: message = "Pritemdyta: \(target)."
        case .setColor(let color): message = "Spalva \(color.name): \(target)."
        }
        if !failures.isEmpty {
            message += " Nepavyko: \(failures.joined(separator: ", "))."
        }
        return CommandOutcome(message: message, success: failures.isEmpty)
    }
}
