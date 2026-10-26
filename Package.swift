// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "MacWatch", platforms: [.macOS(.v13)], products: [.executable(name: "MacWatch", targets: ["MacWatch"])], targets: [.executableTarget(name: "MacWatch"), .testTarget(name: "MacWatchTests", dependencies: ["MacWatch"])])
