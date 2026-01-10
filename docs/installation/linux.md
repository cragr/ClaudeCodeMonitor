# Linux Installation

This guide covers installing Claude Code Monitor on Linux distributions.

## Prerequisites

### 1. Install Podman

Podman is typically available in your distribution's package manager.

**Debian/Ubuntu:**

```bash
sudo apt update
sudo apt install -y podman
```

**Fedora:**

```bash
sudo dnf install -y podman
```

**Arch Linux:**

```bash
sudo pacman -S podman
```

### 2. Install Podman Compose

```bash
sudo apt install -y podman-compose    # Debian/Ubuntu
sudo dnf install -y podman-compose    # Fedora
pip install podman-compose            # Alternative: via pip
```

**Verify:**

```bash
podman --version
podman-compose version
```

### 3. Install Podman Desktop (Optional)

Podman Desktop provides a GUI for managing containers.

**Flatpak (recommended):**

```bash
flatpak install flathub io.podman_desktop.PodmanDesktop
```

**Or download from:** [podman-desktop.io](https://podman-desktop.io/)

## Install the App

### Option A: Download Release

1. Go to the [Releases](https://github.com/cragr/ClaudeCodeMonitor/releases) page
2. Download the appropriate package:
   - `.deb` for Debian/Ubuntu
   - `.rpm` for Fedora/RHEL
   - `.AppImage` for any distribution

**Debian/Ubuntu (.deb):**

```bash
sudo dpkg -i claude-code-monitor_x.x.x_amd64.deb
```

**Fedora/RHEL (.rpm):**

```bash
sudo rpm -i claude-code-monitor-x.x.x-1.x86_64.rpm
```

**AppImage:**

```bash
chmod +x Claude.Code.Monitor_x.x.x_amd64.AppImage
./Claude.Code.Monitor_x.x.x_amd64.AppImage
```

### Option B: Build from Source

#### Install Build Dependencies

**Debian/Ubuntu:**

```bash
sudo apt update
sudo apt install -y \
  libwebkit2gtk-4.1-dev \
  libappindicator3-dev \
  librsvg2-dev \
  patchelf \
  build-essential \
  curl \
  wget \
  file \
  libssl-dev \
  libayatana-appindicator3-dev
```

**Fedora:**

```bash
sudo dnf install -y \
  webkit2gtk4.1-devel \
  libappindicator-gtk3-devel \
  librsvg2-devel \
  patchelf \
  openssl-devel \
  @development-tools
```

#### Install Rust

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
```

#### Install Node.js and pnpm

```bash
# Using NodeSource (Node.js 20 LTS)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Install pnpm
npm install -g pnpm
```

#### Build

```bash
cd tauri-app
pnpm install
pnpm tauri build
```

Build outputs are in `src-tauri/target/release/bundle/`.

## Next Steps

1. [Set up the monitoring stack](../monitoring-stack.md)
2. [Configure environment variables](../configuration.md)
3. Start using Claude Code and view your metrics

## Troubleshooting

### WebKit/GTK errors during build

Ensure all development packages are installed:

```bash
# Debian/Ubuntu
sudo apt install -y libwebkit2gtk-4.1-dev libgtk-3-dev

# Fedora
sudo dnf install -y webkit2gtk4.1-devel gtk3-devel
```

### AppImage won't run

Install FUSE:

```bash
sudo apt install -y fuse libfuse2    # Debian/Ubuntu
sudo dnf install -y fuse fuse-libs   # Fedora
```

### System tray icon not showing

Install the app indicator library:

```bash
sudo apt install -y libayatana-appindicator3-1
```

See [Troubleshooting](../troubleshooting.md) for more solutions.
