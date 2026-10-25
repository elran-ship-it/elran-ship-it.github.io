import SwiftData
import SwiftUI

@main
struct DontForgetApp: App {
    private let container: ModelContainer
    @State private var coordinator: AlarmCoordinator
    @AppStorage(SettingsKey.onboardingDone) private var onboardingDone = false

    init() {
        let container = Self.makeContainer()
        self.container = container
        let coordinator = AlarmCoordinator(container: container)
        _coordinator = State(initialValue: coordinator)
        // Must run during launch so a geofence exit that relaunches the app
        // in the background is delivered to the coordinator.
        coordinator.start()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if onboardingDone {
                    ContentView()
                } else {
                    OnboardingView()
                }
            }
            .environment(coordinator)
        }
        .modelContainer(container)
    }

    /// Tries iCloud sync first (same Apple ID on both phones = shared list),
    /// falls back to an on-device store if the iCloud entitlement is missing.
    private static func makeContainer() -> ModelContainer {
        let schema = Schema([ReminderItem.self])
        let cloud = ModelConfiguration("DontForget", schema: schema, cloudKitDatabase: .automatic)
        if let container = try? ModelContainer(for: schema, configurations: [cloud]) {
            return container
        }
        let local = ModelConfiguration("DontForget", schema: schema, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: [local])
        } catch {
            fatalError("Could not create the data store: \(error)")
        }
    }
}
