import PackageDescription

let package = Package(
    name: "Fiber",
    dependencies: [
        .Package(url: "https://github.com/windoze/swift-context.git", majorVersion: 1)
    ]
)
