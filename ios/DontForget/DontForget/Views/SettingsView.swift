import CoreLocation
import MapKit
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AlarmCoordinator.self) private var coordinator

    @AppStorage(SettingsKey.homeIsSet) private var homeIsSet = false
    @AppStorage(SettingsKey.homeLatitude) private var homeLatitude = 0.0
    @AppStorage(SettingsKey.homeLongitude) private var homeLongitude = 0.0
    @AppStorage(SettingsKey.homeRadius) private var homeRadius = SettingsDefault.homeRadius
    @AppStorage(SettingsKey.nagIntervalMinutes) private var nagInterval = SettingsDefault.nagIntervalMinutes
    @AppStorage(SettingsKey.alarmEnabled) private var alarmEnabled = SettingsDefault.alarmEnabled
    @AppStorage(SettingsKey.allowConfirmWithoutPhoto) private var allowWithoutPhoto = SettingsDefault.allowConfirmWithoutPhoto
    @AppStorage(SettingsKey.partnerName) private var partnerName = SettingsDefault.partnerName

    @State private var settingHome = false
    @State private var homeError: String?
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    private var homeCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: homeLatitude, longitude: homeLongitude)
    }

    var body: some View {
        NavigationStack {
            Form {
                homeSection
                remindersSection
                partnerSection
                permissionsSection
                testSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { notificationStatus = await coordinator.notifications.authorizationStatus() }
            .onChange(of: homeRadius) { _, _ in coordinator.applyHomeMonitoring() }
            .onChange(of: nagInterval) { _, _ in coordinator.refreshHomeNag() }
            .onChange(of: alarmEnabled) { _, enabled in
                if !enabled { coordinator.stopAlarm() }
            }
        }
    }

    // MARK: Sections

    private var homeSection: some View {
        Section {
            if homeIsSet {
                Map(initialPosition: .region(mapRegion)) {
                    Marker("Home", systemImage: "house.fill", coordinate: homeCoordinate)
                    MapCircle(center: homeCoordinate, radius: homeRadius)
                        .foregroundStyle(Color.accentColor.opacity(0.18))
                        .stroke(Color.accentColor, lineWidth: 2)
                }
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .listRowInsets(EdgeInsets())
                .id("\(homeLatitude),\(homeLongitude),\(Int(homeRadius))")
                .allowsHitTesting(false)
            }

            Button {
                Task { await setHomeHere() }
            } label: {
                HStack {
                    Label(homeIsSet ? "Move home to my current location" : "I'm home now. Set home here",
                          systemImage: "location.fill")
                    if settingHome {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(settingHome)

            if homeIsSet {
                VStack(alignment: .leading) {
                    Text("Home radius: \(Int(homeRadius)) m")
                    Slider(value: $homeRadius, in: 100...500, step: 50)
                }
                Button("Forget home", role: .destructive) {
                    coordinator.clearHome()
                }
            }

            if let homeError {
                Text(homeError).foregroundStyle(.red).font(.footnote)
            }
        } header: {
            Text("Home")
        } footer: {
            Text("The alarm fires when you walk out of this circle with unconfirmed items. iOS needs at least 100 m; 150 to 200 m avoids false alarms in the garden or parking lot.")
        }
    }

    private var remindersSection: some View {
        Section {
            Stepper("Remind me every \(nagInterval) min at home", value: $nagInterval, in: 5...120, step: 5)
            Toggle("Alarm when I leave home", isOn: $alarmEnabled)
            Toggle("Allow confirming without a photo", isOn: $allowWithoutPhoto)
        } header: {
            Text("Reminders")
        } footer: {
            Text("Keep photo confirmation on: tapping \"I have it\" from memory is how things get forgotten.")
        }
    }

    private var partnerSection: some View {
        Section {
            TextField("Partner's name", text: $partnerName)
        } header: {
            Text("Partner")
        } footer: {
            Text("Items sync between devices signed in to the same iCloud account. If your partner uses a different Apple ID, add items on this phone for now; sharing between accounts is on the roadmap.")
        }
    }

    private var permissionsSection: some View {
        Section {
            LabeledContent("Location", value: locationStatusText)
            if !coordinator.location.hasAlwaysAuthorization {
                Button("Allow \"Always\" location") {
                    if coordinator.location.authorization == .notDetermined {
                        coordinator.location.requestWhenInUseAuthorization()
                    } else {
                        coordinator.location.requestAlwaysAuthorization()
                    }
                }
            }
            LabeledContent("Notifications", value: notificationStatusText)
            Button("Open iOS Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } header: {
            Text("Permissions")
        } footer: {
            Text("\"Always\" location is required so the alarm works while the app is closed. Location data never leaves your phone.")
        }
    }

    private var testSection: some View {
        Section {
            Button {
                coordinator.triggerTestAlarm()
                dismiss()
            } label: {
                Label("Test the leave-home alarm", systemImage: "bell.and.waves.left.and.right.fill")
            }
        } footer: {
            Text("Shows the full-screen alarm and schedules the same notifications a real exit would.")
        }
    }

    // MARK: Helpers

    private var mapRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: homeCoordinate,
            latitudinalMeters: homeRadius * 5,
            longitudinalMeters: homeRadius * 5
        )
    }

    private func setHomeHere() async {
        settingHome = true
        homeError = nil
        defer { settingHome = false }

        if coordinator.location.authorization == .notDetermined {
            coordinator.location.requestWhenInUseAuthorization()
            try? await Task.sleep(for: .seconds(2))
        }
        guard let fix = await coordinator.location.requestCurrentLocation() else {
            homeError = "Couldn't get your location. Check location permission and try again."
            return
        }
        coordinator.setHome(fix.coordinate)
    }

    private var locationStatusText: String {
        switch coordinator.location.authorization {
        case .authorizedAlways: return "Always ✓"
        case .authorizedWhenInUse: return "Only while using"
        case .denied, .restricted: return "Denied"
        case .notDetermined: return "Not asked yet"
        @unknown default: return "Unknown"
        }
    }

    private var notificationStatusText: String {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: return "Allowed ✓"
        case .denied: return "Denied"
        case .notDetermined: return "Not asked yet"
        @unknown default: return "Unknown"
        }
    }
}
