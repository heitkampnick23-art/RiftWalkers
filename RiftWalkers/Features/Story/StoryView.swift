import SwiftUI

// MARK: - Story Data

struct StoryChapter: Identifiable {
    let id: String
    let number: Int
    let title: String
    let mythology: Mythology
    let synopsis: String
    let dialogueNodes: [DialogueNode]
    let requiredLevel: Int
    let rewardXP: Int
    let rewardGold: Int
    let rewardTitle: String?
}

struct DialogueNode: Identifiable {
    let id: String
    let speaker: String
    let speakerIcon: String
    let text: String
    let choices: [DialogueChoice]?
    let isNarration: Bool
}

struct DialogueChoice: Identifiable {
    let id = UUID().uuidString
    let text: String
    let nextNodeId: String?
    let alignment: String? // "brave", "wise", "cunning"
}

// MARK: - Story Database

struct StoryDatabase {
    static let chapters: [StoryChapter] = [
        StoryChapter(
            id: "ch1", number: 1, title: "The Rift Awakening", mythology: .norse,
            synopsis: "Strange rifts tear through the fabric of reality, unleashing creatures from ancient mythologies. You are among the first to discover you can bond with these beings.",
            dialogueNodes: [
                DialogueNode(id: "1_1", speaker: "", speakerIcon: "", text: "The sky splits open with a sound like breaking glass. A shimmer of light cuts through the clouds above the city, and reality folds in on itself.", choices: nil, isNarration: true),
                DialogueNode(id: "1_2", speaker: "Professor Valen", speakerIcon: "person.fill.viewfinder", text: "You see it too, don't you? The Rift. I've been tracking these anomalies for months. They're getting stronger.", choices: nil, isNarration: false),
                DialogueNode(id: "1_3", speaker: "Professor Valen", speakerIcon: "person.fill.viewfinder", text: "These creatures... they're from the old myths. Norse, Greek, Egyptian. Somehow the barriers between our world and theirs are crumbling.", choices: [
                    DialogueChoice(text: "How do I stop it?", nextNodeId: "1_4a", alignment: "brave"),
                    DialogueChoice(text: "Why can I see them?", nextNodeId: "1_4b", alignment: "wise"),
                ], isNarration: false),
                DialogueNode(id: "1_4a", speaker: "Professor Valen", speakerIcon: "person.fill.viewfinder", text: "Brave. I like that. You can't stop the Rifts alone, but you can walk between worlds. Bond with the creatures. Become a Rift Walker.", choices: nil, isNarration: false),
                DialogueNode(id: "1_4b", speaker: "Professor Valen", speakerIcon: "person.fill.viewfinder", text: "Because you're special. One in a million can perceive the Rifts. We call them Rift Walkers. And you, my friend, just joined our ranks.", choices: nil, isNarration: false),
                DialogueNode(id: "1_5", speaker: "", speakerIcon: "", text: "A small creature emerges from the nearest rift \u{2014} a Norse frost spirit, shimmering with ancient power. It looks at you with curious, glowing eyes.", choices: nil, isNarration: true),
                DialogueNode(id: "1_6", speaker: "Professor Valen", speakerIcon: "person.fill.viewfinder", text: "It's drawn to you. Reach out. This is how it begins.", choices: [
                    DialogueChoice(text: "[Reach out gently]", nextNodeId: nil, alignment: "wise"),
                    DialogueChoice(text: "[Stand firm and call it]", nextNodeId: nil, alignment: "brave"),
                ], isNarration: false),
            ],
            requiredLevel: 1, rewardXP: 500, rewardGold: 300, rewardTitle: nil
        ),
        StoryChapter(
            id: "ch2", number: 2, title: "Echoes of Olympus", mythology: .greek,
            synopsis: "The Greek Rifts are tearing open across ancient ruins. A mysterious figure claims the gods themselves are trying to cross over.",
            dialogueNodes: [
                DialogueNode(id: "2_1", speaker: "", speakerIcon: "", text: "Lightning crackles from a Rift above the ruins. The air smells of ozone and ancient stone.", choices: nil, isNarration: true),
                DialogueNode(id: "2_2", speaker: "Athena's Echo", speakerIcon: "bolt.shield.fill", text: "Mortal... you walk between the veils. The Olympians watch. Our creatures serve as emissaries of a message you are not yet ready to hear.", choices: nil, isNarration: false),
                DialogueNode(id: "2_3", speaker: "Athena's Echo", speakerIcon: "bolt.shield.fill", text: "Prove your worth. The creatures of Olympus do not bond with the unworthy. Seek the three trials.", choices: [
                    DialogueChoice(text: "I accept your challenge.", nextNodeId: nil, alignment: "brave"),
                    DialogueChoice(text: "What is this message?", nextNodeId: nil, alignment: "wise"),
                ], isNarration: false),
            ],
            requiredLevel: 5, rewardXP: 800, rewardGold: 500, rewardTitle: "Olympus Seeker"
        ),
        StoryChapter(
            id: "ch3", number: 3, title: "Sands of the Duat", mythology: .egyptian,
            synopsis: "The Egyptian Rifts lead to the Duat \u{2014} the realm of the dead. Anubis's servants guard secrets about why the Rifts are spreading.",
            dialogueNodes: [
                DialogueNode(id: "3_1", speaker: "", speakerIcon: "", text: "Sand pours through the Rift like an hourglass draining between worlds. The desert heat mixes with a chill that doesn't belong to this plane.", choices: nil, isNarration: true),
                DialogueNode(id: "3_2", speaker: "Keeper Maat", speakerIcon: "scalemass.fill", text: "Your heart is weighed, Walker. The scales of Ma'at see all. You carry the bond of many creatures... but are you balanced?", choices: [
                    DialogueChoice(text: "Balance is for the cautious.", nextNodeId: nil, alignment: "cunning"),
                    DialogueChoice(text: "I seek harmony in all things.", nextNodeId: nil, alignment: "wise"),
                ], isNarration: false),
            ],
            requiredLevel: 8, rewardXP: 1200, rewardGold: 700, rewardTitle: "Duat Explorer"
        ),
        StoryChapter(
            id: "ch4", number: 4, title: "Spirits of the Torii", mythology: .japanese,
            synopsis: "The Japanese Rifts are different \u{2014} quieter, more refined. The yokai that emerge speak of a great convergence approaching.",
            dialogueNodes: [
                DialogueNode(id: "4_1", speaker: "", speakerIcon: "", text: "Cherry blossoms drift through the Rift, each petal carrying a faint glow of spiritual energy.", choices: nil, isNarration: true),
                DialogueNode(id: "4_2", speaker: "Kitsune Elder", speakerIcon: "flame.fill", text: "The convergence approaches, Rift Walker. Ten mythologies. Ten gates. When all ten align... the Primordials will stir.", choices: nil, isNarration: false),
            ],
            requiredLevel: 12, rewardXP: 1500, rewardGold: 1000, rewardTitle: "Spirit Walker"
        ),
        StoryChapter(
            id: "ch5", number: 5, title: "The Celtic Crossing", mythology: .celtic,
            synopsis: "Deep within ancient groves, the Fae courts prepare for war. The Celtic Rifts hold the key to understanding the Primordials.",
            dialogueNodes: [
                DialogueNode(id: "5_1", speaker: "", speakerIcon: "", text: "The forest grows thicker than nature allows. Ancient trees twist into archways, and the air hums with enchantment.", choices: nil, isNarration: true),
                DialogueNode(id: "5_2", speaker: "Queen Morrigan", speakerIcon: "crown.fill", text: "The Fae remember the Primordials, Walker. We sealed them once. But the seals are breaking, and we cannot hold them alone.", choices: [
                    DialogueChoice(text: "Then we fight together.", nextNodeId: nil, alignment: "brave"),
                    DialogueChoice(text: "Tell me about the seals.", nextNodeId: nil, alignment: "wise"),
                ], isNarration: false),
            ],
            requiredLevel: 15, rewardXP: 2000, rewardGold: 1200, rewardTitle: "Fae Ally"
        ),
        StoryChapter(
            id: "ch6", number: 6, title: "The Convergence", mythology: .norse,
            synopsis: "All ten mythological Rifts are tearing open simultaneously. The Primordials begin to emerge, and only the greatest Rift Walkers can face them.",
            dialogueNodes: [
                DialogueNode(id: "6_1", speaker: "", speakerIcon: "", text: "The sky is a mosaic of ten worlds. Norse ice meets Egyptian sand, Greek lightning intertwines with Japanese spirit fire. The Convergence has begun.", choices: nil, isNarration: true),
                DialogueNode(id: "6_2", speaker: "Professor Valen", speakerIcon: "person.fill.viewfinder", text: "This is it. Everything we've prepared for. The Primordials are entities that existed before the mythologies divided. They are neither good nor evil \u{2014} they simply are. And they are impossibly powerful.", choices: nil, isNarration: false),
                DialogueNode(id: "6_3", speaker: "Professor Valen", speakerIcon: "person.fill.viewfinder", text: "Your bonds with creatures from every mythology... that's the key. You are the bridge between worlds. Only you can face them.", choices: [
                    DialogueChoice(text: "I was born for this.", nextNodeId: nil, alignment: "brave"),
                    DialogueChoice(text: "What if I fail?", nextNodeId: nil, alignment: "wise"),
                    DialogueChoice(text: "Let's make a plan.", nextNodeId: nil, alignment: "cunning"),
                ], isNarration: false),
            ],
            requiredLevel: 20, rewardXP: 5000, rewardGold: 3000, rewardTitle: "Convergence Hero"
        ),
    ]
}

// MARK: - Story View (Chapter List)

struct StoryView: View {
    @StateObject private var progression = ProgressionManager.shared
    @State private var selectedChapter: StoryChapter?
    @State private var completedChapters: Set<String> = {
        Set(UserDefaults.standard.stringArray(forKey: "completedStoryChapters") ?? [])
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Story banner
                    ZStack {
                        LinearGradient(colors: [.purple.opacity(0.6), .black], startPoint: .top, endPoint: .bottom)
                            .frame(height: 140)
                        VStack(spacing: 4) {
                            Text("THE RIFT CHRONICLES")
                                .font(.caption.weight(.black))
                                .foregroundStyle(.purple.opacity(0.7))
                                .tracking(4)
                            Text("Story Mode")
                                .font(.title.weight(.black))
                                .foregroundStyle(.white)
                            Text("\(completedChapters.count) / \(StoryDatabase.chapters.count) Chapters Complete")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Chapter timeline
                    VStack(spacing: 0) {
                        ForEach(StoryDatabase.chapters) { chapter in
                            let isUnlocked = progression.player.level >= chapter.requiredLevel
                            let isComplete = completedChapters.contains(chapter.id)
                            let isNext = isUnlocked && !isComplete && !StoryDatabase.chapters.filter { $0.number < chapter.number && !completedChapters.contains($0.id) }.isEmpty.inverted()

                            StoryChapterRow(
                                chapter: chapter,
                                isUnlocked: isUnlocked,
                                isComplete: isComplete,
                                isNext: isNext
                            )
                            .onTapGesture {
                                if isUnlocked { selectedChapter = chapter }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Story")
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(item: $selectedChapter) { chapter in
                DialogueView(chapter: chapter) {
                    completeChapter(chapter)
                }
            }
        }
    }

    private func completeChapter(_ chapter: StoryChapter) {
        completedChapters.insert(chapter.id)
        UserDefaults.standard.set(Array(completedChapters), forKey: "completedStoryChapters")
        ProgressionManager.shared.awardXP(amount: chapter.rewardXP, source: .questComplete)
        EconomyManager.shared.earn(gold: chapter.rewardGold)
        HapticsService.shared.notification(.success)
    }
}

private extension Bool {
    func inverted() -> Bool { !self }
}

// MARK: - Chapter Row

struct StoryChapterRow: View {
    let chapter: StoryChapter
    let isUnlocked: Bool
    let isComplete: Bool
    let isNext: Bool

    var body: some View {
        HStack(spacing: 16) {
            // Timeline dot
            VStack(spacing: 0) {
                Rectangle().fill(.white.opacity(0.1)).frame(width: 2, height: 20)
                ZStack {
                    Circle()
                        .fill(isComplete ? .green : isUnlocked ? chapter.mythology.color : .white.opacity(0.1))
                        .frame(width: 36, height: 36)
                    if isComplete {
                        Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.white)
                    } else if isUnlocked {
                        Text("\(chapter.number)").font(.caption.weight(.black)).foregroundStyle(.white)
                    } else {
                        Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Rectangle().fill(.white.opacity(0.1)).frame(width: 2, height: 20)
            }

            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("Chapter \(chapter.number)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(chapter.mythology.color)
                    Image(systemName: chapter.mythology.icon)
                        .font(.system(size: 10))
                        .foregroundStyle(chapter.mythology.color)
                    Spacer()
                    if !isUnlocked {
                        Text("Lv.\(chapter.requiredLevel)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }

                Text(chapter.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(isUnlocked ? .white : .secondary)

                Text(chapter.synopsis)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if isUnlocked && !isComplete {
                    HStack(spacing: 8) {
                        Label("+\(chapter.rewardXP) XP", systemImage: "star.fill")
                        Label("+\(chapter.rewardGold)", systemImage: "dollarsign.circle.fill")
                        if let title = chapter.rewardTitle {
                            Text(title).foregroundStyle(chapter.mythology.color)
                        }
                    }
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
        }
        .padding(.horizontal)
        .background(
            isNext ? chapter.mythology.color.opacity(0.05) : Color.clear,
            in: RoundedRectangle(cornerRadius: 12)
        )
    }
}

// MARK: - Dialogue View

struct DialogueView: View {
    let chapter: StoryChapter
    let onComplete: () -> Void

    @State private var currentNodeIndex = 0
    @State private var displayedText = ""
    @State private var isTyping = false
    @State private var showChoices = false
    @Environment(\.dismiss) private var dismiss

    private var currentNode: DialogueNode? {
        guard currentNodeIndex < chapter.dialogueNodes.count else { return nil }
        return chapter.dialogueNodes[currentNodeIndex]
    }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [chapter.mythology.color.opacity(0.3), .black],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("Chapter \(chapter.number)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(chapter.mythology.color)
                    Spacer()
                    Text("\(currentNodeIndex + 1)/\(chapter.dialogueNodes.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()

                Spacer()

                // Scene area
                if let node = currentNode {
                    if node.isNarration {
                        // Narration card
                        VStack(spacing: 16) {
                            Image(systemName: chapter.mythology.icon)
                                .font(.system(size: 40))
                                .foregroundStyle(chapter.mythology.color)

                            Text(displayedText)
                                .font(.body)
                                .italic()
                                .foregroundStyle(.white.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                        .padding()
                    } else {
                        // Dialogue card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(chapter.mythology.color.opacity(0.2))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: node.speakerIcon)
                                        .font(.title3)
                                        .foregroundStyle(chapter.mythology.color)
                                }
                                Text(node.speaker)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(chapter.mythology.color)
                                Spacer()
                            }

                            Text(displayedText)
                                .font(.body)
                                .foregroundStyle(.white)

                            // Choices
                            if showChoices, let choices = node.choices {
                                VStack(spacing: 8) {
                                    ForEach(choices) { choice in
                                        Button(action: { advanceNode() }) {
                                            HStack {
                                                Text(choice.text)
                                                    .font(.subheadline.weight(.medium))
                                                    .foregroundStyle(.white)
                                                Spacer()
                                                if let align = choice.alignment {
                                                    Text(align.capitalized)
                                                        .font(.system(size: 9, weight: .bold))
                                                        .foregroundStyle(alignmentColor(align))
                                                }
                                            }
                                            .padding()
                                            .background(
                                                chapter.mythology.color.opacity(0.15),
                                                in: RoundedRectangle(cornerRadius: 12)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .strokeBorder(chapter.mythology.color.opacity(0.3))
                                            )
                                        }
                                    }
                                }
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                        }
                        .padding(20)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                        .padding()
                    }
                } else {
                    // Chapter complete
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.yellow)
                        Text("Chapter Complete!")
                            .font(.title2.weight(.black))
                        Text(chapter.title)
                            .font(.headline)
                            .foregroundStyle(chapter.mythology.color)

                        VStack(spacing: 8) {
                            Label("+\(chapter.rewardXP) XP", systemImage: "star.fill")
                                .foregroundStyle(.cyan)
                            Label("+\(chapter.rewardGold) Gold", systemImage: "dollarsign.circle.fill")
                                .foregroundStyle(.yellow)
                            if let title = chapter.rewardTitle {
                                Label("Title: \(title)", systemImage: "crown.fill")
                                    .foregroundStyle(chapter.mythology.color)
                            }
                        }
                        .font(.subheadline.weight(.bold))

                        Button(action: {
                            onComplete()
                            dismiss()
                        }) {
                            Text("Continue")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(chapter.mythology.color, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal, 40)
                    }
                }

                Spacer()

                // Tap to continue (no choices)
                if let node = currentNode, (node.choices == nil || node.choices?.isEmpty == true) {
                    Button(action: {
                        if isTyping {
                            finishTyping()
                        } else {
                            advanceNode()
                        }
                    }) {
                        Text(isTyping ? "Skip" : "Tap to continue")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding()
                    }
                }
            }
        }
        .onAppear { startTyping() }
    }

    private func startTyping() {
        guard let node = currentNode else { return }
        displayedText = ""
        showChoices = false
        isTyping = true

        let fullText = node.text
        var charIndex = 0

        Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { timer in
            if charIndex < fullText.count {
                let idx = fullText.index(fullText.startIndex, offsetBy: charIndex)
                displayedText.append(fullText[idx])
                charIndex += 1
            } else {
                timer.invalidate()
                isTyping = false
                if node.choices != nil && !(node.choices?.isEmpty ?? true) {
                    withAnimation(.easeIn(duration: 0.3)) { showChoices = true }
                }
            }
        }
    }

    private func finishTyping() {
        guard let node = currentNode else { return }
        isTyping = false
        displayedText = node.text
        if node.choices != nil && !(node.choices?.isEmpty ?? true) {
            withAnimation(.easeIn(duration: 0.3)) { showChoices = true }
        }
    }

    private func advanceNode() {
        currentNodeIndex += 1
        if currentNode != nil {
            startTyping()
        }
        HapticsService.shared.impact(.light)
    }

    private func alignmentColor(_ alignment: String) -> Color {
        switch alignment {
        case "brave": return .red
        case "wise": return .blue
        case "cunning": return .green
        default: return .secondary
        }
    }
}

extension StoryChapter: Equatable {
    static func == (lhs: StoryChapter, rhs: StoryChapter) -> Bool { lhs.id == rhs.id }
}
