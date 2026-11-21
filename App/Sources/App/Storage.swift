import Foundation

/// Saving app state as JSON in UserDefaults, in one place.
extension UserDefaults {
    /// The saved value for `key`, or nil if there is none or it can't be read.
    func decoded<T: Decodable>(_ type: T.Type, forKey key: String,
                               using decoder: JSONDecoder = JSONDecoder()) -> T? {
        guard let data = data(forKey: key) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    func setEncoded<T: Encodable>(_ value: T, forKey key: String,
                                  using encoder: JSONEncoder = JSONEncoder()) {
        if let data = try? encoder.encode(value) { set(data, forKey: key) }
    }
}

/// Keys for the settings views read with `@AppStorage`, so every screen
/// that reads a setting uses the same spelling.
enum SettingKey {
    static let relaxedMode = "relaxedMode"
    static let haptics = "hapticsEnabled"
    static let animatedBackgrounds = "animatedBackgrounds"
    static let gameMode = "gameMode"
    static let difficulty = "difficulty"
}
