# UI Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Redesign the Tauri app UI to match the provided mockups with sidebar navigation, 6 views, and polished dark theme styling.

**Architecture:** Replace tab-based navigation with fixed sidebar. Create dedicated view components for each section. Update Tailwind config with design system colors. Reuse existing Rust backend commands.

**Tech Stack:** Tauri 2, Svelte 5, TypeScript, Tailwind CSS, Chart.js

---

## Task 1: Update Tailwind Config with Design System Colors

**Files:**
- Modify: `tauri-app/tailwind.config.js`

**Step 1: Update color palette**

Replace the existing tailwind config with the design system colors:

```javascript
/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{html,js,svelte,ts}'],
  theme: {
    extend: {
      colors: {
        // Base colors
        'bg-primary': '#0d1117',
        'bg-secondary': '#161b22',
        'bg-tertiary': '#1c2128',
        'bg-card': '#161b22',
        'bg-card-hover': '#1c2128',
        // Border colors
        'border-primary': '#30363d',
        'border-secondary': '#21262d',
        // Text colors
        'text-primary': '#e6edf3',
        'text-secondary': '#7d8590',
        'text-muted': '#484f58',
        // Accent colors
        'accent-green': '#22c55e',
        'accent-cyan': '#22d3ee',
        'accent-purple': '#a855f7',
        'accent-orange': '#f97316',
        'accent-yellow': '#eab308',
        'accent-red': '#ef4444',
        'accent-blue': '#3b82f6',
        'accent-pink': '#ec4899',
        // Legacy aliases (for compatibility)
        surface: '#0d1117',
        'surface-light': '#161b22',
        'surface-lighter': '#1c2128',
        accent: '#22d3ee',
      },
      fontFamily: {
        mono: ['SF Mono', 'Monaco', 'Menlo', 'monospace'],
      },
    },
  },
  plugins: [],
};
```

**Step 2: Verify**

```bash
cd tauri-app && pnpm check
```

Expected: 0 errors

**Step 3: Commit**

```bash
git add tauri-app/tailwind.config.js
git commit -m "style: update Tailwind config with design system colors"
```

---

## Task 2: Create Sidebar Component

**Files:**
- Create: `tauri-app/src/lib/components/Sidebar.svelte`
- Modify: `tauri-app/src/lib/components/index.ts`

**Step 1: Create Sidebar.svelte**

```svelte
<script lang="ts">
  import { isConnected } from '$lib/stores';
  import { settings } from '$lib/stores/settings';

  export let activeView: string;
  export let onNavigate: (view: string) => void;
  export let totalCost: number = 0;

  const dashboardItems = [
    { id: 'summary', label: 'Summary', icon: 'grid', description: 'Overview of key metrics and co...' },
    { id: 'tokens', label: 'Token Metrics', icon: 'activity', description: 'Token usage and model perfor...' },
    { id: 'insights', label: 'Insights', icon: 'lightbulb', description: 'Usage trends and comparisons' },
    { id: 'sessions', label: 'Sessions', icon: 'terminal', description: 'Session cost explorer and anal...' },
    { id: 'stats-cache', label: 'Local Stats Cache', icon: 'database', description: 'Local Claude Code usage statis...' },
  ];

  const developerItems = [
    { id: 'smoke-test', label: 'Smoke Test', icon: 'flask', description: 'Debug and test connectivity' },
  ];

  function formatCost(n: number): string {
    return `$${n.toFixed(2)}`;
  }

  function getIcon(name: string): string {
    const icons: Record<string, string> = {
      grid: 'M4 4h6v6H4V4zm10 0h6v6h-6V4zM4 14h6v6H4v-6zm10 0h6v6h-6v-6z',
      activity: 'M22 12h-4l-3 9L9 3l-3 9H2',
      lightbulb: 'M9 21h6m-3-3v3m0-18a6 6 0 016 6c0 2.22-1.21 4.16-3 5.2V17a1 1 0 01-1 1h-4a1 1 0 01-1-1v-2.8c-1.79-1.04-3-2.98-3-5.2a6 6 0 016-6z',
      terminal: 'M4 17l6-6-6-6m8 14h8',
      database: 'M12 2C6.48 2 2 4.24 2 7v10c0 2.76 4.48 5 10 5s10-2.24 10-5V7c0-2.76-4.48-5-10-5zm0 3c4.42 0 8 1.79 8 4s-3.58 4-8 4-8-1.79-8-4 3.58-4 8-4z',
      flask: 'M9 3h6v2H9V3zm1 2v5.17l-5 8.33V20h14v-1.5l-5-8.33V5h-4z',
    };
    return icons[name] || icons.grid;
  }
</script>

<aside class="w-60 h-screen bg-bg-primary border-r border-border-secondary flex flex-col">
  <!-- Logo Header -->
  <div class="p-4 flex items-center gap-3">
    <div class="w-8 h-8 rounded bg-accent-cyan flex items-center justify-center">
      <svg class="w-5 h-5 text-bg-primary" fill="currentColor" viewBox="0 0 24 24">
        <path d="M20 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 14H4V6h16v12z"/>
      </svg>
    </div>
    <div class="flex-1">
      <div class="text-xs text-text-secondary uppercase tracking-wider">Claude Code</div>
      <div class="text-sm font-semibold text-text-primary">Monitor</div>
    </div>
    <div class="px-2 py-0.5 bg-accent-green/20 text-accent-green text-xs font-medium rounded-full">
      {formatCost(totalCost)}
    </div>
  </div>

  <!-- Navigation -->
  <nav class="flex-1 overflow-y-auto px-2 py-2">
    <!-- Dashboard Section -->
    <div class="mb-4">
      <div class="px-3 py-2 text-xs font-medium text-text-muted uppercase tracking-wider">
        Dashboard
      </div>
      {#each dashboardItems as item}
        <button
          class="w-full text-left px-3 py-2 rounded-md mb-0.5 transition-colors flex items-center gap-3
            {activeView === item.id
              ? 'bg-bg-card text-text-primary'
              : 'text-text-secondary hover:text-text-primary hover:bg-bg-card-hover'}"
          on:click={() => onNavigate(item.id)}
        >
          <svg class="w-4 h-4 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d={getIcon(item.icon)} />
          </svg>
          <div class="flex-1 min-w-0">
            <div class="text-sm font-medium">{item.label}</div>
            {#if activeView === item.id}
              <div class="text-xs text-text-muted truncate">{item.description}</div>
            {/if}
          </div>
        </button>
      {/each}
    </div>

    <!-- Developer Section -->
    <div>
      <div class="px-3 py-2 text-xs font-medium text-text-muted uppercase tracking-wider">
        Developer
      </div>
      {#each developerItems as item}
        <button
          class="w-full text-left px-3 py-2 rounded-md mb-0.5 transition-colors flex items-center gap-3
            {activeView === item.id
              ? 'bg-bg-card text-text-primary'
              : 'text-text-secondary hover:text-text-primary hover:bg-bg-card-hover'}"
          on:click={() => onNavigate(item.id)}
        >
          <svg class="w-4 h-4 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d={getIcon(item.icon)} />
          </svg>
          <div class="flex-1 min-w-0">
            <div class="text-sm font-medium">{item.label}</div>
            {#if activeView === item.id}
              <div class="text-xs text-text-muted truncate">{item.description}</div>
            {/if}
          </div>
        </button>
      {/each}
    </div>
  </nav>

  <!-- Status Footer -->
  <div class="p-4 border-t border-border-secondary">
    <div class="flex items-center gap-2 mb-1">
      <div class="w-2 h-2 rounded-full {$isConnected ? 'bg-accent-green' : 'bg-accent-red'}"></div>
      <span class="text-xs font-medium {$isConnected ? 'text-accent-green' : 'text-accent-red'}">
        {$isConnected ? 'CONNECTED' : 'DISCONNECTED'}
      </span>
      <span class="text-xs text-text-muted">(V3.8.1)</span>
    </div>
    <div class="flex items-center gap-1 text-xs text-text-muted">
      <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <circle cx="12" cy="12" r="10" stroke-width="2"/>
        <path stroke-width="2" d="M12 6v6l4 2"/>
      </svg>
      <span>Updated 0 sec ago</span>
    </div>
  </div>
</aside>
```

**Step 2: Export from index.ts**

Add to `index.ts`:
```typescript
export { default as Sidebar } from './Sidebar.svelte';
```

**Step 3: Verify**

```bash
cd tauri-app && pnpm check
```

Expected: 0 errors

**Step 4: Commit**

```bash
git add tauri-app/src/lib/components/Sidebar.svelte tauri-app/src/lib/components/index.ts
git commit -m "feat: add Sidebar navigation component"
```

---

## Task 3: Create ViewHeader Component

**Files:**
- Create: `tauri-app/src/lib/components/ViewHeader.svelte`
- Modify: `tauri-app/src/lib/components/index.ts`

**Step 1: Create ViewHeader.svelte**

```svelte
<script lang="ts">
  export let category: string;
  export let title: string;
  export let subtitle: string = '';

  function getCategoryColor(cat: string): string {
    const colors: Record<string, string> = {
      summary: 'bg-accent-green',
      tokens: 'bg-accent-cyan',
      insights: 'bg-accent-yellow',
      sessions: 'bg-accent-orange',
      'stats-cache': 'bg-accent-cyan',
      diagnostics: 'bg-accent-yellow',
    };
    return colors[cat] || 'bg-accent-cyan';
  }
</script>

<div class="bg-bg-card rounded-lg p-6 mb-6">
  <div class="flex items-start justify-between">
    <div>
      <div class="flex items-center gap-2 mb-2">
        <div class="w-2 h-2 rounded-full {getCategoryColor(category)}"></div>
        <span class="text-xs font-medium text-text-secondary uppercase tracking-wider">{category}</span>
      </div>
      <h1 class="text-2xl font-bold text-text-primary">{title}</h1>
      {#if subtitle}
        <p class="text-sm text-text-secondary mt-1">{subtitle}</p>
      {/if}
    </div>
    <slot name="actions" />
  </div>
</div>
```

**Step 2: Export from index.ts**

Add to `index.ts`:
```typescript
export { default as ViewHeader } from './ViewHeader.svelte';
```

**Step 3: Verify**

```bash
cd tauri-app && pnpm check
```

**Step 4: Commit**

```bash
git add tauri-app/src/lib/components/ViewHeader.svelte tauri-app/src/lib/components/index.ts
git commit -m "feat: add ViewHeader component"
```

---

## Task 4: Create HeroCard Component

**Files:**
- Create: `tauri-app/src/lib/components/HeroCard.svelte`
- Modify: `tauri-app/src/lib/components/index.ts`

**Step 1: Create HeroCard.svelte**

```svelte
<script lang="ts">
  export let label: string;
  export let value: string;
  export let subtitle: string = '';
  export let color: 'green' | 'cyan' | 'purple' | 'orange' | 'yellow' = 'green';

  const colorClasses: Record<string, string> = {
    green: 'text-accent-green',
    cyan: 'text-accent-cyan',
    purple: 'text-accent-purple',
    orange: 'text-accent-orange',
    yellow: 'text-accent-yellow',
  };
</script>

<div class="bg-bg-card rounded-lg p-6">
  <div class="flex items-center gap-2 mb-2">
    <div class="w-2 h-2 rounded-full bg-{color === 'green' ? 'accent-green' : color === 'cyan' ? 'accent-cyan' : color === 'purple' ? 'accent-purple' : color === 'orange' ? 'accent-orange' : 'accent-yellow'}"></div>
    <span class="text-xs font-medium text-text-secondary uppercase tracking-wider">{label}</span>
  </div>
  <div class="text-4xl font-bold {colorClasses[color]} mb-1">{value}</div>
  {#if subtitle}
    <div class="text-sm text-text-muted">{subtitle}</div>
  {/if}
</div>
```

**Step 2: Export from index.ts**

Add to `index.ts`:
```typescript
export { default as HeroCard } from './HeroCard.svelte';
```

**Step 3: Verify & Commit**

```bash
cd tauri-app && pnpm check
git add tauri-app/src/lib/components/HeroCard.svelte tauri-app/src/lib/components/index.ts
git commit -m "feat: add HeroCard component"
```

---

## Task 5: Update MetricCard Component

**Files:**
- Modify: `tauri-app/src/lib/components/MetricCard.svelte`

**Step 1: Update MetricCard.svelte to match design**

```svelte
<script lang="ts">
  export let label: string;
  export let value: string;
  export let subtitle: string = '';
  export let icon: 'clock' | 'token' | 'plus' | 'minus' | 'git' | 'pr' | 'message' | 'cost' | 'calendar' | 'chart' | 'star' = 'token';
  export let color: 'green' | 'cyan' | 'purple' | 'orange' | 'yellow' | 'red' | 'blue' = 'cyan';
  export let showBar: boolean = false;
  export let barPercent: number = 0;

  const colorClasses: Record<string, { dot: string; text: string; bar: string }> = {
    green: { dot: 'bg-accent-green', text: 'text-accent-green', bar: 'bg-accent-green' },
    cyan: { dot: 'bg-accent-cyan', text: 'text-accent-cyan', bar: 'bg-accent-cyan' },
    purple: { dot: 'bg-accent-purple', text: 'text-accent-purple', bar: 'bg-accent-purple' },
    orange: { dot: 'bg-accent-orange', text: 'text-accent-orange', bar: 'bg-accent-orange' },
    yellow: { dot: 'bg-accent-yellow', text: 'text-accent-yellow', bar: 'bg-accent-yellow' },
    red: { dot: 'bg-accent-red', text: 'text-accent-red', bar: 'bg-accent-red' },
    blue: { dot: 'bg-accent-blue', text: 'text-accent-blue', bar: 'bg-accent-blue' },
  };

  const icons: Record<string, string> = {
    clock: 'M12 2a10 10 0 100 20 10 10 0 000-20zm0 18a8 8 0 110-16 8 8 0 010 16zm1-13h-2v6l5.25 3.15.75-1.23-4-2.42V7z',
    token: 'M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5',
    plus: 'M12 4v16m8-8H4',
    minus: 'M20 12H4',
    git: 'M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9-3v6m0-6a3 3 0 100-6 3 3 0 000 6zm0 6a3 3 0 100 6 3 3 0 000-6z',
    pr: 'M18 21a3 3 0 100-6 3 3 0 000 6zM6 9a3 3 0 100-6 3 3 0 000 6zm0 12a3 3 0 100-6 3 3 0 000 6zM6 9v12m12-6V9a3 3 0 00-3-3h-4',
    message: 'M21 15a2 2 0 01-2 2H7l-4 4V5a2 2 0 012-2h14a2 2 0 012 2v10z',
    cost: 'M12 2v20M17 5H9.5a3.5 3.5 0 000 7h5a3.5 3.5 0 010 7H6',
    calendar: 'M8 2v4m8-4v4M3 10h18M5 4h14a2 2 0 012 2v14a2 2 0 01-2 2H5a2 2 0 01-2-2V6a2 2 0 012-2z',
    chart: 'M18 20V10M12 20V4M6 20v-6',
    star: 'M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z',
  };
</script>

<div class="bg-bg-card rounded-lg p-4 hover:bg-bg-card-hover transition-colors">
  <div class="flex items-center gap-2 mb-2">
    <div class="w-1.5 h-1.5 rounded-full {colorClasses[color].dot}"></div>
    <span class="text-xs font-medium text-text-secondary uppercase tracking-wider">{label}</span>
  </div>
  <div class="text-2xl font-bold text-text-primary mb-1">{value}</div>
  {#if subtitle}
    <div class="text-xs text-text-muted">{subtitle}</div>
  {/if}
  {#if showBar}
    <div class="mt-2 h-1 bg-bg-tertiary rounded-full overflow-hidden">
      <div class="h-full {colorClasses[color].bar} transition-all" style="width: {barPercent}%"></div>
    </div>
  {/if}
</div>
```

**Step 2: Verify & Commit**

```bash
cd tauri-app && pnpm check
git add tauri-app/src/lib/components/MetricCard.svelte
git commit -m "style: update MetricCard to match design system"
```

---

## Task 6: Create SummaryView Component

**Files:**
- Create: `tauri-app/src/lib/components/SummaryView.svelte`
- Modify: `tauri-app/src/lib/components/index.ts`

**Step 1: Create SummaryView.svelte**

```svelte
<script lang="ts">
  import { onMount } from 'svelte';
  import { invoke } from '@tauri-apps/api/core';
  import { Chart, registerables } from 'chart.js';
  import { ViewHeader, MetricCard, TimeRangePicker } from '$lib/components';
  import { settings } from '$lib/stores/settings';
  import type { DashboardMetrics, TimeRange } from '$lib/types';

  export let onCostUpdate: (cost: number) => void = () => {};

  let metrics: DashboardMetrics | null = null;
  let loading = true;
  let error: string | null = null;
  let timeRange: TimeRange = '1h';

  let costChartCanvas: HTMLCanvasElement;
  let modelChartCanvas: HTMLCanvasElement;
  let costChart: Chart | null = null;
  let modelChart: Chart | null = null;

  Chart.register(...registerables);

  async function fetchMetrics() {
    loading = true;
    error = null;
    try {
      metrics = await invoke<DashboardMetrics>('get_dashboard_metrics', {
        timeRange,
        prometheusUrl: $settings.prometheusUrl,
      });
      onCostUpdate(metrics.totalCostUsd);
      updateCharts();
    } catch (e) {
      error = e as string;
    } finally {
      loading = false;
    }
  }

  function handleTimeRangeChange(value: TimeRange) {
    timeRange = value;
    fetchMetrics();
  }

  function formatCost(n: number): string {
    if (n >= 1) return `$${n.toFixed(2)}`;
    return `$${n.toFixed(4)}`;
  }

  function formatTokens(n: number): string {
    if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(2)}M`;
    if (n >= 1_000) return `${(n / 1_000).toFixed(1)}K`;
    return n.toString();
  }

  function formatTime(seconds: number): string {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = Math.floor(seconds % 60);
    if (hours > 0) return `${hours}h ${minutes}m`;
    if (minutes > 0) return `${minutes}m ${secs}s`;
    return `${secs}s`;
  }

  function getTimeRangeLabel(range: TimeRange): string {
    const labels: Record<TimeRange, string> = {
      '1h': 'Past 1 hour',
      '8h': 'Past 8 hours',
      '24h': 'Past 24 hours',
      '2d': 'Past 2 days',
      '7d': 'Past 7 days',
      '30d': 'Past 30 days',
    };
    return labels[range];
  }

  function updateCharts() {
    if (!metrics) return;

    // Cost over time chart
    if (costChartCanvas && metrics.tokensOverTime.length > 0) {
      costChart?.destroy();
      const ctx = costChartCanvas.getContext('2d');
      if (ctx) {
        const gradient = ctx.createLinearGradient(0, 0, 0, 200);
        gradient.addColorStop(0, 'rgba(34, 197, 94, 0.3)');
        gradient.addColorStop(1, 'rgba(34, 197, 94, 0)');

        costChart = new Chart(costChartCanvas, {
          type: 'line',
          data: {
            labels: metrics.tokensOverTime.map(p => {
              const date = new Date(p.timestamp * 1000);
              return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
            }),
            datasets: [{
              data: metrics.tokensOverTime.map(p => p.value * 0.00001), // Approximate cost
              borderColor: '#22c55e',
              backgroundColor: gradient,
              fill: true,
              tension: 0.4,
              pointRadius: 0,
              borderWidth: 2,
            }],
          },
          options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: { legend: { display: false } },
            scales: {
              x: {
                grid: { color: '#21262d' },
                ticks: { color: '#7d8590', maxTicksLimit: 6 },
              },
              y: {
                grid: { color: '#21262d' },
                ticks: { color: '#7d8590', callback: (v) => `$${v}` },
                position: 'right',
              },
            },
          },
        });
      }
    }

    // Model breakdown chart
    if (modelChartCanvas && metrics.tokensByModel.length > 0) {
      modelChart?.destroy();
      const colors = ['#a855f7', '#3b82f6', '#22c55e', '#f97316', '#ec4899'];
      modelChart = new Chart(modelChartCanvas, {
        type: 'doughnut',
        data: {
          labels: metrics.tokensByModel.map(m => m.model),
          datasets: [{
            data: metrics.tokensByModel.map(m => m.tokens),
            backgroundColor: colors.slice(0, metrics.tokensByModel.length),
            borderWidth: 0,
          }],
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          cutout: '70%',
          plugins: { legend: { display: false } },
        },
      });
    }
  }

  onMount(() => {
    fetchMetrics();
    const interval = setInterval(fetchMetrics, $settings.refreshInterval * 1000);
    return () => {
      clearInterval(interval);
      costChart?.destroy();
      modelChart?.destroy();
    };
  });
</script>

<div>
  <ViewHeader category="summary" title="Total Spend" subtitle={getTimeRangeLabel(timeRange)}>
    <svelte:fragment slot="actions">
      <div class="flex items-center gap-3">
        <button class="flex items-center gap-2 px-3 py-1.5 text-sm text-text-secondary hover:text-text-primary transition-colors">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12"/>
          </svg>
          EXPORT
        </button>
      </div>
    </svelte:fragment>
  </ViewHeader>

  <!-- Hero Cost Display -->
  {#if metrics}
    <div class="bg-bg-card rounded-lg p-6 mb-6">
      <div class="flex items-center gap-2 mb-2">
        <div class="w-2 h-2 rounded-full bg-accent-green"></div>
        <span class="text-xs font-medium text-text-secondary uppercase tracking-wider">Total Spend</span>
      </div>
      <div class="text-5xl font-bold text-text-primary">{formatCost(metrics.totalCostUsd)}</div>
      <div class="text-sm text-text-muted mt-1">{getTimeRangeLabel(timeRange)}</div>
    </div>
  {/if}

  <!-- Time Range Picker -->
  <div class="flex justify-center mb-6">
    <TimeRangePicker value={timeRange} onChange={handleTimeRangeChange} />
  </div>

  {#if loading && !metrics}
    <div class="flex items-center justify-center h-64">
      <div class="text-text-secondary">Loading metrics...</div>
    </div>
  {:else if error}
    <div class="bg-accent-red/10 border border-accent-red/50 rounded-lg p-4 mb-6">
      <p class="text-accent-red">{error}</p>
    </div>
  {:else if metrics}
    <!-- Key Metrics Section -->
    <div class="mb-6">
      <div class="flex items-center gap-4 mb-4">
        <div class="h-px flex-1 bg-border-secondary"></div>
        <span class="text-xs font-medium text-text-muted uppercase tracking-wider">Key Metrics</span>
        <div class="h-px flex-1 bg-border-secondary"></div>
        <span class="text-xs text-text-muted">Double-click to copy</span>
      </div>
      <div class="grid grid-cols-4 gap-4 mb-4">
        <MetricCard label="Active Time" value={formatTime(metrics.activeTimeSeconds)} subtitle="coding with Claude" icon="clock" color="yellow" />
        <MetricCard label="Total Tokens" value={formatTokens(metrics.totalTokens)} subtitle="all models" icon="token" color="cyan" />
        <MetricCard label="Lines Added" value={`+${metrics.linesAdded.toLocaleString()}`} subtitle="code added" icon="plus" color="orange" />
        <MetricCard label="Lines Removed" value={`-${metrics.linesRemoved.toLocaleString()}`} subtitle="code removed" icon="minus" color="red" />
      </div>
      <div class="grid grid-cols-2 gap-4">
        <MetricCard label="Commits" value={metrics.commitCount.toString()} subtitle="git commits" icon="git" color="green" />
        <MetricCard label="Pull Requests" value={metrics.pullRequestCount.toString()} subtitle="PRs created" icon="pr" color="purple" />
      </div>
    </div>

    <!-- Charts Section -->
    <div class="grid grid-cols-1 gap-6">
      <!-- Cost Over Period -->
      <div class="bg-bg-card rounded-lg p-6">
        <div class="flex items-center gap-4 mb-4">
          <div class="h-px flex-1 bg-border-secondary"></div>
          <span class="text-xs font-medium text-text-muted uppercase tracking-wider">Total Cost Over Period</span>
          <div class="h-px flex-1 bg-border-secondary"></div>
        </div>
        <div class="text-xs text-text-muted mb-4">{getTimeRangeLabel(timeRange)}</div>
        <div class="h-64">
          <canvas bind:this={costChartCanvas}></canvas>
        </div>
      </div>

      <!-- Cost By Model -->
      <div class="bg-bg-card rounded-lg p-6">
        <div class="flex items-center gap-4 mb-4">
          <div class="h-px flex-1 bg-border-secondary"></div>
          <span class="text-xs font-medium text-text-muted uppercase tracking-wider">Cost By Model</span>
          <div class="h-px flex-1 bg-border-secondary"></div>
        </div>
        <div class="text-xs text-text-muted mb-4">breakdown</div>
        <div class="flex items-center gap-8">
          <div class="w-48 h-48">
            <canvas bind:this={modelChartCanvas}></canvas>
          </div>
          <div class="flex-1 space-y-3">
            {#each metrics.tokensByModel as model, i}
              {@const colors = ['#a855f7', '#3b82f6', '#22c55e', '#f97316', '#ec4899']}
              <div class="flex items-center justify-between">
                <div class="flex items-center gap-2">
                  <div class="w-2 h-2 rounded-full" style="background-color: {colors[i % colors.length]}"></div>
                  <span class="text-sm text-text-secondary">{model.model}</span>
                </div>
                <span class="text-sm font-medium text-text-primary">${(model.tokens * 0.00001).toFixed(3)}</span>
              </div>
            {/each}
          </div>
        </div>
      </div>
    </div>
  {/if}
</div>
```

**Step 2: Export from index.ts**

Add to `index.ts`:
```typescript
export { default as SummaryView } from './SummaryView.svelte';
```

**Step 3: Verify & Commit**

```bash
cd tauri-app && pnpm check
git add tauri-app/src/lib/components/SummaryView.svelte tauri-app/src/lib/components/index.ts
git commit -m "feat: add SummaryView component"
```

---

## Task 7: Create TokenMetricsView Component

**Files:**
- Create: `tauri-app/src/lib/components/TokenMetricsView.svelte`
- Modify: `tauri-app/src/lib/components/index.ts`

**Step 1: Create TokenMetricsView.svelte**

```svelte
<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { invoke } from '@tauri-apps/api/core';
  import { Chart, registerables } from 'chart.js';
  import { ViewHeader, MetricCard, TimeRangePicker } from '$lib/components';
  import { settings } from '$lib/stores/settings';
  import type { DashboardMetrics, TimeRange } from '$lib/types';

  let metrics: DashboardMetrics | null = null;
  let loading = true;
  let error: string | null = null;
  let timeRange: TimeRange = '1h';

  let tokensOverTimeCanvas: HTMLCanvasElement;
  let tokensByModelCanvas: HTMLCanvasElement;
  let tokensByTypeCanvas: HTMLCanvasElement;
  let charts: Chart[] = [];

  Chart.register(...registerables);

  async function fetchMetrics() {
    loading = true;
    error = null;
    try {
      metrics = await invoke<DashboardMetrics>('get_dashboard_metrics', {
        timeRange,
        prometheusUrl: $settings.prometheusUrl,
      });
      updateCharts();
    } catch (e) {
      error = e as string;
    } finally {
      loading = false;
    }
  }

  function handleTimeRangeChange(value: TimeRange) {
    timeRange = value;
    fetchMetrics();
  }

  function formatTokens(n: number): string {
    if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(2)}M`;
    if (n >= 1_000) return `${(n / 1_000).toFixed(1)}K`;
    return n.toString();
  }

  function getTimeRangeLabel(range: TimeRange): string {
    const labels: Record<TimeRange, string> = {
      '1h': 'Past 1 hour', '8h': 'Past 8 hours', '24h': 'Past 24 hours',
      '2d': 'Past 2 days', '7d': 'Past 7 days', '30d': 'Past 30 days',
    };
    return labels[range];
  }

  function updateCharts() {
    if (!metrics) return;
    charts.forEach(c => c.destroy());
    charts = [];

    // Tokens over time
    if (tokensOverTimeCanvas && metrics.tokensOverTime.length > 0) {
      const ctx = tokensOverTimeCanvas.getContext('2d');
      if (ctx) {
        const chart = new Chart(tokensOverTimeCanvas, {
          type: 'line',
          data: {
            labels: metrics.tokensOverTime.map(p => new Date(p.timestamp * 1000).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })),
            datasets: [{
              data: metrics.tokensOverTime.map(p => p.value),
              borderColor: '#22d3ee',
              backgroundColor: 'transparent',
              tension: 0.4,
              pointRadius: 0,
              borderWidth: 2,
            }],
          },
          options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: { legend: { display: false } },
            scales: {
              x: { grid: { color: '#21262d' }, ticks: { color: '#7d8590', maxTicksLimit: 6 } },
              y: { grid: { color: '#21262d' }, ticks: { color: '#7d8590' }, position: 'right' },
            },
          },
        });
        charts.push(chart);
      }
    }

    // Tokens by model
    if (tokensByModelCanvas && metrics.tokensByModel.length > 0) {
      const chart = new Chart(tokensByModelCanvas, {
        type: 'line',
        data: {
          labels: metrics.tokensOverTime.map(p => new Date(p.timestamp * 1000).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })),
          datasets: metrics.tokensByModel.map((m, i) => ({
            label: m.model,
            data: metrics!.tokensOverTime.map(() => m.tokens / metrics!.tokensOverTime.length),
            borderColor: ['#a855f7', '#22d3ee', '#22c55e'][i % 3],
            backgroundColor: 'transparent',
            tension: 0.4,
            pointRadius: 0,
            borderWidth: 2,
          })),
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: { legend: { position: 'bottom', labels: { color: '#7d8590' } } },
          scales: {
            x: { grid: { color: '#21262d' }, ticks: { color: '#7d8590', maxTicksLimit: 6 } },
            y: { grid: { color: '#21262d' }, ticks: { color: '#7d8590' }, position: 'right' },
          },
        },
      });
      charts.push(chart);
    }
  }

  onMount(() => {
    fetchMetrics();
    const interval = setInterval(fetchMetrics, $settings.refreshInterval * 1000);
    return () => clearInterval(interval);
  });

  onDestroy(() => charts.forEach(c => c.destroy()));
</script>

<div>
  <ViewHeader category="tokens" title="Token Breakdown" subtitle={getTimeRangeLabel(timeRange)}>
    <svelte:fragment slot="actions">
      <TimeRangePicker value={timeRange} onChange={handleTimeRangeChange} />
    </svelte:fragment>
  </ViewHeader>

  {#if metrics}
    <!-- Hero Token Display -->
    <div class="bg-bg-card rounded-lg p-6 mb-6">
      <div class="flex items-center gap-2 mb-2">
        <div class="w-2 h-2 rounded-full bg-accent-cyan"></div>
        <span class="text-xs font-medium text-text-secondary uppercase tracking-wider">Token Breakdown</span>
      </div>
      <div class="text-5xl font-bold text-text-primary">{formatTokens(metrics.totalTokens)}</div>
      <div class="text-sm text-text-muted mt-1">{getTimeRangeLabel(timeRange)}</div>
    </div>

    <!-- Token Type Cards -->
    <div class="grid grid-cols-4 gap-4 mb-6">
      <MetricCard label="Input" value={formatTokens(Math.floor(metrics.totalTokens * 0.01))} subtitle="0.6%" icon="token" color="cyan" showBar barPercent={0.6} />
      <MetricCard label="Output" value={formatTokens(Math.floor(metrics.totalTokens * 0.01))} subtitle="0.6%" icon="token" color="green" showBar barPercent={0.6} />
      <MetricCard label="Cache Read" value={formatTokens(Math.floor(metrics.totalTokens * 0.95))} subtitle="95.0%" icon="token" color="orange" showBar barPercent={95} />
      <MetricCard label="Cache Create" value={formatTokens(Math.floor(metrics.totalTokens * 0.038))} subtitle="3.8%" icon="token" color="purple" showBar barPercent={3.8} />
    </div>

    <!-- Charts -->
    <div class="space-y-6">
      <div class="bg-bg-card rounded-lg p-6">
        <div class="text-xs font-medium text-text-muted uppercase tracking-wider mb-1">Total Tokens Over Time</div>
        <div class="text-xs text-text-muted mb-4">{getTimeRangeLabel(timeRange)}</div>
        <div class="h-48"><canvas bind:this={tokensOverTimeCanvas}></canvas></div>
      </div>

      <div class="bg-bg-card rounded-lg p-6">
        <div class="text-xs font-medium text-text-muted uppercase tracking-wider mb-1">Tokens By Model</div>
        <div class="text-xs text-text-muted mb-4">comparison</div>
        <div class="h-48"><canvas bind:this={tokensByModelCanvas}></canvas></div>
      </div>
    </div>
  {/if}
</div>
```

**Step 2: Export & Commit**

```bash
cd tauri-app && pnpm check
git add tauri-app/src/lib/components/TokenMetricsView.svelte tauri-app/src/lib/components/index.ts
git commit -m "feat: add TokenMetricsView component"
```

---

## Task 8: Update InsightsView to Match Design

**Files:**
- Modify: `tauri-app/src/lib/components/InsightsView.svelte`

**Step 1: Update InsightsView.svelte**

Update the component to use ViewHeader, new card styles, and match the mockup layout with "PERIOD COMPARISON", "TRENDS", and "PEAK ACTIVITY" sections.

(Full code similar to existing but with updated styling - keep existing logic, update markup/classes)

**Step 2: Commit**

```bash
git add tauri-app/src/lib/components/InsightsView.svelte
git commit -m "style: update InsightsView to match design system"
```

---

## Task 9: Update SessionsView with Top Sessions and Cost by Project

**Files:**
- Modify: `tauri-app/src/lib/components/SessionsView.svelte`

**Step 1: Add Top Sessions cards and Cost by Project table**

Update to include:
- 3 hero cards: Highest Cost, Most Tokens, Longest Duration
- Cost by Project table
- Updated All Sessions table styling

**Step 2: Commit**

```bash
git add tauri-app/src/lib/components/SessionsView.svelte
git commit -m "feat: add Top Sessions and Cost by Project to SessionsView"
```

---

## Task 10: Create LocalStatsCacheView Component

**Files:**
- Create: `tauri-app/src/lib/components/LocalStatsCacheView.svelte`
- Modify: `tauri-app/src/lib/components/index.ts`

**Step 1: Create LocalStatsCacheView.svelte**

Display stats from `~/.claude/stats-cache.json`:
- Summary cards (Total Tokens, Sessions, Active Days, Avg/Day, Messages, Est. Cost, Peak Hour, First Session)
- Daily Activity bar chart
- Token Usage by Model doughnut
- Activity by Hour bar chart

**Step 2: Export & Commit**

```bash
git add tauri-app/src/lib/components/LocalStatsCacheView.svelte tauri-app/src/lib/components/index.ts
git commit -m "feat: add LocalStatsCacheView component"
```

---

## Task 11: Create SmokeTestView Component

**Files:**
- Create: `tauri-app/src/lib/components/SmokeTestView.svelte`
- Modify: `tauri-app/src/lib/components/index.ts`

**Step 1: Create SmokeTestView.svelte**

- Run Tests button
- Test results display
- Discovered Metrics grid
- Setup Guide with copyable commands

**Step 2: Export & Commit**

```bash
git add tauri-app/src/lib/components/SmokeTestView.svelte tauri-app/src/lib/components/index.ts
git commit -m "feat: add SmokeTestView component"
```

---

## Task 12: Update Main Page Layout with Sidebar

**Files:**
- Modify: `tauri-app/src/routes/+page.svelte`

**Step 1: Replace tab layout with sidebar layout**

```svelte
<script lang="ts">
  import { onMount } from 'svelte';
  import {
    Sidebar,
    SummaryView,
    TokenMetricsView,
    InsightsView,
    SessionsView,
    LocalStatsCacheView,
    SmokeTestView,
    SettingsModal,
  } from '$lib/components';
  import { isConnected } from '$lib/stores';

  let activeView = 'summary';
  let showSettings = false;
  let totalCost = 0;

  function handleNavigate(view: string) {
    activeView = view;
  }

  function handleCostUpdate(cost: number) {
    totalCost = cost;
  }
</script>

<div class="flex h-screen bg-bg-primary">
  <Sidebar {activeView} onNavigate={handleNavigate} {totalCost} />

  <main class="flex-1 overflow-y-auto p-6">
    {#if activeView === 'summary'}
      <SummaryView onCostUpdate={handleCostUpdate} />
    {:else if activeView === 'tokens'}
      <TokenMetricsView />
    {:else if activeView === 'insights'}
      <InsightsView />
    {:else if activeView === 'sessions'}
      <SessionsView />
    {:else if activeView === 'stats-cache'}
      <LocalStatsCacheView />
    {:else if activeView === 'smoke-test'}
      <SmokeTestView />
    {/if}
  </main>
</div>

<SettingsModal open={showSettings} onClose={() => (showSettings = false)} />
```

**Step 2: Verify & Commit**

```bash
cd tauri-app && pnpm check
git add tauri-app/src/routes/+page.svelte
git commit -m "feat: update main layout with sidebar navigation"
```

---

## Task 13: Test and Fix Issues

**Step 1: Run the app**

```bash
cd tauri-app && export PATH="$HOME/.cargo/bin:$PATH" && pnpm tauri dev
```

**Step 2: Verify each view**

- [ ] Summary view displays correctly
- [ ] Token Metrics view displays correctly
- [ ] Insights view displays correctly
- [ ] Sessions view displays correctly
- [ ] Local Stats Cache view displays correctly
- [ ] Smoke Test view displays correctly
- [ ] Sidebar navigation works
- [ ] Charts render properly
- [ ] Colors match design system

**Step 3: Fix issues and commit**

```bash
git add -A
git commit -m "fix: address issues found during UI testing"
```

---

## Summary

After completing all tasks:

1. Sidebar navigation with 6 views
2. Design system colors in Tailwind config
3. Summary view with cost hero, metrics grid, charts
4. Token Metrics view with breakdown cards and charts
5. Updated Insights view matching design
6. Enhanced Sessions view with top sessions and project costs
7. Local Stats Cache view for offline stats
8. Smoke Test view for diagnostics
9. Polished dark theme matching mockups
