import Foundation

public struct SecurityScopedFileReader: ImportedFileReading {
    public init() {}

    public func readData(from url: URL) throws -> Data {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try Data(contentsOf: url)
    }
}
