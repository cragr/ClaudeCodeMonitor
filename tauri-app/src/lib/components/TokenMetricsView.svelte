<script lang="ts">
  import { onMount, onDestroy, tick } from 'svelte';
  import { invoke } from '@tauri-apps/api/core';
  import { Chart, registerables } from 'chart.js';
  import { ViewHeader, MetricCard, TimeRangePicker } from '$lib/components';
  import { settings } from '$lib/stores/settings';
  import { timeRange as timeRangeStore } from '$lib/stores';
  import type { DashboardMetrics, TimeRange } from '$lib/types';

  let metrics: DashboardMetrics | null = null;
  let loading = true;
  let error: string | null = null;

  let tokensOverTimeCanvas: HTMLCanvasElement;
  let tokensByModelCanvas: HTMLCanvasElement;
  let charts: Chart[] = [];

  // macOS dark theme colors (matching Swift version)
  const colors = {
    green: '#00ff88',     // Bright green for positive
    sky: '#00d9ff',       // Cyan (primary accent)
    mauve: '#a855f7',     // Purple
    peach: '#ffb347',     // Orange
    pink: '#ff6b9d',
    yellow: '#ffd93d',
    red: '#ff6b6b',       // Softer red
    blue: '#007aff',      // macOS blue
    teal: '#00d9ff',      // Teal/Cyan
    surface0: '#2c2c2e',  // Card background
    surface1: '#3a3a3c',  // Hover state
    overlay0: '#8e8e93',  // Muted text
    text: '#ffffff',
    subtext1: '#e5e5e7',
  };

  Chart.register(...registerables);

  async function fetchMetrics() {
    loading = true;
    error = null;
    try {
      metrics = await invoke<DashboardMetrics>('get_dashboard_metrics', {
        timeRange: $timeRangeStore,
        prometheusUrl: $settings.prometheusUrl,
      });
      await tick();
      updateCharts();
    } catch (e) {
      error = e as string;
    } finally {
      loading = false;
    }
  }

  function handleTimeRangeChange(value: TimeRange) {
    timeRangeStore.set(value);
    fetchMetrics();
  }

  function formatTokens(n: number): string {
    if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(2)}M`;
    if (n >= 1_000) return `${(n / 1_000).toFixed(1)}K`;
    return n.toString();
  }

  function formatModelName(model: string): string {
    // Extract friendly model name from full identifier
    // e.g., "claude-opus-4-5-20251101" -> "Opus 4.5"
    // e.g., "claude-3-5-haiku-20241022" -> "Haiku 3.5"
    // e.g., "claude-sonnet-4-20250514" -> "Sonnet 4"
    const lower = model.toLowerCase();

    // Check for model family names
    if (lower.includes('opus')) {
      const match = lower.match(/opus[- ]?(\d)[- ]?(\d)?/);
      if (match) {
        return match[2] ? `Opus ${match[1]}.${match[2]}` : `Opus ${match[1]}`;
      }
      return 'Opus';
    }
    if (lower.includes('sonnet')) {
      const match = lower.match(/sonnet[- ]?(\d)[- ]?(\d)?/);
      if (match) {
        return match[2] ? `Sonnet ${match[1]}.${match[2]}` : `Sonnet ${match[1]}`;
      }
      return 'Sonnet';
    }
    if (lower.includes('haiku')) {
      // Handle "claude-3-5-haiku" format
      const match = lower.match(/(\d)[- ](\d)[- ]haiku/) || lower.match(/haiku[- ]?(\d)[- ]?(\d)?/);
      if (match) {
        return match[2] ? `Haiku ${match[1]}.${match[2]}` : `Haiku ${match[1]}`;
      }
      return 'Haiku';
    }

    // Fallback: return original but truncate if too long
    return model.length > 15 ? model.substring(0, 12) + '...' : model;
  }

  function getTimeRangeLabel(range: TimeRange): string {
    const labels: Record<Exclude<TimeRange, 'custom'>, string> = {
      '15m': 'Past 15 minutes',
      '1h': 'Past hour',
      '4h': 'Past 4 hours',
      '1d': 'Past day',
      '7d': 'Past week',
    };
    return labels[range as Exclude<TimeRange, 'custom'>] || 'Custom range';
  }

  function updateCharts() {
    if (!metrics) return;
    charts.forEach(c => c.destroy());
    charts = [];

    // Tokens over time - with gradient fill like SummaryView
    if (tokensOverTimeCanvas && metrics.tokensOverTime.length > 0) {
      const ctx = tokensOverTimeCanvas.getContext('2d');
      if (ctx) {
        const gradient = ctx.createLinearGradient(0, 0, 0, 160);
        gradient.addColorStop(0, 'rgba(0, 217, 255, 0.4)');   // Cyan accent
        gradient.addColorStop(1, 'rgba(0, 217, 255, 0)');

        // Backend returns rate per step via rate()
        // Compute cumulative sum then scale to match total (matching Swift app)
        let cumulative = 0;
        const rawCumulativeData = metrics.tokensOverTime.map(p => {
          cumulative += p.value;
          return cumulative;
        });

        // Scale cumulative values so final value matches totalTokens
        const rawTotal = rawCumulativeData[rawCumulativeData.length - 1] || 0;
        const targetTotal = metrics.totalTokens;
        const scaleFactor = (rawTotal > 0 && targetTotal > 0) ? targetTotal / rawTotal : 1;
        const cumulativeData = rawCumulativeData.map(v => v * scaleFactor);

        const chart = new Chart(tokensOverTimeCanvas, {
          type: 'line',
          data: {
            labels: metrics.tokensOverTime.map(p => new Date(p.timestamp * 1000).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })),
            datasets: [{
              data: cumulativeData,
              borderColor: colors.sky,
              backgroundColor: gradient,
              fill: true,
              tension: 0,
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
                grid: { color: 'rgba(142, 142, 147, 0.2)', drawTicks: true },
                ticks: { color: colors.overlay0, maxTicksLimit: 6, font: { size: 10 } },
              },
              y: {
                grid: { color: 'rgba(142, 142, 147, 0.2)' },
                ticks: {
                  color: colors.overlay0,
                  font: { size: 10 },
                  maxTicksLimit: 5,
                  callback: (v) => formatTokens(Number(v)),
                },
                position: 'right',
                beginAtZero: true,
              },
            },
          },
        });
        charts.push(chart);
      }
    }

    // Tokens by model - horizontal bar chart
    if (tokensByModelCanvas && metrics.tokensByModel.length > 0) {
      const chartColors = [colors.mauve, colors.sky, colors.green, colors.peach, colors.pink];

      const chart = new Chart(tokensByModelCanvas, {
        type: 'bar',
        data: {
          labels: metrics.tokensByModel.map(m => formatModelName(m.model)),
          datasets: [{
            data: metrics.tokensByModel.map(m => m.tokens),
            backgroundColor: metrics.tokensByModel.map((_, i) => chartColors[i % chartColors.length]),
            borderColor: metrics.tokensByModel.map((_, i) => chartColors[i % chartColors.length]),
            borderWidth: 1,
            borderRadius: 4,
          }],
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          indexAxis: 'y',
          plugins: { legend: { display: false } },
          scales: {
            x: {
              grid: { color: 'rgba(142, 142, 147, 0.2)' },
              ticks: {
                color: colors.overlay0,
                font: { size: 10 },
                callback: (v) => formatTokens(Number(v)),
              },
              beginAtZero: true,
            },
            y: {
              grid: { display: false },
              ticks: { color: colors.subtext1, font: { size: 10 } },
            },
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

<div class="flex flex-col h-full">
  <!-- Header Row: Title + Time Range -->
  <div class="flex items-center justify-between mb-4">
    <div>
      <h1 class="text-lg font-semibold text-text-primary">Token Metrics</h1>
      <p class="text-xs text-text-muted">{getTimeRangeLabel($timeRangeStore)}</p>
    </div>
    <TimeRangePicker value={$timeRangeStore} onChange={handleTimeRangeChange} />
  </div>

  {#if loading && !metrics}
    <div class="flex items-center justify-center h-32">
      <div class="text-xs text-text-muted">Loading metrics...</div>
    </div>
  {:else if error}
    <div class="bg-red/10 border border-red/50 rounded-md p-3 mb-4">
      <p class="text-xs text-red">{error}</p>
    </div>
  {:else if metrics}
    <!-- Token Type Cards -->
    {@const inputPercent = metrics.totalTokens > 0 ? (metrics.inputTokens / metrics.totalTokens) * 100 : 0}
    {@const outputPercent = metrics.totalTokens > 0 ? (metrics.outputTokens / metrics.totalTokens) * 100 : 0}
    {@const cacheReadPercent = metrics.totalTokens > 0 ? (metrics.cacheReadTokens / metrics.totalTokens) * 100 : 0}
    {@const cacheCreatePercent = metrics.totalTokens > 0 ? (metrics.cacheCreationTokens / metrics.totalTokens) * 100 : 0}
    <!-- Row 1: Total Tokens, Input, Output -->
    <div class="grid grid-cols-3 gap-2 mb-2">
      <MetricCard label="Total Tokens" value={formatTokens(metrics.totalTokens)} subtitle={getTimeRangeLabel($timeRangeStore)} color="cyan" highlight={true} />
      <MetricCard label="Input" value={formatTokens(metrics.inputTokens)} subtitle="{inputPercent.toFixed(1)}%" color="green" showBar barPercent={inputPercent} />
      <MetricCard label="Output" value={formatTokens(metrics.outputTokens)} subtitle="{outputPercent.toFixed(1)}%" color="purple" showBar barPercent={outputPercent} />
    </div>
    <!-- Row 2: Cache Read, Cache Create -->
    <div class="grid grid-cols-2 gap-2 mb-4">
      <MetricCard label="Cache Read" value={formatTokens(metrics.cacheReadTokens)} subtitle="{cacheReadPercent.toFixed(1)}%" color="orange" showBar barPercent={cacheReadPercent} />
      <MetricCard label="Cache Create" value={formatTokens(metrics.cacheCreationTokens)} subtitle="{cacheCreatePercent.toFixed(1)}%" color="blue" showBar barPercent={cacheCreatePercent} />
    </div>

    <!-- Total Tokens Over Time -->
    <div class="bg-bg-card rounded-md p-4 mb-4">
      <div class="flex items-center justify-between mb-1">
        <span class="text-xs font-medium text-text-muted uppercase tracking-wider">Total Tokens Over Time</span>
        <span class="text-xs text-text-muted">{getTimeRangeLabel($timeRangeStore)}</span>
      </div>
      <div class="h-40"><canvas bind:this={tokensOverTimeCanvas}></canvas></div>
    </div>

    <!-- Tokens By Model -->
    <div class="bg-bg-card rounded-md p-4">
      <div class="flex items-center justify-between mb-1">
        <span class="text-xs font-medium text-text-muted uppercase tracking-wider">Tokens By Model</span>
        <span class="text-xs text-text-muted">comparison</span>
      </div>
      <div class="h-40"><canvas bind:this={tokensByModelCanvas}></canvas></div>
    </div>
  {/if}
</div>
