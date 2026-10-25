import SwiftData
import SwiftUI

/// Full-screen red alarm shown while you are away from home with unconfirmed items.
struct AlarmView: View {
    @Environment(AlarmCoordinator.self) private var coordinator
    @Query(
        filter: #Predicate<ReminderItem> { $0.isConfirmed == false && $0.isArchived == false },
        sort: \ReminderItem.createdAt
    ) private var pending: [ReminderItem]

    @State private var confirming: ReminderItem?
    @State private var pulse = false

    var body: some View {
        ZStack {
            Color.red.ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 72))
                    .scaleEffect(pulse ? 1.12 : 0.92)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulse)
                    .padding(.top, 32)

                Text("You're leaving without:")
                    .font(.title.bold())

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(pending) { item in
                            Button {
                                confirming = item
                            } label: {
                                HStack(spacing: 12) {
                                    ItemThumbnail(data: item.photoData, size: 52)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.displayTitle)
                                            .font(.headline)
                                        if !item.note.isEmpty {
                                            Text(item.note)
                                                .font(.footnote)
                                                .opacity(0.8)
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "camera.fill")
                                        .font(.title3)
                                }
                                .padding(12)
                                .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }

                Text("Tap an item and photograph it to stop the alarm.")
                    .font(.footnote)
                    .opacity(0.85)

                Button("Snooze 5 minutes") {
                    coordinator.snooze(minutes: 5)
                }
                .buttonStyle(.bordered)
                .tint(.white)
                .padding(.bottom, 24)
            }
            .foregroundStyle(.white)
        }
        .onAppear { pulse = true }
        .onChange(of: pending.count) { _, count in
            if count == 0 {
                coordinator.stopAlarm()
            }
        }
        .sheet(item: $confirming) { item in
            ConfirmItemView(item: item)
        }
    }
}
