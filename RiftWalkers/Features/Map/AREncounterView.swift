import SwiftUI
import ARKit
import RealityKit

// MARK: - AR Creature Encounter View
// Researched: Pokemon GO's AR mode is the #1 viral screenshot driver.
// Players literally show friends "look what's in my backyard!"
// AR encounter → screenshot → share → organic installs. Free marketing.
// Also adds the "talk to creature" feature via AI Companion.

struct AREncounterView: View {
    let spawn: SpawnEvent

    @StateObject private var guide = AICompanionService.shared
    @State private var arActive = true
    @State private var showCaptureUI = true
    @State private var creatureScale: Float = 0.3
    @State private var selectedSphere = "basic"
    @State private var captureState: CaptureState = .idle
    @State private var chatInput = ""
    @State private var chatMessages: [(role: String, text: String)] = []
    @State private var isChattingWithCreature = false
    @State private var showChat = false

    @Environment(\.dismiss) private var dismiss

    enum CaptureState {
        case idle, throwing, captured, escaped
    }

    var species: CreatureSpecies? {
        SpeciesDatabase.shared.getSpecies(spawn.speciesID)
    }

    var body: some View {
        ZStack {
            // AR Camera View
            ARViewContainer(speciesName: species?.name ?? "Creature", elementColor: species?.element.color ?? .white)
                .ignoresSafeArea()

            // Top controls
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .shadow(radius: 4)
                    }

                    Spacer()

                    if let species = species {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(species.name)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                                .shadow(radius: 4)
                            HStack(spacing: 4) {
                                ForEach(0..<species.rarity.stars, id: \.self) { _ in
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 8))
                                        .foregroundStyle(species.rarity.color)
                                }
                            }
                        }
                    }
                }
                .padding()

                Spacer()

                // Creature interaction area
                if captureState == .idle {
                    // Chat / Talk button
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Button(action: { withAnimation { showChat.toggle() } }) {
                                VStack(spacing: 4) {
                                    Image(systemName: "bubble.left.and.bubble.right.fill")
                                        .font(.title3)
                                    Text("Talk")
                                        .font(.system(size: 9, weight: .bold))
                                }
                                .foregroundStyle(.white)
                                .frame(width: 56, height: 56)
                                .background(.blue.opacity(0.6), in: Circle())
                                .shadow(radius: 4)
                            }

                            Button(action: { /* screenshot */ }) {
                                VStack(spacing: 4) {
                                    Image(systemName: "camera.fill")
                                        .font(.title3)
                                    Text("Photo")
                                        .font(.system(size: 9, weight: .bold))
                                }
                                .foregroundStyle(.white)
                                .frame(width: 56, height: 56)
                                .background(.white.opacity(0.2), in: Circle())
                                .shadow(radius: 4)
                            }
                        }
                        .padding(.trailing, 16)
                    }
                }

                // Chat overlay
                if showChat {
                    chatOverlay
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Capture controls
                if captureState == .idle && !showChat {
                    captureControls
                        .transition(.move(edge: .bottom))
                }

                // Capture result
                if captureState == .captured {
                    capturedOverlay
                        .transition(.scale.combined(with: .opacity))
                }

                if captureState == .escaped {
                    escapedOverlay
                }
            }

            // Rift Guide overlay
            RiftGuideOverlay()
        }
        .onAppear {
            if let species = species {
                guide.onCreatureEncounter(species: species, isShiny: spawn.isShiny)
            }
        }
    }

    // MARK: - Chat Overlay (Talk to Creature)

    private var chatOverlay: some View {
        VStack(spacing: 0) {
            // Chat header
            HStack {
                Image(systemName: species?.element.icon ?? "sparkle")
                    .foregroundStyle(species?.element.color ?? .white)
                Text("Talking to \(species?.name ?? "Creature")")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Button(action: { withAnimation { showChat = false } }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Messages
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(chatMessages.enumerated()), id: \.offset) { _, msg in
                        HStack {
                            if msg.role == "user" { Spacer() }
                            Text(msg.text)
                                .font(.caption)
                                .padding(8)
                                .background(
                                    msg.role == "user" ? Color.blue.opacity(0.6) : Color.white.opacity(0.15),
                                    in: RoundedRectangle(cornerRadius: 10)
                                )
                                .foregroundStyle(.white)
                            if msg.role != "user" { Spacer() }
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
            .frame(height: 150)

            // Input
            HStack(spacing: 8) {
                TextField("Say something...", text: $chatInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)

                Button(action: sendChat) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.cyan)
                }
                .disabled(chatInput.isEmpty)
            }
            .padding(12)
        }
        .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private func sendChat() {
        let userMessage = chatInput
        chatMessages.append((role: "user", text: userMessage))
        chatInput = ""

        // Generate creature response via AI
        Task {
            let prompt = """
            You are a \(species?.name ?? "mythological creature") from \(species?.mythology.rawValue ?? "ancient") mythology \
            in a game called RiftWalkers. A player is trying to talk to you before capturing you. \
            Respond in character as the creature — be playful, mysterious, or fierce depending on your nature. \
            Keep response under 30 words. Element: \(species?.element.rawValue ?? "unknown"). \
            Rarity: \(species?.rarity.rawValue ?? "common"). Player said: "\(userMessage)"
            """
            if let response = await AIContentService.shared.generateQuestNarrative(
                title: userMessage, mythology: species?.mythology, type: "creature_chat"
            ) {
                await MainActor.run {
                    chatMessages.append((role: "creature", text: response))
                }
            } else {
                // Fallback responses
                let fallbacks = [
                    "*\(species?.name ?? "The creature") growls softly and tilts its head curiously*",
                    "*It watches you with glowing eyes, as if testing your worthiness*",
                    "*A low rumble echoes from the rift energy surrounding it*",
                ]
                await MainActor.run {
                    chatMessages.append((role: "creature", text: fallbacks.randomElement()!))
                }
            }
        }
    }

    // MARK: - Capture Controls

    private var captureControls: some View {
        VStack(spacing: 12) {
            // Sphere selector
            HStack(spacing: 16) {
                SphereButton(type: "basic", name: "Basic", color: .gray, isSelected: selectedSphere == "basic") {
                    selectedSphere = "basic"
                }
                SphereButton(type: "great", name: "Great", color: .blue, isSelected: selectedSphere == "great") {
                    selectedSphere = "great"
                }
                SphereButton(type: "ultra", name: "Ultra", color: .purple, isSelected: selectedSphere == "ultra") {
                    selectedSphere = "ultra"
                }
            }

            // Throw button
            Button(action: attemptARCapture) {
                VStack(spacing: 4) {
                    Image(systemName: "circle.circle.fill")
                        .font(.system(size: 40))
                    Text("Throw")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(width: 90, height: 80)
                .background(
                    LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: 16)
                )
                .shadow(color: .cyan.opacity(0.5), radius: 10)
            }

            Button("Switch to Card View") { dismiss() }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.bottom, 40)
    }

    private func attemptARCapture() {
        withAnimation { captureState = .throwing }
        HapticsService.shared.sphereShake()

        let captureChance: Double = {
            switch selectedSphere {
            case "great": return 0.5
            case "ultra": return 0.7
            default: return 0.3
            }
        }() / Double(species?.rarity.stars ?? 1)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if Double.random(in: 0...1) < min(0.95, captureChance) {
                withAnimation(.spring()) { captureState = .captured }
                HapticsService.shared.captureSuccess()
                AudioService.shared.playSFX(.creatureCapture)
                if let creature = SpawnManager.shared.getCreatureForSpawn(spawn) {
                    SpawnManager.shared.markCaptured(spawn.id)
                    ProgressionManager.shared.addCreature(creature)
                    guide.onCaptureSuccess(creature: creature)
                }
            } else {
                withAnimation { captureState = .escaped }
                HapticsService.shared.captureFailure()
                AudioService.shared.playSFX(.creatureEscape)
                guide.onCaptureFail()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { captureState = .idle }
                }
            }
        }
    }

    // MARK: - Result Overlays

    private var capturedOverlay: some View {
        VStack(spacing: 12) {
            Text("CAPTURED!")
                .font(.title.weight(.black))
                .foregroundStyle(
                    LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing)
                )
                .shadow(radius: 8)
            if let species = species {
                Text(species.name)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .shadow(radius: 4)
            }
            Button("Continue") { dismiss() }
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 12)
                .background(.blue, in: Capsule())
        }
        .padding(.bottom, 60)
    }

    private var escapedOverlay: some View {
        VStack(spacing: 8) {
            Text("It broke free!")
                .font(.title3.weight(.bold))
                .foregroundStyle(.red)
                .shadow(radius: 4)
            Text("Try again!")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.bottom, 20)
    }
}

// MARK: - AR View Container (RealityKit)

struct ARViewContainer: UIViewRepresentable {
    let speciesName: String
    let elementColor: Color

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // Configure AR session
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic
        arView.session.run(config)

        // Add creature anchor
        let anchor = AnchorEntity(plane: .horizontal, minimumBounds: [0.2, 0.2])

        // Create a glowing orb as creature placeholder
        let mesh = MeshResource.generateSphere(radius: 0.15)
        let uiColor = UIColor(elementColor)
        let material = SimpleMaterial(color: uiColor.withAlphaComponent(0.8), isMetallic: true)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.position = [0, 0.15, 0]

        // Floating animation
        entity.generateCollisionShapes(recursive: true)
        arView.installGestures([.all], for: entity)

        anchor.addChild(entity)

        // Add particle-like ring
        let ringMesh = MeshResource.generateBox(size: [0.4, 0.005, 0.4], cornerRadius: 0.2)
        let ringMaterial = SimpleMaterial(color: uiColor.withAlphaComponent(0.3), isMetallic: false)
        let ring = ModelEntity(mesh: ringMesh, materials: [ringMaterial])
        ring.position = [0, 0.02, 0]
        anchor.addChild(ring)

        arView.scene.addAnchor(anchor)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}
