import SwiftUI

/// "Picture it back": you confirm an item by photographing it in your hand or bag.
struct ConfirmItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AlarmCoordinator.self) private var coordinator
    @AppStorage(SettingsKey.allowConfirmWithoutPhoto) private var allowWithoutPhoto = SettingsDefault.allowConfirmWithoutPhoto

    let item: ReminderItem

    @State private var photo: UIImage?
    @State private var showCamera = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let data = item.photoData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    VStack(spacing: 6) {
                        Text(item.displayTitle)
                            .font(.title2.bold())
                        if !item.note.isEmpty {
                            Text(item.note)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .multilineTextAlignment(.center)

                    Text("Take a photo of it in your hand or bag to confirm you really have it.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    if let photo {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(alignment: .topTrailing) {
                                Button {
                                    showCamera = true
                                } label: {
                                    Image(systemName: "arrow.counterclockwise.circle.fill")
                                        .font(.title)
                                        .foregroundStyle(.white, .black.opacity(0.5))
                                }
                                .padding(8)
                            }

                        Button {
                            confirm(with: photo)
                        } label: {
                            Label("I have it", systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(.green)
                    } else {
                        Button {
                            showCamera = true
                        } label: {
                            Label("Take confirmation photo", systemImage: "camera.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }

                    if allowWithoutPhoto {
                        Button("Confirm without a photo") {
                            confirm(with: nil)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Got it?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not yet") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker(image: $photo)
                    .ignoresSafeArea()
            }
        }
    }

    private func confirm(with image: UIImage?) {
        coordinator.confirm(item, photo: image?.storageData(maxDimension: 800, quality: 0.5))
        dismiss()
    }
}
