// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RiftWalkers",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "RiftWalkers", targets: ["RiftWalkers"])
    ],
    dependencies: [
        // Firebase for backend (auth, Firestore, analytics, crashlytics, messaging)
        // .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "10.0.0"),

        // Lottie for high-quality animations
        // .package(url: "https://github.com/airbnb/lottie-spm.git", from: "4.0.0"),

        // SDWebImage for async image loading
        // .package(url: "https://github.com/SDWebImage/SDWebImageSwiftUI.git", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "RiftWalkers",
            dependencies: [],
            path: "RiftWalkers"
        )
    ]
)
