# Architecture

This document describes the technical architecture of Claude Code Monitor.

## System Overview

Claude Code Monitor is a cross-platform desktop application that visualizes Claude Code usage metrics collected via OpenTelemetry.

```
┌─────────────────┐     ┌──────────────────┐     ┌────────────┐     ┌───────────────────┐
│   Claude Code   │────▶│  OTel Collector  │────▶│ Prometheus │────▶│ Claude Code Monitor│
│     (CLI)       │     │  (4317/4318)     │     │   (9090)   │     │      (App)        │
└─────────────────┘     └──────────────────┘     └────────────┘     └───────────────────┘
        │                        │                      │                     │
    OTLP/gRPC              Prometheus             HTTP API              Tauri App
                            Export               (PromQL)
```

## Tech Stack

| Layer | Technology |
|-------|------------|
| Desktop Framework | [Tauri 2](https://tauri.app/) |
| Backend | Rust |
| Frontend | [Svelte 5](https://svelte.dev/) + TypeScript |
| Styling | [Tailwind CSS](https://tailwindcss.com/) |
| Charts | [Chart.js](https://www.chartjs.org/) |
| Build Tool | [Vite](https://vitejs.dev/) |
| Package Manager | [pnpm](https://pnpm.io/) |

## Directory Structure

```
ClaudeCodeMonitor/
├── tauri-app/                    # Main application
│   ├── src/                      # Svelte frontend
│   │   ├── lib/
│   │   │   ├── components/       # UI components
│   │   │   ├── stores/           # Svelte stores (state)
│   │   │   └── types/            # TypeScript types
│   │   ├── routes/               # SvelteKit pages
│   │   └── app.css               # Global styles
│   ├── src-tauri/                # Rust backend
│   │   ├── src/
│   │   │   ├── main.rs           # App entry, window management
│   │   │   ├── lib.rs            # Library exports
│   │   │   ├── prometheus.rs     # HTTP client for Prometheus
│   │   │   ├── metrics.rs        # Data models
│   │   │   └── commands.rs       # Tauri IPC commands
│   │   ├── Cargo.toml            # Rust dependencies
│   │   └── tauri.conf.json       # Tauri configuration
│   ├── package.json              # Node.js dependencies
│   └── tailwind.config.js        # Tailwind configuration
├── compose.yaml                  # Monitoring stack definition
├── prometheus.yml                # Prometheus scrape config
├── otel-collector-config.yaml    # OTel Collector config
└── docs/                         # Documentation
```

## Data Flow

### 1. Metrics Collection

Claude Code exports metrics via OpenTelemetry:

```
Claude Code CLI
    │
    ▼ OTLP/gRPC (port 4317)
    │
OTel Collector
    │
    ▼ Prometheus Remote Write
    │
Prometheus (port 9090)
    │
    ▼ Stored in TSDB
```

### 2. Metrics Query

The app queries Prometheus via HTTP:

```
Claude Code Monitor (Svelte)
    │
    ▼ Tauri IPC (invoke)
    │
Rust Backend (commands.rs)
    │
    ▼ HTTP GET /api/v1/query
    │
Prometheus
    │
    ▼ JSON Response
    │
Rust Backend
    │
    ▼ Deserialized structs
    │
Svelte Frontend (reactive stores)
```

## Rust Backend

### Prometheus Client

The Rust backend handles all Prometheus communication:

```rust
// prometheus.rs
pub struct PrometheusClient {
    client: reqwest::Client,
    base_url: String,
}

impl PrometheusClient {
    pub async fn query(&self, query: &str) -> Result<QueryResponse>
    pub async fn query_range(&self, query: &str, start: i64, end: i64, step: &str) -> Result<RangeResponse>
}
```

### Tauri Commands

Frontend-backend communication uses Tauri's IPC system:

```rust
// commands.rs
#[tauri::command]
async fn get_dashboard_metrics(time_range: String, prometheus_url: String) -> Result<DashboardMetrics, String>

#[tauri::command]
async fn test_connection(url: String) -> Result<bool, String>

#[tauri::command]
async fn discover_metrics(prometheus_url: String) -> Result<Vec<String>, String>
```

### Data Models

```rust
// metrics.rs
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
```

## Svelte Frontend

### State Management

Svelte stores manage application state:

```typescript
// stores/metrics.ts
export const metrics = writable<DashboardMetrics | null>(null);
export const isLoading = writable(false);
export const isConnected = writable(false);
export const timeRange = writable<TimeRange>('24h');

// stores/settings.ts
export const settings = writable<Settings>({
    prometheusUrl: 'http://localhost:9090',
    refreshInterval: 30,
});
```

### Component Architecture

```
+page.svelte
├── Sidebar.svelte
├── ViewHeader.svelte
└── [View Components]
    ├── SummaryView.svelte
    ├── TokenMetricsView.svelte
    ├── InsightsView.svelte
    ├── SessionsView.svelte
    ├── LocalStatsCacheView.svelte
    └── SmokeTestView.svelte
```

### Tauri API Usage

```typescript
import { invoke } from '@tauri-apps/api/core';

// Call Rust backend
const metrics = await invoke<DashboardMetrics>('get_dashboard_metrics', {
    timeRange: '24h',
    prometheusUrl: 'http://localhost:9090',
});
```

## System Tray

Configured in `tauri.conf.json`:

```json
{
  "app": {
    "trayIcon": {
      "iconPath": "icons/32x32.png",
      "iconAsTemplate": true
    }
  }
}
```

Features:
- Quick stats display
- Open dashboard
- Settings access
- Quit application

## Auto-Updates

The Tauri updater checks for new versions:

```json
{
  "plugins": {
    "updater": {
      "endpoints": [
        "https://github.com/cragr/ClaudeCodeMonitor/releases/latest/download/latest.json"
      ],
      "pubkey": "RWSCQYY2MrcAzBtxI/LDkcD4FkASa9AJqhswVS4SJbxrBpKGQevtq1oX"
    }
  }
}
```

## Build Outputs

| Platform | Targets |
|----------|---------|
| macOS | `.dmg` (Intel, Apple Silicon) |
| Windows | `.msi`, `.exe` installer |
| Linux | `.deb`, `.rpm`, `.AppImage` |

Configured in `tauri.conf.json`:

```json
{
  "bundle": {
    "targets": ["dmg", "nsis", "deb", "rpm", "appimage"]
  }
}
```

## Prometheus Metrics Reference

### Counter Metrics

| Metric | Description |
|--------|-------------|
| `claude_code_token_usage_tokens_total` | Total tokens consumed |
| `claude_code_cost_usage_USD_total` | Cost in USD |
| `claude_code_active_time_seconds_total` | Active coding time |
| `claude_code_session_count_total` | Number of sessions |
| `claude_code_lines_of_code_count_total` | Lines added/removed |
| `claude_code_commit_count_total` | Git commits |
| `claude_code_pull_request_count_total` | Pull requests |

### Labels

| Label | Description |
|-------|-------------|
| `session_id` | Unique session identifier |
| `model` | Claude model (e.g., `claude-sonnet-4-20250514`) |
| `terminal_type` | Terminal application |
| `app_version` | Claude Code version |
| `type` | For LOC: `added` or `removed` |

### Example PromQL Queries

```promql
# Total tokens in last 24h
increase(claude_code_token_usage_tokens_total[24h])

# Cost by model
sum by (model) (increase(claude_code_cost_usage_USD_total[24h]))

# Tokens over time (rate)
rate(claude_code_token_usage_tokens_total[5m])

# Active sessions
count(count by (session_id) (claude_code_session_count_total))
```
