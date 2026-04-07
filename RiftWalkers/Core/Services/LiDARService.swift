import Foundation
import ARKit
import RealityKit
import Combine

// MARK: - LiDAR Service
// Feature #8: LiDAR-powered AR with persistent anchors.
// Researched: Apple's ARKit scene reconstruction + Niantic Lightship.
// LiDAR enables creatures to hide behind real furniture, peek around real walls,
// and portals that anchor to real surfaces — a massive immersion upgrade over flat AR.

final class LiDARService: ObservableObject {
    static let shared = LiDARService()

    // MARK: - Published State

    @Published var isLiDARAvailable: Bool = false
    @Published var detectedSurfaces: [SurfaceInfo] = []
    @Published var persistentAnchors: [GameAnchor] = []
    @Published var isSessionActive: Bool = false

    // MARK: - Models

    struct SurfaceInfo: Identifiable {
        let id: UUID
        let classification: SurfaceClassification
        let area: Float // square meters
        let normal: SIMD3<Float>
        let transform: simd_float4x4
        let detectedAt: Date

        init(
            id: UUID = UUID(),
            classification: SurfaceClassification,
            area: Float,
            normal: SIMD3<Float>,
            transform: simd_float4x4,
            detectedAt: Date = Date()
        ) {
            self.id = id
            self.classification = classification
            self.area = area
            self.normal = normal
            self.transform = transform
            self.detectedAt = detectedAt
        }
    }

    enum SurfaceClassification: String, Codable {
        case wall
        case floor
        case ceiling
        case table
        case seat
        case door
        case window
        case unknown

        init(from arClassification: ARMeshClassification) {
            switch arClassification {
            case .wall: self = .wall
            case .floor: self = .floor
            case .ceiling: self = .ceiling
            case .table: self = .table
            case .seat: self = .seat
            case .door: self = .door
            case .window: self = .window
            default: self = .unknown
            }
        }
    }

    struct GameAnchor: Identifiable, Codable {
        let id: UUID
        let type: AnchorType
        let createdBy: String
        let location: CodableMatrix4x4
        let mythology: Mythology?
        let creatureId: String?
        let createdAt: Date
        let expiresAt: Date

        init(
            id: UUID = UUID(),
            type: AnchorType,
            createdBy: String,
            location: simd_float4x4,
            mythology: Mythology? = nil,
            creatureId: String? = nil,
            createdAt: Date = Date(),
            expiresAt: Date = Date().addingTimeInterval(86400) // 24 hours default
        ) {
            self.id = id
            self.type = type
            self.createdBy = createdBy
            self.location = CodableMatrix4x4(matrix: location)
            self.mythology = mythology
            self.creatureId = creatureId
            self.createdAt = createdAt
            self.expiresAt = expiresAt
        }

        var isExpired: Bool { Date() > expiresAt }
    }

    enum AnchorType: String, Codable {
        case creatureGuard
        case riftPortal
        case lootCache
    }

    /// Codable wrapper for simd_float4x4
    struct CodableMatrix4x4: Codable {
        let columns: [[Float]]

        init(matrix: simd_float4x4) {
            columns = [
                [matrix.columns.0.x, matrix.columns.0.y, matrix.columns.0.z, matrix.columns.0.w],
                [matrix.columns.1.x, matrix.columns.1.y, matrix.columns.1.z, matrix.columns.1.w],
                [matrix.columns.2.x, matrix.columns.2.y, matrix.columns.2.z, matrix.columns.2.w],
                [matrix.columns.3.x, matrix.columns.3.y, matrix.columns.3.z, matrix.columns.3.w]
            ]
        }

        var simdMatrix: simd_float4x4 {
            simd_float4x4(
                SIMD4<Float>(columns[0][0], columns[0][1], columns[0][2], columns[0][3]),
                SIMD4<Float>(columns[1][0], columns[1][1], columns[1][2], columns[1][3]),
                SIMD4<Float>(columns[2][0], columns[2][1], columns[2][2], columns[2][3]),
                SIMD4<Float>(columns[3][0], columns[3][1], columns[3][2], columns[3][3])
            )
        }
    }

    // MARK: - Private State

    private var arSession: ARSession?
    private var cleanupTimer: Timer?

    // MARK: - Init

    private init() {
        checkLiDARAvailability()
        startAnchorCleanup()
    }

    deinit {
        cleanupTimer?.invalidate()
    }

    // MARK: - LiDAR Availability

    private func checkLiDARAvailability() {
        isLiDARAvailable = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    }

    // MARK: - Surface Classification

    /// Processes an AR frame to classify detected mesh surfaces.
    func classifySurfaces(frame: ARFrame) {
        guard isLiDARAvailable else { return }
        guard let meshAnchors = frame.anchors.compactMap({ $0 as? ARMeshAnchor }) as [ARMeshAnchor]?,
              !meshAnchors.isEmpty else { return }

        var newSurfaces: [SurfaceInfo] = []

        for meshAnchor in meshAnchors {
            let geometry = meshAnchor.geometry
            let classifications = extractClassifications(from: geometry)

            for classification in classifications {
                let surface = SurfaceInfo(
                    classification: SurfaceClassification(from: classification.type),
                    area: classification.area,
                    normal: classification.normal,
                    transform: meshAnchor.transform
                )
                newSurfaces.append(surface)
            }
        }

        DispatchQueue.main.async {
            self.detectedSurfaces = newSurfaces
        }
    }

    private struct ClassificationResult {
        let type: ARMeshClassification
        let area: Float
        let normal: SIMD3<Float>
    }

    private func extractClassifications(from geometry: ARMeshGeometry) -> [ClassificationResult] {
        var results: [ClassificationResult] = []

        guard let classificationSource = geometry.classification else {
            // No classification data available — return floor as default
            results.append(ClassificationResult(type: .floor, area: 1.0, normal: SIMD3<Float>(0, 1, 0)))
            return results
        }

        // Group faces by classification
        var classificationGroups: [ARMeshClassification: Int] = [:]

        for faceIndex in 0..<geometry.faces.count {
            let pointer = classificationSource.buffer.contents()
                .advanced(by: classificationSource.offset + faceIndex * classificationSource.stride)
            let rawValue = pointer.assumingMemoryBound(to: UInt8.self).pointee
            let classification = ARMeshClassification(rawValue: Int(rawValue)) ?? .none
            classificationGroups[classification, default: 0] += 1
        }

        // Estimate area per classification
        let avgFaceArea: Float = 0.01
        for (classification, faceCount) in classificationGroups {
            results.append(ClassificationResult(
                type: classification,
                area: Float(faceCount) * avgFaceArea,
                normal: classification == .wall ? SIMD3<Float>(1, 0, 0) : SIMD3<Float>(0, 1, 0)
            ))
        }

        return results
    }

    // MARK: - Place Creature Guard

    /// Places a persistent creature at a real-world location to guard the spot.
    func placeCreatureGuard(creatureId: String, transform: simd_float4x4, createdBy: String = "Player") -> GameAnchor {
        let anchor = GameAnchor(
            type: .creatureGuard,
            createdBy: createdBy,
            location: transform,
            creatureId: creatureId,
            expiresAt: Date().addingTimeInterval(43200) // 12 hours
        )

        DispatchQueue.main.async {
            self.persistentAnchors.append(anchor)
        }

        return anchor
    }

    // MARK: - Place Rift Portal

    /// Creates a visible rift portal anchored to a real surface.
    func placeRiftPortal(mythology: Mythology, transform: simd_float4x4, createdBy: String = "Player") -> GameAnchor {
        let anchor = GameAnchor(
            type: .riftPortal,
            createdBy: createdBy,
            location: transform,
            mythology: mythology,
            expiresAt: Date().addingTimeInterval(3600) // 1 hour
        )

        DispatchQueue.main.async {
            self.persistentAnchors.append(anchor)
        }

        return anchor
    }

    // MARK: - Place Loot Cache

    /// Places a loot cache that other players can discover.
    func placeLootCache(transform: simd_float4x4, createdBy: String = "Player") -> GameAnchor {
        let anchor = GameAnchor(
            type: .lootCache,
            createdBy: createdBy,
            location: transform,
            expiresAt: Date().addingTimeInterval(21600) // 6 hours
        )

        DispatchQueue.main.async {
            self.persistentAnchors.append(anchor)
        }

        return anchor
    }

    // MARK: - Find Suitable Surface

    /// Finds the best surface for the given anchor type placement.
    func findSuitableSurface(for type: AnchorType) -> SurfaceInfo? {
        switch type {
        case .creatureGuard:
            // Creatures prefer floors near walls (so they can peek around corners)
            return detectedSurfaces
                .filter { $0.classification == .floor && $0.area > 0.5 }
                .sorted { $0.area > $1.area }
                .first

        case .riftPortal:
            // Portals look best on large walls
            return detectedSurfaces
                .filter { $0.classification == .wall && $0.area > 1.0 }
                .sorted { $0.area > $1.area }
                .first

        case .lootCache:
            // Loot caches go on tables or floors
            return detectedSurfaces
                .filter { $0.classification == .table || $0.classification == .floor }
                .filter { $0.area > 0.3 }
                .sorted { $0.area > $1.area }
                .first
        }
    }

    // MARK: - Creature Hiding Behavior

    /// Calculates a hiding position behind a wall surface based on the wall's normal direction.
    /// Creatures hide behind walls and peek around corners for an immersive encounter.
    func calculateHidingPosition(
        creatureTransform: simd_float4x4,
        nearWall wall: SurfaceInfo
    ) -> simd_float4x4 {
        // Offset the creature behind the wall surface by moving along the inverse normal
        let hideOffset: Float = 0.3 // meters behind the wall
        let peekOffset: Float = 0.15 // meters to the side for peeking

        var hiddenPosition = creatureTransform
        // Move behind wall along its normal
        hiddenPosition.columns.3.x += wall.normal.x * (-hideOffset)
        hiddenPosition.columns.3.y += wall.normal.y * (-hideOffset)
        hiddenPosition.columns.3.z += wall.normal.z * (-hideOffset)

        // Slight lateral offset for the peeking effect
        let lateralDirection = simd_normalize(simd_cross(wall.normal, SIMD3<Float>(0, 1, 0)))
        hiddenPosition.columns.3.x += lateralDirection.x * peekOffset
        hiddenPosition.columns.3.z += lateralDirection.z * peekOffset

        return hiddenPosition
    }

    /// Finds the nearest wall surface for a creature to hide behind.
    func findNearestWall(to position: SIMD3<Float>) -> SurfaceInfo? {
        detectedSurfaces
            .filter { $0.classification == .wall }
            .min { surfaceA, surfaceB in
                let posA = SIMD3<Float>(surfaceA.transform.columns.3.x,
                                        surfaceA.transform.columns.3.y,
                                        surfaceA.transform.columns.3.z)
                let posB = SIMD3<Float>(surfaceB.transform.columns.3.x,
                                        surfaceB.transform.columns.3.y,
                                        surfaceB.transform.columns.3.z)
                return simd_distance(position, posA) < simd_distance(position, posB)
            }
    }

    // MARK: - Anchor Cleanup

    private func startAnchorCleanup() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.removeExpiredAnchors()
        }
    }

    private func removeExpiredAnchors() {
        DispatchQueue.main.async {
            self.persistentAnchors.removeAll { $0.isExpired }
        }
    }

    // MARK: - Session Management

    func removeAnchor(_ anchorId: UUID) {
        DispatchQueue.main.async {
            self.persistentAnchors.removeAll { $0.id == anchorId }
        }
    }

    func removeAllAnchors() {
        DispatchQueue.main.async {
            self.persistentAnchors.removeAll()
        }
    }
}
