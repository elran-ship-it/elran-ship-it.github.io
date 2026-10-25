import UIKit

extension UIImage {
    /// Downscales and JPEG-compresses so item photos stay small enough to sync comfortably.
    func storageData(maxDimension: CGFloat = 1200, quality: CGFloat = 0.6) -> Data? {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return jpegData(compressionQuality: quality) }
        let scale = maxDimension / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        let resized = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
