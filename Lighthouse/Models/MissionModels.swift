import Foundation
import SwiftData

@Model
final class Mission {
    @Attribute(.unique) var id: String
    var name: String
    var status: String
    var disasterType: String
    var location: String
    var latitude: Double?
    var longitude: Double?
    var priority: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        name: String,
        status: String = "active",
        disasterType: String,
        location: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        priority: String = "high",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.disasterType = disasterType
        self.location = location
        self.latitude = latitude
        self.longitude = longitude
        self.priority = priority
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class Incident {
    @Attribute(.unique) var id: String
    var missionId: String
    var number: Int
    var location: String
    var incidentDescription: String
    var victimCount: Int
    var status: String
    var priority: String
    var score: Int
    var reporter: String
    var confidence: Double
    var hasChildren: Bool
    var hasElderly: Bool
    var hasUnconscious: Bool
    var accessibility: String
    var latitude: Double?
    var longitude: Double?
    var locationSource: String
    var photoPath: String?
    var ocrText: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        missionId: String,
        number: Int,
        location: String,
        incidentDescription: String,
        victimCount: Int,
        status: String = "awaiting_rescue",
        priority: String = "medium",
        score: Int = 50,
        reporter: String,
        confidence: Double = 0.92,
        hasChildren: Bool = false,
        hasElderly: Bool = false,
        hasUnconscious: Bool = false,
        accessibility: String = "unknown",
        latitude: Double? = nil,
        longitude: Double? = nil,
        locationSource: String = "reported",
        photoPath: String? = nil,
        ocrText: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.missionId = missionId
        self.number = number
        self.location = location
        self.incidentDescription = incidentDescription
        self.victimCount = victimCount
        self.status = status
        self.priority = priority
        self.score = score
        self.reporter = reporter
        self.confidence = confidence
        self.hasChildren = hasChildren
        self.hasElderly = hasElderly
        self.hasUnconscious = hasUnconscious
        self.accessibility = accessibility
        self.latitude = latitude
        self.longitude = longitude
        self.locationSource = locationSource
        self.photoPath = photoPath
        self.ocrText = ocrText
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
