import Foundation

/// Atpažinta komanda: ką daryti ir su kuriais šviestuvais.
struct ParsedCommand: Equatable {
    enum Action: Equatable {
        case turnOn
        case turnOff
        case setBrightness(Int)
        case brighter
        case dimmer
        case setColor(LightColor)
    }

    var action: Action
    var lightIDs: [UUID]
    /// Kam taikoma, žmogui suprantamai: „visos šviesos“, „Svetainė“, „Toršeras“.
    var targetDescription: String
}

enum CommandError: Error, Equatable {
    case empty
    case unknownAction
    case noLights
    case unknownTarget(String)

    var message: String {
        switch self {
        case .empty:
            return "Nieko neišgirdau. Pabandykite dar kartą."
        case .unknownAction:
            return "Nesupratau, ką daryti. Pasakykite, pvz., „įjunk šviesą svetainėje“."
        case .noLights:
            return "Nerasta jokių šviestuvų."
        case .unknownTarget(let word):
            return "Neradau kambario ar šviestuvo „\(word)“."
        }
    }
}

/// Paverčia lietuvišką (arba anglišką) frazę komanda.
///
/// Pavyzdžiai:
/// - „Įjunk šviesą svetainėje“
/// - „Išjunk visas šviesas“
/// - „Pritemdyk miegamąjį iki 20 procentų“
/// - „Virtuvėje nustatyk raudoną spalvą“
/// - „Turn off the kitchen lights“
enum CommandParser {

    // MARK: Žodynas (be diakritikos, žodžių pradžios)

    static let offStems = ["isjung", "isjunk", "gesin", "uzgesin", "uzgesyk", "isjun"]
    static let onStems = ["ijung", "ijunk", "uzdek", "uzdeg", "ijun"]
    static let dimStems = ["pritemd", "temdyk", "temdink", "tamsiau", "sumazin", "mazin", "silpn",
                           "dim", "darker", "lower"]
    static let brightStems = ["pasviesin", "sviesiau", "sviesesn", "ryskiau", "padidin", "didin",
                              "stipr", "brighter", "brighten", "increase", "raise"]
    static let brightnessWords = ["proc", "procent", "percent", "sviesum", "ryskum", "lyg",
                                  "brightness", "level", "iki"]
    static let allWords = ["vis", "viska", "visur", "all", "everything", "everywhere", "namuose",
                           "namus", "namie"]
    /// Bendri žodžiai, kurie nenurodo konkretaus šviestuvo.
    static let genericStems = ["svies", "lemp", "lemput", "sviestuv", "light", "lamp", "bulb"]
    static let fillerWords: Set<String> = [
        "prasau", "please", "the", "in", "to", "at", "on", "off", "of", "and", "ir", "i", "is",
        "man", "mano", "my", "set", "turn", "switch", "make", "nustatyk", "nustatyti", "pakeisk",
        "padaryk", "spalva", "spalvos", "color", "colour", "kambaryje", "room", "home",
        "a", "an", "it", "ja", "jas", "juos", "ta", "tas", "dabar", "now", "labai", "very",
        "bit", "little", "truputi", "siek", "tiek", "kiek", "per", "up", "down", "kad", "butu",
        "nors", "dar", "more", "su", "with", "hey", "ei", "labas", "aciu", "thanks",
        "maksimaliai", "maksimalus", "pilnai", "max", "maximum", "full", "puse", "pusiau", "half",
        "minimaliai", "minimum", "min"
    ]

    static let colors: [(stems: [String], color: LightColor)] = [
        (["raudon", "red"], LightColor(name: "raudona", hue: 0, saturation: 100)),
        (["oranz", "orange"], LightColor(name: "oranžinė", hue: 30, saturation: 100)),
        (["gelton", "yellow"], LightColor(name: "geltona", hue: 55, saturation: 100)),
        (["zal", "green"], LightColor(name: "žalia", hue: 120, saturation: 100)),
        (["zydr", "cyan", "turkio"], LightColor(name: "žydra", hue: 190, saturation: 100)),
        (["melyn", "blue"], LightColor(name: "mėlyna", hue: 230, saturation: 100)),
        (["violet", "purpur", "purple"], LightColor(name: "violetinė", hue: 280, saturation: 100)),
        (["rozin", "pink"], LightColor(name: "rožinė", hue: 330, saturation: 80)),
        (["balt", "white"], LightColor(name: "balta", hue: 0, saturation: 0)),
        (["silt", "warm", "jauk"], LightColor(name: "šilta", hue: 35, saturation: 45)),
        (["salt", "cold", "cool"], LightColor(name: "šalta", hue: 210, saturation: 20)),
    ]

    static let numberWords: [(stem: String, value: Int)] = [
        ("devyniasdesim", 90), ("astuoniasdesim", 80), ("septyniasdesim", 70),
        ("sesiasdesim", 60), ("penkiasdesim", 50), ("keturiasdesim", 40),
        ("trisdesim", 30), ("dvidesim", 20), ("desim", 10), ("simt", 100), ("penkiolik", 15),
    ]

    // MARK: Analizė

    static func parse(_ text: String, lights: [Light]) -> Result<ParsedCommand, CommandError> {
        let tokens = TextNormalizer.tokens(text)
        guard !tokens.isEmpty else { return .failure(.empty) }
        guard !lights.isEmpty else { return .failure(.noLights) }

        guard let action = detectAction(tokens) else { return .failure(.unknownAction) }

        switch resolveTargets(tokens, lights: lights) {
        case .success(let (ids, description)):
            return .success(ParsedCommand(action: action, lightIDs: ids, targetDescription: description))
        case .failure(let error):
            return .failure(error)
        }
    }

    static func detectAction(_ tokens: [String]) -> ParsedCommand.Action? {
        let wantsOff = tokens.contains { matches($0, offStems) } || tokens.contains("off")
        let wantsOn = tokens.contains { matches($0, onStems) } || tokens.contains("on")
        let wantsDim = tokens.contains { matches($0, dimStems) }
        let wantsBright = tokens.contains { matches($0, brightStems) }
        let mentionsBrightness = tokens.contains { matches($0, brightnessWords) }
        let number = extractNumber(tokens)
        let color = detectColor(tokens)

        if wantsOff && !wantsOn { return .turnOff }
        if let number, mentionsBrightness || wantsDim || wantsBright || wantsOn {
            let value = min(100, max(0, number))
            return value == 0 ? .turnOff : .setBrightness(value)
        }
        if let color { return .setColor(color) }
        if wantsDim { return .dimmer }
        if wantsBright { return .brighter }
        if wantsOn { return .turnOn }
        if wantsOff { return .turnOff }
        if let number, number > 0 { return .setBrightness(min(100, number)) }
        return nil
    }

    static func extractNumber(_ tokens: [String]) -> Int? {
        for token in tokens {
            if let value = Int(token) { return value }
        }
        for token in tokens {
            if token.hasPrefix("maksimal") || ["max", "maximum", "full", "pilnai"].contains(token) { return 100 }
            if ["puse", "pusiau", "half"].contains(token) { return 50 }
            if token.hasPrefix("minimal") || ["min", "minimum"].contains(token) { return 5 }
        }
        // Skaičiai žodžiais: „trisdešimt penki“ → 35 (sudedama).
        var total = 0
        var found = false
        for token in tokens {
            if let match = numberWords.first(where: { token.hasPrefix($0.stem) }) {
                total += match.value
                found = true
            } else if found, let unit = unitValue(token) {
                total += unit
            }
        }
        return found ? total : nil
    }

    private static func unitValue(_ token: String) -> Int? {
        let units: [(String, Int)] = [("vien", 1), ("du", 2), ("dvi", 2), ("tri", 3), ("ketur", 4),
                                      ("penk", 5), ("ses", 6), ("septyn", 7), ("astuon", 8), ("devyn", 9)]
        return units.first(where: { token.hasPrefix($0.0) })?.1
    }

    static func detectColor(_ tokens: [String]) -> LightColor? {
        for token in tokens {
            if let entry = colors.first(where: { matches(token, $0.stems) }) {
                return entry.color
            }
        }
        return nil
    }

    // MARK: Taikiniai (kambariai ir šviestuvai)

    static func resolveTargets(_ tokens: [String], lights: [Light]) -> Result<([UUID], String), CommandError> {
        let mentionsAll = tokens.contains(where: isAllWord)
        let meaningful = tokens.filter(isMeaningful)

        // 1. Kambariai.
        let rooms = Array(Set(lights.map(\.room))).sorted()
        let roomScores = rooms.map { room in (room, score(words: significantWords(room), in: meaningful)) }
        let bestRoom = roomScores.map(\.1).max() ?? 0
        let matchedRooms = bestRoom > 0 ? roomScores.filter { $0.1 == bestRoom }.map(\.0) : []
        let roomWords = matchedRooms.flatMap(significantWords)

        // 2. Konkretūs šviestuvai pagal pavadinimą (be žodžių, kurie jau nurodė kambarį,
        //    kad „įjunk virtuvės šviesą“ įjungtų visas virtuvės šviesas).
        let nameTokens = meaningful.filter { token in !roomWords.contains { TextNormalizer.sameWord($0, token) } }
        let nameScores = lights.map { light in (light, score(words: significantWords(light.name), in: nameTokens)) }
        let bestName = nameScores.map(\.1).max() ?? 0
        let byName = bestName > 0 ? nameScores.filter { $0.1 == bestName }.map(\.0) : []

        if !byName.isEmpty {
            let narrowed = byName.filter { matchedRooms.contains($0.room) }
            let chosen = narrowed.isEmpty ? byName : narrowed
            return .success((chosen.map(\.id), chosen.map(\.name).joined(separator: ", ")))
        }
        let byRoom = lights.filter { matchedRooms.contains($0.room) }
        if !byRoom.isEmpty {
            return .success((byRoom.map(\.id), matchedRooms.joined(separator: ", ")))
        }

        // 3. Niekas nerasta: jei paminėtas nežinomas žodis (pvz., „garaže“), geriau nieko nedaryti.
        if !mentionsAll, let unknown = meaningful.first {
            return .failure(.unknownTarget(unknown))
        }
        return .success((lights.map(\.id), "visos šviesos"))
    }

    static func isAllWord(_ token: String) -> Bool {
        allWords.contains(token) || (token.hasPrefix("vis") && token.count <= 6)
    }

    /// Žodžiai, kurie gali būti kambario ar šviestuvo pavadinimas (ne veiksmai, spalvos ar skaičiai).
    static func isMeaningful(_ token: String) -> Bool {
        guard token.count >= 3, Int(token) == nil else { return false }
        if fillerWords.contains(token) { return false }
        if isAllWord(token) { return false }
        let vocabulary = offStems + onStems + dimStems + brightStems + brightnessWords + genericStems
            + colors.flatMap(\.stems) + numberWords.map(\.stem)
        return !matches(token, vocabulary)
    }

    static func significantWords(_ name: String) -> [String] {
        TextNormalizer.tokens(name).filter { word in
            word.count >= 3 && !matches(word, genericStems)
        }
    }

    private static func score(words: [String], in tokens: [String]) -> Int {
        words.filter { word in tokens.contains { TextNormalizer.sameWord(word, $0) } }.count
    }

    private static func matches(_ token: String, _ stems: [String]) -> Bool {
        stems.contains { token.hasPrefix($0) }
    }
}
