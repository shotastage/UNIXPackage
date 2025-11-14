import Foundation

@main
struct UNIXPackage {
    static func main() {
        let cli = CLI(arguments: CommandLine.arguments)
        cli.run()
    }
}

struct CLI {
    private let arguments: [String]
    private let manager: PackageManager

    init(arguments: [String]) {
        self.arguments = arguments
        do {
            self.manager = try PackageManager()
        } catch {
            Self.printError("Failed to initialize data directory: \(error.localizedDescription)")
            exit(1)
        }
    }

    func run() {
        guard arguments.count > 1 else {
            printWelcome()
            return
        }

        switch arguments[1] {
        case "install":
            handleInstall()
        case "remove", "uninstall":
            handleRemove()
        case "list":
            handleList()
        case "search":
            handleSearch()
        case "info":
            handleInfo()
        case "help", "--help", "-h":
            printHelp()
        case "--version", "-V":
            print("UNIXPackage 0.1.0")
        default:
            Self.printError("Unknown command: \(arguments[1])")
            printHelp()
        }
    }

    private func handleInstall() {
        guard arguments.count >= 3 else {
            Self.printError("install requires a package name.")
            return
        }

        do {
            let installed = try manager.install(packageNamed: arguments[2])
            print("Installed \(installed.name) \(installed.version)")
        } catch {
            Self.printError(error.localizedDescription)
        }
    }

    private func handleRemove() {
        guard arguments.count >= 3 else {
            Self.printError("remove requires a package name.")
            return
        }

        do {
            let removed = try manager.remove(packageNamed: arguments[2])
            print("Removed \(removed.name)")
        } catch {
            Self.printError(error.localizedDescription)
        }
    }

    private func handleList() {
        let packages = manager.installedPackages()
        guard !packages.isEmpty else {
            print("No packages installed yet. Try `unixpackage install <name>`.")
            return
        }

        for pkg in packages {
            print("\(pkg.name) \(pkg.version) — installed \(pkg.formattedInstallDate)")
        }
    }

    private func handleSearch() {
        let query = arguments.count >= 3 ? arguments[2] : ""
        let matches = manager.searchPackages(containing: query)
        guard !matches.isEmpty else {
            print("No packages matched \"\(query)\".")
            return
        }

        for pkg in matches {
            let platforms = pkg.supportedPlatforms.map(\.displayName).joined(separator: ", ")
            print("\(pkg.name) \(pkg.version) [\(platforms)]")
            print("  \(pkg.description)")
        }
    }

    private func handleInfo() {
        guard arguments.count >= 3 else {
            Self.printError("info requires a package name.")
            return
        }

        let (available, installed) = manager.info(for: arguments[2])
        if let pkg = available {
            print("\(pkg.name) \(pkg.version)")
            print(pkg.description)
            print("Homepage: \(pkg.homepage)")
            let platforms = pkg.supportedPlatforms.map(\.displayName).joined(separator: ", ")
            print("Platforms: \(platforms)")
        } else {
            print("No information found for \(arguments[2]).")
        }

        if let installed = installed {
            print("Installed at: \(installed.formattedInstallDate)")
        }
    }

    private func printWelcome() {
        print("""
        UNIXPackage — lightweight UNIX package manager prototype

        Usage:
          unixpackage <command> [arguments]

        Try `unixpackage help` to see available commands.
        """)
    }

    private func printHelp() {
        print("""
        Commands:
          install <name>      Install a package from the default repository.
          remove <name>       Remove a package from the local store.
          list                List installed packages.
          search [query]      Search packages (empty query lists all).
          info <name>         Show details for a package.
          help                Display this message.

        This prototype keeps state in \(PackageStore.storeLocationDescription).
        """)
    }

    private static func printError(_ message: String) {
        fputs("Error: \(message)\n", stderr)
    }
}

struct PackageManager {
    private let repository: PackageRepository
    private let store: PackageStore

    init(fileManager: FileManager = .default) throws {
        self.repository = PackageRepository()
        self.store = try PackageStore(fileManager: fileManager)
    }

    func installedPackages() -> [InstalledPackage] {
        store.installedPackages
    }

    func install(packageNamed name: String) throws -> InstalledPackage {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let package = repository.package(named: normalized) else {
            throw PackageManagerError.packageNotFound(name)
        }

        guard !store.isInstalled(name: package.name) else {
            throw PackageManagerError.packageAlreadyInstalled(package.name)
        }

        guard package.supportsCurrentPlatform() else {
            throw PackageManagerError.platformUnsupported(
                package.name,
                Package.Platform.current?.displayName ?? "current platform"
            )
        }

        do {
            return try store.install(package)
        } catch {
            throw PackageManagerError.storageFailure(error.localizedDescription)
        }
    }

    func remove(packageNamed name: String) throws -> InstalledPackage {
        do {
            if let removed = try store.remove(name: name) {
                return removed
            }
            throw PackageManagerError.packageNotInstalled(name)
        } catch let error as PackageManagerError {
            throw error
        } catch {
            throw PackageManagerError.storageFailure(error.localizedDescription)
        }
    }

    func searchPackages(containing query: String) -> [Package] {
        repository.search(matching: query)
    }

    func info(for name: String) -> (Package?, InstalledPackage?) {
        let available = repository.package(named: name)
        let installed = store.installedPackage(named: name)
        return (available, installed)
    }
}

enum PackageManagerError: LocalizedError {
    case packageNotFound(String)
    case packageAlreadyInstalled(String)
    case packageNotInstalled(String)
    case platformUnsupported(String, String)
    case storageFailure(String)

    var errorDescription: String? {
        switch self {
        case .packageNotFound(let name):
            return "No package named \(name) in the default repository."
        case .packageAlreadyInstalled(let name):
            return "\(name) is already installed."
        case .packageNotInstalled(let name):
            return "\(name) is not installed."
        case .platformUnsupported(let name, let platform):
            return "\(name) is not available for \(platform)."
        case .storageFailure(let message):
            return "Unable to update local package store: \(message)"
        }
    }
}

struct PackageRepository {
    private let packages: [Package]

    init() {
        self.packages = PackageRepository.seedPackages
    }

    func package(named name: String) -> Package? {
        let normalized = name.lowercased()
        return packages.first { $0.name.lowercased() == normalized }
    }

    func search(matching query: String) -> [Package] {
        guard !query.isEmpty else {
            return packages.sorted { $0.name.lowercased() < $1.name.lowercased() }
        }

        let normalized = query.lowercased()
        return packages.filter {
            $0.name.lowercased().contains(normalized) ||
            $0.description.lowercased().contains(normalized)
        }.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    private static let seedPackages: [Package] = [
        Package(
            name: "curl",
            version: "8.7.1",
            description: "Command-line tool for transferring data with URL syntax.",
            homepage: "https://curl.se",
            supportedPlatforms: [.macOS, .linux, .freeBSD, .openBSD]
        ),
        Package(
            name: "wget",
            version: "1.24.5",
            description: "Non-interactive network downloader supporting HTTP, HTTPS, and FTP.",
            homepage: "https://www.gnu.org/software/wget/",
            supportedPlatforms: [.macOS, .linux, .freeBSD]
        ),
        Package(
            name: "git",
            version: "2.45.1",
            description: "Distributed version control system.",
            homepage: "https://git-scm.com",
            supportedPlatforms: [.macOS, .linux, .freeBSD, .openBSD]
        ),
        Package(
            name: "openssl",
            version: "3.2.1",
            description: "Toolkit for TLS and general-purpose cryptography.",
            homepage: "https://www.openssl.org",
            supportedPlatforms: [.macOS, .linux, .freeBSD, .openBSD, .solaris]
        ),
        Package(
            name: "python",
            version: "3.12.3",
            description: "High-level programming language focused on readability.",
            homepage: "https://www.python.org",
            supportedPlatforms: [.macOS, .linux, .freeBSD]
        ),
        Package(
            name: "node",
            version: "22.2.0",
            description: "JavaScript runtime built on Chrome's V8 engine.",
            homepage: "https://nodejs.org",
            supportedPlatforms: [.macOS, .linux]
        ),
        Package(
            name: "neovim",
            version: "0.9.5",
            description: "Refactor-friendly fork of Vim with modern features.",
            homepage: "https://neovim.io",
            supportedPlatforms: [.macOS, .linux, .freeBSD]
        ),
        Package(
            name: "htop",
            version: "3.3.0",
            description: "Interactive process viewer for Unix systems.",
            homepage: "https://htop.dev",
            supportedPlatforms: [.macOS, .linux, .freeBSD]
        )
    ]
}

struct Package: Codable {
    enum Platform: String, Codable, CaseIterable {
        case macOS = "macOS"
        case linux = "Linux"
        case freeBSD = "FreeBSD"
        case openBSD = "OpenBSD"
        case solaris = "Solaris"

        static var current: Platform? {
#if os(macOS)
            return .macOS
#elseif os(Linux)
            return .linux
#elseif os(FreeBSD)
            return .freeBSD
#elseif os(OpenBSD)
            return .openBSD
#else
            return nil
#endif
        }

        var displayName: String {
            rawValue
        }
    }

    let name: String
    let version: String
    let description: String
    let homepage: String
    let supportedPlatforms: [Platform]

    func supportsCurrentPlatform() -> Bool {
        guard let current = Platform.current else {
            return true
        }
        return supportedPlatforms.contains(current)
    }
}

struct InstalledPackage: Codable {
    let name: String
    let version: String
    let description: String
    let homepage: String
    let installedAt: Date

    init(name: String, version: String, description: String, homepage: String, installedAt: Date = Date()) {
        self.name = name
        self.version = version
        self.description = description
        self.homepage = homepage
        self.installedAt = installedAt
    }

    init(from package: Package) {
        self.init(
            name: package.name,
            version: package.version,
            description: package.description,
            homepage: package.homepage
        )
    }

    var formattedInstallDate: String {
        ISO8601DateFormatter().string(from: installedAt)
    }
}

final class PackageStore {
    private let fileManager: FileManager
    private let storeURL: URL
    private var cache: [String: InstalledPackage] = [:]
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    static var storeLocationDescription: String {
        defaultStoreDirectory(fileManager: .default).path
    }

    init(fileManager: FileManager = .default) throws {
        self.fileManager = fileManager
        self.storeURL = try PackageStore.prepareStoreURL(fileManager: fileManager)
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        try load()
    }

    var installedPackages: [InstalledPackage] {
        cache.values.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    func isInstalled(name: String) -> Bool {
        cache[name.lowercased()] != nil
    }

    func installedPackage(named name: String) -> InstalledPackage? {
        cache[name.lowercased()]
    }

    func install(_ package: Package) throws -> InstalledPackage {
        let installed = InstalledPackage(from: package)
        cache[package.name.lowercased()] = installed
        try persist()
        return installed
    }

    func remove(name: String) throws -> InstalledPackage? {
        guard let removed = cache.removeValue(forKey: name.lowercased()) else {
            return nil
        }
        try persist()
        return removed
    }

    private func load() throws {
        let data = try Data(contentsOf: storeURL)
        if data.isEmpty {
            cache = [:]
            return
        }

        let packages = try decoder.decode([InstalledPackage].self, from: data)
        cache = Dictionary(uniqueKeysWithValues: packages.map { ($0.name.lowercased(), $0) })
    }

    private func persist() throws {
        let packages = cache.values.sorted { $0.name.lowercased() < $1.name.lowercased() }
        let data = try encoder.encode(packages)
        try data.write(to: storeURL, options: .atomic)
    }

    private static func prepareStoreURL(fileManager: FileManager) throws -> URL {
        let directory = defaultStoreDirectory(fileManager: fileManager)
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let url = directory.appendingPathComponent("packages.json", isDirectory: false)
        if !fileManager.fileExists(atPath: url.path) {
            try Data("[]".utf8).write(to: url)
        }
        return url
    }

    private static func defaultStoreDirectory(fileManager: FileManager) -> URL {
#if os(macOS)
        let base = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("UNIXPackage", isDirectory: true)
#else
        let base = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".local", isDirectory: true)
            .appendingPathComponent("share", isDirectory: true)
            .appendingPathComponent("unixpackage", isDirectory: true)
#endif
        return base
    }
}
