# Tauri Cross-Platform Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a cross-platform Claude Code Monitor using Tauri + Svelte that runs on macOS and Windows.

**Architecture:** Rust backend handles Prometheus queries and system integration via Tauri commands. Svelte + TypeScript frontend renders the dashboard UI. Tailwind CSS provides styling with a modern dark theme.

**Tech Stack:** Tauri 2.x, Rust, Svelte 5, TypeScript, Tailwind CSS, Chart.js, Vite

---

## Task 1: Initialize Tauri + Svelte Project

**Files:**
- Create: `tauri-app/` directory structure
- Create: `tauri-app/package.json`
- Create: `tauri-app/src-tauri/Cargo.toml`
- Create: `tauri-app/src-tauri/tauri.conf.json`

**Step 1: Create the tauri-app directory**

```bash
cd /Users/crobins1/workspace/git/cragr/ClaudeCodeMonitor/.worktrees/tauri-app
mkdir -p tauri-app
cd tauri-app
```

**Step 2: Initialize Tauri with Svelte template**

```bash
pnpm create tauri-app . --template svelte-ts --manager pnpm
```

When prompted:
- Project name: `claude-code-monitor`
- Identifier: `com.claudecode.monitor`

**Step 3: Verify project structure exists**

```bash
ls -la src-tauri/
ls -la src/
```

Expected: `src-tauri/` with Cargo.toml, `src/` with Svelte files

**Step 4: Install dependencies**

```bash
pnpm install
```

**Step 5: Test dev server starts**

```bash
pnpm tauri dev
```

Expected: Window opens with default Svelte template

**Step 6: Commit**

```bash
git add tauri-app/
git commit -m "feat(tauri): initialize Tauri + Svelte project scaffold"
```

---

## Task 2: Configure Tailwind CSS

**Files:**
- Modify: `tauri-app/package.json`
- Create: `tauri-app/tailwind.config.js`
- Create: `tauri-app/postcss.config.js`
- Modify: `tauri-app/src/app.css`

**Step 1: Install Tailwind dependencies**

```bash
cd tauri-app
pnpm add -D tailwindcss postcss autoprefixer
pnpm tailwindcss init -p
```

**Step 2: Configure tailwind.config.js**

```javascript
/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{html,js,svelte,ts}'],
  theme: {
    extend: {
      colors: {
        surface: {
          DEFAULT: '#1a1a2e',
          light: '#232340',
          lighter: '#2d2d4a',
        },
        accent: {
          DEFAULT: '#6366f1',
          light: '#818cf8',
        },
      },
    },
  },
  plugins: [],
};
```

**Step 3: Update src/app.css with Tailwind directives**

```css
@tailwind base;
@tailwind components;
@tailwind utilities;

:root {
  font-family: Inter, system-ui, Avenir, Helvetica, Arial, sans-serif;
  background-color: #1a1a2e;
  color: #e2e8f0;
}

body {
  margin: 0;
  min-height: 100vh;
}
```

**Step 4: Test Tailwind is working**

Update `src/App.svelte` temporarily:
```svelte
<main class="p-8 bg-surface min-h-screen">
  <h1 class="text-2xl font-bold text-accent">Claude Code Monitor</h1>
  <p class="text-gray-400 mt-2">Tailwind is working!</p>
</main>
```

Run: `pnpm tauri dev`
Expected: Dark background, purple heading

**Step 5: Commit**

```bash
git add -A
git commit -m "feat(tauri): configure Tailwind CSS with dark theme"
```

---

## Task 3: Create TypeScript Types

**Files:**
- Create: `tauri-app/src/lib/types.ts`

**Step 1: Create the types file**

```typescript
// tauri-app/src/lib/types.ts

export interface DashboardMetrics {
  totalTokens: number;
  totalCostUsd: number;
  activeTimeSeconds: number;
  sessionCount: number;
  linesAdded: number;
  linesRemoved: number;
  commitCount: number;
  pullRequestCount: number;
  tokensByModel: ModelTokens[];
  tokensOverTime: TimeSeriesPoint[];
}

export interface ModelTokens {
  model: string;
  tokens: number;
}

export interface TimeSeriesPoint {
  timestamp: number;
  value: number;
}

export interface Settings {
  prometheusUrl: string;
  refreshInterval: number;
  pricingProvider: 'anthropic' | 'aws-bedrock' | 'google-vertex';
}

export type TimeRange = '1h' | '8h' | '24h' | '2d' | '7d' | '30d';

export const TIME_RANGE_OPTIONS: { value: TimeRange; label: string }[] = [
  { value: '1h', label: 'Last Hour' },
  { value: '8h', label: 'Last 8 Hours' },
  { value: '24h', label: 'Last 24 Hours' },
  { value: '2d', label: 'Last 2 Days' },
  { value: '7d', label: 'Last 7 Days' },
  { value: '30d', label: 'Last 30 Days' },
];
```

**Step 2: Verify TypeScript compiles**

```bash
pnpm check
```

Expected: No errors

**Step 3: Commit**

```bash
git add tauri-app/src/lib/types.ts
git commit -m "feat(tauri): add TypeScript types for metrics and settings"
```

---

## Task 4: Create Svelte Stores

**Files:**
- Create: `tauri-app/src/lib/stores/metrics.ts`
- Create: `tauri-app/src/lib/stores/settings.ts`
- Create: `tauri-app/src/lib/stores/index.ts`

**Step 1: Create metrics store**

```typescript
// tauri-app/src/lib/stores/metrics.ts
import { writable } from 'svelte/store';
import type { DashboardMetrics, TimeRange } from '$lib/types';

export const metrics = writable<DashboardMetrics | null>(null);
export const isLoading = writable(false);
export const error = writable<string | null>(null);
export const timeRange = writable<TimeRange>('24h');
export const isConnected = writable(false);
```

**Step 2: Create settings store**

```typescript
// tauri-app/src/lib/stores/settings.ts
import { writable } from 'svelte/store';
import type { Settings } from '$lib/types';

const defaultSettings: Settings = {
  prometheusUrl: 'http://localhost:9090',
  refreshInterval: 30,
  pricingProvider: 'anthropic',
};

export const settings = writable<Settings>(defaultSettings);
```

**Step 3: Create barrel export**

```typescript
// tauri-app/src/lib/stores/index.ts
export * from './metrics';
export * from './settings';
```

**Step 4: Commit**

```bash
git add tauri-app/src/lib/stores/
git commit -m "feat(tauri): add Svelte stores for metrics and settings"
```

---

## Task 5: Rust - Add Dependencies to Cargo.toml

**Files:**
- Modify: `tauri-app/src-tauri/Cargo.toml`

**Step 1: Add required dependencies**

Add to `[dependencies]` section in `src-tauri/Cargo.toml`:

```toml
[dependencies]
tauri = { version = "2", features = ["tray-icon"] }
tauri-plugin-shell = "2"
tauri-plugin-store = "2"
serde = { version = "1", features = ["derive"] }
serde_json = "1"
reqwest = { version = "0.12", features = ["json"] }
tokio = { version = "1", features = ["full"] }
thiserror = "1"
```

**Step 2: Verify it compiles**

```bash
cd tauri-app
pnpm tauri build --debug 2>&1 | head -20
```

Expected: Compilation starts (may take a while first time)

**Step 3: Commit**

```bash
git add tauri-app/src-tauri/Cargo.toml
git commit -m "feat(tauri): add Rust dependencies for HTTP client and storage"
```

---

## Task 6: Rust - Prometheus Client

**Files:**
- Create: `tauri-app/src-tauri/src/prometheus.rs`

**Step 1: Create the Prometheus client module**

```rust
// tauri-app/src-tauri/src/prometheus.rs

use reqwest::Client;
use serde::Deserialize;
use std::collections::HashMap;

#[derive(Debug, thiserror::Error)]
pub enum PrometheusError {
    #[error("HTTP request failed: {0}")]
    Request(#[from] reqwest::Error),
    #[error("Invalid response: {0}")]
    InvalidResponse(String),
}

#[derive(Debug, Deserialize)]
pub struct QueryResponse {
    pub status: String,
    pub data: QueryData,
}

#[derive(Debug, Deserialize)]
pub struct QueryData {
    #[serde(rename = "resultType")]
    pub result_type: String,
    pub result: Vec<QueryResult>,
}

#[derive(Debug, Deserialize)]
pub struct QueryResult {
    pub metric: HashMap<String, String>,
    pub value: Option<(f64, String)>,
    pub values: Option<Vec<(f64, String)>>,
}

pub struct PrometheusClient {
    client: Client,
    base_url: String,
}

impl PrometheusClient {
    pub fn new(base_url: &str) -> Self {
        Self {
            client: Client::new(),
            base_url: base_url.trim_end_matches('/').to_string(),
        }
    }

    pub async fn query(&self, query: &str) -> Result<Vec<QueryResult>, PrometheusError> {
        let url = format!("{}/api/v1/query", self.base_url);
        let response: QueryResponse = self
            .client
            .get(&url)
            .query(&[("query", query)])
            .send()
            .await?
            .json()
            .await?;

        if response.status != "success" {
            return Err(PrometheusError::InvalidResponse(response.status));
        }

        Ok(response.data.result)
    }

    pub async fn query_range(
        &self,
        query: &str,
        start: i64,
        end: i64,
        step: &str,
    ) -> Result<Vec<QueryResult>, PrometheusError> {
        let url = format!("{}/api/v1/query_range", self.base_url);
        let response: QueryResponse = self
            .client
            .get(&url)
            .query(&[
                ("query", query),
                ("start", &start.to_string()),
                ("end", &end.to_string()),
                ("step", step),
            ])
            .send()
            .await?
            .json()
            .await?;

        if response.status != "success" {
            return Err(PrometheusError::InvalidResponse(response.status));
        }

        Ok(response.data.result)
    }

    pub async fn test_connection(&self) -> Result<bool, PrometheusError> {
        let url = format!("{}/-/healthy", self.base_url);
        let response = self.client.get(&url).send().await?;
        Ok(response.status().is_success())
    }
}
```

**Step 2: Add module to main.rs**

Add at the top of `src-tauri/src/main.rs`:
```rust
mod prometheus;
```

**Step 3: Verify compilation**

```bash
cd tauri-app/src-tauri
cargo check
```

Expected: No errors

**Step 4: Commit**

```bash
git add tauri-app/src-tauri/src/prometheus.rs tauri-app/src-tauri/src/main.rs
git commit -m "feat(tauri): add Prometheus HTTP client"
```

---

## Task 7: Rust - Metrics Models

**Files:**
- Create: `tauri-app/src-tauri/src/metrics.rs`

**Step 1: Create metrics models**

```rust
// tauri-app/src-tauri/src/metrics.rs

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
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

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ModelTokens {
    pub model: String,
    pub tokens: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TimeSeriesPoint {
    pub timestamp: i64,
    pub value: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Settings {
    pub prometheus_url: String,
    pub refresh_interval: u32,
    pub pricing_provider: String,
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            prometheus_url: "http://localhost:9090".to_string(),
            refresh_interval: 30,
            pricing_provider: "anthropic".to_string(),
        }
    }
}
```

**Step 2: Add module to main.rs**

```rust
mod metrics;
mod prometheus;
```

**Step 3: Verify compilation**

```bash
cargo check
```

**Step 4: Commit**

```bash
git add tauri-app/src-tauri/src/metrics.rs tauri-app/src-tauri/src/main.rs
git commit -m "feat(tauri): add metrics and settings models"
```

---

## Task 8: Rust - Tauri Commands

**Files:**
- Create: `tauri-app/src-tauri/src/commands.rs`
- Modify: `tauri-app/src-tauri/src/main.rs`

**Step 1: Create commands module**

```rust
// tauri-app/src-tauri/src/commands.rs

use crate::metrics::{DashboardMetrics, ModelTokens, Settings, TimeSeriesPoint};
use crate::prometheus::PrometheusClient;
use std::time::{SystemTime, UNIX_EPOCH};

fn time_range_to_seconds(range: &str) -> i64 {
    match range {
        "1h" => 3600,
        "8h" => 8 * 3600,
        "24h" => 24 * 3600,
        "2d" => 2 * 24 * 3600,
        "7d" => 7 * 24 * 3600,
        "30d" => 30 * 24 * 3600,
        _ => 24 * 3600,
    }
}

fn time_range_to_promql(range: &str) -> &str {
    match range {
        "1h" => "1h",
        "8h" => "8h",
        "24h" => "24h",
        "2d" => "2d",
        "7d" => "7d",
        "30d" => "30d",
        _ => "24h",
    }
}

#[tauri::command]
pub async fn get_dashboard_metrics(
    time_range: String,
    prometheus_url: String,
) -> Result<DashboardMetrics, String> {
    let client = PrometheusClient::new(&prometheus_url);
    let range = time_range_to_promql(&time_range);

    // Query for total tokens
    let tokens_query = format!(
        "sum(increase(claude_code_token_usage_tokens_total[{}]))",
        range
    );
    let total_tokens = client
        .query(&tokens_query)
        .await
        .map_err(|e| e.to_string())?
        .first()
        .and_then(|r| r.value.as_ref())
        .and_then(|(_, v)| v.parse::<f64>().ok())
        .unwrap_or(0.0) as u64;

    // Query for total cost
    let cost_query = format!(
        "sum(increase(claude_code_cost_usage_USD_total[{}]))",
        range
    );
    let total_cost_usd = client
        .query(&cost_query)
        .await
        .map_err(|e| e.to_string())?
        .first()
        .and_then(|r| r.value.as_ref())
        .and_then(|(_, v)| v.parse::<f64>().ok())
        .unwrap_or(0.0);

    // Query for active time
    let time_query = format!(
        "sum(increase(claude_code_active_time_seconds_total[{}]))",
        range
    );
    let active_time_seconds = client
        .query(&time_query)
        .await
        .map_err(|e| e.to_string())?
        .first()
        .and_then(|r| r.value.as_ref())
        .and_then(|(_, v)| v.parse::<f64>().ok())
        .unwrap_or(0.0);

    // Query for session count
    let session_query = format!(
        "sum(increase(claude_code_session_count_total[{}]))",
        range
    );
    let session_count = client
        .query(&session_query)
        .await
        .map_err(|e| e.to_string())?
        .first()
        .and_then(|r| r.value.as_ref())
        .and_then(|(_, v)| v.parse::<f64>().ok())
        .unwrap_or(0.0) as u32;

    // Query for lines added
    let lines_added_query = format!(
        "sum(increase(claude_code_lines_of_code_count_total{{type=\"added\"}}[{}]))",
        range
    );
    let lines_added = client
        .query(&lines_added_query)
        .await
        .map_err(|e| e.to_string())?
        .first()
        .and_then(|r| r.value.as_ref())
        .and_then(|(_, v)| v.parse::<f64>().ok())
        .unwrap_or(0.0) as u64;

    // Query for lines removed
    let lines_removed_query = format!(
        "sum(increase(claude_code_lines_of_code_count_total{{type=\"removed\"}}[{}]))",
        range
    );
    let lines_removed = client
        .query(&lines_removed_query)
        .await
        .map_err(|e| e.to_string())?
        .first()
        .and_then(|r| r.value.as_ref())
        .and_then(|(_, v)| v.parse::<f64>().ok())
        .unwrap_or(0.0) as u64;

    // Query for commit count
    let commit_query = format!(
        "sum(increase(claude_code_commit_count_total[{}]))",
        range
    );
    let commit_count = client
        .query(&commit_query)
        .await
        .map_err(|e| e.to_string())?
        .first()
        .and_then(|r| r.value.as_ref())
        .and_then(|(_, v)| v.parse::<f64>().ok())
        .unwrap_or(0.0) as u32;

    // Query for PR count
    let pr_query = format!(
        "sum(increase(claude_code_pull_request_count_total[{}]))",
        range
    );
    let pull_request_count = client
        .query(&pr_query)
        .await
        .map_err(|e| e.to_string())?
        .first()
        .and_then(|r| r.value.as_ref())
        .and_then(|(_, v)| v.parse::<f64>().ok())
        .unwrap_or(0.0) as u32;

    // Query for tokens by model
    let model_query = format!(
        "sum by (model) (increase(claude_code_token_usage_tokens_total[{}]))",
        range
    );
    let tokens_by_model: Vec<ModelTokens> = client
        .query(&model_query)
        .await
        .map_err(|e| e.to_string())?
        .iter()
        .filter_map(|r| {
            let model = r.metric.get("model")?.clone();
            let tokens = r.value.as_ref()?.1.parse::<f64>().ok()? as u64;
            Some(ModelTokens { model, tokens })
        })
        .collect();

    // Query for tokens over time
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs() as i64;
    let start = now - time_range_to_seconds(&time_range);
    let step = if time_range_to_seconds(&time_range) > 86400 {
        "1h"
    } else {
        "5m"
    };

    let range_query = "sum(rate(claude_code_token_usage_tokens_total[5m])) * 300";
    let tokens_over_time: Vec<TimeSeriesPoint> = client
        .query_range(range_query, start, now, step)
        .await
        .map_err(|e| e.to_string())?
        .first()
        .and_then(|r| r.values.as_ref())
        .map(|values| {
            values
                .iter()
                .map(|(ts, v)| TimeSeriesPoint {
                    timestamp: *ts as i64,
                    value: v.parse::<f64>().unwrap_or(0.0),
                })
                .collect()
        })
        .unwrap_or_default();

    Ok(DashboardMetrics {
        total_tokens,
        total_cost_usd,
        active_time_seconds,
        session_count,
        lines_added,
        lines_removed,
        commit_count,
        pull_request_count,
        tokens_by_model,
        tokens_over_time,
    })
}

#[tauri::command]
pub async fn test_connection(url: String) -> Result<bool, String> {
    let client = PrometheusClient::new(&url);
    client.test_connection().await.map_err(|e| e.to_string())
}
```

**Step 2: Update main.rs to register commands**

```rust
// tauri-app/src-tauri/src/main.rs

mod commands;
mod metrics;
mod prometheus;

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![
            commands::get_dashboard_metrics,
            commands::test_connection,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
```

**Step 3: Verify compilation**

```bash
cargo check
```

**Step 4: Commit**

```bash
git add tauri-app/src-tauri/src/
git commit -m "feat(tauri): add Tauri commands for dashboard metrics"
```

---

## Task 9: Svelte - MetricCard Component

**Files:**
- Create: `tauri-app/src/lib/components/MetricCard.svelte`

**Step 1: Create the MetricCard component**

```svelte
<!-- tauri-app/src/lib/components/MetricCard.svelte -->
<script lang="ts">
  export let label: string;
  export let value: string;
  export let subValue: string = '';
</script>

<div class="bg-surface-light rounded-lg p-4 hover:bg-surface-lighter transition-colors">
  <div class="text-gray-400 text-sm font-medium uppercase tracking-wide">
    {label}
  </div>
  <div class="text-2xl font-bold text-white mt-1">
    {value}
  </div>
  {#if subValue}
    <div class="text-gray-500 text-sm mt-1">
      {subValue}
    </div>
  {/if}
</div>
```

**Step 2: Commit**

```bash
git add tauri-app/src/lib/components/MetricCard.svelte
git commit -m "feat(tauri): add MetricCard component"
```

---

## Task 10: Svelte - StatusIndicator Component

**Files:**
- Create: `tauri-app/src/lib/components/StatusIndicator.svelte`

**Step 1: Create the StatusIndicator component**

```svelte
<!-- tauri-app/src/lib/components/StatusIndicator.svelte -->
<script lang="ts">
  export let connected: boolean;
</script>

<div class="flex items-center gap-2">
  <div
    class="w-2 h-2 rounded-full {connected ? 'bg-green-500' : 'bg-red-500'}"
  ></div>
  <span class="text-sm text-gray-400">
    {connected ? 'Connected' : 'Disconnected'}
  </span>
</div>
```

**Step 2: Commit**

```bash
git add tauri-app/src/lib/components/StatusIndicator.svelte
git commit -m "feat(tauri): add StatusIndicator component"
```

---

## Task 11: Svelte - TimeRangePicker Component

**Files:**
- Create: `tauri-app/src/lib/components/TimeRangePicker.svelte`

**Step 1: Create the TimeRangePicker component**

```svelte
<!-- tauri-app/src/lib/components/TimeRangePicker.svelte -->
<script lang="ts">
  import { TIME_RANGE_OPTIONS, type TimeRange } from '$lib/types';

  export let value: TimeRange;
  export let onChange: (value: TimeRange) => void;
</script>

<select
  bind:value
  on:change={() => onChange(value)}
  class="bg-surface-light text-white border border-gray-600 rounded-md px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-accent"
>
  {#each TIME_RANGE_OPTIONS as option}
    <option value={option.value}>{option.label}</option>
  {/each}
</select>
```

**Step 2: Commit**

```bash
git add tauri-app/src/lib/components/TimeRangePicker.svelte
git commit -m "feat(tauri): add TimeRangePicker component"
```

---

## Task 12: Svelte - TokensChart Component

**Files:**
- Create: `tauri-app/src/lib/components/TokensChart.svelte`
- Modify: `tauri-app/package.json` (add chart.js)

**Step 1: Install Chart.js**

```bash
cd tauri-app
pnpm add chart.js
```

**Step 2: Create the TokensChart component**

```svelte
<!-- tauri-app/src/lib/components/TokensChart.svelte -->
<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { Chart, registerables } from 'chart.js';
  import type { TimeSeriesPoint } from '$lib/types';

  export let data: TimeSeriesPoint[];

  let canvas: HTMLCanvasElement;
  let chart: Chart | null = null;

  Chart.register(...registerables);

  function formatTime(timestamp: number): string {
    return new Date(timestamp * 1000).toLocaleTimeString([], {
      hour: '2-digit',
      minute: '2-digit',
    });
  }

  $: if (chart && data) {
    chart.data.labels = data.map((p) => formatTime(p.timestamp));
    chart.data.datasets[0].data = data.map((p) => p.value);
    chart.update();
  }

  onMount(() => {
    chart = new Chart(canvas, {
      type: 'line',
      data: {
        labels: data.map((p) => formatTime(p.timestamp)),
        datasets: [
          {
            label: 'Tokens',
            data: data.map((p) => p.value),
            borderColor: '#6366f1',
            backgroundColor: 'rgba(99, 102, 241, 0.1)',
            fill: true,
            tension: 0.3,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
        },
        scales: {
          x: {
            grid: { color: 'rgba(255,255,255,0.1)' },
            ticks: { color: '#9ca3af' },
          },
          y: {
            grid: { color: 'rgba(255,255,255,0.1)' },
            ticks: { color: '#9ca3af' },
          },
        },
      },
    });
  });

  onDestroy(() => {
    chart?.destroy();
  });
</script>

<div class="bg-surface-light rounded-lg p-4">
  <h3 class="text-gray-400 text-sm font-medium mb-4">Tokens Over Time</h3>
  <div class="h-48">
    <canvas bind:this={canvas}></canvas>
  </div>
</div>
```

**Step 3: Commit**

```bash
git add tauri-app/src/lib/components/TokensChart.svelte tauri-app/package.json tauri-app/pnpm-lock.yaml
git commit -m "feat(tauri): add TokensChart component with Chart.js"
```

---

## Task 13: Svelte - ModelBreakdown Component

**Files:**
- Create: `tauri-app/src/lib/components/ModelBreakdown.svelte`

**Step 1: Create the ModelBreakdown component**

```svelte
<!-- tauri-app/src/lib/components/ModelBreakdown.svelte -->
<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { Chart, registerables } from 'chart.js';
  import type { ModelTokens } from '$lib/types';

  export let data: ModelTokens[];

  let canvas: HTMLCanvasElement;
  let chart: Chart | null = null;

  Chart.register(...registerables);

  const colors = ['#6366f1', '#8b5cf6', '#a855f7', '#d946ef', '#ec4899'];

  $: if (chart && data) {
    chart.data.labels = data.map((m) => m.model);
    chart.data.datasets[0].data = data.map((m) => m.tokens);
    chart.update();
  }

  onMount(() => {
    chart = new Chart(canvas, {
      type: 'bar',
      data: {
        labels: data.map((m) => m.model),
        datasets: [
          {
            label: 'Tokens',
            data: data.map((m) => m.tokens),
            backgroundColor: colors.slice(0, data.length),
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        indexAxis: 'y',
        plugins: {
          legend: { display: false },
        },
        scales: {
          x: {
            grid: { color: 'rgba(255,255,255,0.1)' },
            ticks: { color: '#9ca3af' },
          },
          y: {
            grid: { display: false },
            ticks: { color: '#9ca3af' },
          },
        },
      },
    });
  });

  onDestroy(() => {
    chart?.destroy();
  });
</script>

<div class="bg-surface-light rounded-lg p-4">
  <h3 class="text-gray-400 text-sm font-medium mb-4">Tokens by Model</h3>
  <div class="h-48">
    <canvas bind:this={canvas}></canvas>
  </div>
</div>
```

**Step 2: Commit**

```bash
git add tauri-app/src/lib/components/ModelBreakdown.svelte
git commit -m "feat(tauri): add ModelBreakdown bar chart component"
```

---

## Task 14: Svelte - Component Barrel Export

**Files:**
- Create: `tauri-app/src/lib/components/index.ts`

**Step 1: Create barrel export**

```typescript
// tauri-app/src/lib/components/index.ts
export { default as MetricCard } from './MetricCard.svelte';
export { default as StatusIndicator } from './StatusIndicator.svelte';
export { default as TimeRangePicker } from './TimeRangePicker.svelte';
export { default as TokensChart } from './TokensChart.svelte';
export { default as ModelBreakdown } from './ModelBreakdown.svelte';
```

**Step 2: Commit**

```bash
git add tauri-app/src/lib/components/index.ts
git commit -m "feat(tauri): add component barrel export"
```

---

## Task 15: Svelte - Dashboard Page

**Files:**
- Modify: `tauri-app/src/App.svelte`

**Step 1: Create the Dashboard UI**

```svelte
<!-- tauri-app/src/App.svelte -->
<script lang="ts">
  import { onMount } from 'svelte';
  import { invoke } from '@tauri-apps/api/core';
  import {
    MetricCard,
    StatusIndicator,
    TimeRangePicker,
    TokensChart,
    ModelBreakdown,
  } from '$lib/components';
  import { metrics, isLoading, error, timeRange, isConnected } from '$lib/stores';
  import { settings } from '$lib/stores/settings';
  import type { DashboardMetrics, TimeRange } from '$lib/types';

  let showSettings = false;

  async function fetchMetrics() {
    $isLoading = true;
    $error = null;

    try {
      const result = await invoke<DashboardMetrics>('get_dashboard_metrics', {
        timeRange: $timeRange,
        prometheusUrl: $settings.prometheusUrl,
      });
      $metrics = result;
      $isConnected = true;
    } catch (e) {
      $error = e as string;
      $isConnected = false;
    } finally {
      $isLoading = false;
    }
  }

  function handleTimeRangeChange(value: TimeRange) {
    $timeRange = value;
    fetchMetrics();
  }

  function formatTokens(n: number): string {
    if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(2)}M`;
    if (n >= 1_000) return `${(n / 1_000).toFixed(1)}K`;
    return n.toString();
  }

  function formatCost(n: number): string {
    if (n >= 1) return `$${n.toFixed(2)}`;
    if (n >= 0.01) return `$${n.toFixed(3)}`;
    return `$${n.toFixed(4)}`;
  }

  function formatTime(seconds: number): string {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    if (hours > 0) return `${hours}h ${minutes}m`;
    return `${minutes}m`;
  }

  onMount(() => {
    fetchMetrics();
    const interval = setInterval(fetchMetrics, $settings.refreshInterval * 1000);
    return () => clearInterval(interval);
  });
</script>

<main class="min-h-screen bg-surface p-6">
  <!-- Header -->
  <div class="flex items-center justify-between mb-6">
    <h1 class="text-xl font-bold text-white">Claude Code Monitor</h1>
    <div class="flex items-center gap-4">
      <TimeRangePicker value={$timeRange} onChange={handleTimeRangeChange} />
      <button
        on:click={() => (showSettings = !showSettings)}
        class="text-gray-400 hover:text-white transition-colors"
      >
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"></path>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path>
        </svg>
      </button>
      <StatusIndicator connected={$isConnected} />
    </div>
  </div>

  <!-- Error Banner -->
  {#if $error}
    <div class="bg-red-900/50 border border-red-500 rounded-lg p-4 mb-6">
      <p class="text-red-200">{$error}</p>
    </div>
  {/if}

  <!-- Loading State -->
  {#if $isLoading && !$metrics}
    <div class="flex items-center justify-center h-64">
      <div class="text-gray-400">Loading metrics...</div>
    </div>
  {:else if $metrics}
    <!-- Metric Cards Grid -->
    <div class="grid grid-cols-4 gap-4 mb-6">
      <MetricCard
        label="Tokens"
        value={formatTokens($metrics.totalTokens)}
      />
      <MetricCard
        label="Cost"
        value={formatCost($metrics.totalCostUsd)}
      />
      <MetricCard
        label="Active Time"
        value={formatTime($metrics.activeTimeSeconds)}
      />
      <MetricCard
        label="Sessions"
        value={$metrics.sessionCount.toString()}
      />
    </div>

    <div class="grid grid-cols-3 gap-4 mb-6">
      <MetricCard
        label="Lines Added"
        value={`+${$metrics.linesAdded.toLocaleString()}`}
      />
      <MetricCard
        label="Lines Removed"
        value={`-${$metrics.linesRemoved.toLocaleString()}`}
      />
      <MetricCard
        label="Commits"
        value={$metrics.commitCount.toString()}
      />
    </div>

    <!-- Charts -->
    <div class="grid grid-cols-1 gap-6">
      <TokensChart data={$metrics.tokensOverTime} />
      <ModelBreakdown data={$metrics.tokensByModel} />
    </div>
  {/if}
</main>
```

**Step 2: Test the dashboard**

```bash
pnpm tauri dev
```

Expected: Dashboard loads, shows loading state, then metrics (or error if Prometheus not running)

**Step 3: Commit**

```bash
git add tauri-app/src/App.svelte
git commit -m "feat(tauri): implement Dashboard page with metrics and charts"
```

---

## Task 16: Svelte - Settings Modal

**Files:**
- Create: `tauri-app/src/lib/components/SettingsModal.svelte`
- Modify: `tauri-app/src/App.svelte`

**Step 1: Create SettingsModal component**

```svelte
<!-- tauri-app/src/lib/components/SettingsModal.svelte -->
<script lang="ts">
  import { invoke } from '@tauri-apps/api/core';
  import { settings } from '$lib/stores/settings';
  import type { Settings } from '$lib/types';

  export let open: boolean;
  export let onClose: () => void;

  let localSettings: Settings = { ...$settings };
  let testStatus: 'idle' | 'testing' | 'success' | 'error' = 'idle';

  async function testConnection() {
    testStatus = 'testing';
    try {
      const result = await invoke<boolean>('test_connection', {
        url: localSettings.prometheusUrl,
      });
      testStatus = result ? 'success' : 'error';
    } catch {
      testStatus = 'error';
    }
  }

  function save() {
    $settings = { ...localSettings };
    onClose();
  }

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') onClose();
  }
</script>

<svelte:window on:keydown={handleKeydown} />

{#if open}
  <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
    <div class="bg-surface-light rounded-lg p-6 w-full max-w-md">
      <h2 class="text-lg font-bold text-white mb-4">Settings</h2>

      <div class="space-y-4">
        <!-- Prometheus URL -->
        <div>
          <label class="block text-sm text-gray-400 mb-1">Prometheus URL</label>
          <div class="flex gap-2">
            <input
              type="text"
              bind:value={localSettings.prometheusUrl}
              class="flex-1 bg-surface border border-gray-600 rounded px-3 py-2 text-white focus:outline-none focus:ring-2 focus:ring-accent"
            />
            <button
              on:click={testConnection}
              class="px-3 py-2 bg-surface border border-gray-600 rounded text-gray-300 hover:bg-surface-lighter"
            >
              {#if testStatus === 'testing'}
                Testing...
              {:else if testStatus === 'success'}
                ✓
              {:else if testStatus === 'error'}
                ✗
              {:else}
                Test
              {/if}
            </button>
          </div>
        </div>

        <!-- Refresh Interval -->
        <div>
          <label class="block text-sm text-gray-400 mb-1">Refresh Interval (seconds)</label>
          <input
            type="number"
            bind:value={localSettings.refreshInterval}
            min="5"
            max="300"
            class="w-full bg-surface border border-gray-600 rounded px-3 py-2 text-white focus:outline-none focus:ring-2 focus:ring-accent"
          />
        </div>

        <!-- Pricing Provider -->
        <div>
          <label class="block text-sm text-gray-400 mb-1">Pricing Provider</label>
          <select
            bind:value={localSettings.pricingProvider}
            class="w-full bg-surface border border-gray-600 rounded px-3 py-2 text-white focus:outline-none focus:ring-2 focus:ring-accent"
          >
            <option value="anthropic">Anthropic (Direct API)</option>
            <option value="aws-bedrock">AWS Bedrock</option>
            <option value="google-vertex">Google Vertex AI</option>
          </select>
        </div>
      </div>

      <!-- Actions -->
      <div class="flex justify-end gap-3 mt-6">
        <button
          on:click={onClose}
          class="px-4 py-2 text-gray-400 hover:text-white"
        >
          Cancel
        </button>
        <button
          on:click={save}
          class="px-4 py-2 bg-accent text-white rounded hover:bg-accent-light"
        >
          Save
        </button>
      </div>
    </div>
  </div>
{/if}
```

**Step 2: Add to component exports**

Add to `tauri-app/src/lib/components/index.ts`:
```typescript
export { default as SettingsModal } from './SettingsModal.svelte';
```

**Step 3: Integrate into App.svelte**

Add import and component to App.svelte:
```svelte
<script>
  // Add to imports
  import { SettingsModal } from '$lib/components';
</script>

<!-- Add before closing </main> -->
<SettingsModal bind:open={showSettings} onClose={() => (showSettings = false)} />
```

**Step 4: Commit**

```bash
git add tauri-app/src/lib/components/
git commit -m "feat(tauri): add Settings modal with connection test"
```

---

## Task 17: Configure System Tray

**Files:**
- Modify: `tauri-app/src-tauri/tauri.conf.json`
- Modify: `tauri-app/src-tauri/src/main.rs`
- Create: `tauri-app/src-tauri/icons/tray-icon.png`

**Step 1: Update tauri.conf.json for tray**

Add to the `"tauri"` section in `tauri.conf.json`:
```json
{
  "trayIcon": {
    "iconPath": "icons/tray-icon.png",
    "iconAsTemplate": true
  }
}
```

**Step 2: Create a simple tray icon**

Copy or create a 22x22 PNG icon at `src-tauri/icons/tray-icon.png`

```bash
# Use existing icon or create placeholder
cp ../macos-app/ClaudeCodeMonitor/Assets.xcassets/AppIcon.appiconset/icon_16x16@2x.png src-tauri/icons/tray-icon.png 2>/dev/null || \
  convert -size 22x22 xc:'#6366f1' src-tauri/icons/tray-icon.png 2>/dev/null || \
  echo "Create tray-icon.png manually (22x22 PNG)"
```

**Step 3: Update main.rs for tray menu**

```rust
// tauri-app/src-tauri/src/main.rs

mod commands;
mod metrics;
mod prometheus;

use tauri::{
    menu::{Menu, MenuItem},
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
    Manager,
};

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .setup(|app| {
            let quit = MenuItem::with_id(app, "quit", "Quit", true, None::<&str>)?;
            let show = MenuItem::with_id(app, "show", "Open Dashboard", true, None::<&str>)?;
            let menu = Menu::with_items(app, &[&show, &quit])?;

            let _tray = TrayIconBuilder::new()
                .icon(app.default_window_icon().unwrap().clone())
                .menu(&menu)
                .menu_on_left_click(false)
                .on_menu_event(|app, event| match event.id.as_ref() {
                    "quit" => {
                        app.exit(0);
                    }
                    "show" => {
                        if let Some(window) = app.get_webview_window("main") {
                            let _ = window.show();
                            let _ = window.set_focus();
                        }
                    }
                    _ => {}
                })
                .on_tray_icon_event(|tray, event| {
                    if let TrayIconEvent::Click {
                        button: MouseButton::Left,
                        button_state: MouseButtonState::Up,
                        ..
                    } = event
                    {
                        let app = tray.app_handle();
                        if let Some(window) = app.get_webview_window("main") {
                            let _ = window.show();
                            let _ = window.set_focus();
                        }
                    }
                })
                .build(app)?;

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            commands::get_dashboard_metrics,
            commands::test_connection,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
```

**Step 4: Test tray icon**

```bash
pnpm tauri dev
```

Expected: Tray icon appears, right-click shows menu, left-click opens window

**Step 5: Commit**

```bash
git add tauri-app/src-tauri/
git commit -m "feat(tauri): add system tray with menu"
```

---

## Task 18: Configure Auto-Updates

**Files:**
- Modify: `tauri-app/src-tauri/tauri.conf.json`
- Modify: `tauri-app/src-tauri/Cargo.toml`

**Step 1: Add updater plugin to Cargo.toml**

Add to dependencies:
```toml
tauri-plugin-updater = "2"
```

**Step 2: Update tauri.conf.json**

Add updater configuration:
```json
{
  "plugins": {
    "updater": {
      "endpoints": [
        "https://github.com/cragr/ClaudeCodeMonitor/releases/latest/download/latest.json"
      ],
      "pubkey": ""
    }
  }
}
```

**Step 3: Add updater plugin to main.rs**

```rust
.plugin(tauri_plugin_updater::Builder::new().build())
```

**Step 4: Generate signing keys**

```bash
pnpm tauri signer generate -w ~/.tauri/claude-code-monitor.key
```

Save the public key and add to tauri.conf.json `pubkey` field.

**Step 5: Commit**

```bash
git add tauri-app/src-tauri/
git commit -m "feat(tauri): configure auto-updater"
```

---

## Task 19: Build and Test Release

**Files:**
- Create: `tauri-app/scripts/build.sh`

**Step 1: Create build script**

```bash
#!/bin/bash
# tauri-app/scripts/build.sh
set -e

cd "$(dirname "$0")/.."

echo "Building Tauri app..."
pnpm tauri build

echo "Build complete!"
ls -la src-tauri/target/release/bundle/
```

**Step 2: Make executable**

```bash
chmod +x tauri-app/scripts/build.sh
```

**Step 3: Run build**

```bash
./tauri-app/scripts/build.sh
```

Expected: DMG (macOS) or MSI (Windows) created in bundle directory

**Step 4: Commit**

```bash
git add tauri-app/scripts/
git commit -m "feat(tauri): add build script"
```

---

## Task 20: Update README

**Files:**
- Modify: `README.md`

**Step 1: Add Tauri app section to README**

Add section for cross-platform app:
```markdown
## Cross-Platform App (Tauri)

The `tauri-app/` directory contains the cross-platform version that runs on macOS and Windows.

### Development

```bash
cd tauri-app
pnpm install
pnpm tauri dev
```

### Building

```bash
cd tauri-app
pnpm tauri build
```

Outputs:
- macOS: `src-tauri/target/release/bundle/dmg/`
- Windows: `src-tauri/target/release/bundle/msi/`
```

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add Tauri app instructions to README"
```

---

## Summary

After completing all tasks, you will have:

1. **Tauri + Svelte project** scaffolded with TypeScript and Tailwind
2. **Rust backend** with Prometheus HTTP client and Tauri commands
3. **Svelte frontend** with Dashboard, metrics cards, and charts
4. **Settings modal** with connection testing
5. **System tray** with menu and click-to-open
6. **Auto-updater** configured (keys need to be generated)
7. **Build pipeline** for creating distributable packages

**Next steps after MVP:**
- Add Insights view
- Add Sessions view
- Set up GitHub Actions for CI/CD
- Add Windows code signing
