import Foundation
import SwiftData

/// Who added the reminder. Stored as a raw string so it syncs through CloudKit.
enum Author: String, CaseIterable, Identifiable {
    case me = "Me"
    case partner = "Partner"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .me: return "person.fill"
        case .partner: return "heart.fill"
        }
    }
}

/// One thing you must not leave home without.
///
/// Every property has a default value and relationships are absent, which is
/// what SwiftData needs to sync the model through CloudKit.
@Model
final class ReminderItem {
    var uuid: UUID = UUID()
    var title: String = ""
    var note: String = ""
    @Attribute(.externalStorage) var photoData: Data? = nil
    @Attribute(.externalStorage) var confirmationPhotoData: Data? = nil
    var createdAt: Date = Date()
    var confirmedAt: Date? = nil
    var isConfirmed: Bool = false
    /// Recurring items (keys, badge, wallet) un-confirm themselves every time you get back home.
    var isRecurring: Bool = false
    var isArchived: Bool = false
    var addedBy: String = Author.me.rawValue

    init(
        title: String,
        note: String = "",
        photoData: Data? = nil,
        addedBy: Author = .me,
        isRecurring: Bool = false
    ) {
        self.uuid = UUID()
        self.title = title
        self.note = note
        self.photoData = photoData
        self.createdAt = Date()
        self.addedBy = addedBy.rawValue
        self.isRecurring = isRecurring
    }

    var author: Author { Author(rawValue: addedBy) ?? .me }

    var isPending: Bool { !isConfirmed && !isArchived }

    var displayTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Photo reminder" : title
    }
}
