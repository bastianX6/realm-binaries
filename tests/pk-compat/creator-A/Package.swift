// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "creatorA",
    platforms: [.iOS(.v18)],
    products: [],
    targets: [
        .binaryTarget(name: "Realm", path: "Binaries/Realm.xcframework"),
        .binaryTarget(name: "RealmSwift", path: "Binaries/RealmSwift.xcframework"),
        .testTarget(name: "CreatorATests", dependencies: ["Realm", "RealmSwift"])
    ]
)
