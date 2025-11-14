# CLI Usage and State

This document expands on the high-level README to describe how to invoke the CLI, where it stores state, and what to expect from each command.

## Building and Running
- Build with SwiftPM: `swift build --disable-sandbox`
- Run ad-hoc via SwiftPM: `swift run unixpackage <command> [arguments]`
- Pass through environment variables such as `SWIFT_USER_CACHE_DIR` if your environment restricts writes to the default SwiftPM cache (helpful on CI or sandboxed setups).

## Commands
| Command | Description |
| --- | --- |
| `install <name>` | Installs a package from the built-in metadata repository. Prints the simulated download + install workflow based on the package distribution type and records the installation target. |
| `remove <name>`/`uninstall <name>` | Removes metadata about an installed package. (Future work can hook this up to real uninstall scripts.) |
| `list` | Lists installed packages with their distribution type, version, and destination path. |
| `search [query]` | Searches package metadata by name or description. An empty query dumps all packages ordered alphabetically. |
| `info <name>` | Shows repository metadata (homepage, platforms, distribution type) and local installation data if present. |
| `help` | Prints concise usage guidance and storage location. |

All commands emit actionable error messages if arguments are missing, packages are unknown, or the platform is unsupported.

## State Location
UNIXPackage persists installed packages inside `packages.json`:
- macOS: `~/Library/Application Support/UNIXPackage/packages.json`
- Other UNIX targets: `~/.local/share/unixpackage/packages.json`

The JSON file contains an array of installed packages with timestamps, distribution types, and resolved install locations. You can safely remove the file to reset the prototype (the CLI will recreate it).

## Installation Workflow Output
When you run `install`, the CLI prints a plan similar to:
```
Starting installation via DMG → /Applications.
  - Download ArcBrowser.dmg directly from the vendor.
  - Mount the disk image using hdiutil.
  - Copy ArcBrowser.app into /Applications.
  - Detach the disk image and remove temporary files.
Installed ArcBrowser 1.16.4
Destination: /Applications/ArcBrowser.app
```
This makes it easy to script or manually perform the necessary actions while the project is still a prototype.

## Extending the Repository
Package definitions live in `Sources/UNIXPackage/UNIXPackage.swift` inside `PackageRepository.seedPackages`. Add entries with the fields:
- `name`
- `version`
- `description`
- `homepage`
- `supportedPlatforms`
- `distribution` (one of the supported types described in [package distribution types](distribution-types.md))

The CLI auto-detects new entries without additional configuration.
