import Foundation

enum ImagePayloadValidator {
    static func isValid(data: Data, contentType: String) -> Bool {
        switch contentType {
        case "image/png":
            data.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        case "image/jpeg":
            data.starts(with: [0xFF, 0xD8, 0xFF])
        case "image/webp":
            data.count >= 12
                && data.prefix(4) == Data("RIFF".utf8)
                && data.dropFirst(8).prefix(4) == Data("WEBP".utf8)
        default:
            false
        }
    }
}
