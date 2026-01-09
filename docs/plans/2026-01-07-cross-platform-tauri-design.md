# Cross-Platform Tauri Rewrite Design

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rewrite Claude Code Monitor as a cross-platform desktop app supporting both macOS and Windows using Tauri + Svelte.

**Architecture:** Rust backend for Prometheus queries and system integration, Svelte + TypeScript frontend for UI, Tailwind CSS for styling. Single codebase builds native apps for both platforms.

**Tech Stack:** Tauri 2.x, Rust, Svelte, TypeScript, Tailwind CSS, Chart.js

---

## Context

The current Claude Code Monitor is a native macOS SwiftUI application (~17,000 lines of Swift across 59 files). To support Windows users, we're rewriting as a cross-platform app using Tauri.

**Key Constraint Validated:** Podman Desktop + VPN networking should work on Windows since localhost port forwarding is unaffected by VPN routing (user to validate before implementation).

## Scope

**MVP Features (v0.5.0):**
- Dashboard with core metrics (tokens, cost, active time, sessions, LOC, commits, PRs)
- Settings (Prometheus URL, refresh interval, pricing provider)
- System tray with quick stats
- Auto-updates via Tauri updater

**Deferred to Later Releases:**
- Insights view (period comparisons, sparklines, streaks)
- Sessions view (cost by session, cost by project)
- Stats Cache view (raw metrics)

**Design Direction:**
- Fresh modern dark theme (not terminal noir)
- Clean, minimal UI appropriate for both platforms

---

## Architecture

### Project Structure

```
claude-code-monitor/
├── src-tauri/               # Rust backend
│   ├── src/
│   │   ├── main.rs          # App entry, tray, window management
│   │   ├── prometheus.rs    # HTTP client, PromQL queries
│   │   ├── metrics.rs       # Data models (serde structs)
│   │   └── commands.rs      # Tauri IPC commands
│   ├── Cargo.toml
│   └── tauri.conf.json
├── src/                     # Svelte frontend
│   ├── lib/
│   │   ├── components/      # Reusable UI components
│   │   └── stores/          # Svelte stores (state management)
│   ├── routes/              # Pages (dashboard, settings)
│   ├── app.css              # Tailwind + custom styles
│   └── main.ts
├── package.json
└── vite.config.ts
```

### Data Flow

1. Svelte frontend calls Tauri command (IPC)
2. Rust backend queries Prometheus HTTP API
3. Rust returns typed data to frontend
4. Svelte stores manage state, trigger re-renders

---

## Rust Backend

### Prometheus Client (`prometheus.rs`)

```rust
use reqwest::Client;
use serde::Deserialize;

pub struct PrometheusClient {
    client: Client,
    base_url: String,
}

impl PrometheusClient {
    pub fn new(base_url: &str) -> Self {
        Self {
            client: Client::new(),
            base_url: base_url.to_string(),
        }
    }

    pub async fn query(&self, query: &str) -> Result<QueryResponse, Error> {
        // Instant query: /api/v1/query?query=...
    }

    pub async fn query_range(
        &self,
        query: &str,
        start: i64,
        end: i64,
        step: &str,
    ) -> Result<RangeResponse, Error> {
        // Range query: /api/v1/query_range?query=...&start=...&end=...&step=...
    }
}
```

### Tauri Commands (`commands.rs`)

```rust
#[tauri::command]
async fn get_dashboard_metrics(
    time_range: String,
    prometheus_url: String,
) -> Result<DashboardMetrics, String>

#[tauri::command]
async fn test_connection(url: String) -> Result<bool, String>

#[tauri::command]
fn get_settings() -> Settings

#[tauri::command]
fn save_settings(settings: Settings) -> Result<(), String>
```

### Data Models (`metrics.rs`)

```rust
use serde::{Deserialize, Serialize};

#[derive(Serialize)]
pub struct DashboardMetrics {
    pub total_tokens: u64,
    pub total_cost_usd: f64,
    pub active_time_seconds: f64,
    pub session_count: u32,
    pub lines_added: u64,
    pub lines_removed: u64,
    pub commit_count: u32,
    pub pull_request_count: u32,
    pub tokens_by_model: Vec<ModelTokens>,
    pub tokens_over_time: Vec<TimeSeriesPoint>,
}

#[derive(Serialize)]
pub struct ModelTokens {
    pub model: String,
    pub tokens: u64,
}

#[derive(Serialize)]
pub struct TimeSeriesPoint {
    pub timestamp: i64,
    pub value: f64,
}

#[derive(Serialize, Deserialize)]
pub struct Settings {
    pub prometheus_url: String,
    pub refresh_interval: u32,
    pub pricing_provider: String,
}
```

### Settings Storage

Use `tauri-plugin-store` for JSON file storage:
- Windows: `%APPDATA%/com.claudecode.monitor/settings.json`
- macOS: `~/Library/Application Support/com.claudecode.monitor/settings.json`

---

## Svelte Frontend

### Stores (`src/lib/stores/`)

```typescript
// metrics.ts
import { writable } from 'svelte/store';
import type { DashboardMetrics } from '$lib/types';

export const metrics = writable<DashboardMetrics | null>(null);
export const isLoading = writable(false);
export const error = writable<string | null>(null);
export const timeRange = writable('24h');

// settings.ts
export const settings = writable<Settings>({
  prometheusUrl: 'http://localhost:9090',
  refreshInterval: 30,
  pricingProvider: 'anthropic',
});
```

### Components (`src/lib/components/`)

| Component | Purpose |
|-----------|---------|
| `MetricCard.svelte` | Single stat with label, value, optional trend indicator |
| `TokensChart.svelte` | Line chart for tokens over time |
| `ModelBreakdown.svelte` | Bar chart for tokens by model |
| `StatusIndicator.svelte` | Connection status dot (green/red) |
| `TimeRangePicker.svelte` | Dropdown for 1h/24h/7d/30d selection |

### Dashboard Layout

```
┌─────────────────────────────────────────────────┐
│ Claude Code Monitor          [1h ▾] [⚙️]  [●]  │
├─────────────────────────────────────────────────┤
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐           │
│  │Tokens│ │ Cost │ │ Time │ │ Sess │           │
│  │1.2M  │ │$4.50 │ │2h 15m│ │  12  │           │
│  └──────┘ └──────┘ └──────┘ └──────┘           │
│  ┌──────┐ ┌──────┐ ┌──────┐                    │
│  │ LOC+ │ │ LOC- │ │Commit│                    │
│  │ 450  │ │ 120  │ │  8   │                    │
│  └──────┘ └──────┘ └──────┘                    │
├─────────────────────────────────────────────────┤
│  [Tokens Over Time - Line Chart               ] │
├─────────────────────────────────────────────────┤
│  [Tokens by Model - Bar Chart                 ] │
└─────────────────────────────────────────────────┘
```

---

## System Tray

### Configuration (`tauri.conf.json`)

```json
{
  "tauri": {
    "systemTray": {
      "iconPath": "icons/tray-icon.png",
      "iconAsTemplate": true
    }
  }
}
```

### Menu Items

- "Tokens: 1.2M | Cost: $4.50" (disabled, info display)
- separator
- "Open Dashboard"
- "Settings..."
- separator
- "Check for Updates"
- "Quit"

### Behavior

- Left-click: Open dashboard window
- Right-click: Show menu
- Updates every 30 seconds with latest metrics

---

## Auto-Updates

### Configuration (`tauri.conf.json`)

```json
{
  "tauri": {
    "updater": {
      "active": true,
      "dialog": true,
      "endpoints": [
        "https://github.com/cragr/ClaudeCodeMonitor/releases/latest/download/latest.json"
      ],
      "pubkey": "YOUR_PUBLIC_KEY"
    }
  }
}
```

### Update Manifest (`latest.json`)

```json
{
  "version": "0.5.0",
  "notes": "Cross-platform release with Windows support",
  "pub_date": "2026-01-15T12:00:00Z",
  "platforms": {
    "darwin-x86_64": {
      "url": "https://github.com/.../ClaudeCodeMonitor_0.5.0_x64.dmg",
      "signature": "..."
    },
    "darwin-aarch64": {
      "url": "https://github.com/.../ClaudeCodeMonitor_0.5.0_aarch64.dmg",
      "signature": "..."
    },
    "windows-x86_64": {
      "url": "https://github.com/.../ClaudeCodeMonitor_0.5.0_x64-setup.msi",
      "signature": "..."
    }
  }
}
```

### Signing

Generate keys with: `pnpm tauri signer generate -w ~/.tauri/keys`

---

## Build & Release Pipeline

### Development

```bash
# Prerequisites: Rust, Node.js 18+, pnpm

# Install dependencies
pnpm install

# Dev mode (hot reload)
pnpm tauri dev

# Build for current platform
pnpm tauri build
```

### GitHub Actions (`.github/workflows/release.yml`)

```yaml
name: Release

on:
  push:
    tags: ['v*']

jobs:
  build:
    strategy:
      matrix:
        include:
          - os: macos-latest
            target: universal-apple-darwin
          - os: windows-latest
            target: x86_64-pc-windows-msvc

    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v2
      - uses: actions/setup-node@v4
      - uses: dtolnay/rust-toolchain@stable

      - name: Install dependencies
        run: pnpm install

      - name: Build
        run: pnpm tauri build
        env:
          TAURI_PRIVATE_KEY: ${{ secrets.TAURI_PRIVATE_KEY }}

      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: ${{ matrix.target }}
          path: src-tauri/target/release/bundle/*

  release:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - name: Download artifacts
      - name: Create Release
      - name: Upload latest.json
```

### Release Artifacts

```
v0.5.0/
├── ClaudeCodeMonitor_0.5.0_universal.dmg    # macOS (Intel + Apple Silicon)
├── ClaudeCodeMonitor_0.5.0_x64-setup.msi    # Windows
└── latest.json                               # Updater manifest
```

### Code Signing

- **macOS:** Existing Developer ID certificate (Craig Robinson)
- **Windows:** Requires code signing certificate (DigiCert, Sectigo, etc.)

---

## Repository & Migration Strategy

### Directory Structure

```
ClaudeCodeMonitor/
├── macos-app/           # Existing SwiftUI (deprecated eventually)
├── tauri-app/           # New cross-platform app
│   ├── src-tauri/
│   ├── src/
│   └── package.json
├── docker-compose.yml   # Shared Prometheus stack
├── prometheus.yml
└── README.md
```

### Migration Path

1. **v0.5.0-beta:** Ship Tauri MVP (Dashboard + Settings), announce Windows support
2. **v0.6.0:** Add Insights view
3. **v0.7.0:** Add Sessions view
4. **v0.8.0:** Add Stats Cache view
5. **v1.0.0:** Feature parity, deprecate SwiftUI version

### What Carries Over

- PromQL queries (logic translates directly to Rust)
- Metric names and semantics
- Pricing provider rates
- Docker/Podman stack (unchanged)

### What's New

- Rust HTTP client (replaces Swift actor-based client)
- Svelte components (replaces SwiftUI views)
- Tailwind CSS (replaces DesignSystem.swift)
- Cross-platform system tray and auto-updates

---

## Open Questions

1. **Windows code signing:** Purchase certificate or use self-signed for beta?
2. **Chart library:** Chart.js vs Layerchart (Svelte-native)?
3. **Icon design:** Keep existing icon or refresh for cross-platform?
