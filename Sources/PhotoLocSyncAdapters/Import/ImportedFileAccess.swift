import Foundation

public protocol ImportedFileReading: Sendable {
    func readData(from url: URL) throws -> Data
}

public enum ImportedFileAccess {
    public static func isSupportedTimelineFile(url: URL) -> Bool {
        let fileName = url.lastPathComponent.lowercased()
        return fileName.hasSuffix(".json") || fileName == "location-history.json"
    }
}
