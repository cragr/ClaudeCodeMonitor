<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
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

  onDestroy(() => {
    costChart?.destroy();
    modelChart?.destroy();
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
        <MetricCard label="Active Time" value={formatTime(metrics.activeTimeSeconds)} subtitle="coding with Claude" color="yellow" />
        <MetricCard label="Total Tokens" value={formatTokens(metrics.totalTokens)} subtitle="all models" color="cyan" />
        <MetricCard label="Lines Added" value={`+${metrics.linesAdded.toLocaleString()}`} subtitle="code added" color="orange" />
        <MetricCard label="Lines Removed" value={`-${metrics.linesRemoved.toLocaleString()}`} subtitle="code removed" color="red" />
      </div>
      <div class="grid grid-cols-2 gap-4">
        <MetricCard label="Commits" value={metrics.commitCount.toString()} subtitle="git commits" color="green" />
        <MetricCard label="Pull Requests" value={metrics.pullRequestCount.toString()} subtitle="PRs created" color="purple" />
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
