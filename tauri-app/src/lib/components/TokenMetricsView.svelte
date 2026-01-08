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

  {#if loading && !metrics}
    <div class="flex items-center justify-center h-64">
      <div class="text-text-secondary">Loading metrics...</div>
    </div>
  {:else if error}
    <div class="bg-accent-red/10 border border-accent-red/50 rounded-lg p-4 mb-6">
      <p class="text-accent-red">{error}</p>
    </div>
  {:else if metrics}
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
      <MetricCard label="Input" value={formatTokens(Math.floor(metrics.totalTokens * 0.01))} subtitle="0.6%" color="cyan" showBar barPercent={0.6} />
      <MetricCard label="Output" value={formatTokens(Math.floor(metrics.totalTokens * 0.01))} subtitle="0.6%" color="green" showBar barPercent={0.6} />
      <MetricCard label="Cache Read" value={formatTokens(Math.floor(metrics.totalTokens * 0.95))} subtitle="95.0%" color="orange" showBar barPercent={95} />
      <MetricCard label="Cache Create" value={formatTokens(Math.floor(metrics.totalTokens * 0.038))} subtitle="3.8%" color="purple" showBar barPercent={3.8} />
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
