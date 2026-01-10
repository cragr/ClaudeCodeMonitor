# Claude Code Monitor Documentation

Welcome to the Claude Code Monitor documentation. This guide helps you install, configure, and use the monitoring app across all supported platforms.

## Quick Links

| Document | Description |
|----------|-------------|
| [Main README](../README.md) | Project overview and quickstart |
| [Build Guide](../BUILD.md) | Build from source on any platform |

## Installation Guides

Choose your platform:

- [macOS](installation/macos.md) - Intel and Apple Silicon
- [Linux](installation/linux.md) - Debian/Ubuntu, Fedora, and AppImage
- [Windows](installation/windows.md) - Windows 10/11

## Setup & Configuration

- [Monitoring Stack](monitoring-stack.md) - Set up Podman Desktop and the Prometheus/OTel stack
- [Configuration](configuration.md) - Environment variables and app settings

## Reference

- [Architecture](architecture.md) - Technical overview of Tauri app and metrics flow
- [Troubleshooting](troubleshooting.md) - Common issues and solutions
- [Migration from Swift](migration-from-swift.md) - For contributors familiar with the legacy macOS app

## Getting Started Path

**New users:**
1. Install the app for your platform ([macOS](installation/macos.md) | [Linux](installation/linux.md) | [Windows](installation/windows.md))
2. Set up the [monitoring stack](monitoring-stack.md)
3. Configure [environment variables](configuration.md)
4. Run Claude Code and view your metrics

**Developers:**
1. Read the [Build Guide](../BUILD.md)
2. Review the [Architecture](architecture.md)
3. Check [CLAUDE.md](../CLAUDE.md) for AI assistant context
