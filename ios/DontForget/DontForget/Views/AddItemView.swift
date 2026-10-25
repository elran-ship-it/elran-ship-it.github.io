import PhotosUI
import SwiftData
import SwiftUI

struct AddItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AlarmCoordinator.self) private var coordinator
    @AppStorage(SettingsKey.partnerName) private var partnerName = SettingsDefault.partnerName

    @State private var title = ""
    @State private var note = ""
    @State private var addedBy: Author = .me
    @State private var isRecurring = false
    @State private var photo: UIImage?
    @State private var showCamera = false
    @State private var pickerItem: PhotosPickerItem?

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || photo != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What must not be forgotten?", text: $title)
                    TextField("Note (optional)", text: $note, axis: .vertical)
                        .lineLimit(1...3)
                }

                Section {
                    if let photo {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .listRowInsets(EdgeInsets())
                            .padding(.vertical, 8)
                    }
                    HStack {
                        Button {
                            showCamera = true
                        } label: {
                            Label(photo == nil ? "Take photo" : "Retake", systemImage: "camera.fill")
                        }
                        Spacer()
                        PhotosPicker(selection: $pickerItem, matching: .images) {
                            Label("Library", systemImage: "photo.on.rectangle")
                        }
                    }
                } header: {
                    Text("Photo")
                } footer: {
                    Text("A photo is the fastest way: just snap the lunch box on the counter.")
                }

                Section {
                    Picker("Added by", selection: $addedBy) {
                        ForEach(Author.allCases) { author in
                            Text(author == .me ? "Me" : partnerName).tag(author)
                        }
                    }
                    .pickerStyle(.segmented)
                    Toggle("Every time I leave", isOn: $isRecurring)
                } footer: {
                    Text("Recurring items (keys, badge, wallet) reset themselves each time you come home.")
                }
            }
            .navigationTitle("Remember to take…")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker(image: $photo)
                    .ignoresSafeArea()
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        photo = image
                    }
                }
            }
        }
    }

    private func save() {
        let item = ReminderItem(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            photoData: photo?.storageData(),
            addedBy: addedBy,
            isRecurring: isRecurring
        )
        context.insert(item)
        try? context.save()
        coordinator.itemsChanged()
        dismiss()
    }
}
