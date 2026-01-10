# Building Claude Code Monitor

This guide covers building the Claude Code Monitor app from source on all supported platforms.

## Prerequisites by Platform

### macOS

1. **Xcode Command Line Tools**
   ```bash
   xcode-select --install
   ```

2. **Rust**
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   source $HOME/.cargo/env
   ```

3. **Node.js 18+**
   ```bash
   brew install node
   ```

4. **pnpm**
   ```bash
   npm install -g pnpm
   ```

### Linux (Debian/Ubuntu)

1. **Build essentials and WebKit/GTK dependencies**
   ```bash
   sudo apt update
   sudo apt install -y \
     build-essential \
     curl \
     wget \
     file \
     libssl-dev \
     libwebkit2gtk-4.1-dev \
     libappindicator3-dev \
     librsvg2-dev \
     patchelf \
     libayatana-appindicator3-dev
   ```

2. **Rust**
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   source $HOME/.cargo/env
   ```

3. **Node.js 18+**
   ```bash
   curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
   sudo apt install -y nodejs
   ```

4. **pnpm**
   ```bash
   npm install -g pnpm
   ```

### Linux (Fedora)

1. **Build essentials and WebKit/GTK dependencies**
   ```bash
   sudo dnf install -y \
     @development-tools \
     openssl-devel \
     webkit2gtk4.1-devel \
     libappindicator-gtk3-devel \
     librsvg2-devel \
     patchelf
   ```

2. **Rust**
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   source $HOME/.cargo/env
   ```

3. **Node.js 18+**
   ```bash
   sudo dnf install -y nodejs
   ```

4. **pnpm**
   ```bash
   npm install -g pnpm
   ```

### Windows

1. **Visual Studio Build Tools**
   - Download [Visual Studio Build Tools](https://visualstudio.microsoft.com/visual-cpp-build-tools/)
   - Run installer and select **"Desktop development with C++"** workload
   - Restart your terminal after installation

2. **Rust**
   - Download and run [rustup-init.exe](https://rustup.rs/)
   - Follow prompts (default options work)
   - Restart your terminal

3. **Node.js 18+**
   - Download and install from [nodejs.org](https://nodejs.org/)

4. **pnpm**
   ```powershell
   npm install -g pnpm
   ```

## Building the App

### Development Mode

Run with hot-reload for development:

```bash
cd tauri-app
pnpm install
pnpm tauri dev
```

### Production Build

Build release artifacts:

```bash
cd tauri-app
pnpm install
pnpm tauri build
```

### Build Outputs

Build artifacts are created in `tauri-app/src-tauri/target/release/bundle/`:

| Platform | Output Path | Formats |
|----------|-------------|---------|
| macOS | `bundle/dmg/` | `.dmg` |
| Windows | `bundle/nsis/` | `.exe` installer |
| Windows | `bundle/msi/` | `.msi` installer |
| Linux | `bundle/deb/` | `.deb` (Debian/Ubuntu) |
| Linux | `bundle/rpm/` | `.rpm` (Fedora/RHEL) |
| Linux | `bundle/appimage/` | `.AppImage` (Universal) |

### Cross-Compilation (macOS)

Build for both Intel and Apple Silicon on macOS:

```bash
# Add targets
rustup target add aarch64-apple-darwin
rustup target add x86_64-apple-darwin

# Build for Apple Silicon
pnpm tauri build --target aarch64-apple-darwin

# Build for Intel
pnpm tauri build --target x86_64-apple-darwin
```

## Validation

### Type Checking

```bash
cd tauri-app
pnpm check
```

### Rust Checks

```bash
cd tauri-app/src-tauri
cargo check
cargo clippy
```

## Project Structure

```
tauri-app/
├── src/                      # Svelte frontend
│   ├── lib/
│   │   ├── components/       # UI components
│   │   ├── stores/           # Svelte stores
│   │   └── types/            # TypeScript types
│   ├── routes/               # SvelteKit pages
│   └── app.css               # Global styles (Tailwind)
├── src-tauri/                # Rust backend
│   ├── src/
│   │   ├── main.rs           # App entry point
│   │   ├── lib.rs            # Library exports
│   │   ├── prometheus.rs     # Prometheus HTTP client
│   │   ├── metrics.rs        # Data models
│   │   └── commands.rs       # Tauri IPC commands
│   ├── Cargo.toml            # Rust dependencies
│   ├── tauri.conf.json       # Tauri configuration
│   └── icons/                # App icons
├── package.json              # Node.js dependencies
├── tailwind.config.js        # Tailwind CSS config
├── svelte.config.js          # SvelteKit config
└── vite.config.js            # Vite bundler config
```

## CI/CD Pipeline

The project uses GitHub Actions for automated builds. See `.github/workflows/release.yml`.

### Release Process

1. Tag a new version:
   ```bash
   git tag v0.6.0
   git push origin v0.6.0
   ```

2. GitHub Actions builds for all platforms:
   - macOS (aarch64, x86_64)
   - Windows (x86_64)
   - Linux (x86_64)

3. Artifacts are uploaded to a draft release

4. Edit the release notes and publish

### Build Matrix

| Platform | Runner | Target |
|----------|--------|--------|
| macOS (ARM) | `macos-latest` | `aarch64-apple-darwin` |
| macOS (Intel) | `macos-latest` | `x86_64-apple-darwin` |
| Linux | `ubuntu-22.04` | `x86_64-unknown-linux-gnu` |
| Windows | `windows-latest` | `x86_64-pc-windows-msvc` |

## Code Signing

### macOS

macOS builds are signed and notarized via GitHub Actions using these secrets:

- `APPLE_CERTIFICATE` - Base64-encoded .p12 certificate
- `APPLE_CERTIFICATE_PASSWORD` - Certificate password
- `APPLE_SIGNING_IDENTITY` - Developer ID identity string
- `APPLE_ID` - Apple ID email
- `APPLE_PASSWORD` - App-specific password
- `APPLE_TEAM_ID` - Team ID

### Windows

Windows code signing requires a certificate (DigiCert, Sectigo, etc.). Configure via:

- `WINDOWS_CERTIFICATE` - Base64-encoded .pfx certificate
- `WINDOWS_CERTIFICATE_PASSWORD` - Certificate password

### Auto-Updates

The Tauri updater is configured in `tauri.conf.json`:

```json
{
  "plugins": {
    "updater": {
      "endpoints": [
        "https://github.com/cragr/ClaudeCodeMonitor/releases/latest/download/latest.json"
      ],
      "pubkey": "..."
    }
  }
}
```

The `latest.json` manifest is auto-generated by the tauri-action GitHub Action.

## Troubleshooting

### "error: linker `cc` not found" (Linux)

Install build essentials:

```bash
sudo apt install -y build-essential  # Debian/Ubuntu
sudo dnf install -y @development-tools  # Fedora
```

### "WebKit/GTK not found" (Linux)

Install WebKit development packages:

```bash
sudo apt install -y libwebkit2gtk-4.1-dev  # Debian/Ubuntu
sudo dnf install -y webkit2gtk4.1-devel     # Fedora
```

### "LINK : fatal error" (Windows)

Ensure Visual Studio Build Tools are installed with the C++ workload. Try running from "Developer PowerShell for VS".

### "xcrun: error: invalid active developer path" (macOS)

Install Xcode Command Line Tools:

```bash
xcode-select --install
```

### Rust version issues

Update Rust to the latest stable:

```bash
rustup update stable
```

## Development Tips

### Hot Reload

`pnpm tauri dev` provides hot-reload for the Svelte frontend. Rust backend changes require a restart.

### Debugging Rust

Add logging to Rust code:

```rust
println!("Debug: {:?}", value);
```

View output in the terminal running `pnpm tauri dev`.

### DevTools

Press `F12` or `Cmd+Option+I` (macOS) / `Ctrl+Shift+I` (Windows/Linux) to open browser DevTools in the app window.

## See Also

- [Architecture](docs/architecture.md) - Technical overview
- [Troubleshooting](docs/troubleshooting.md) - More solutions
