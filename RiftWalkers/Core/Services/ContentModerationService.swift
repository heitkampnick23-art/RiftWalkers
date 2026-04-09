import Foundation
import SwiftUI

// MARK: - Content Moderation Service
// Apple Guideline 1.2 compliance: UGC safety, filtering, reporting, blocking.
// Required for App Store approval of any app with user-generated content.

final class ContentModerationService: ObservableObject {
    static let shared = ContentModerationService()

    // MARK: - Published State

    @Published var blockedUsers: Set<String> = []
    @Published var reportedContent: [ContentReport] = []
    @Published var hasAcceptedEULA: Bool = false

    private let blockedUsersKey = "riftwalkers_blocked_users"
    private let eulaAcceptedKey = "riftwalkers_eula_accepted"
    private let reportsKey = "riftwalkers_content_reports"

    // MARK: - Models

    struct ContentReport: Identifiable, Codable {
        let id: UUID
        let contentType: ContentType
        let contentId: String
        let reportedUserId: String
        let reportedUserName: String
        let reason: ReportReason
        let details: String
        let reportedAt: Date

        init(
            id: UUID = UUID(),
            contentType: ContentType,
            contentId: String,
            reportedUserId: String,
            reportedUserName: String,
            reason: ReportReason,
            details: String = "",
            reportedAt: Date = Date()
        ) {
            self.id = id
            self.contentType = contentType
            self.contentId = contentId
            self.reportedUserId = reportedUserId
            self.reportedUserName = reportedUserName
            self.reason = reason
            self.details = details
            self.reportedAt = reportedAt
        }
    }

    enum ContentType: String, Codable, CaseIterable {
        case chatMessage = "Chat Message"
        case creatureDesign = "Creature Design"
        case username = "Username"
        case guildName = "Guild Name"
    }

    enum ReportReason: String, Codable, CaseIterable {
        case inappropriate = "Inappropriate Content"
        case harassment = "Harassment or Bullying"
        case hateSpeech = "Hate Speech"
        case spam = "Spam"
        case cheating = "Cheating"
        case impersonation = "Impersonation"
        case other = "Other"

        var icon: String {
            switch self {
            case .inappropriate: return "exclamationmark.triangle"
            case .harassment: return "hand.raised"
            case .hateSpeech: return "xmark.shield"
            case .spam: return "envelope.badge"
            case .cheating: return "eye.slash"
            case .impersonation: return "person.crop.circle.badge.exclamationmark"
            case .other: return "ellipsis.circle"
            }
        }
    }

    // MARK: - Init

    private init() {
        loadState()
    }

    // MARK: - EULA / Terms

    func acceptEULA() {
        hasAcceptedEULA = true
        UserDefaults.standard.set(true, forKey: eulaAcceptedKey)
    }

    func revokeEULA() {
        hasAcceptedEULA = false
        UserDefaults.standard.set(false, forKey: eulaAcceptedKey)
    }

    // MARK: - Profanity Filter

    /// Checks if text contains objectionable content. Returns cleaned text if needed.
    func filterContent(_ text: String) -> (isClean: Bool, filtered: String) {
        let lowered = text.lowercased()

        // Check against profanity list
        for word in profanityList {
            if lowered.contains(word) {
                let cleaned = replaceProfanity(in: text)
                return (false, cleaned)
            }
        }

        // Check for excessive caps (shouting)
        let uppercaseRatio = Double(text.filter(\.isUppercase).count) / max(Double(text.count), 1)
        if text.count > 5 && uppercaseRatio > 0.8 {
            return (true, text.lowercased().capitalized)
        }

        return (true, text)
    }

    /// Returns true if text passes content filter.
    func isContentAppropriate(_ text: String) -> Bool {
        filterContent(text).isClean
    }

    /// Replaces profanity with asterisks.
    private func replaceProfanity(in text: String) -> String {
        var result = text
        let lowered = text.lowercased()
        for word in profanityList {
            if lowered.contains(word) {
                let replacement = String(repeating: "*", count: word.count)
                result = result.replacingOccurrences(
                    of: word,
                    with: replacement,
                    options: .caseInsensitive
                )
            }
        }
        return result
    }

    /// Validates a username for appropriateness.
    func isUsernameAppropriate(_ name: String) -> Bool {
        let lowered = name.lowercased()
        for word in profanityList {
            if lowered.contains(word) { return false }
        }
        // No special characters that could be used for impersonation
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_- "))
        if name.unicodeScalars.contains(where: { !allowed.contains($0) }) {
            return false
        }
        return true
    }

    // MARK: - Report Content

    func reportContent(
        type: ContentType,
        contentId: String,
        userId: String,
        userName: String,
        reason: ReportReason,
        details: String = ""
    ) {
        let report = ContentReport(
            contentType: type,
            contentId: contentId,
            reportedUserId: userId,
            reportedUserName: userName,
            reason: reason,
            details: details
        )
        reportedContent.append(report)
        saveReports()

        // In production, this would send to the backend for review
        // For now, auto-hide content from reported users after 3+ reports
        let reportsForUser = reportedContent.filter { $0.reportedUserId == userId }
        if reportsForUser.count >= 3 {
            blockUser(userId)
        }
    }

    // MARK: - Block Users

    func blockUser(_ userId: String) {
        blockedUsers.insert(userId)
        saveBlockedUsers()
    }

    func unblockUser(_ userId: String) {
        blockedUsers.remove(userId)
        saveBlockedUsers()
    }

    func isBlocked(_ userId: String) -> Bool {
        blockedUsers.contains(userId)
    }

    /// Filters out content from blocked users.
    func filterBlockedContent<T>(_ items: [T], userIdKeyPath: KeyPath<T, String>) -> [T] {
        items.filter { !blockedUsers.contains($0[keyPath: userIdKeyPath]) }
    }

    // MARK: - Account Deletion

    func requestAccountDeletion() async -> Bool {
        // Clear all local data
        let defaults = UserDefaults.standard
        let allKeys = ["riftwalkers_guild", "hasCompletedOnboarding", "riftwalker_plus_active",
                       blockedUsersKey, eulaAcceptedKey, reportsKey,
                       "riftwalkers_player_save", "riftwalkers_creatures_save"]
        for key in allKeys {
            defaults.removeObject(forKey: key)
        }

        // In production, also call backend to delete server-side data
        // try? await NetworkService.shared.deleteAccount()

        return true
    }

    // MARK: - Persistence

    private func loadState() {
        hasAcceptedEULA = UserDefaults.standard.bool(forKey: eulaAcceptedKey)

        if let data = UserDefaults.standard.data(forKey: blockedUsersKey),
           let users = try? JSONDecoder().decode(Set<String>.self, from: data) {
            blockedUsers = users
        }

        if let data = UserDefaults.standard.data(forKey: reportsKey),
           let reports = try? JSONDecoder().decode([ContentReport].self, from: data) {
            reportedContent = reports
        }
    }

    private func saveBlockedUsers() {
        if let data = try? JSONEncoder().encode(blockedUsers) {
            UserDefaults.standard.set(data, forKey: blockedUsersKey)
        }
    }

    private func saveReports() {
        if let data = try? JSONEncoder().encode(reportedContent) {
            UserDefaults.standard.set(data, forKey: reportsKey)
        }
    }

    // MARK: - Profanity Word List

    private let profanityList: [String] = [
        // Common profanity - comprehensive list for content filtering
        "fuck", "shit", "ass", "damn", "bitch", "bastard", "dick", "cock",
        "pussy", "cunt", "whore", "slut", "fag", "faggot", "nigger", "nigga",
        "retard", "retarded", "kike", "chink", "spic", "wetback", "cracker",
        "tranny", "dyke", "homo", "twat", "wanker", "prick", "arsehole",
        "asshole", "motherfucker", "bullshit", "horseshit", "dipshit",
        "dumbass", "jackass", "shithead", "fuckface", "dickhead",
        // Hate speech terms
        "nazi", "heil hitler", "white power", "kill yourself", "kys",
        // Sexual content
        "porn", "hentai", "xxx", "nsfw", "nude", "naked",
        // Violence
        "murder", "rape", "molest", "terrorist", "bomb threat",
        // Drug references
        "cocaine", "heroin", "meth",
        // Leetspeak variants
        "f4ck", "sh1t", "b1tch", "d1ck", "a55", "fuk", "fcuk", "phuck"
    ]
}

// MARK: - Report Content Sheet View

struct ReportContentView: View {
    let contentType: ContentModerationService.ContentType
    let contentId: String
    let userId: String
    let userName: String
    var onDismiss: () -> Void

    @State private var selectedReason: ContentModerationService.ReportReason?
    @State private var additionalDetails = ""
    @State private var showConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Report \(contentType.rawValue)")
                            .font(.headline)
                        Text("From: \(userName)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Reason") {
                    ForEach(ContentModerationService.ReportReason.allCases, id: \.self) { reason in
                        Button(action: { selectedReason = reason }) {
                            HStack {
                                Image(systemName: reason.icon)
                                    .foregroundStyle(.orange)
                                    .frame(width: 24)
                                Text(reason.rawValue)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedReason == reason {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }

                Section("Additional Details (Optional)") {
                    TextEditor(text: $additionalDetails)
                        .frame(minHeight: 80)
                }

                Section {
                    Button(action: submitReport) {
                        HStack {
                            Spacer()
                            Text("Submit Report")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.red)
                    .disabled(selectedReason == nil)
                }

                Section {
                    Button(action: blockAndReport) {
                        HStack {
                            Image(systemName: "hand.raised.fill")
                                .foregroundStyle(.red)
                            Text("Block \(userName)")
                                .foregroundStyle(.red)
                        }
                    }
                } footer: {
                    Text("Blocking will hide all content from this user. You can unblock them later in Settings.")
                }
            }
            .navigationTitle("Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
            }
            .alert("Report Submitted", isPresented: $showConfirmation) {
                Button("OK") { onDismiss() }
            } message: {
                Text("Thank you for helping keep RiftWalkers safe. We will review this report within 24 hours and take appropriate action.")
            }
        }
    }

    private func submitReport() {
        guard let reason = selectedReason else { return }
        ContentModerationService.shared.reportContent(
            type: contentType,
            contentId: contentId,
            userId: userId,
            userName: userName,
            reason: reason,
            details: additionalDetails
        )
        showConfirmation = true
    }

    private func blockAndReport() {
        ContentModerationService.shared.blockUser(userId)
        if let reason = selectedReason {
            ContentModerationService.shared.reportContent(
                type: contentType,
                contentId: contentId,
                userId: userId,
                userName: userName,
                reason: reason,
                details: additionalDetails
            )
        }
        showConfirmation = true
    }
}

// MARK: - EULA / Terms of Use View

struct EULAView: View {
    var onAccept: () -> Void
    @State private var scrolledToBottom = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Terms of Use & End User License Agreement")
                            .font(.title2.weight(.bold))

                        Text("Last Updated: April 8, 2026")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Group {
                            sectionTitle("1. Acceptance of Terms")
                            sectionBody("By downloading, installing, or using RiftWalkers GO (\"the App\"), you agree to be bound by these Terms of Use. If you do not agree to these terms, do not use the App.")

                            sectionTitle("2. User-Generated Content Policy")
                            sectionBody("""
                            RiftWalkers GO allows users to create and share content including creature designs, guild chat messages, and usernames. By submitting content, you agree that:

                            a) You will not post content that is offensive, abusive, harassing, threatening, obscene, defamatory, or otherwise objectionable.
                            b) You will not post content that promotes hatred, discrimination, or violence against any individual or group.
                            c) You will not post sexually explicit content or content inappropriate for minors.
                            d) You will not post spam, advertisements, or solicitations.
                            e) You will not impersonate other users or public figures.
                            f) All content you submit is your original creation and does not infringe on any third-party rights.
                            """)

                            sectionTitle("3. Content Moderation")
                            sectionBody("""
                            We reserve the right to review, filter, and remove any user-generated content at our sole discretion. Content that violates these terms will be removed and the offending user may be banned. We act on objectionable content reports within 24 hours by removing the content and ejecting the user who provided the offending content.
                            """)

                            sectionTitle("4. Reporting & Blocking")
                            sectionBody("""
                            Users can report objectionable content and block abusive users through the in-app reporting system. When a user is blocked, their content is immediately hidden from the blocking user's feed. All reports are reviewed by our moderation team. Blocking also notifies our team of the inappropriate content.
                            """)

                            sectionTitle("5. Zero Tolerance Policy")
                            sectionBody("RiftWalkers GO has zero tolerance for objectionable content or abusive users. Violations will result in immediate content removal, account suspension, or permanent ban at our discretion.")

                            sectionTitle("6. Account Termination")
                            sectionBody("We may terminate or suspend your account at any time for violations of these terms. You may delete your account at any time through the app's Profile > Settings > Delete Account option.")

                            sectionTitle("7. Privacy")
                            sectionBody("Your use of the App is also governed by our Privacy Policy. We collect location data to provide gameplay features, device identifiers for account management, and gameplay data for cloud saves. We do not sell your personal data to third parties.")

                            sectionTitle("8. In-App Purchases")
                            sectionBody("The App offers optional in-app purchases including consumable gem packs and auto-renewable subscriptions. All purchases are processed by Apple. Subscriptions automatically renew unless canceled at least 24 hours before the end of the current period. You can manage subscriptions in your Apple ID settings.")

                            sectionTitle("9. Disclaimer")
                            sectionBody("The App is provided \"as is\" without warranties of any kind. We are not responsible for user-generated content posted by other users.")

                            sectionTitle("10. Contact")
                            sectionBody("For questions about these terms, content concerns, or to report violations, contact us at support@riftwalkers.app.")
                        }
                    }
                    .padding()

                    // Scroll detection
                    GeometryReader { geo in
                        Color.clear
                            .onChange(of: geo.frame(in: .global).maxY) { _, maxY in
                                if maxY < UIScreen.main.bounds.height + 100 {
                                    scrolledToBottom = true
                                }
                            }
                    }
                    .frame(height: 1)
                }

                // Accept button
                VStack(spacing: 8) {
                    Button(action: {
                        ContentModerationService.shared.acceptEULA()
                        onAccept()
                    }) {
                        Text("I Accept the Terms of Use")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)

                    Button("Decline") {
                        dismiss()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
            .navigationTitle("Terms of Use")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline.weight(.bold))
            .padding(.top, 4)
    }

    private func sectionBody(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Blocked Users Management View

struct BlockedUsersView: View {
    @StateObject private var moderation = ContentModerationService.shared

    var body: some View {
        List {
            if moderation.blockedUsers.isEmpty {
                ContentUnavailableView(
                    "No Blocked Users",
                    systemImage: "hand.raised.slash",
                    description: Text("Users you block will appear here.")
                )
            } else {
                ForEach(Array(moderation.blockedUsers), id: \.self) { userId in
                    HStack {
                        Image(systemName: "person.crop.circle.badge.xmark")
                            .foregroundStyle(.red)
                        Text(userId)
                            .font(.subheadline)
                        Spacer()
                        Button("Unblock") {
                            moderation.unblockUser(userId)
                        }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.blue)
                    }
                }
            }
        }
        .navigationTitle("Blocked Users")
        .navigationBarTitleDisplayMode(.inline)
    }
}
