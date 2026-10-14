// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PKCompat",
    platforms: [.iOS(.v18)],
    products: [],
    targets: [
        .binaryTarget(name: "Realm", path: "Binaries/Realm.xcframework"),
        .binaryTarget(name: "RealmSwift", path: "Binaries/RealmSwift.xcframework"),
        .testTarget(
            name: "PKCompatTests",
            dependencies: ["Realm", "RealmSwift"],
            resources: [.copy("Resources")]
        )
    ]
)
