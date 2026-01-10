# macOS Installation

This guide covers installing Claude Code Monitor on macOS (Intel and Apple Silicon).

## Prerequisites

### 1. Install Podman Desktop

Podman Desktop provides the container runtime for the monitoring stack.

**Using Homebrew (recommended):**

```bash
brew install podman-desktop
```

**Or download directly:**

Visit [podman-desktop.io](https://podman-desktop.io/) and download the macOS installer.

### 2. Initialize Podman Machine

After installing Podman Desktop, initialize and start the Podman machine:

```bash
podman machine init
podman machine start
```

**Verify:**

```bash
podman --version
podman compose version
```

Both commands should return version information.

### 3. Configure Autostart (Recommended)

To have the Podman machine start automatically when you log in, use **Podman Desktop**:

1. Open Podman Desktop
2. Go to **Settings** → **Resources**
3. Find your Podman machine and enable **"Start on login"**

**Alternative (launchd):**

Create a launch agent at `~/Library/LaunchAgents/com.podman.machine.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.podman.machine</string>
    <key>ProgramArguments</key>
    <array>
        <string>/opt/homebrew/bin/podman</string>
        <string>machine</string>
        <string>start</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
```

Then load it:

```bash
launchctl load ~/Library/LaunchAgents/com.podman.machine.plist
```

This ensures the monitoring stack is available immediately after login without manual intervention.

## Install the App

### Option A: Download Release (Recommended)

1. Go to the [Releases](https://github.com/cragr/ClaudeCodeMonitor/releases) page
2. Download `Claude.Code.Monitor_x.x.x_aarch64.dmg` (Apple Silicon) or `Claude.Code.Monitor_x.x.x_x64.dmg` (Intel)
3. Open the DMG and drag the app to Applications
4. Launch from Applications

**Note:** On first launch, you may need to right-click and select "Open" to bypass Gatekeeper for unsigned builds.

### Option B: Build from Source

See the [Build Guide](../../BUILD.md) for instructions on building from source.

## Next Steps

1. [Set up the monitoring stack](../monitoring-stack.md)
2. [Configure environment variables](../configuration.md)
3. Start using Claude Code and view your metrics

## Troubleshooting

### "App is damaged and can't be opened"

Remove the quarantine attribute:

```bash
xattr -cr /Applications/Claude\ Code\ Monitor.app
```

### Podman machine won't start

Reset the machine:

```bash
podman machine stop
podman machine rm
podman machine init
podman machine start
```

### App won't connect to Prometheus

Ensure Podman machine is running and the monitoring stack is up:

```bash
podman machine start
podman compose up -d
podman compose ps
```

See [Troubleshooting](../troubleshooting.md) for more solutions.
