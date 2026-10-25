import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(AlarmCoordinator.self) private var coordinator
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \ReminderItem.createdAt, order: .reverse) private var items: [ReminderItem]
    @AppStorage(SettingsKey.homeIsSet) private var homeIsSet = false
    @AppStorage(SettingsKey.partnerName) private var partnerName = SettingsDefault.partnerName

    @State private var showAdd = false
    @State private var showSettings = false
    @State private var confirming: ReminderItem?

    private var pending: [ReminderItem] { items.filter(\.isPending) }
    private var confirmed: [ReminderItem] { items.filter { $0.isConfirmed && !$0.isArchived } }

    var body: some View {
        @Bindable var coordinator = coordinator
        NavigationStack {
            List {
                if !homeIsSet {
                    setupBanner
                } else {
                    statusRow
                }

                Section {
                    if pending.isEmpty {
                        emptyState
                    } else {
                        ForEach(pending) { item in
                            Button {
                                confirming = item
                            } label: {
                                ItemRow(item: item, partnerName: partnerName)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    coordinator.delete(item)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    confirming = item
                                } label: {
                                    Label("Got it", systemImage: "checkmark")
                                }
                                .tint(.green)
                            }
                        }
                    }
                } header: {
                    Text("Take with you")
                }

                if !confirmed.isEmpty {
                    Section {
                        ForEach(confirmed) { item in
                            ItemRow(item: item, partnerName: partnerName)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        coordinator.delete(item)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    Button {
                                        coordinator.unconfirm(item)
                                    } label: {
                                        Label("Undo", systemImage: "arrow.uturn.backward")
                                    }
                                }
                        }
                    } header: {
                        HStack {
                            Text("Confirmed")
                            Spacer()
                            Button("Clear") { coordinator.archiveConfirmed() }
                                .font(.footnote)
                                .textCase(nil)
                        }
                    }
                }
            }
            .navigationTitle("Don't Forget")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddItemView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(item: $confirming) { item in
                ConfirmItemView(item: item)
            }
            .fullScreenCover(isPresented: $coordinator.isAlarming) {
                AlarmView()
            }
        }
        .task {
            await coordinator.requestPermissionsIfNeeded()
            coordinator.appBecameActive()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: coordinator.appBecameActive()
            case .background: coordinator.appWentToBackground()
            default: break
            }
        }
    }

    private var setupBanner: some View {
        Section {
            Button {
                showSettings = true
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "house.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Set your home location")
                            .font(.headline)
                        Text("The alarm only works once the app knows where home is.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var statusRow: some View {
        Section {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                Text(statusText)
                    .font(.subheadline)
                Spacer()
                if !coordinator.location.hasAlwaysAuthorization {
                    Button("Fix location access") { showSettings = true }
                        .font(.footnote)
                }
            }
        }
    }

    private var statusText: String {
        switch coordinator.location.isAtHome {
        case .some(true):
            return pending.isEmpty ? "At home. Nothing pending." : "At home. \(pending.count) to take with you."
        case .some(false):
            return pending.isEmpty ? "Away from home." : "Away from home with items unconfirmed!"
        case .none:
            return "Checking where you are…"
        }
    }

    private var statusColor: Color {
        switch coordinator.location.isAtHome {
        case .some(true): return pending.isEmpty ? .green : .orange
        case .some(false): return pending.isEmpty ? .green : .red
        case .none: return .gray
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Nothing to remember right now")
                .font(.headline)
            Text("Tap + to add something. Your \(partnerName.lowercased()) can add things too: a photo of the lunch box is enough.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

struct ItemRow: View {
    let item: ReminderItem
    let partnerName: String

    var body: some View {
        HStack(spacing: 12) {
            ItemThumbnail(data: item.photoData)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayTitle)
                    .font(.body.weight(.medium))
                    .strikethrough(item.isConfirmed)
                if !item.note.isEmpty {
                    Text(item.note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 4) {
                    Image(systemName: item.author.symbol)
                    Text(item.author == .me ? "Me" : partnerName)
                    if item.isRecurring {
                        Text("· every time")
                    }
                    Text("· \(item.createdAt.formatted(date: .omitted, time: .shortened))")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
            Spacer()
            Image(systemName: item.isConfirmed ? "checkmark.circle.fill" : "camera.circle")
                .font(.title2)
                .foregroundStyle(item.isConfirmed ? .green : Color.accentColor)
        }
        .padding(.vertical, 2)
    }
}
