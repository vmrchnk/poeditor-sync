// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// MARK: - Scripts

let scripts = [
    Script(
        name: "POEditorSync",
        executableName: "poeditor-sync",
        dependencies: [.argumentParser, .yams]
    ),
]

// MARK: - Configuration

// MARK: Package Dependencies

struct Dependency {
    let name: String
    let url: String
    let packageName: String
    let version: String
}

extension Dependency {
    static let argumentParser = Dependency(
        name: "ArgumentParser",
        url: "https://github.com/apple/swift-argument-parser",
        packageName: "swift-argument-parser",
        version: "1.3.0"
    )
    static let yams = Dependency(
        name: "Yams",
        url: "https://github.com/jpsim/Yams",
        packageName: "Yams",
        version: "5.0.0"
    )
}

// MARK: Script Definition

struct Script {
    let name: String
    let executableName: String
    let dependencies: [Dependency]

    init(
        name: String,
        executableName: String,
        dependencies: [Dependency] = []
    ) {
        self.name = name
        self.executableName = executableName
        self.dependencies = dependencies
    }
}

// MARK: - Implementation

// MARK: Product & Target Generation

func products(from scripts: [Script]) -> [Product] {
    scripts.map { script in
        .executable(name: script.executableName, targets: [script.name])
    }
}

func targets(from scripts: [Script]) -> [Target] {
    scripts.map { script in
        let targetDependencies: [Target.Dependency] = script.dependencies.map { dep in
            .product(name: dep.name, package: dep.packageName)
        }

        return .executableTarget(
            name: script.name,
            dependencies: targetDependencies,
            path: "\(script.name)/Sources"
        )
    }
}

// MARK: External Dependencies

var externalDependencies: [Package.Dependency] {
    // Collect all unique dependencies from scripts
    let allDeps = scripts
        .flatMap { $0.dependencies }
        .reduce(into: [String: Dependency]()) { result, dep in
            result[dep.name] = dep
        }
        .values

    // Convert to Package.Dependency
    return allDeps.map { dep in
        .package(url: dep.url, exact: Version(stringLiteral: dep.version))
    }
}

// MARK: - Package

let package = Package(
    name: "Scripts",
    platforms: [.macOS(.v13)],
    products: products(from: scripts),
    dependencies: externalDependencies,
    targets: targets(from: scripts)
)
