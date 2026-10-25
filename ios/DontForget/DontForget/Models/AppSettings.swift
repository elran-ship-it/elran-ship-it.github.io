import CoreLocation
import Foundation

/// UserDefaults keys. Views read them through `@AppStorage`, services through `AppSettings`.
enum SettingsKey {
    static let onboardingDone = "onboarding.done"
    static let homeIsSet = "home.isSet"
    static let homeLatitude = "home.latitude"
    static let homeLongitude = "home.longitude"
    static let homeRadius = "home.radius"
    static let nagIntervalMinutes = "reminders.nagIntervalMinutes"
    static let alarmEnabled = "reminders.alarmEnabled"
    static let allowConfirmWithoutPhoto = "reminders.allowConfirmWithoutPhoto"
    static let partnerName = "partner.name"
}

enum SettingsDefault {
    static let homeRadius: Double = 150
    static let nagIntervalMinutes: Int = 15
    static let alarmEnabled = true
    static let allowConfirmWithoutPhoto = false
    static let partnerName = "Partner"
}

/// Typed read/write access to the same values the SwiftUI views bind to.
struct AppSettings {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var homeCoordinate: CLLocationCoordinate2D? {
        get {
            guard defaults.bool(forKey: SettingsKey.homeIsSet) else { return nil }
            return CLLocationCoordinate2D(
                latitude: defaults.double(forKey: SettingsKey.homeLatitude),
                longitude: defaults.double(forKey: SettingsKey.homeLongitude)
            )
        }
        nonmutating set {
            if let newValue {
                defaults.set(newValue.latitude, forKey: SettingsKey.homeLatitude)
                defaults.set(newValue.longitude, forKey: SettingsKey.homeLongitude)
                defaults.set(true, forKey: SettingsKey.homeIsSet)
            } else {
                defaults.set(false, forKey: SettingsKey.homeIsSet)
            }
        }
    }

    var homeRadius: Double {
        get { defaults.object(forKey: SettingsKey.homeRadius) as? Double ?? SettingsDefault.homeRadius }
        nonmutating set { defaults.set(newValue, forKey: SettingsKey.homeRadius) }
    }

    var nagIntervalMinutes: Int {
        defaults.object(forKey: SettingsKey.nagIntervalMinutes) as? Int ?? SettingsDefault.nagIntervalMinutes
    }

    var alarmEnabled: Bool {
        defaults.object(forKey: SettingsKey.alarmEnabled) as? Bool ?? SettingsDefault.alarmEnabled
    }

    var allowConfirmWithoutPhoto: Bool {
        defaults.object(forKey: SettingsKey.allowConfirmWithoutPhoto) as? Bool ?? SettingsDefault.allowConfirmWithoutPhoto
    }

    var partnerName: String {
        let value = defaults.string(forKey: SettingsKey.partnerName) ?? ""
        return value.isEmpty ? SettingsDefault.partnerName : value
    }
}
