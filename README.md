# UNIXPackage

UNIXPackage is an experimental Swift-based package manager that targets macOS first and keeps UNIX and UNIX-like platforms in mind. It aims to provide a lightweight alternative to Homebrew with a clear installation story for graphical apps, macOS installers, and repository bundles.

## Features
- Swift CLI with commands for `install`, `remove`, `list`, `search`, and `info`
- Built-in metadata repository that showcases core developer tooling and apps
- Persistent local store under `~/Library/Application Support/UNIXPackage/packages.json` (macOS) or `~/.local/share/unixpackage/packages.json` (other UNIX targets)
- Three distinct distribution types (DMG, PKG, repository bundle) to model common macOS workflows — see [docs/distribution-types.md](docs/distribution-types.md) for details
- Platform-awareness that refuses to install packages not supported by the current OS

## Requirements
- Swift 6 toolchain (Xcode 15.3+ on macOS or Swift 6 toolchain on Linux/BSD)
- macOS 14 for DMG/PKG flows (repository bundles work on any supported UNIX target)

## Quick Start
1. Clone the repository
2. Build: `swift build --disable-sandbox`
3. Explore the CLI: `swift run unixpackage help`

## Basic Usage
```sh
unixpackage install curl
unixpackage info git
unixpackage list
unixpackage remove curl
```

> The CLI prints step-by-step installation guidance depending on the package type and records the destination path for later inspection.

## Documentation
- [CLI usage and state management](docs/usage.md)
- [Package distribution types](docs/distribution-types.md)

Contributions and ideas are welcome! Feel free to open issues or experiment with the repository data to add more packages.
