# Sessions View Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a Sessions view that displays individual Claude Code sessions with cost, tokens, and duration from Prometheus, with sortable table and detail modal.

**Architecture:** Sessions tab queries Prometheus for metrics grouped by `session_id`. Rust backend fetches session-level aggregates. Frontend displays sortable table with detail modal for token breakdown.

**Tech Stack:** Tauri 2, Svelte 5, TypeScript, Chart.js, Rust with reqwest

---

## Task 1: Add Session Types to Rust

**Files:**
- Create: `tauri-app/src-tauri/src/sessions.rs`
- Modify: `tauri-app/src-tauri/src/lib.rs`

**Step 1: Create sessions.rs with data types**

```rust
// tauri-app/src-tauri/src/sessions.rs

use crate::prometheus::PrometheusClient;
use serde::Serialize;
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SessionMetrics {
    pub session_id: String,
    pub total_cost_usd: f64,
    pub total_tokens: u64,
    pub input_tokens: u64,
    pub output_tokens: u64,
    pub cache_read_tokens: u64,
    pub cache_creation_tokens: u64,
    pub active_time_seconds: f64,
    pub tokens_by_model: Vec<ModelTokenCount>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ModelTokenCount {
    pub model: String,
    pub tokens: u64,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SessionsData {
    pub sessions: Vec<SessionMetrics>,
    pub total_count: usize,
}
```

**Step 2: Add module to lib.rs**

Add at top of `lib.rs` with other mod declarations:
```rust
mod sessions;
```

**Step 3: Verify compilation**

```bash
cd tauri-app/src-tauri && cargo check
```

Expected: Compiles with no errors (may have unused warnings)

**Step 4: Commit**

```bash
git add tauri-app/src-tauri/src/sessions.rs tauri-app/src-tauri/src/lib.rs
git commit -m "feat(sessions): add Rust types for session metrics"
```

---

## Task 2: Implement get_sessions_data Command

**Files:**
- Modify: `tauri-app/src-tauri/src/sessions.rs`
- Modify: `tauri-app/src-tauri/src/lib.rs`

**Step 1: Add helper functions and command to sessions.rs**

Append to `sessions.rs`:

```rust
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

pub async fn fetch_sessions(
    prometheus_url: &str,
    time_range: &str,
) -> Result<SessionsData, String> {
    let client = PrometheusClient::new(prometheus_url);
    let range = time_range_to_promql(time_range);

    // Query cost by session
    let cost_query = format!(
        "sum by (session_id) (increase(claude_code_cost_usage_USD_total[{}]))",
        range
    );
    let cost_results = client.query(&cost_query).await.map_err(|e| e.to_string())?;

    // Build session map from cost results (cost identifies active sessions)
    let mut sessions_map: HashMap<String, SessionMetrics> = HashMap::new();
    for result in &cost_results {
        if let Some(session_id) = result.metric.get("session_id") {
            if session_id.is_empty() {
                continue;
            }
            let cost = result
                .value
                .as_ref()
                .and_then(|(_, v)| v.parse::<f64>().ok())
                .unwrap_or(0.0);

            if cost > 0.0 {
                sessions_map.insert(
                    session_id.clone(),
                    SessionMetrics {
                        session_id: session_id.clone(),
                        total_cost_usd: cost,
                        total_tokens: 0,
                        input_tokens: 0,
                        output_tokens: 0,
                        cache_read_tokens: 0,
                        cache_creation_tokens: 0,
                        active_time_seconds: 0.0,
                        tokens_by_model: vec![],
                    },
                );
            }
        }
    }

    // Query total tokens by session
    let tokens_query = format!(
        "sum by (session_id) (increase(claude_code_token_usage_tokens_total[{}]))",
        range
    );
    let tokens_results = client.query(&tokens_query).await.map_err(|e| e.to_string())?;
    for result in &tokens_results {
        if let Some(session_id) = result.metric.get("session_id") {
            if let Some(session) = sessions_map.get_mut(session_id) {
                session.total_tokens = result
                    .value
                    .as_ref()
                    .and_then(|(_, v)| v.parse::<f64>().ok())
                    .unwrap_or(0.0) as u64;
            }
        }
    }

    // Query tokens by type
    let type_query = format!(
        "sum by (session_id, type) (increase(claude_code_token_usage_tokens_total[{}]))",
        range
    );
    let type_results = client.query(&type_query).await.map_err(|e| e.to_string())?;
    for result in &type_results {
        if let (Some(session_id), Some(token_type)) =
            (result.metric.get("session_id"), result.metric.get("type"))
        {
            if let Some(session) = sessions_map.get_mut(session_id) {
                let tokens = result
                    .value
                    .as_ref()
                    .and_then(|(_, v)| v.parse::<f64>().ok())
                    .unwrap_or(0.0) as u64;

                match token_type.as_str() {
                    "input" => session.input_tokens = tokens,
                    "output" => session.output_tokens = tokens,
                    "cache_read" => session.cache_read_tokens = tokens,
                    "cache_creation" => session.cache_creation_tokens = tokens,
                    _ => {}
                }
            }
        }
    }

    // Query active time by session
    let time_query = format!(
        "sum by (session_id) (increase(claude_code_active_time_seconds_total[{}]))",
        range
    );
    let time_results = client.query(&time_query).await.map_err(|e| e.to_string())?;
    for result in &time_results {
        if let Some(session_id) = result.metric.get("session_id") {
            if let Some(session) = sessions_map.get_mut(session_id) {
                session.active_time_seconds = result
                    .value
                    .as_ref()
                    .and_then(|(_, v)| v.parse::<f64>().ok())
                    .unwrap_or(0.0);
            }
        }
    }

    // Query tokens by model per session
    let model_query = format!(
        "sum by (session_id, model) (increase(claude_code_token_usage_tokens_total[{}]))",
        range
    );
    let model_results = client.query(&model_query).await.map_err(|e| e.to_string())?;
    for result in &model_results {
        if let (Some(session_id), Some(model)) =
            (result.metric.get("session_id"), result.metric.get("model"))
        {
            if let Some(session) = sessions_map.get_mut(session_id) {
                let tokens = result
                    .value
                    .as_ref()
                    .and_then(|(_, v)| v.parse::<f64>().ok())
                    .unwrap_or(0.0) as u64;

                if tokens > 0 {
                    session.tokens_by_model.push(ModelTokenCount {
                        model: model.clone(),
                        tokens,
                    });
                }
            }
        }
    }

    // Convert map to sorted vec (by cost descending)
    let mut sessions: Vec<SessionMetrics> = sessions_map.into_values().collect();
    sessions.sort_by(|a, b| b.total_cost_usd.partial_cmp(&a.total_cost_usd).unwrap());

    let total_count = sessions.len();

    Ok(SessionsData {
        sessions,
        total_count,
    })
}

#[tauri::command]
pub async fn get_sessions_data(
    time_range: String,
    prometheus_url: String,
) -> Result<SessionsData, String> {
    fetch_sessions(&prometheus_url, &time_range).await
}
```

**Step 2: Register command in lib.rs**

Update the `invoke_handler` in `lib.rs`:

```rust
.invoke_handler(tauri::generate_handler![
    commands::get_dashboard_metrics,
    commands::test_connection,
    insights::get_insights_data,
    sessions::get_sessions_data,
])
```

**Step 3: Verify compilation**

```bash
cd tauri-app/src-tauri && cargo check
```

Expected: Compiles with no errors

**Step 4: Commit**

```bash
git add tauri-app/src-tauri/src/sessions.rs tauri-app/src-tauri/src/lib.rs
git commit -m "feat(sessions): implement get_sessions_data Tauri command"
```

---

## Task 3: Add TypeScript Types for Sessions

**Files:**
- Modify: `tauri-app/src/lib/types.ts`

**Step 1: Add Sessions types**

Append to `types.ts`:

```typescript
// Sessions types
export interface SessionMetrics {
  sessionId: string;
  totalCostUsd: number;
  totalTokens: number;
  inputTokens: number;
  outputTokens: number;
  cacheReadTokens: number;
  cacheCreationTokens: number;
  activeTimeSeconds: number;
  tokensByModel: ModelTokenCount[];
}

export interface ModelTokenCount {
  model: string;
  tokens: number;
}

export interface SessionsData {
  sessions: SessionMetrics[];
  totalCount: number;
}

export type SessionSortField = 'cost' | 'tokens' | 'duration' | 'sessionId';
export type SortDirection = 'asc' | 'desc';
```

**Step 2: Verify types**

```bash
cd tauri-app && pnpm check
```

Expected: 0 errors

**Step 3: Commit**

```bash
git add tauri-app/src/lib/types.ts
git commit -m "feat(sessions): add TypeScript types for sessions data"
```

---

## Task 4: Create SessionsTable Component

**Files:**
- Create: `tauri-app/src/lib/components/SessionsTable.svelte`
- Modify: `tauri-app/src/lib/components/index.ts`

**Step 1: Create SessionsTable.svelte**

```svelte
<script lang="ts">
  import type { SessionMetrics, SessionSortField, SortDirection } from '$lib/types';

  export let sessions: SessionMetrics[];
  export let onSelectSession: (session: SessionMetrics) => void;

  let sortField: SessionSortField = 'cost';
  let sortDirection: SortDirection = 'desc';

  function handleSort(field: SessionSortField) {
    if (sortField === field) {
      sortDirection = sortDirection === 'asc' ? 'desc' : 'asc';
    } else {
      sortField = field;
      sortDirection = 'desc';
    }
  }

  function formatCost(n: number): string {
    if (n >= 1) return `$${n.toFixed(2)}`;
    if (n >= 0.01) return `$${n.toFixed(3)}`;
    return `$${n.toFixed(4)}`;
  }

  function formatTokens(n: number): string {
    if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
    if (n >= 1_000) return `${(n / 1_000).toFixed(1)}K`;
    return n.toString();
  }

  function formatDuration(seconds: number): string {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    if (hours > 0) return `${hours}h ${minutes}m`;
    if (minutes > 0) return `${minutes}m`;
    return `${Math.floor(seconds)}s`;
  }

  function truncateId(id: string): string {
    return id.length > 12 ? `${id.slice(0, 6)}...${id.slice(-4)}` : id;
  }

  $: sortedSessions = [...sessions].sort((a, b) => {
    let comparison = 0;
    switch (sortField) {
      case 'cost':
        comparison = a.totalCostUsd - b.totalCostUsd;
        break;
      case 'tokens':
        comparison = a.totalTokens - b.totalTokens;
        break;
      case 'duration':
        comparison = a.activeTimeSeconds - b.activeTimeSeconds;
        break;
      case 'sessionId':
        comparison = a.sessionId.localeCompare(b.sessionId);
        break;
    }
    return sortDirection === 'asc' ? comparison : -comparison;
  });

  function getSortIcon(field: SessionSortField): string {
    if (sortField !== field) return '↕';
    return sortDirection === 'asc' ? '↑' : '↓';
  }
</script>

<div class="bg-surface-light rounded-lg overflow-hidden">
  <table class="w-full">
    <thead>
      <tr class="border-b border-gray-700">
        <th class="text-left p-3">
          <button
            class="text-xs uppercase tracking-wide text-gray-400 hover:text-white flex items-center gap-1"
            on:click={() => handleSort('sessionId')}
          >
            Session {getSortIcon('sessionId')}
          </button>
        </th>
        <th class="text-right p-3">
          <button
            class="text-xs uppercase tracking-wide text-gray-400 hover:text-white flex items-center gap-1 ml-auto"
            on:click={() => handleSort('cost')}
          >
            Cost {getSortIcon('cost')}
          </button>
        </th>
        <th class="text-right p-3">
          <button
            class="text-xs uppercase tracking-wide text-gray-400 hover:text-white flex items-center gap-1 ml-auto"
            on:click={() => handleSort('tokens')}
          >
            Tokens {getSortIcon('tokens')}
          </button>
        </th>
        <th class="text-right p-3">
          <button
            class="text-xs uppercase tracking-wide text-gray-400 hover:text-white flex items-center gap-1 ml-auto"
            on:click={() => handleSort('duration')}
          >
            Duration {getSortIcon('duration')}
          </button>
        </th>
      </tr>
    </thead>
    <tbody>
      {#each sortedSessions as session}
        <tr
          class="border-b border-gray-700/50 hover:bg-surface cursor-pointer transition-colors"
          on:click={() => onSelectSession(session)}
        >
          <td class="p-3">
            <span class="text-gray-300 font-mono text-sm" title={session.sessionId}>
              {truncateId(session.sessionId)}
            </span>
          </td>
          <td class="p-3 text-right text-white font-medium">
            {formatCost(session.totalCostUsd)}
          </td>
          <td class="p-3 text-right text-gray-300">
            {formatTokens(session.totalTokens)}
          </td>
          <td class="p-3 text-right text-gray-400">
            {formatDuration(session.activeTimeSeconds)}
          </td>
        </tr>
      {/each}
      {#if sortedSessions.length === 0}
        <tr>
          <td colspan="4" class="p-8 text-center text-gray-500">
            No sessions found for this time range
          </td>
        </tr>
      {/if}
    </tbody>
  </table>
</div>
```

**Step 2: Export from index.ts**

Add to `index.ts`:
```typescript
export { default as SessionsTable } from './SessionsTable.svelte';
```

**Step 3: Verify**

```bash
cd tauri-app && pnpm check
```

Expected: 0 errors

**Step 4: Commit**

```bash
git add tauri-app/src/lib/components/SessionsTable.svelte tauri-app/src/lib/components/index.ts
git commit -m "feat(sessions): add SessionsTable component"
```

---

## Task 5: Create SessionDetailModal Component

**Files:**
- Create: `tauri-app/src/lib/components/SessionDetailModal.svelte`
- Modify: `tauri-app/src/lib/components/index.ts`

**Step 1: Create SessionDetailModal.svelte**

```svelte
<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { Chart, registerables } from 'chart.js';
  import type { SessionMetrics } from '$lib/types';

  export let session: SessionMetrics | null;
  export let onClose: () => void;

  let modelChartCanvas: HTMLCanvasElement;
  let typeChartCanvas: HTMLCanvasElement;
  let modelChart: Chart | null = null;
  let typeChart: Chart | null = null;

  Chart.register(...registerables);

  function formatCost(n: number): string {
    if (n >= 1) return `$${n.toFixed(2)}`;
    if (n >= 0.01) return `$${n.toFixed(3)}`;
    return `$${n.toFixed(4)}`;
  }

  function formatTokens(n: number): string {
    if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(2)}M`;
    if (n >= 1_000) return `${(n / 1_000).toFixed(1)}K`;
    return n.toLocaleString();
  }

  function formatDuration(seconds: number): string {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = Math.floor(seconds % 60);
    if (hours > 0) return `${hours}h ${minutes}m`;
    if (minutes > 0) return `${minutes}m ${secs}s`;
    return `${secs}s`;
  }

  const typeColors = {
    input: '#22d3ee',
    output: '#a855f7',
    cache_read: '#22c55e',
    cache_creation: '#f59e0b',
  };

  const modelColors = ['#6366f1', '#ec4899', '#14b8a6', '#f97316', '#8b5cf6'];

  function createCharts() {
    if (!session) return;

    // Type breakdown chart
    if (typeChartCanvas) {
      const typeData = [
        { label: 'Input', value: session.inputTokens, color: typeColors.input },
        { label: 'Output', value: session.outputTokens, color: typeColors.output },
        { label: 'Cache Read', value: session.cacheReadTokens, color: typeColors.cache_read },
        { label: 'Cache Creation', value: session.cacheCreationTokens, color: typeColors.cache_creation },
      ].filter(d => d.value > 0);

      typeChart = new Chart(typeChartCanvas, {
        type: 'doughnut',
        data: {
          labels: typeData.map(d => d.label),
          datasets: [{
            data: typeData.map(d => d.value),
            backgroundColor: typeData.map(d => d.color),
            borderWidth: 0,
          }],
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: {
              position: 'bottom',
              labels: { color: '#9ca3af', font: { size: 11 } },
            },
          },
        },
      });
    }

    // Model breakdown chart
    if (modelChartCanvas && session.tokensByModel.length > 0) {
      modelChart = new Chart(modelChartCanvas, {
        type: 'doughnut',
        data: {
          labels: session.tokensByModel.map(m => m.model),
          datasets: [{
            data: session.tokensByModel.map(m => m.tokens),
            backgroundColor: modelColors.slice(0, session.tokensByModel.length),
            borderWidth: 0,
          }],
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: {
              position: 'bottom',
              labels: { color: '#9ca3af', font: { size: 11 } },
            },
          },
        },
      });
    }
  }

  function destroyCharts() {
    typeChart?.destroy();
    modelChart?.destroy();
    typeChart = null;
    modelChart = null;
  }

  $: if (session) {
    destroyCharts();
    // Use setTimeout to ensure canvas is rendered
    setTimeout(createCharts, 0);
  }

  onDestroy(destroyCharts);

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') onClose();
  }

  function handleBackdropClick(e: MouseEvent) {
    if (e.target === e.currentTarget) onClose();
  }
</script>

<svelte:window on:keydown={handleKeydown} />

{#if session}
  <div
    class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4"
    on:click={handleBackdropClick}
    role="dialog"
    aria-modal="true"
  >
    <div class="bg-surface rounded-lg max-w-2xl w-full max-h-[90vh] overflow-y-auto">
      <!-- Header -->
      <div class="flex items-center justify-between p-4 border-b border-gray-700">
        <div>
          <h2 class="text-lg font-semibold text-white">Session Details</h2>
          <p class="text-sm text-gray-400 font-mono">{session.sessionId}</p>
        </div>
        <button
          on:click={onClose}
          class="text-gray-400 hover:text-white transition-colors"
          aria-label="Close"
        >
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>

      <!-- Summary Stats -->
      <div class="grid grid-cols-3 gap-4 p-4 border-b border-gray-700">
        <div class="text-center">
          <div class="text-2xl font-bold text-white">{formatCost(session.totalCostUsd)}</div>
          <div class="text-xs text-gray-400 uppercase">Total Cost</div>
        </div>
        <div class="text-center">
          <div class="text-2xl font-bold text-white">{formatTokens(session.totalTokens)}</div>
          <div class="text-xs text-gray-400 uppercase">Total Tokens</div>
        </div>
        <div class="text-center">
          <div class="text-2xl font-bold text-white">{formatDuration(session.activeTimeSeconds)}</div>
          <div class="text-xs text-gray-400 uppercase">Duration</div>
        </div>
      </div>

      <!-- Charts -->
      <div class="grid grid-cols-2 gap-4 p-4">
        <div>
          <h3 class="text-sm font-medium text-gray-400 mb-2">Tokens by Type</h3>
          <div class="h-48">
            <canvas bind:this={typeChartCanvas}></canvas>
          </div>
        </div>
        <div>
          <h3 class="text-sm font-medium text-gray-400 mb-2">Tokens by Model</h3>
          <div class="h-48">
            {#if session.tokensByModel.length > 0}
              <canvas bind:this={modelChartCanvas}></canvas>
            {:else}
              <div class="h-full flex items-center justify-center text-gray-500 text-sm">
                No model data
              </div>
            {/if}
          </div>
        </div>
      </div>

      <!-- Token Details -->
      <div class="p-4 border-t border-gray-700">
        <h3 class="text-sm font-medium text-gray-400 mb-3">Token Breakdown</h3>
        <div class="grid grid-cols-2 gap-2 text-sm">
          <div class="flex justify-between">
            <span class="text-gray-400">Input</span>
            <span class="text-white">{formatTokens(session.inputTokens)}</span>
          </div>
          <div class="flex justify-between">
            <span class="text-gray-400">Output</span>
            <span class="text-white">{formatTokens(session.outputTokens)}</span>
          </div>
          <div class="flex justify-between">
            <span class="text-gray-400">Cache Read</span>
            <span class="text-white">{formatTokens(session.cacheReadTokens)}</span>
          </div>
          <div class="flex justify-between">
            <span class="text-gray-400">Cache Creation</span>
            <span class="text-white">{formatTokens(session.cacheCreationTokens)}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
{/if}
```

**Step 2: Export from index.ts**

Add to `index.ts`:
```typescript
export { default as SessionDetailModal } from './SessionDetailModal.svelte';
```

**Step 3: Verify**

```bash
cd tauri-app && pnpm check
```

Expected: 0 errors

**Step 4: Commit**

```bash
git add tauri-app/src/lib/components/SessionDetailModal.svelte tauri-app/src/lib/components/index.ts
git commit -m "feat(sessions): add SessionDetailModal component"
```

---

## Task 6: Create SessionsView Component

**Files:**
- Create: `tauri-app/src/lib/components/SessionsView.svelte`
- Modify: `tauri-app/src/lib/components/index.ts`

**Step 1: Create SessionsView.svelte**

```svelte
<script lang="ts">
  import { onMount } from 'svelte';
  import { invoke } from '@tauri-apps/api/core';
  import { SessionsTable, SessionDetailModal, TimeRangePicker } from '$lib/components';
  import { settings } from '$lib/stores/settings';
  import type { SessionsData, SessionMetrics, TimeRange } from '$lib/types';

  let data: SessionsData | null = null;
  let loading = true;
  let error: string | null = null;
  let timeRange: TimeRange = '24h';
  let selectedSession: SessionMetrics | null = null;

  async function fetchSessions() {
    loading = true;
    error = null;
    try {
      data = await invoke<SessionsData>('get_sessions_data', {
        timeRange,
        prometheusUrl: $settings.prometheusUrl,
      });
    } catch (e) {
      error = e as string;
    } finally {
      loading = false;
    }
  }

  function handleTimeRangeChange(value: TimeRange) {
    timeRange = value;
    fetchSessions();
  }

  function handleSelectSession(session: SessionMetrics) {
    selectedSession = session;
  }

  function handleCloseModal() {
    selectedSession = null;
  }

  onMount(fetchSessions);
</script>

<div>
  <!-- Header -->
  <div class="flex justify-between items-center mb-6">
    <div>
      <h2 class="text-lg font-semibold text-white">Sessions</h2>
      {#if data}
        <p class="text-sm text-gray-400">{data.totalCount} sessions found</p>
      {/if}
    </div>
    <TimeRangePicker value={timeRange} onChange={handleTimeRangeChange} />
  </div>

  {#if loading && !data}
    <div class="flex items-center justify-center h-64">
      <div class="text-gray-400">Loading sessions...</div>
    </div>
  {:else if error}
    <div class="bg-surface-light rounded-lg p-8 text-center">
      <div class="text-gray-400 mb-2">Unable to load sessions</div>
      <div class="text-gray-500 text-sm">{error}</div>
    </div>
  {:else if data}
    <SessionsTable
      sessions={data.sessions}
      onSelectSession={handleSelectSession}
    />
  {/if}
</div>

<SessionDetailModal session={selectedSession} onClose={handleCloseModal} />
```

**Step 2: Export from index.ts**

Add to `index.ts`:
```typescript
export { default as SessionsView } from './SessionsView.svelte';
```

**Step 3: Verify**

```bash
cd tauri-app && pnpm check
```

Expected: 0 errors

**Step 4: Commit**

```bash
git add tauri-app/src/lib/components/SessionsView.svelte tauri-app/src/lib/components/index.ts
git commit -m "feat(sessions): add SessionsView component"
```

---

## Task 7: Integrate SessionsView into Main Page

**Files:**
- Modify: `tauri-app/src/routes/+page.svelte`

**Step 1: Update imports**

Add `SessionsView` to the imports:
```svelte
import {
  MetricCard,
  StatusIndicator,
  TimeRangePicker,
  TokensChart,
  ModelBreakdown,
  SettingsModal,
  TabNav,
  InsightsView,
  SessionsView,
} from '$lib/components';
```

**Step 2: Replace sessions placeholder**

Find and replace the sessions placeholder:
```svelte
{:else if activeTab === 'sessions'}
  <div class="flex items-center justify-center h-64">
    <div class="text-gray-400">Sessions view coming soon...</div>
  </div>
```

With:
```svelte
{:else if activeTab === 'sessions'}
  <SessionsView />
```

**Step 3: Verify**

```bash
cd tauri-app && pnpm check
```

Expected: 0 errors

**Step 4: Commit**

```bash
git add tauri-app/src/routes/+page.svelte
git commit -m "feat(sessions): integrate SessionsView into main page"
```

---

## Task 8: Test and Fix Issues

**Step 1: Run the app**

```bash
cd tauri-app && pnpm tauri dev
```

**Step 2: Verify functionality**

- [ ] Sessions tab displays sessions table
- [ ] Table sorts by clicking column headers
- [ ] Clicking a row opens detail modal
- [ ] Detail modal shows token breakdown charts
- [ ] Time range picker changes displayed sessions
- [ ] Empty state shown when no sessions
- [ ] Error state shown when Prometheus unreachable

**Step 3: Fix any issues found**

Address any compilation errors, runtime errors, or visual bugs.

**Step 4: Commit fixes**

```bash
git add -A
git commit -m "fix(sessions): address issues found during testing"
```

---

## Summary

After completing all tasks:

1. Rust backend queries Prometheus for session-level metrics grouped by `session_id`
2. Sessions table with sortable columns (cost, tokens, duration, session ID)
3. Session detail modal with token breakdown charts (by type and model)
4. Time range picker to filter sessions
5. Full integration with existing tab navigation
