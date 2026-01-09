# Insights View Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add an Insights view that displays usage analytics from `~/.claude/stats-cache.json` with period comparisons, sparkline charts, and peak activity stats.

**Architecture:** Tab-based navigation switching between Dashboard and Insights views. Rust backend reads local stats cache file and computes period comparisons. Frontend displays comparison cards, sparklines, and detail rows.

**Tech Stack:** Tauri 2, Svelte 5, TypeScript, Chart.js, Rust with serde/chrono

---

## Task 1: Add chrono and dirs Dependencies

**Files:**
- Modify: `tauri-app/src-tauri/Cargo.toml`

**Step 1: Add dependencies**

Add to `[dependencies]` section in `Cargo.toml`:

```toml
chrono = { version = "0.4", features = ["serde"] }
dirs = "5"
```

**Step 2: Verify compilation**

```bash
cd tauri-app/src-tauri && cargo check
```

Expected: Compiles with no errors

**Step 3: Commit**

```bash
git add tauri-app/src-tauri/Cargo.toml
git commit -m "chore: add chrono and dirs dependencies for insights"
```

---

## Task 2: Create Insights Rust Types

**Files:**
- Create: `tauri-app/src-tauri/src/insights.rs`
- Modify: `tauri-app/src-tauri/src/lib.rs`

**Step 1: Create insights.rs with StatsCache types**

```rust
// tauri-app/src-tauri/src/insights.rs

use chrono::{Datelike, NaiveDate, Utc, Weekday};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;

/// Raw stats cache from ~/.claude/stats-cache.json
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct StatsCache {
    pub daily_activity: Vec<DailyActivity>,
    pub daily_model_tokens: Option<Vec<DailyModelTokens>>,
    pub model_usage: HashMap<String, ModelUsage>,
    pub total_sessions: u32,
    pub total_messages: u32,
    pub longest_session: Option<LongestSession>,
    pub first_session_date: Option<String>,
    pub hour_counts: Option<HashMap<String, u32>>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DailyActivity {
    pub date: String,
    pub message_count: u32,
    pub session_count: u32,
    pub tool_call_count: u32,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DailyModelTokens {
    pub date: String,
    pub tokens_by_model: HashMap<String, u64>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ModelUsage {
    pub input_tokens: u64,
    pub output_tokens: u64,
    pub cache_read_input_tokens: u64,
    pub cache_creation_input_tokens: u64,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LongestSession {
    pub duration: u64,
    pub message_count: u32,
}

/// Response types for frontend
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct InsightsData {
    pub period: String,
    pub comparison: PeriodComparison,
    pub daily_activity: Vec<DailyActivityPoint>,
    pub sessions_per_day: Vec<DailyActivityPoint>,
    pub peak_activity: PeakActivity,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PeriodComparison {
    pub messages: MetricComparison,
    pub sessions: MetricComparison,
    pub tokens: MetricComparison,
    pub estimated_cost: MetricComparison,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct MetricComparison {
    pub current: f64,
    pub previous: f64,
    pub percent_change: Option<f64>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DailyActivityPoint {
    pub date: String,
    pub value: f64,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PeakActivity {
    pub most_active_hour: Option<u32>,
    pub longest_session_minutes: Option<u32>,
    pub current_streak: u32,
    pub member_since: Option<String>,
}

impl MetricComparison {
    pub fn new(current: f64, previous: f64) -> Self {
        let percent_change = if previous > 0.0 {
            Some(((current - previous) / previous) * 100.0)
        } else if current > 0.0 {
            Some(100.0)
        } else {
            None
        };
        Self {
            current,
            previous,
            percent_change,
        }
    }
}

pub fn get_stats_cache_path() -> Option<PathBuf> {
    dirs::home_dir().map(|h| h.join(".claude").join("stats-cache.json"))
}

pub fn load_stats_cache() -> Result<StatsCache, String> {
    let path = get_stats_cache_path().ok_or("Could not find home directory")?;
    let contents = fs::read_to_string(&path)
        .map_err(|_| "Stats cache file not found. Use Claude Code to generate usage data.")?;
    serde_json::from_str(&contents).map_err(|e| format!("Failed to parse stats cache: {}", e))
}
```

**Step 2: Add module to lib.rs**

Add at top of `lib.rs` with other mod declarations:
```rust
mod insights;
```

**Step 3: Verify compilation**

```bash
cd tauri-app/src-tauri && cargo check
```

Expected: Compiles with no errors

**Step 4: Commit**

```bash
git add tauri-app/src-tauri/src/insights.rs tauri-app/src-tauri/src/lib.rs
git commit -m "feat(insights): add Rust types for stats cache parsing"
```

---

## Task 3: Implement get_insights_data Command

**Files:**
- Modify: `tauri-app/src-tauri/src/insights.rs`
- Modify: `tauri-app/src-tauri/src/lib.rs`

**Step 1: Add period calculation functions to insights.rs**

Append to `insights.rs`:

```rust
use chrono::{Duration, Local};

fn get_period_dates(period: &str) -> (NaiveDate, NaiveDate, NaiveDate, NaiveDate) {
    let today = Local::now().date_naive();

    match period {
        "this_week" => {
            let week_start = today - Duration::days(today.weekday().num_days_from_monday() as i64);
            let prev_week_start = week_start - Duration::days(7);
            let prev_week_end = week_start - Duration::days(1);
            (week_start, today, prev_week_start, prev_week_end)
        }
        "this_month" => {
            let month_start = NaiveDate::from_ymd_opt(today.year(), today.month(), 1).unwrap();
            let prev_month_end = month_start - Duration::days(1);
            let prev_month_start = NaiveDate::from_ymd_opt(prev_month_end.year(), prev_month_end.month(), 1).unwrap();
            (month_start, today, prev_month_start, prev_month_end)
        }
        _ => {
            // last_7_days
            let start = today - Duration::days(6);
            let prev_end = start - Duration::days(1);
            let prev_start = prev_end - Duration::days(6);
            (start, today, prev_start, prev_end)
        }
    }
}

fn sum_activity_in_range(
    activities: &[DailyActivity],
    start: NaiveDate,
    end: NaiveDate,
) -> (u32, u32) {
    let mut messages = 0u32;
    let mut sessions = 0u32;

    for activity in activities {
        if let Ok(date) = NaiveDate::parse_from_str(&activity.date, "%Y-%m-%d") {
            if date >= start && date <= end {
                messages += activity.message_count;
                sessions += activity.session_count;
            }
        }
    }
    (messages, sessions)
}

fn sum_tokens_in_range(
    daily_tokens: &Option<Vec<DailyModelTokens>>,
    start: NaiveDate,
    end: NaiveDate,
) -> u64 {
    let Some(tokens) = daily_tokens else { return 0 };

    let mut total = 0u64;
    for day in tokens {
        if let Ok(date) = NaiveDate::parse_from_str(&day.date, "%Y-%m-%d") {
            if date >= start && date <= end {
                total += day.tokens_by_model.values().sum::<u64>();
            }
        }
    }
    total
}

fn calculate_cost(tokens: u64, pricing_provider: &str) -> f64 {
    // Simplified cost calculation (using average of input/output rates)
    // Opus 4.5: ~$15/1M tokens average
    let rate_per_million = match pricing_provider {
        "google-vertex" => 16.5, // 10% premium
        _ => 15.0, // anthropic, aws-bedrock
    };
    (tokens as f64 / 1_000_000.0) * rate_per_million
}

fn calculate_streak(activities: &[DailyActivity]) -> u32 {
    let today = Local::now().date_naive();
    let yesterday = today - Duration::days(1);

    let mut dates: Vec<NaiveDate> = activities
        .iter()
        .filter_map(|a| NaiveDate::parse_from_str(&a.date, "%Y-%m-%d").ok())
        .filter(|d| a.message_count > 0)
        .collect();
    dates.sort();
    dates.reverse();

    let mut streak = 0u32;
    let mut expected = yesterday;

    for date in dates {
        if date == expected || date == today {
            streak += 1;
            expected = date - Duration::days(1);
        } else if date < expected {
            break;
        }
    }
    streak
}

fn find_peak_hour(hour_counts: &Option<HashMap<String, u32>>) -> Option<u32> {
    hour_counts.as_ref().and_then(|counts| {
        counts
            .iter()
            .max_by_key(|(_, &v)| v)
            .and_then(|(k, _)| k.parse().ok())
    })
}

fn get_daily_activity_points(
    activities: &[DailyActivity],
    start: NaiveDate,
    end: NaiveDate,
) -> Vec<DailyActivityPoint> {
    activities
        .iter()
        .filter_map(|a| {
            let date = NaiveDate::parse_from_str(&a.date, "%Y-%m-%d").ok()?;
            if date >= start && date <= end {
                Some(DailyActivityPoint {
                    date: a.date.clone(),
                    value: a.message_count as f64,
                })
            } else {
                None
            }
        })
        .collect()
}

fn get_sessions_per_day_points(
    activities: &[DailyActivity],
    start: NaiveDate,
    end: NaiveDate,
) -> Vec<DailyActivityPoint> {
    activities
        .iter()
        .filter_map(|a| {
            let date = NaiveDate::parse_from_str(&a.date, "%Y-%m-%d").ok()?;
            if date >= start && date <= end {
                Some(DailyActivityPoint {
                    date: a.date.clone(),
                    value: a.session_count as f64,
                })
            } else {
                None
            }
        })
        .collect()
}

pub fn compute_insights(period: &str, pricing_provider: &str) -> Result<InsightsData, String> {
    let cache = load_stats_cache()?;
    let (curr_start, curr_end, prev_start, prev_end) = get_period_dates(period);

    // Calculate comparisons
    let (curr_msgs, curr_sess) = sum_activity_in_range(&cache.daily_activity, curr_start, curr_end);
    let (prev_msgs, prev_sess) = sum_activity_in_range(&cache.daily_activity, prev_start, prev_end);

    let curr_tokens = sum_tokens_in_range(&cache.daily_model_tokens, curr_start, curr_end);
    let prev_tokens = sum_tokens_in_range(&cache.daily_model_tokens, prev_start, prev_end);

    let curr_cost = calculate_cost(curr_tokens, pricing_provider);
    let prev_cost = calculate_cost(prev_tokens, pricing_provider);

    let comparison = PeriodComparison {
        messages: MetricComparison::new(curr_msgs as f64, prev_msgs as f64),
        sessions: MetricComparison::new(curr_sess as f64, prev_sess as f64),
        tokens: MetricComparison::new(curr_tokens as f64, prev_tokens as f64),
        estimated_cost: MetricComparison::new(curr_cost, prev_cost),
    };

    // Calculate streak - need to fix the filter
    let dates_with_activity: Vec<NaiveDate> = cache.daily_activity
        .iter()
        .filter(|a| a.message_count > 0)
        .filter_map(|a| NaiveDate::parse_from_str(&a.date, "%Y-%m-%d").ok())
        .collect();

    let today = Local::now().date_naive();
    let yesterday = today - Duration::days(1);
    let mut sorted_dates = dates_with_activity;
    sorted_dates.sort();
    sorted_dates.reverse();

    let mut streak = 0u32;
    let mut expected = yesterday;
    for date in &sorted_dates {
        if *date == expected || *date == today {
            streak += 1;
            expected = *date - Duration::days(1);
        } else if *date < expected {
            break;
        }
    }

    let peak_activity = PeakActivity {
        most_active_hour: find_peak_hour(&cache.hour_counts),
        longest_session_minutes: cache.longest_session.as_ref().map(|s| (s.duration / 60000) as u32),
        current_streak: streak,
        member_since: cache.first_session_date.clone(),
    };

    let daily_activity = get_daily_activity_points(&cache.daily_activity, curr_start, curr_end);
    let sessions_per_day = get_sessions_per_day_points(&cache.daily_activity, curr_start, curr_end);

    Ok(InsightsData {
        period: period.to_string(),
        comparison,
        daily_activity,
        sessions_per_day,
        peak_activity,
    })
}
```

**Step 2: Add Tauri command**

Add at the end of `insights.rs`:

```rust
#[tauri::command]
pub async fn get_insights_data(
    period: String,
    pricing_provider: String,
) -> Result<InsightsData, String> {
    compute_insights(&period, &pricing_provider)
}
```

**Step 3: Register command in lib.rs**

Update the `invoke_handler` in `lib.rs`:

```rust
use crate::insights::get_insights_data;

// In the builder chain:
.invoke_handler(tauri::generate_handler![
    commands::get_dashboard_metrics,
    commands::test_connection,
    get_insights_data,
])
```

**Step 4: Verify compilation**

```bash
cd tauri-app/src-tauri && cargo check
```

Expected: Compiles with no errors (may have warnings)

**Step 5: Commit**

```bash
git add tauri-app/src-tauri/src/insights.rs tauri-app/src-tauri/src/lib.rs
git commit -m "feat(insights): implement get_insights_data Tauri command"
```

---

## Task 4: Add TypeScript Types for Insights

**Files:**
- Modify: `tauri-app/src/lib/types.ts`

**Step 1: Add Insights types**

Append to `types.ts`:

```typescript
// Insights types
export type PeriodType = 'this_week' | 'last_7_days' | 'this_month';

export interface InsightsData {
  period: string;
  comparison: PeriodComparison;
  dailyActivity: DailyActivityPoint[];
  sessionsPerDay: DailyActivityPoint[];
  peakActivity: PeakActivity;
}

export interface PeriodComparison {
  messages: MetricComparison;
  sessions: MetricComparison;
  tokens: MetricComparison;
  estimatedCost: MetricComparison;
}

export interface MetricComparison {
  current: number;
  previous: number;
  percentChange: number | null;
}

export interface DailyActivityPoint {
  date: string;
  value: number;
}

export interface PeakActivity {
  mostActiveHour: number | null;
  longestSessionMinutes: number | null;
  currentStreak: number;
  memberSince: string | null;
}

export const PERIOD_OPTIONS: { value: PeriodType; label: string }[] = [
  { value: 'this_week', label: 'This Week' },
  { value: 'last_7_days', label: 'Last 7 Days' },
  { value: 'this_month', label: 'This Month' },
];
```

**Step 2: Verify types**

```bash
cd tauri-app && pnpm check
```

Expected: 0 errors

**Step 3: Commit**

```bash
git add tauri-app/src/lib/types.ts
git commit -m "feat(insights): add TypeScript types for insights data"
```

---

## Task 5: Create TabNav Component

**Files:**
- Create: `tauri-app/src/lib/components/TabNav.svelte`
- Modify: `tauri-app/src/lib/components/index.ts`

**Step 1: Create TabNav.svelte**

```svelte
<script lang="ts">
  export let activeTab: 'dashboard' | 'insights' | 'sessions';
  export let onTabChange: (tab: 'dashboard' | 'insights' | 'sessions') => void;

  const tabs = [
    { id: 'dashboard' as const, label: 'Dashboard' },
    { id: 'insights' as const, label: 'Insights' },
    { id: 'sessions' as const, label: 'Sessions' },
  ];
</script>

<nav class="flex border-b border-gray-700 mb-6">
  {#each tabs as tab}
    <button
      class="px-4 py-2 text-sm font-medium transition-colors relative {activeTab === tab.id
        ? 'text-white'
        : 'text-gray-400 hover:text-gray-200'}"
      on:click={() => onTabChange(tab.id)}
    >
      {tab.label}
      {#if activeTab === tab.id}
        <div class="absolute bottom-0 left-0 right-0 h-0.5 bg-accent"></div>
      {/if}
    </button>
  {/each}
</nav>
```

**Step 2: Export from index.ts**

Add to `index.ts`:
```typescript
export { default as TabNav } from './TabNav.svelte';
```

**Step 3: Verify**

```bash
cd tauri-app && pnpm check
```

Expected: 0 errors

**Step 4: Commit**

```bash
git add tauri-app/src/lib/components/TabNav.svelte tauri-app/src/lib/components/index.ts
git commit -m "feat(insights): add TabNav component"
```

---

## Task 6: Create PeriodSelector Component

**Files:**
- Create: `tauri-app/src/lib/components/PeriodSelector.svelte`
- Modify: `tauri-app/src/lib/components/index.ts`

**Step 1: Create PeriodSelector.svelte**

```svelte
<script lang="ts">
  import type { PeriodType } from '$lib/types';
  import { PERIOD_OPTIONS } from '$lib/types';

  export let value: PeriodType;
  export let onChange: (value: PeriodType) => void;
</script>

<div class="flex bg-surface-light rounded-lg p-1 gap-1">
  {#each PERIOD_OPTIONS as option}
    <button
      class="px-3 py-1.5 text-sm rounded-md transition-colors {value === option.value
        ? 'bg-accent text-white'
        : 'text-gray-400 hover:text-white hover:bg-surface'}"
      on:click={() => onChange(option.value)}
    >
      {option.label}
    </button>
  {/each}
</div>
```

**Step 2: Export from index.ts**

Add to `index.ts`:
```typescript
export { default as PeriodSelector } from './PeriodSelector.svelte';
```

**Step 3: Verify**

```bash
cd tauri-app && pnpm check
```

Expected: 0 errors

**Step 4: Commit**

```bash
git add tauri-app/src/lib/components/PeriodSelector.svelte tauri-app/src/lib/components/index.ts
git commit -m "feat(insights): add PeriodSelector component"
```

---

## Task 7: Create ComparisonCard Component

**Files:**
- Create: `tauri-app/src/lib/components/ComparisonCard.svelte`
- Modify: `tauri-app/src/lib/components/index.ts`

**Step 1: Create ComparisonCard.svelte**

```svelte
<script lang="ts">
  import type { MetricComparison } from '$lib/types';

  export let label: string;
  export let data: MetricComparison;
  export let format: 'number' | 'compact' | 'currency' = 'number';

  function formatValue(n: number): string {
    if (format === 'currency') {
      return n >= 1 ? `$${n.toFixed(2)}` : `$${n.toFixed(3)}`;
    }
    if (format === 'compact') {
      if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
      if (n >= 1_000) return `${(n / 1_000).toFixed(1)}K`;
    }
    return Math.round(n).toLocaleString();
  }

  $: isPositive = data.percentChange !== null && data.percentChange > 0;
  $: isNegative = data.percentChange !== null && data.percentChange < 0;
</script>

<div class="bg-surface-light rounded-lg p-4 hover:bg-surface-lighter transition-colors">
  <div class="text-gray-400 text-xs uppercase tracking-wide mb-2">{label}</div>
  <div class="text-2xl font-bold text-white mb-2">{formatValue(data.current)}</div>
  <div class="flex items-center gap-1 text-sm">
    {#if data.percentChange !== null}
      <span class={isPositive ? 'text-green-400' : isNegative ? 'text-red-400' : 'text-gray-400'}>
        {isPositive ? '↑' : isNegative ? '↓' : ''}
        {Math.abs(data.percentChange).toFixed(0)}%
      </span>
      <span class="text-gray-500">vs prev</span>
    {:else}
      <span class="text-gray-500">—</span>
    {/if}
  </div>
</div>
```

**Step 2: Export from index.ts**

Add to `index.ts`:
```typescript
export { default as ComparisonCard } from './ComparisonCard.svelte';
```

**Step 3: Verify**

```bash
cd tauri-app && pnpm check
```

Expected: 0 errors

**Step 4: Commit**

```bash
git add tauri-app/src/lib/components/ComparisonCard.svelte tauri-app/src/lib/components/index.ts
git commit -m "feat(insights): add ComparisonCard component"
```

---

## Task 8: Create SparklineChart Component

**Files:**
- Create: `tauri-app/src/lib/components/SparklineChart.svelte`
- Modify: `tauri-app/src/lib/components/index.ts`

**Step 1: Create SparklineChart.svelte**

```svelte
<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { Chart, registerables } from 'chart.js';
  import type { DailyActivityPoint } from '$lib/types';

  export let title: string;
  export let data: DailyActivityPoint[];
  export let color: string = '#6366f1';

  let canvas: HTMLCanvasElement;
  let chart: Chart | null = null;

  Chart.register(...registerables);

  $: average = data.length > 0
    ? (data.reduce((sum, d) => sum + d.value, 0) / data.length).toFixed(1)
    : '0';

  $: if (chart && data) {
    chart.data.labels = data.map((d) => d.date.slice(5)); // MM-DD
    chart.data.datasets[0].data = data.map((d) => d.value);
    chart.update();
  }

  onMount(() => {
    chart = new Chart(canvas, {
      type: 'line',
      data: {
        labels: data.map((d) => d.date.slice(5)),
        datasets: [
          {
            data: data.map((d) => d.value),
            borderColor: color,
            backgroundColor: `${color}20`,
            fill: true,
            tension: 0.4,
            pointRadius: 0,
            borderWidth: 2,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: { enabled: false },
        },
        scales: {
          x: { display: false },
          y: { display: false },
        },
      },
    });
  });

  onDestroy(() => {
    chart?.destroy();
  });
</script>

<div class="bg-surface-light rounded-lg p-4">
  <div class="text-gray-400 text-xs uppercase tracking-wide">{title}</div>
  <div class="text-gray-500 text-xs mb-2">Avg: {average}/day</div>
  <div class="h-16">
    {#if data.length > 0}
      <canvas bind:this={canvas}></canvas>
    {:else}
      <div class="h-full bg-surface rounded flex items-center justify-center text-gray-600 text-xs">
        No data
      </div>
    {/if}
  </div>
</div>
```

**Step 2: Export from index.ts**

Add to `index.ts`:
```typescript
export { default as SparklineChart } from './SparklineChart.svelte';
```

**Step 3: Verify**

```bash
cd tauri-app && pnpm check
```

Expected: 0 errors

**Step 4: Commit**

```bash
git add tauri-app/src/lib/components/SparklineChart.svelte tauri-app/src/lib/components/index.ts
git commit -m "feat(insights): add SparklineChart component"
```

---

## Task 9: Create InsightsView Component

**Files:**
- Create: `tauri-app/src/lib/components/InsightsView.svelte`
- Modify: `tauri-app/src/lib/components/index.ts`

**Step 1: Create InsightsView.svelte**

```svelte
<script lang="ts">
  import { onMount } from 'svelte';
  import { invoke } from '@tauri-apps/api/core';
  import { PeriodSelector, ComparisonCard, SparklineChart } from '$lib/components';
  import { settings } from '$lib/stores/settings';
  import type { InsightsData, PeriodType } from '$lib/types';

  let data: InsightsData | null = null;
  let loading = true;
  let error: string | null = null;
  let period: PeriodType = 'last_7_days';

  async function fetchInsights() {
    loading = true;
    error = null;
    try {
      data = await invoke<InsightsData>('get_insights_data', {
        period,
        pricingProvider: $settings.pricingProvider,
      });
    } catch (e) {
      error = e as string;
    } finally {
      loading = false;
    }
  }

  function handlePeriodChange(newPeriod: PeriodType) {
    period = newPeriod;
    fetchInsights();
  }

  function formatHour(hour: number | null): string {
    if (hour === null) return '—';
    const suffix = hour >= 12 ? 'PM' : 'AM';
    const h = hour % 12 || 12;
    return `${h} ${suffix}`;
  }

  function formatDuration(minutes: number | null): string {
    if (minutes === null) return '—';
    if (minutes >= 60) {
      const h = Math.floor(minutes / 60);
      const m = minutes % 60;
      return m > 0 ? `${h}h ${m}m` : `${h}h`;
    }
    return `${minutes}m`;
  }

  function formatDate(iso: string | null): string {
    if (!iso) return '—';
    const date = new Date(iso);
    return date.toLocaleDateString('en-US', { month: 'short', year: 'numeric' });
  }

  onMount(fetchInsights);
</script>

<div>
  <!-- Period Selector -->
  <div class="flex justify-between items-center mb-6">
    <h2 class="text-lg font-semibold text-white">Usage Insights</h2>
    <PeriodSelector value={period} onChange={handlePeriodChange} />
  </div>

  {#if loading && !data}
    <div class="flex items-center justify-center h-64">
      <div class="text-gray-400">Loading insights...</div>
    </div>
  {:else if error}
    <div class="bg-surface-light rounded-lg p-8 text-center">
      <div class="text-gray-400 mb-2">No usage data yet</div>
      <div class="text-gray-500 text-sm">Use Claude Code to start tracking your activity</div>
    </div>
  {:else if data}
    <!-- Comparison Cards -->
    <div class="grid grid-cols-4 gap-4 mb-6">
      <ComparisonCard label="Messages" data={data.comparison.messages} />
      <ComparisonCard label="Sessions" data={data.comparison.sessions} />
      <ComparisonCard label="Tokens" data={data.comparison.tokens} format="compact" />
      <ComparisonCard label="Est. Cost" data={data.comparison.estimatedCost} format="currency" />
    </div>

    <!-- Sparkline Charts -->
    <div class="grid grid-cols-2 gap-4 mb-6">
      <SparklineChart title="Daily Activity" data={data.dailyActivity} color="#22d3ee" />
      <SparklineChart title="Sessions/Day" data={data.sessionsPerDay} color="#a855f7" />
    </div>

    <!-- Peak Activity -->
    <div class="bg-surface-light rounded-lg p-4">
      <h3 class="text-gray-400 text-xs uppercase tracking-wide mb-4">Peak Activity</h3>
      <div class="grid grid-cols-4 gap-4">
        <div>
          <div class="text-gray-500 text-xs mb-1">Most Active Hour</div>
          <div class="text-white font-medium">{formatHour(data.peakActivity.mostActiveHour)}</div>
        </div>
        <div>
          <div class="text-gray-500 text-xs mb-1">Longest Session</div>
          <div class="text-white font-medium">{formatDuration(data.peakActivity.longestSessionMinutes)}</div>
        </div>
        <div>
          <div class="text-gray-500 text-xs mb-1">Current Streak</div>
          <div class="text-white font-medium">{data.peakActivity.currentStreak} days</div>
        </div>
        <div>
          <div class="text-gray-500 text-xs mb-1">Member Since</div>
          <div class="text-white font-medium">{formatDate(data.peakActivity.memberSince)}</div>
        </div>
      </div>
    </div>
  {/if}
</div>
```

**Step 2: Export from index.ts**

Add to `index.ts`:
```typescript
export { default as InsightsView } from './InsightsView.svelte';
```

**Step 3: Verify**

```bash
cd tauri-app && pnpm check
```

Expected: 0 errors

**Step 4: Commit**

```bash
git add tauri-app/src/lib/components/InsightsView.svelte tauri-app/src/lib/components/index.ts
git commit -m "feat(insights): add InsightsView component"
```

---

## Task 10: Integrate TabNav and InsightsView into Page

**Files:**
- Modify: `tauri-app/src/routes/+page.svelte`

**Step 1: Update +page.svelte imports**

Replace the imports section:
```svelte
<script lang="ts">
  import { onMount } from 'svelte';
  import { invoke } from '@tauri-apps/api/core';
  import {
    MetricCard,
    StatusIndicator,
    TimeRangePicker,
    TokensChart,
    ModelBreakdown,
    SettingsModal,
    TabNav,
    InsightsView,
  } from '$lib/components';
  import { metrics, isLoading, error, timeRange, isConnected } from '$lib/stores';
  import { settings } from '$lib/stores/settings';
  import type { DashboardMetrics, TimeRange } from '$lib/types';

  let showSettings = false;
  let activeTab: 'dashboard' | 'insights' | 'sessions' = 'dashboard';
```

**Step 2: Add tab change handler**

Add after other function definitions:
```typescript
function handleTabChange(tab: 'dashboard' | 'insights' | 'sessions') {
  activeTab = tab;
}
```

**Step 3: Update the template**

Replace the main content (everything inside `<main>`) with:
```svelte
<main class="min-h-screen bg-surface p-6">
  <!-- Header -->
  <div class="flex items-center justify-between mb-4">
    <h1 class="text-xl font-bold text-white">Claude Code Monitor</h1>
    <div class="flex items-center gap-4">
      {#if activeTab === 'dashboard'}
        <TimeRangePicker value={$timeRange} onChange={handleTimeRangeChange} />
      {/if}
      <button
        on:click={() => (showSettings = !showSettings)}
        class="text-gray-400 hover:text-white transition-colors"
        aria-label="Settings"
      >
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"></path>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path>
        </svg>
      </button>
      <StatusIndicator connected={$isConnected} />
    </div>
  </div>

  <!-- Tab Navigation -->
  <TabNav {activeTab} onTabChange={handleTabChange} />

  <!-- Tab Content -->
  {#if activeTab === 'dashboard'}
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
  {:else if activeTab === 'insights'}
    <InsightsView />
  {:else if activeTab === 'sessions'}
    <div class="flex items-center justify-center h-64">
      <div class="text-gray-400">Sessions view coming soon...</div>
    </div>
  {/if}
</main>

<SettingsModal open={showSettings} onClose={() => (showSettings = false)} />
```

**Step 4: Verify**

```bash
cd tauri-app && pnpm check
```

Expected: 0 errors

**Step 5: Commit**

```bash
git add tauri-app/src/routes/+page.svelte
git commit -m "feat(insights): integrate TabNav and InsightsView into main page"
```

---

## Task 11: Test and Fix Issues

**Step 1: Run the app**

```bash
cd tauri-app && pnpm tauri dev
```

**Step 2: Verify functionality**

- [ ] Tab navigation switches between Dashboard/Insights/Sessions
- [ ] Insights view loads data from stats cache
- [ ] Period selector changes the data
- [ ] Comparison cards show values and percentage changes
- [ ] Sparkline charts render
- [ ] Peak activity section shows correct data
- [ ] Error state shows when stats cache missing

**Step 3: Fix any issues found**

Address any compilation errors, runtime errors, or visual bugs.

**Step 4: Commit fixes**

```bash
git add -A
git commit -m "fix(insights): address issues found during testing"
```

---

## Summary

After completing all tasks:

1. Rust backend reads `~/.claude/stats-cache.json` and computes period comparisons
2. Tab navigation (Dashboard | Insights | Sessions)
3. Period selector (This Week, Last 7 Days, This Month)
4. 4 comparison cards with percentage changes
5. 2 sparkline charts for activity trends
6. Peak activity section with streak, peak hour, longest session
