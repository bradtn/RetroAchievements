import Foundation
import UIKit

class ImageLoader {
    static let shared = ImageLoader()

    private let baseUrl = "https://retroachievements.org"
    private let cacheDirectory: URL?

    private init() {
        if let containerUrl = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.bradnohra.retrotrack"
        ) {
            cacheDirectory = containerUrl.appendingPathComponent("ImageCache", isDirectory: true)
            try? FileManager.default.createDirectory(
                at: cacheDirectory!,
                withIntermediateDirectories: true
            )
        } else {
            cacheDirectory = nil
        }
    }

    func loadImage(from path: String) -> UIImage? {
        guard !path.isEmpty else { return nil }

        let cacheKey = path.replacingOccurrences(of: "/", with: "_")

        // Check cache first
        if let cachedImage = loadFromCache(key: cacheKey) {
            return cachedImage
        }

        // Build full URL
        let fullUrl: String
        if path.hasPrefix("http") {
            fullUrl = path
        } else {
            fullUrl = baseUrl + path
        }

        // Try to load from network (synchronously for widget)
        guard let url = URL(string: fullUrl),
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            return nil
        }

        // Cache the image
        saveToCache(image: image, key: cacheKey)

        return image
    }

    private func loadFromCache(key: String) -> UIImage? {
        guard let cacheDirectory = cacheDirectory else { return nil }
        let fileUrl = cacheDirectory.appendingPathComponent(key)

        guard FileManager.default.fileExists(atPath: fileUrl.path),
              let data = try? Data(contentsOf: fileUrl),
              let image = UIImage(data: data) else {
            return nil
        }

        return image
    }

    private func saveToCache(image: UIImage, key: String) {
        guard let cacheDirectory = cacheDirectory,
              let data = image.pngData() else { return }

        let fileUrl = cacheDirectory.appendingPathComponent(key)
        try? data.write(to: fileUrl)
    }
}
