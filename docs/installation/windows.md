# Windows Installation

This guide covers installing Claude Code Monitor on Windows 10/11.

## Prerequisites

### 1. Install Podman Desktop

Podman Desktop provides the container runtime with WSL2 backend.

1. Download from [podman-desktop.io](https://podman-desktop.io/)
2. Run the installer
3. Follow the setup wizard to configure WSL2 backend

**WSL2 Requirement:** Podman Desktop uses WSL2 to run Linux containers. The installer will prompt you to enable WSL2 if needed.

**Verify installation:**

Open PowerShell and run:

```powershell
podman --version
podman compose version
```

### 2. Initialize Podman Machine

```powershell
podman machine init
podman machine start
```

## Install the App

### Option A: Download Release (Recommended)

1. Go to the [Releases](https://github.com/cragr/ClaudeCodeMonitor/releases) page
2. Download `Claude.Code.Monitor_x.x.x_x64-setup.exe` or `.msi`
3. Run the installer
4. Launch from the Start menu

### Option B: Build from Source

#### Install Visual Studio Build Tools

1. Download [Visual Studio Build Tools](https://visualstudio.microsoft.com/visual-cpp-build-tools/)
2. Run the installer
3. Select **"Desktop development with C++"** workload
4. Complete the installation

#### Install Rust

1. Download [rustup-init.exe](https://rustup.rs/)
2. Run the installer
3. Follow the prompts (default options are fine)
4. Restart your terminal

**Verify:**

```powershell
rustc --version
cargo --version
```

#### Install Node.js and pnpm

1. Download Node.js LTS from [nodejs.org](https://nodejs.org/)
2. Run the installer
3. Install pnpm:

```powershell
npm install -g pnpm
```

#### Build

```powershell
cd tauri-app
pnpm install
pnpm tauri build
```

Build outputs are in `src-tauri\target\release\bundle\`.

## WebView2 Runtime

Claude Code Monitor uses Microsoft Edge WebView2 for rendering. WebView2 is included in Windows 11 and recent Windows 10 updates.

**If the app fails to start**, install WebView2:
- Download from [Microsoft WebView2](https://developer.microsoft.com/en-us/microsoft-edge/webview2/)

## Next Steps

1. [Set up the monitoring stack](../monitoring-stack.md)
2. [Configure environment variables](../configuration.md)
3. Start using Claude Code and view your metrics

## Troubleshooting

### "VCRUNTIME140.dll not found"

Install the Visual C++ Redistributable:
- Download from [Microsoft VC++ Redistributable](https://aka.ms/vs/17/release/vc_redist.x64.exe)

### Podman machine fails to start

Ensure WSL2 is properly installed:

```powershell
wsl --install
wsl --set-default-version 2
```

Then reset the Podman machine:

```powershell
podman machine stop
podman machine rm
podman machine init
podman machine start
```

### Build fails with link errors

Ensure Visual Studio Build Tools are installed with the C++ workload. You may need to run the build from a "Developer PowerShell for VS" terminal.

### Environment variables not recognized

PowerShell requires different syntax for environment variables. See [Configuration](../configuration.md) for PowerShell setup.

See [Troubleshooting](../troubleshooting.md) for more solutions.
