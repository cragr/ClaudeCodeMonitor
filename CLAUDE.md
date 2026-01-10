# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Claude Code Monitor is a cross-platform desktop application for monitoring Claude Code usage via Prometheus telemetry data. It displays real-time and historical metrics including tokens, cost, active time, sessions, lines of code, commits, and pull requests.

**Tech Stack:** Tauri 2, Rust, Svelte 5, TypeScript, Tailwind CSS, Chart.js

**Supported Platforms:** macOS, Linux, Windows

## Repository Structure

```
ClaudeCodeMonitor/
├── tauri-app/                    # Main application
│   ├── src/                      # Svelte frontend
│   │   ├── lib/components/       # UI components
│   │   ├── lib/stores/           # Svelte stores (state)
│   │   ├── lib/types/            # TypeScript types
│   │   └── routes/               # SvelteKit pages
│   ├── src-tauri/                # Rust backend
│   │   ├── src/main.rs           # App entry, tray, window
│   │   ├── src/prometheus.rs     # HTTP client for Prometheus
│   │   ├── src/metrics.rs        # Data models (serde structs)
│   │   └── src/commands.rs       # Tauri IPC commands
│   ├── package.json              # Node.js dependencies
│   └── tailwind.config.js        # Tailwind configuration
├── compose.yaml                  # Monitoring stack (Podman Compose)
├── prometheus.yml                # Prometheus scrape configuration
├── otel-collector-config.yaml    # OpenTelemetry collector config
└── docs/                         # Documentation
```

## Build Commands

```bash
# Install dependencies
cd tauri-app && pnpm install

# Development with hot-reload
cd tauri-app && pnpm tauri dev

# Production build
cd tauri-app && pnpm tauri build

# Type checking (Svelte + TypeScript)
cd tauri-app && pnpm check

# Rust checks
cd tauri-app/src-tauri && cargo check
cd tauri-app/src-tauri && cargo clippy
```

## Architecture

### Rust Backend (`src-tauri/src/`)

- **`main.rs`** - App entry point, window management, system tray setup
- **`lib.rs`** - Library exports and Tauri command registration
- **`prometheus.rs`** - Async HTTP client for Prometheus API queries
- **`metrics.rs`** - Serde structs for metrics data (`DashboardMetrics`, `TimeSeriesPoint`, etc.)
- **`commands.rs`** - Tauri IPC commands (`get_dashboard_metrics`, `test_connection`, etc.)

### Svelte Frontend (`src/`)

- **`lib/components/`** - Reusable UI components (`MetricCard`, `Sidebar`, `ViewHeader`, etc.)
- **`lib/stores/`** - Svelte stores for state management (`metrics.ts`, `settings.ts`)
- **`lib/types/`** - TypeScript type definitions
- **`routes/+page.svelte`** - Main app layout with sidebar navigation

### Key Patterns

- **Tauri IPC** - Frontend calls `invoke('command_name', { params })` to execute Rust commands
- **Svelte Stores** - Reactive state with `writable()` stores
- **Async Rust** - `reqwest` for HTTP, `tokio` runtime
- **Settings** - `tauri-plugin-store` for persistent JSON storage

## Monitoring Stack

Start with Podman Compose:

```bash
podman compose up -d
```

Services:
- **OpenTelemetry Collector** - Ports 4317 (gRPC), 4318 (HTTP), 8889 (metrics)
- **Prometheus** - Port 9090

## Prometheus Metric Names

Metrics are prefixed with `claude_code_` and use `_total` suffix for counters:

| Metric | Description |
|--------|-------------|
| `claude_code_token_usage_tokens_total` | Token consumption |
| `claude_code_cost_usage_USD_total` | Cost in USD |
| `claude_code_active_time_seconds_total` | Active coding time |
| `claude_code_session_count_total` | Session count |
| `claude_code_lines_of_code_count_total` | Lines added/removed (has `type` label) |
| `claude_code_commit_count_total` | Git commits |
| `claude_code_pull_request_count_total` | Pull requests created |

### Labels

- `session_id` - Session identifier
- `model` - Claude model (e.g., `claude-sonnet-4-20250514`)
- `terminal_type` - Terminal application
- `app_version` - Claude Code version

## Requirements

- **Rust** (stable)
- **Node.js 18+** with pnpm
- **Platform-specific:**
  - macOS: Xcode Command Line Tools
  - Linux: `libwebkit2gtk-4.1-dev`, `libappindicator3-dev`, `librsvg2-dev`, `patchelf`
  - Windows: Visual Studio Build Tools (C++ workload)

## Configuration Files

- `tauri-app/tauri.conf.json` - Tauri configuration (window, tray, updater, bundle targets)
- `tauri-app/package.json` - Node.js scripts and dependencies
- `tauri-app/src-tauri/Cargo.toml` - Rust dependencies
- `tauri-app/tailwind.config.js` - Tailwind CSS theme configuration
