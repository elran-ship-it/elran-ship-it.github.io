import SwiftUI

/// Short AbMax-style onboarding: name the pain, pick what you forget,
/// explain the mechanic, grant permissions, set home. Five taps, then the app.
struct OnboardingView: View {
    @Environment(AlarmCoordinator.self) private var coordinator
    @Environment(\.modelContext) private var context
    @AppStorage(SettingsKey.onboardingDone) private var onboardingDone = false
    @AppStorage(SettingsKey.partnerName) private var partnerName = SettingsDefault.partnerName

    @State private var step = 0
    @State private var selectedItems: Set<String> = []
    @State private var settingHome = false
    @State private var homeError: String?

    private let commonItems = ["Keys", "Wallet", "Phone charger", "Lunch", "Work badge", "Laptop", "Gym bag", "Medication", "Kids' stuff"]

    var body: some View {
        VStack {
            TabView(selection: $step) {
                painPage.tag(0)
                pickItemsPage.tag(1)
                howItWorksPage.tag(2)
                permissionsPage.tag(3)
                homePage.tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .animation(.easeInOut, value: step)
        }
        .background(Color(.systemBackground))
    }

    // MARK: Pages

    private var painPage: some View {
        page(
            symbol: "brain.head.profile",
            title: "Left home without it again?",
            body: "Lunch on the counter. Charger by the bed. Badge in yesterday's jacket. Don't Forget stops you at the door."
        ) {
            primaryButton("Yes, that's me") { step = 1 }
        }
    }

    private var pickItemsPage: some View {
        page(
            symbol: "checklist",
            title: "What do you usually forget?",
            body: "We'll add these as recurring items. They reset every time you come home."
        ) {
            VStack(spacing: 16) {
                FlowChips(items: commonItems, selected: $selectedItems)
                primaryButton(selectedItems.isEmpty ? "Skip" : "Add \(selectedItems.count) items") { step = 2 }
            }
        }
    }

    private var howItWorksPage: some View {
        page(
            symbol: "figure.walk.departure",
            title: "How it works",
            body: ""
        ) {
            VStack(alignment: .leading, spacing: 18) {
                stepRow(number: 1, text: "You or your partner add an item. A photo is enough.")
                stepRow(number: 2, text: "At home, you get a soft reminder every few minutes.")
                stepRow(number: 3, text: "Walk out the door without it and your phone alarms.")
                stepRow(number: 4, text: "Photograph the item in your hand to prove you have it. Silence.")
                primaryButton("Makes sense") { step = 3 }
            }
        }
    }

    private var permissionsPage: some View {
        page(
            symbol: "location.fill.viewfinder",
            title: "Two permissions",
            body: "Location, set to \"Always\", so the alarm works while the app is closed. Notifications, so we can actually alarm you. Your location never leaves your phone."
        ) {
            primaryButton("Allow") {
                Task {
                    await coordinator.requestPermissionsIfNeeded()
                    step = 4
                }
            }
        }
    }

    private var homePage: some View {
        page(
            symbol: "house.fill",
            title: "Are you at home right now?",
            body: "We save your current location as home. You can move it later in Settings."
        ) {
            VStack(spacing: 12) {
                primaryButton(settingHome ? "Locating…" : "Yes, set home here") {
                    Task { await finishWithHome() }
                }
                .disabled(settingHome)
                Button("Not now, I'll set it later") { finish(setHome: false) }
                    .foregroundStyle(.secondary)
                if let homeError {
                    Text(homeError).font(.footnote).foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: Building blocks

    private func page<Content: View>(symbol: String, title: String, body text: String, @ViewBuilder footer: () -> Content) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: symbol)
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)
            Text(title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            if !text.isEmpty {
                Text(text)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            footer()
                .padding(.bottom, 48)
        }
        .padding(.horizontal, 28)
    }

    private func stepRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .frame(width: 28, height: 28)
                .background(Color.accentColor.opacity(0.15), in: Circle())
            Text(text)
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    // MARK: Finish

    private func finishWithHome() async {
        settingHome = true
        homeError = nil
        defer { settingHome = false }
        guard let fix = await coordinator.location.requestCurrentLocation() else {
            homeError = "Couldn't get your location. You can set home later in Settings."
            return
        }
        coordinator.setHome(fix.coordinate)
        finish(setHome: true)
    }

    private func finish(setHome: Bool) {
        for title in selectedItems.sorted() {
            context.insert(ReminderItem(title: title, addedBy: .me, isRecurring: true))
        }
        try? context.save()
        coordinator.itemsChanged()
        onboardingDone = true
    }
}

/// Simple wrapping chip picker.
struct FlowChips: View {
    let items: [String]
    @Binding var selected: Set<String>

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(items, id: \.self) { item in
                let isOn = selected.contains(item)
                Button {
                    if isOn { selected.remove(item) } else { selected.insert(item) }
                } label: {
                    Text(item)
                        .font(.subheadline.weight(.medium))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity)
                        .background(isOn ? Color.accentColor : Color.secondary.opacity(0.12), in: Capsule())
                        .foregroundStyle(isOn ? .white : .primary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
