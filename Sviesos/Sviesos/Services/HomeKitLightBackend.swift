import Foundation
import HomeKit

/// Tikri šviestuvai iš Apple „Namai“ (Home) programėlės per HomeKit.
/// Tinka bet kokios HomeKit / Matter lemputės: Philips Hue, IKEA, Nanoleaf, Aqara ir kt.
@MainActor
final class HomeKitLightBackend: NSObject, LightBackend {
    var onChange: ((Bool) -> Void)?
    private(set) var statusMessage: String?

    private let manager = HMHomeManager()
    private var isReady = false
    private var readyWaiters: [CheckedContinuation<Void, Never>] = []
    private var services: [UUID: HMService] = [:]

    override init() {
        super.init()
        manager.delegate = self
        // Jei HomeKit neatsako (pvz., nėra leidimo), nelaukiame amžinai.
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            self?.markReady()
        }
    }

    // MARK: Įkėlimas

    func load() async {
        await waitUntilReady()
        services.removeAll()

        if !manager.authorizationStatus.contains(.authorized) {
            statusMessage = "Nėra leidimo naudoti HomeKit. Įjunkite: Nustatymai → Privatumas ir saugumas → HomeKit → Šviesos."
            return
        }

        let homes = orderedHomes()
        guard !homes.isEmpty else {
            statusMessage = "Nerasta namų. Pridėkite šviestuvus programėlėje „Namai“ (Home) arba įjunkite demonstracinį režimą."
            return
        }

        for home in homes {
            for accessory in home.accessories {
                accessory.delegate = self
                for service in accessory.services where service.serviceType == HMServiceTypeLightbulb {
                    guard characteristic(HMCharacteristicTypePowerState, in: service) != nil else { continue }
                    services[service.uniqueIdentifier] = service
                    guard accessory.isReachable else { continue }
                    for item in service.characteristics where Self.observedTypes.contains(item.characteristicType) {
                        try? await item.readValue()
                        if item.properties.contains(HMCharacteristicPropertySupportsEventNotification) {
                            try? await item.enableNotification(true)
                        }
                    }
                }
            }
        }

        statusMessage = services.isEmpty
            ? "Namuose nerasta šviestuvų. Pridėkite juos programėlėje „Namai“ (Home)."
            : nil
    }

    func snapshot() -> [Light] {
        services.values.map { service in
            let accessory = service.accessory
            let room = accessory?.room?.name ?? "Kiti"
            let name = service.name.isEmpty ? (accessory?.name ?? "Šviestuvas") : service.name
            let power = characteristic(HMCharacteristicTypePowerState, in: service)
            let brightness = characteristic(HMCharacteristicTypeBrightness, in: service)
            let hue = characteristic(HMCharacteristicTypeHue, in: service)
            let saturation = characteristic(HMCharacteristicTypeSaturation, in: service)

            return Light(
                id: service.uniqueIdentifier,
                name: name,
                room: room,
                isOn: (power?.value as? NSNumber)?.boolValue ?? false,
                brightness: brightness.map { ($0.value as? NSNumber)?.intValue ?? 0 },
                hue: hue.map { ($0.value as? NSNumber)?.doubleValue ?? 0 },
                saturation: saturation.map { ($0.value as? NSNumber)?.doubleValue ?? 0 },
                isReachable: accessory?.isReachable ?? false
            )
        }
        .sorted { ($0.room, $0.name) < ($1.room, $1.name) }
    }

    // MARK: Valdymas

    func setPower(_ isOn: Bool, for id: UUID) async throws {
        try await write(isOn, type: HMCharacteristicTypePowerState, id: id)
    }

    func setBrightness(_ value: Int, for id: UUID) async throws {
        try await write(value, type: HMCharacteristicTypeBrightness, id: id)
    }

    func setColor(hue: Double, saturation: Double, for id: UUID) async throws {
        try await write(Float(hue), type: HMCharacteristicTypeHue, id: id)
        try await write(Float(saturation), type: HMCharacteristicTypeSaturation, id: id)
    }

    private func write(_ value: Any, type: String, id: UUID) async throws {
        guard let service = services[id] else { throw LightBackendError.notFound }
        guard let item = characteristic(type, in: service) else { throw LightBackendError.unsupported }
        guard service.accessory?.isReachable ?? false else {
            throw LightBackendError.unreachable(service.name)
        }
        try await item.writeValue(value)
        onChange?(false)
    }

    // MARK: Pagalbinės

    private static let observedTypes: Set<String> = [
        HMCharacteristicTypePowerState, HMCharacteristicTypeBrightness,
        HMCharacteristicTypeHue, HMCharacteristicTypeSaturation,
    ]

    private func characteristic(_ type: String, in service: HMService) -> HMCharacteristic? {
        service.characteristics.first { $0.characteristicType == type }
    }

    /// Pagrindiniai namai – pirmi.
    private func orderedHomes() -> [HMHome] {
        manager.homes.filter(\.isPrimary) + manager.homes.filter { !$0.isPrimary }
    }

    private func waitUntilReady() async {
        if isReady { return }
        await withCheckedContinuation { readyWaiters.append($0) }
    }

    private func markReady() {
        guard !isReady else { return }
        isReady = true
        readyWaiters.forEach { $0.resume() }
        readyWaiters.removeAll()
    }

    private func homesChanged() {
        let wasReady = isReady
        markReady()
        if wasReady { onChange?(true) }
    }
}

// MARK: - HomeKit delegatai

extension HomeKitLightBackend: HMHomeManagerDelegate, HMAccessoryDelegate {
    nonisolated func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        Task { @MainActor in self.homesChanged() }
    }

    nonisolated func homeManager(_ manager: HMHomeManager, didUpdate status: HMHomeManagerAuthorizationStatus) {
        Task { @MainActor in self.homesChanged() }
    }

    nonisolated func homeManager(_ manager: HMHomeManager, didAdd home: HMHome) {
        Task { @MainActor in self.homesChanged() }
    }

    nonisolated func homeManager(_ manager: HMHomeManager, didRemove home: HMHome) {
        Task { @MainActor in self.homesChanged() }
    }

    nonisolated func accessory(_ accessory: HMAccessory, service: HMService,
                               didUpdateValueFor characteristic: HMCharacteristic) {
        Task { @MainActor in self.onChange?(false) }
    }

    nonisolated func accessoryDidUpdateReachability(_ accessory: HMAccessory) {
        Task { @MainActor in self.onChange?(false) }
    }

    nonisolated func accessoryDidUpdateServices(_ accessory: HMAccessory) {
        Task { @MainActor in self.onChange?(true) }
    }
}
