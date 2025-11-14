# Package Distribution Types

UNIXPackage currently models three installation flows that cover popular macOS and UNIX distribution formats. Each package declares its `distribution`, which drives download messaging, install steps, and the final destination path recorded in the local store.

## 1. DMG Applications (`dmgApp`)
- **Source**: Direct download of a `.dmg` disk image from the vendor.
- **Workflow**:
  1. Download the DMG.
  2. Mount it with `hdiutil attach`.
  3. Copy `*.app` bundles into `/Applications`.
  4. Detach (`hdiutil detach`) and remove temporary files.
- **Install Location**: `/Applications/<PackageName>.app`.
- **Use Cases**: GUI apps distributed outside the Mac App Store (e.g., Arc Browser, VS Code insiders).

## 2. PKG Installers (`pkgInstaller`)
- **Source**: Direct download of a signed `.pkg` installer.
- **Workflow**:
  1. Download the PKG.
  2. Run `/usr/sbin/installer -pkg <name>.pkg -target /` (which handles privilege escalation as needed).
  3. Verify receipts/binaries and clean up the downloaded file.
- **Install Location**: `/usr/local/<package-name>` normalized to lowercase with `-` replacing spaces/dots (mirrors the CLI output).
- **Use Cases**: Language runtimes or tooling that already ships official installers (e.g., Git, Python, Node.js).

## 3. Repository Bundles (`repositoryBundle`)
- **Source**: Downloads a custom `.upkg` archive from the UNIXPackage repository (simulated in this prototype).
- **Workflow**:
  1. Fetch metadata from the repository.
  2. Download and verify the bundle.
  3. Extract into `/opt/unixpackage/<package-name>`.
  4. Register the manifest in the local store for listing/removal later.
- **Install Location**: `/opt/unixpackage/<package-name>` normalized the same way as PKG entries.
- **Use Cases**: Cross-platform CLI tools or open-source projects that opt into the UNIXPackage repository instead of bundling DMG/PKG assets.

Each distribution type exposes helper methods (`installSteps`, `installLocation`, and `downloadDescription`) so the CLI can present accurate guidance before the project integrates real download/extraction logic.
