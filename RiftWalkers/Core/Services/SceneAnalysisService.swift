import Foundation
import Vision
import UIKit
import CoreLocation
import Combine

// MARK: - Scene Analysis Service (Core ML + Vision)
// Analyzes camera frames to understand the real-world environment.
// Maps detected scenes/objects to creature spawn biases:
//   Water detected → water/ice creatures spawned
//   Trees/parks → nature/earth creatures
//   Urban/buildings → shadow/lightning creatures
//   Night sky → void/arcane creatures
// Uses Apple's built-in VNClassifyImageRequest (no custom model needed).

final class SceneAnalysisService: ObservableObject {
    static let shared = SceneAnalysisService()

    @Published var currentScene: SceneClassification = .unknown
    @Published var detectedObjects: [DetectedObject] = []
    @Published var confidence: Float = 0
    @Published var isAnalyzing = false

    private var lastAnalysisTime: Date = .distantPast
    private let analysisInterval: TimeInterval = 5 // Analyze every 5 seconds
    private let minimumConfidence: Float = 0.15

    // MARK: - Scene Types

    enum SceneClassification: String, CaseIterable {
        case water       // Lakes, rivers, ocean, pools
        case park        // Trees, grass, gardens
        case urban       // Buildings, streets, concrete
        case indoor      // Inside buildings
        case mountain    // Hills, rocks, elevation
        case desert      // Sand, dry terrain
        case snow        // Snow, ice, winter
        case night       // Dark, nighttime
        case forest      // Dense trees, woods
        case beach       // Sand + water
        case unknown

        var preferredElements: [Element] {
            switch self {
            case .water:    return [.water, .ice, .frost]
            case .park:     return [.nature, .earth, .wind]
            case .urban:    return [.lightning, .shadow, .arcane]
            case .indoor:   return [.shadow, .light, .arcane]
            case .mountain: return [.earth, .air, .ice]
            case .desert:   return [.fire, .earth, .wind]
            case .snow:     return [.ice, .frost, .wind]
            case .night:    return [.shadow, .void, .arcane]
            case .forest:   return [.nature, .earth, .shadow]
            case .beach:    return [.water, .wind, .nature]
            case .unknown:  return Element.allCases
            }
        }

        var preferredMythologies: [Mythology] {
            switch self {
            case .water:    return [.norse, .greek, .japanese]
            case .park:     return [.celtic, .japanese, .hindu]
            case .urban:    return [.greek, .egyptian, .aztec]
            case .indoor:   return [.egyptian, .chinese, .slavic]
            case .mountain: return [.norse, .hindu, .chinese]
            case .desert:   return [.egyptian, .aztec, .african]
            case .snow:     return [.norse, .slavic, .chinese]
            case .night:    return [.slavic, .japanese, .african]
            case .forest:   return [.celtic, .slavic, .japanese]
            case .beach:    return [.greek, .african, .japanese]
            case .unknown:  return Mythology.allCases
            }
        }

        var spawnRarityBoost: Double {
            switch self {
            case .water, .forest, .mountain, .beach: return 1.3
            case .night, .snow, .desert: return 1.5
            case .park, .urban, .indoor: return 1.0
            case .unknown: return 1.0
            }
        }
    }

    struct DetectedObject: Identifiable {
        let id = UUID()
        let label: String
        let confidence: Float
        let element: Element?
    }

    // Vision scene classification labels → our SceneClassification
    private let sceneMapping: [String: SceneClassification] = [
        // Water
        "lake": .water, "ocean": .water, "river": .water, "pond": .water,
        "swimming_pool": .water, "fountain": .water, "waterfall": .water,
        "creek": .water, "harbor": .water, "canal": .water,
        // Park / Nature
        "park": .park, "garden": .park, "lawn": .park, "yard": .park,
        "playground": .park, "golf_course": .park, "field": .park,
        // Forest
        "forest": .forest, "bamboo_forest": .forest, "rainforest": .forest,
        "woodland": .forest, "tree_farm": .forest, "jungle": .forest,
        // Urban
        "street": .urban, "downtown": .urban, "skyscraper": .urban,
        "apartment_building": .urban, "parking_lot": .urban,
        "crosswalk": .urban, "alley": .urban, "bridge": .urban,
        "highway": .urban, "sidewalk": .urban,
        // Indoor
        "bedroom": .indoor, "kitchen": .indoor, "living_room": .indoor,
        "office": .indoor, "classroom": .indoor, "library": .indoor,
        "restaurant": .indoor, "store": .indoor, "mall": .indoor,
        "gym": .indoor, "lobby": .indoor,
        // Mountain
        "mountain": .mountain, "cliff": .mountain, "hill": .mountain,
        "volcano": .mountain, "valley": .mountain, "canyon": .mountain,
        // Desert
        "desert": .desert, "sand_dune": .desert, "badlands": .desert,
        // Snow
        "snowfield": .snow, "ice_shelf": .snow, "ski_slope": .snow,
        "glacier": .snow, "tundra": .snow,
        // Beach
        "beach": .beach, "coast": .beach, "sandbar": .beach,
        // Night
        "sky": .night, // will also check brightness
    ]

    // Object labels → Element affinities
    private let objectElementMapping: [String: Element] = [
        "fire": .fire, "flame": .fire, "candle": .fire, "fireplace": .fire,
        "water": .water, "rain": .water, "puddle": .water,
        "tree": .nature, "flower": .nature, "plant": .nature, "grass": .nature,
        "rock": .earth, "stone": .earth, "boulder": .earth, "mountain": .earth,
        "cloud": .air, "sky": .air, "bird": .air,
        "lightning": .lightning, "electricity": .lightning,
        "shadow": .shadow, "dark": .shadow,
        "light": .light, "sun": .light, "lamp": .light,
        "snow": .ice, "ice": .ice, "icicle": .ice,
        "wind": .wind, "flag": .wind, "kite": .wind,
    ]

    private init() {}

    // MARK: - Analyze Camera Frame

    func analyzeFrame(_ image: UIImage) {
        guard Date().timeIntervalSince(lastAnalysisTime) >= analysisInterval else { return }
        guard !isAnalyzing else { return }

        lastAnalysisTime = Date()

        guard let cgImage = image.cgImage else { return }

        DispatchQueue.main.async { self.isAnalyzing = true }

        let request = VNClassifyImageRequest { [weak self] request, error in
            guard let self else { return }

            if let error {
                print("[SceneAnalysis] Error: \(error)")
                DispatchQueue.main.async { self.isAnalyzing = false }
                return
            }

            guard let results = request.results as? [VNClassificationObservation] else {
                DispatchQueue.main.async { self.isAnalyzing = false }
                return
            }

            self.processResults(results, image: image)
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }

    /// Analyze from raw pixel buffer (for real-time camera feed)
    func analyzePixelBuffer(_ buffer: CVPixelBuffer) {
        guard Date().timeIntervalSince(lastAnalysisTime) >= analysisInterval else { return }
        guard !isAnalyzing else { return }

        lastAnalysisTime = Date()
        DispatchQueue.main.async { self.isAnalyzing = true }

        let request = VNClassifyImageRequest { [weak self] request, error in
            guard let self else { return }
            if let results = request.results as? [VNClassificationObservation] {
                self.processResults(results, image: nil)
            }
            DispatchQueue.main.async { self.isAnalyzing = false }
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }

    // MARK: - Process Vision Results

    private func processResults(_ results: [VNClassificationObservation], image: UIImage?) {
        // Get top classifications above threshold
        let topResults = results
            .filter { $0.confidence >= minimumConfidence }
            .prefix(10)

        // Map to scene classification
        var bestScene: SceneClassification = .unknown
        var bestConfidence: Float = 0

        for result in topResults {
            let label = result.identifier.lowercased()
            if let scene = sceneMapping[label], result.confidence > bestConfidence {
                bestScene = scene
                bestConfidence = result.confidence
            }
        }

        // Check brightness for night detection
        if let image, bestScene == .unknown || bestConfidence < 0.3 {
            let brightness = estimateBrightness(image)
            if brightness < 0.25 {
                bestScene = .night
                bestConfidence = max(bestConfidence, 0.6)
            }
        }

        // Map detected objects
        let objects = topResults.compactMap { result -> DetectedObject? in
            let label = result.identifier.lowercased()
            let element = objectElementMapping[label]
            guard result.confidence >= minimumConfidence else { return nil }
            return DetectedObject(label: label, confidence: result.confidence, element: element)
        }

        DispatchQueue.main.async {
            self.currentScene = bestScene
            self.confidence = bestConfidence
            self.detectedObjects = Array(objects.prefix(5))
            self.isAnalyzing = false
        }
    }

    // MARK: - Spawn Weight Modifier

    /// Returns a weight multiplier for a given species based on current scene analysis
    func spawnWeight(for species: CreatureSpecies) -> Double {
        var weight = 1.0

        // Element match bonus
        if currentScene.preferredElements.contains(species.element) {
            weight *= 2.5
        }

        // Mythology match bonus
        if currentScene.preferredMythologies.contains(species.mythology) {
            weight *= 1.8
        }

        // Rarity boost for interesting scenes
        weight *= currentScene.spawnRarityBoost

        // Object-specific bonus
        for obj in detectedObjects {
            if let objElement = obj.element, objElement == species.element {
                weight *= 1.0 + Double(obj.confidence)
            }
        }

        return weight
    }

    /// Get the best mythology for current scene
    func suggestedMythology() -> Mythology? {
        currentScene.preferredMythologies.first
    }

    /// Get the best elements for current scene
    func suggestedElements() -> [Element] {
        currentScene.preferredElements
    }

    // MARK: - Brightness Estimation

    private func estimateBrightness(_ image: UIImage) -> CGFloat {
        guard let cgImage = image.cgImage else { return 0.5 }

        let width = 20
        let height = 20
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var rawData = [UInt8](repeating: 0, count: width * height * 4)

        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return 0.5 }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var totalBrightness: CGFloat = 0
        let pixelCount = width * height

        for i in 0..<pixelCount {
            let offset = i * 4
            let r = CGFloat(rawData[offset]) / 255.0
            let g = CGFloat(rawData[offset + 1]) / 255.0
            let b = CGFloat(rawData[offset + 2]) / 255.0
            totalBrightness += (r * 0.299 + g * 0.587 + b * 0.114)
        }

        return totalBrightness / CGFloat(pixelCount)
    }
}
