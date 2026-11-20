// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "KeyView",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "KeyView",
            path: "Sources/KeyView"
        ),
        // With Command Line Tools only (no Xcode), run tests with:
        // swift test -Xswiftc -plugin-path -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
        .testTarget(
            name: "KeyViewTests",
            dependencies: ["KeyView"],
            path: "Tests/KeyViewTests"
        ),
    ]
)
