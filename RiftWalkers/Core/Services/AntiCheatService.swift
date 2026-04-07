import Foundation
import CoreLocation
import Combine

// MARK: - Anti-Cheat Service
// Feature #9: Anti-cheat ML detection.
// Researched: Pokemon GO's anti-spoof measures + Niantic's Real World Platform.
// Key insight: You can't stop all cheaters, but you CAN make cheating unrewarding.
// Soft bans (shadow bans with reduced spawns) are more effective than hard bans —
// cheaters don't know they're caught, so they don't create new accounts.

final class AntiCheatService: ObservableObject {
    static let shared = AntiCheatService()

    // MARK: - Published State

    @Published var trustScore: Double = 1.0  // 0.0 (banned) to 1.0 (fully trusted)
    @Published var flaggedBehaviors: [CheatFlag] = []

    // MARK: - Models

    struct CheatFlag: Identifiable {
        let id: UUID
        let type: CheatType
        let severity: Severity
        let timestamp: Date
        let details: String

        init(
            id: UUID = UUID(),
            type: CheatType,
            severity: Severity,
            timestamp: Date = Date(),
            details: String
        ) {
            self.id = id
            self.type = type
            self.severity = severity
            self.timestamp = timestamp
            self.details = details
        }
    }

    enum CheatType: String, Codable {
        case teleportation
        case speedHack
        case botPattern
        case jailbreak
        case mockLocation
        case timeManipulation
    }

    enum Severity: String, Codable, Comparable {
        case low
        case medium
        case high
        case critical

        var trustPenalty: Double {
            switch self {
            case .low: return 0.05
            case .medium: return 0.15
            case .high: return 0.30
            case .critical: return 0.50
            }
        }

        private var sortOrder: Int {
            switch self {
            case .low: return 0
            case .medium: return 1
            case .high: return 2
            case .critical: return 3
            }
        }

        static func < (lhs: Severity, rhs: Severity) -> Bool {
            lhs.sortOrder < rhs.sortOrder
        }
    }

    struct LocationSample {
        let coordinate: CLLocationCoordinate2D
        let timestamp: Date
        let speed: CLLocationSpeed // m/s
        let horizontalAccuracy: CLLocationAccuracy
    }

    // MARK: - Private State

    private var locationHistory: [LocationSample] = []
    private let maxHistorySize = 100
    private var trustRecoveryTimer: Timer?
    private var routeSegments: [[CLLocationCoordinate2D]] = [] // For bot pattern detection

    // Thresholds
    private let maxReasonableSpeedKmh: Double = 200.0  // ~124 mph, generous for highway
    private let teleportDistanceThresholdKm: Double = 1.0  // 1km instant jump
    private let botPatternMinSegments: Int = 3
    private let straightLineToleranceDegrees: Double = 2.0

    // MARK: - Init

    private init() {
        startTrustRecovery()
    }

    deinit {
        trustRecoveryTimer?.invalidate()
    }

    // MARK: - Record Location

    /// Records a new location sample and runs all cheat detection checks.
    func recordLocation(_ location: CLLocation) {
        let sample = LocationSample(
            coordinate: location.coordinate,
            timestamp: location.timestamp,
            speed: location.speed,
            horizontalAccuracy: location.horizontalAccuracy
        )

        locationHistory.append(sample)
        if locationHistory.count > maxHistorySize {
            locationHistory.removeFirst()
        }

        // Run checks
        checkTeleportation()
        checkSpeedHack(location)
        checkBotPattern()
    }

    // MARK: - Teleportation Detection

    /// Flags if distance between consecutive points implies impossible travel speed (>200 km/h).
    func checkTeleportation() {
        guard locationHistory.count >= 2 else { return }

        let current = locationHistory[locationHistory.count - 1]
        let previous = locationHistory[locationHistory.count - 2]

        let currentLoc = CLLocation(latitude: current.coordinate.latitude, longitude: current.coordinate.longitude)
        let previousLoc = CLLocation(latitude: previous.coordinate.latitude, longitude: previous.coordinate.longitude)

        let distanceKm = currentLoc.distance(from: previousLoc) / 1000.0
        let timeHours = current.timestamp.timeIntervalSince(previous.timestamp) / 3600.0

        // Avoid division by zero for very small time intervals
        guard timeHours > 0.0001 else {
            if distanceKm > teleportDistanceThresholdKm {
                addFlag(
                    type: .teleportation,
                    severity: .critical,
                    details: "Instant teleport detected: \(String(format: "%.2f", distanceKm))km in near-zero time."
                )
            }
            return
        }

        let impliedSpeedKmh = distanceKm / timeHours

        if impliedSpeedKmh > maxReasonableSpeedKmh {
            let severity: Severity = impliedSpeedKmh > 1000 ? .critical : .high
            addFlag(
                type: .teleportation,
                severity: severity,
                details: "Teleportation suspected: \(String(format: "%.0f", impliedSpeedKmh)) km/h implied speed over \(String(format: "%.2f", distanceKm))km."
            )
        }
    }

    // MARK: - Speed Hack Detection

    private func checkSpeedHack(_ location: CLLocation) {
        // CLLocation.speed reports device-measured speed
        guard location.speed >= 0 else { return } // Negative means invalid

        let speedKmh = location.speed * 3.6 // m/s to km/h

        if speedKmh > maxReasonableSpeedKmh && location.horizontalAccuracy < 50 {
            addFlag(
                type: .speedHack,
                severity: .high,
                details: "Device reporting \(String(format: "%.0f", speedKmh)) km/h ground speed."
            )
        }
    }

    // MARK: - Bot Pattern Detection

    /// Flags if movement follows perfectly straight lines or identical repeated routes.
    func checkBotPattern() {
        guard locationHistory.count >= 10 else { return }

        // Check for perfectly straight-line movement (bots walk in grids)
        let recentPoints = Array(locationHistory.suffix(10))
        if isNearlyStraightLine(recentPoints) {
            addFlag(
                type: .botPattern,
                severity: .medium,
                details: "Movement follows a suspiciously straight path over \(recentPoints.count) points."
            )
        }

        // Check for repeated route patterns
        if hasRepeatedRoute() {
            addFlag(
                type: .botPattern,
                severity: .high,
                details: "Identical movement route detected repeating \(botPatternMinSegments)+ times."
            )
        }
    }

    private func isNearlyStraightLine(_ samples: [LocationSample]) -> Bool {
        guard samples.count >= 3 else { return false }

        // Calculate bearing from first to last point
        let startLat = samples.first!.coordinate.latitude
        let startLon = samples.first!.coordinate.longitude
        let endLat = samples.last!.coordinate.latitude
        let endLon = samples.last!.coordinate.longitude

        let overallBearing = bearing(from: startLat, fromLon: startLon, to: endLat, toLon: endLon)

        // Check if all intermediate points deviate less than tolerance from the overall bearing
        for i in 0..<(samples.count - 1) {
            let segmentBearing = bearing(
                from: samples[i].coordinate.latitude,
                fromLon: samples[i].coordinate.longitude,
                to: samples[i + 1].coordinate.latitude,
                toLon: samples[i + 1].coordinate.longitude
            )
            let deviation = abs(angleDifference(overallBearing, segmentBearing))
            if deviation > straightLineToleranceDegrees {
                return false
            }
        }

        return true
    }

    private func hasRepeatedRoute() -> Bool {
        guard locationHistory.count >= 30 else { return false }

        // Compare the last 10 points against earlier segments of 10
        let segmentSize = 10
        let recent = Array(locationHistory.suffix(segmentSize))

        var matchCount = 0
        let totalSegments = (locationHistory.count - segmentSize) / segmentSize

        for segmentIndex in 0..<totalSegments {
            let start = segmentIndex * segmentSize
            let segment = Array(locationHistory[start..<(start + segmentSize)])

            if routeSegmentsMatch(recent, segment, toleranceMeters: 20.0) {
                matchCount += 1
            }
        }

        return matchCount >= botPatternMinSegments
    }

    private func routeSegmentsMatch(_ a: [LocationSample], _ b: [LocationSample], toleranceMeters: Double) -> Bool {
        guard a.count == b.count else { return false }

        for i in 0..<a.count {
            let locA = CLLocation(latitude: a[i].coordinate.latitude, longitude: a[i].coordinate.longitude)
            let locB = CLLocation(latitude: b[i].coordinate.latitude, longitude: b[i].coordinate.longitude)
            if locA.distance(from: locB) > toleranceMeters {
                return false
            }
        }
        return true
    }

    // MARK: - Jailbreak Detection

    /// Basic checks for jailbreak indicators — Cydia, suspicious paths, etc.
    func checkJailbreak() {
        let suspiciousPaths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt",
            "/usr/bin/ssh",
            "/private/var/stash",
            "/private/var/lib/cydia"
        ]

        let fileManager = FileManager.default
        var detectedPaths: [String] = []

        for path in suspiciousPaths {
            if fileManager.fileExists(atPath: path) {
                detectedPaths.append(path)
            }
        }

        // Check if app can write outside sandbox
        let testPath = "/private/jailbreak_test_\(UUID().uuidString)"
        let canWriteOutsideSandbox: Bool
        do {
            try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try fileManager.removeItem(atPath: testPath)
            canWriteOutsideSandbox = true
        } catch {
            canWriteOutsideSandbox = false
        }

        if !detectedPaths.isEmpty {
            addFlag(
                type: .jailbreak,
                severity: .critical,
                details: "Jailbreak indicators found: \(detectedPaths.joined(separator: ", "))"
            )
        }

        if canWriteOutsideSandbox {
            addFlag(
                type: .jailbreak,
                severity: .critical,
                details: "App can write outside sandbox — likely jailbroken device."
            )
        }
    }

    // MARK: - Validate Catch

    /// Ensures the player is actually near a creature's spawn point before allowing a catch.
    func validateCatch(speciesId: String, spawnLocation: CLLocationCoordinate2D) -> Bool {
        guard let currentLocation = LocationService.shared.currentLocation else {
            addFlag(
                type: .mockLocation,
                severity: .medium,
                details: "Catch attempted with no valid location for species \(speciesId)."
            )
            return false
        }

        let spawnPoint = CLLocation(latitude: spawnLocation.latitude, longitude: spawnLocation.longitude)
        let distance = currentLocation.distance(from: spawnPoint)

        // Allow catches within 80 meters (generous for GPS drift)
        let maxCatchDistance: CLLocationDistance = 80.0

        if distance > maxCatchDistance {
            addFlag(
                type: .mockLocation,
                severity: .high,
                details: "Catch attempted \(String(format: "%.0f", distance))m from spawn (max: \(Int(maxCatchDistance))m) for species \(speciesId)."
            )
            return false
        }

        // Additional check: if trust is very low, reject more aggressively
        if trustScore < 0.3 && distance > maxCatchDistance * 0.5 {
            return false
        }

        return true
    }

    // MARK: - Trust Score Management

    /// Players with trust < 0.5 get reduced spawns and no PvP matchmaking.
    var isRestricted: Bool {
        trustScore < 0.5
    }

    /// Spawn rate multiplier based on trust score.
    var spawnRateMultiplier: Double {
        if trustScore >= 0.8 { return 1.0 }
        if trustScore >= 0.5 { return 0.7 }
        if trustScore >= 0.3 { return 0.3 }
        return 0.1 // Shadow ban territory
    }

    /// Whether the player can participate in PvP matchmaking.
    var canPvPMatch: Bool {
        trustScore >= 0.5
    }

    private func addFlag(type: CheatType, severity: Severity, details: String) {
        // Prevent duplicate flags of the same type within 60 seconds
        let recentCutoff = Date().addingTimeInterval(-60)
        let hasDuplicate = flaggedBehaviors.contains {
            $0.type == type && $0.timestamp > recentCutoff
        }
        guard !hasDuplicate else { return }

        let flag = CheatFlag(type: type, severity: severity, details: details)

        DispatchQueue.main.async {
            self.flaggedBehaviors.append(flag)
            self.trustScore = max(0.0, self.trustScore - severity.trustPenalty)
        }
    }

    // MARK: - Trust Recovery

    /// Trust score recovers slowly over time: 0.01 per hour of clean play.
    private func startTrustRecovery() {
        // Check every 5 minutes, recover proportionally
        trustRecoveryTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            // Only recover if no flags in the last 30 minutes
            let recentCutoff = Date().addingTimeInterval(-1800)
            let hasRecentFlags = self.flaggedBehaviors.contains { $0.timestamp > recentCutoff }

            if !hasRecentFlags && self.trustScore < 1.0 {
                DispatchQueue.main.async {
                    // 0.01 per hour = ~0.000833 per 5 minutes
                    self.trustScore = min(1.0, self.trustScore + 0.000833)
                }
            }
        }
    }

    // MARK: - Bearing Math Helpers

    private func bearing(from fromLat: Double, fromLon: Double, to toLat: Double, toLon: Double) -> Double {
        let lat1 = fromLat * .pi / 180.0
        let lat2 = toLat * .pi / 180.0
        let dLon = (toLon - fromLon) * .pi / 180.0

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)

        return atan2(y, x) * 180.0 / .pi
    }

    private func angleDifference(_ a: Double, _ b: Double) -> Double {
        var diff = a - b
        while diff > 180 { diff -= 360 }
        while diff < -180 { diff += 360 }
        return diff
    }

    // MARK: - Reset (Testing / Admin)

    func resetTrustScore() {
        DispatchQueue.main.async {
            self.trustScore = 1.0
            self.flaggedBehaviors.removeAll()
            self.locationHistory.removeAll()
        }
    }
}
