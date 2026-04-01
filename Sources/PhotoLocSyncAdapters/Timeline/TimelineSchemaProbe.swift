import Foundation

public struct TimelineSchemaSummary: Sendable, Hashable {
    public let totalRecords: Int
    public let recordTypeCounts: [String: Int]

    public init(totalRecords: Int, recordTypeCounts: [String: Int]) {
        self.totalRecords = totalRecords
        self.recordTypeCounts = recordTypeCounts
    }
}

public enum TimelineSchemaProbeError: LocalizedError {
    case invalidTopLevel
    case emptyFile

    public var errorDescription: String? {
        switch self {
        case .invalidTopLevel:
            "Timeline JSON must be an array of timeline records."
        case .emptyFile:
            "Timeline JSON did not contain any records."
        }
    }
}

public struct TimelineSchemaProbe: Sendable {
    public init() {}

    public func probe(data: Data) throws -> TimelineSchemaSummary {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let array = object as? [[String: Any]] else {
            throw TimelineSchemaProbeError.invalidTopLevel
        }
        guard !array.isEmpty else {
            throw TimelineSchemaProbeError.emptyFile
        }

        var counts: [String: Int] = [:]
        for item in array {
            if item["visit"] != nil { counts["visit", default: 0] += 1 }
            if item["activity"] != nil { counts["activity", default: 0] += 1 }
            if item["timelinePath"] != nil { counts["timelinePath", default: 0] += 1 }
            if item["timelineMemory"] != nil { counts["timelineMemory", default: 0] += 1 }
        }
        return TimelineSchemaSummary(totalRecords: array.count, recordTypeCounts: counts)
    }
}
