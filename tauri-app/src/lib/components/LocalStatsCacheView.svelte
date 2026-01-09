<script lang="ts">
  import { onMount, onDestroy, tick } from 'svelte';
  import { invoke } from '@tauri-apps/api/core';
  import { Chart, registerables } from 'chart.js';
  import { ViewHeader, MetricCard } from '$lib/components';
  import { settings } from '$lib/stores/settings';
  import type { LocalStatsCacheData } from '$lib/types';

  let data: LocalStatsCacheData | null = null;
  let loading = true;
  let error: string | null = null;

  let dailyChartCanvas: HTMLCanvasElement;
  let modelChartCanvas: HTMLCanvasElement;
  let hourlyChartCanvas: HTMLCanvasElement;
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
  };

  Chart.register(...registerables);

  async function fetchData() {
    loading = true;
    error = null;
    try {
      data = await invoke<LocalStatsCacheData>('get_local_stats_cache', {
        pricingProvider: $settings.pricingProvider,
      });
      await tick();
      updateCharts();
    } catch (e) {
      error = e as string;
    } finally {
      loading = false;
    }
  }

  function formatTokens(n: number): string {
    if (n >= 1_000_000_000) return `${(n / 1_000_000_000).toFixed(2)}B`;
    if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(2)}M`;
    if (n >= 1_000) return `${(n / 1_000).toFixed(1)}K`;
    return n.toString();
  }

  function formatCost(n: number): string {
    if (n >= 1) return `$${n.toFixed(2)}`;
    return `$${n.toFixed(4)}`;
  }

  function formatHour(hour: number | null): string {
    if (hour === null) return '—';
    const suffix = hour >= 12 ? 'PM' : 'AM';
    const h = hour % 12 || 12;
    return `${h} ${suffix}`;
  }

  function formatDate(iso: string | null): string {
    if (!iso) return '—';
    const date = new Date(iso);
    return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
  }

  function formatModelName(model: string): string {
    // Extract friendly model name from full identifier
    // e.g., "claude-opus-4-5-20251101" -> "Opus 4.5"
    // e.g., "claude-3-5-haiku-20241022" -> "Haiku 3.5"
    // e.g., "claude-sonnet-4-5-20250929" -> "Sonnet 4.5"
    const lower = model.toLowerCase();

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
      const match = lower.match(/(\d)[- ](\d)[- ]haiku/) || lower.match(/haiku[- ]?(\d)[- ]?(\d)?/);
      if (match) {
        return match[2] ? `Haiku ${match[1]}.${match[2]}` : `Haiku ${match[1]}`;
      }
      return 'Haiku';
    }
    // Fallback: return the original model name
    return model;
  }

  function updateCharts() {
    if (!data) return;
    charts.forEach(c => c.destroy());
    charts = [];

    // Daily activity bar chart
    if (dailyChartCanvas && data.dailyActivity.length > 0) {
      const ctx = dailyChartCanvas.getContext('2d');
      if (ctx) {
        const chart = new Chart(dailyChartCanvas, {
          type: 'bar',
          data: {
            labels: data.dailyActivity.slice(-30).map(d => d.date.slice(5)),
            datasets: [{
              data: data.dailyActivity.slice(-30).map(d => d.value),
              backgroundColor: colors.sky,
              borderRadius: 2,
            }],
          },
          options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: { legend: { display: false } },
            scales: {
              x: { grid: { display: false }, ticks: { color: colors.overlay0, maxTicksLimit: 10 } },
              y: {
                grid: {
                  color: 'rgba(142, 142, 147, 0.3)',
                  drawTicks: true,
                },
                ticks: { color: colors.overlay0 },
              },
            },
          },
        });
        charts.push(chart);
      }
    }

    // Model breakdown doughnut
    if (modelChartCanvas && data.tokensByModel.length > 0) {
      const chartColors = [colors.mauve, colors.sky, colors.green, colors.peach, colors.pink, colors.blue];
      const chart = new Chart(modelChartCanvas, {
        type: 'doughnut',
        data: {
          labels: data.tokensByModel.map(m => m.model),
          datasets: [{
            data: data.tokensByModel.map(m => m.tokens),
            backgroundColor: chartColors.slice(0, data.tokensByModel.length),
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
      charts.push(chart);
    }

    // Hourly activity bar chart
    if (hourlyChartCanvas && data.activityByHour.length > 0) {
      const chart = new Chart(hourlyChartCanvas, {
        type: 'bar',
        data: {
          labels: data.activityByHour.map(h => `${h.hour}:00`),
          datasets: [{
            data: data.activityByHour.map(h => h.count),
            backgroundColor: colors.mauve,
            borderRadius: 2,
          }],
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: { legend: { display: false } },
          scales: {
            x: { grid: { display: false }, ticks: { color: colors.overlay0, maxTicksLimit: 12 } },
            y: {
              grid: {
                color: 'rgba(142, 142, 147, 0.3)',
                drawTicks: true,
              },
              ticks: { color: colors.overlay0 },
            },
          },
        },
      });
      charts.push(chart);
    }
  }

  const chartColors = [colors.mauve, colors.sky, colors.green, colors.peach, colors.pink, colors.blue];

  onMount(fetchData);
  onDestroy(() => charts.forEach(c => c.destroy()));
</script>

<div>
  <ViewHeader category="stats-cache" title="Lifetime Stats" subtitle="From ~/.claude/stats-cache.json" />

  {#if loading && !data}
    <div class="flex items-center justify-center h-32">
      <div class="text-xs text-text-muted">Loading stats cache...</div>
    </div>
  {:else if error}
    <div class="bg-bg-card rounded-md p-4 text-center">
      <div class="text-xs text-text-secondary mb-1">Unable to load stats cache</div>
      <div class="text-xs text-text-muted">{error}</div>
    </div>
  {:else if data}
    <!-- Summary Cards - 8 cards in 2 rows of 4 -->
    <div class="grid grid-cols-4 gap-2 mb-3">
      <MetricCard label="Est. Cost" value={formatCost(data.estimatedCost)} subtitle="all time" color="green" highlight={true} />
      <MetricCard label="Total Tokens" value={formatTokens(data.totalTokens)} subtitle="all time" color="cyan" highlight={true} />
      <MetricCard label="Sessions" value={data.totalSessions.toString()} subtitle="all time" color="green" />
      <MetricCard label="Active Days" value={data.activeDays.toString()} subtitle="days used" color="yellow" />
    </div>
    <div class="grid grid-cols-4 gap-2 mb-3">
      <MetricCard label="Messages" value={data.totalMessages.toLocaleString()} subtitle="all time" color="purple" />
      <MetricCard label="Avg/Day" value={data.avgMessagesPerDay.toFixed(1)} subtitle="messages" color="orange" />
      <MetricCard label="Peak Hour" value={formatHour(data.peakHour)} subtitle="most active" color="cyan" />
      <MetricCard label="First Session" value={formatDate(data.firstSession)} subtitle="started using" color="blue" />
    </div>

    <!-- Daily Activity Chart -->
    <div class="bg-bg-card rounded-md p-3 mb-3">
      <div class="flex items-center justify-between mb-2">
        <div class="text-xs font-medium text-text-muted uppercase tracking-wider">Daily Activity</div>
        <span class="text-xs text-text-muted">Last 30 days</span>
      </div>
      <div class="h-32"><canvas bind:this={dailyChartCanvas}></canvas></div>
    </div>

    <!-- Token Usage by Model -->
    <div class="bg-bg-card rounded-md p-4 mb-3">
      <div class="text-xs font-medium text-text-muted uppercase tracking-wider mb-3">Token Usage by Model</div>
      <div class="flex items-center gap-5">
        <div class="w-30 h-30 flex-shrink-0" style="width: 120px; height: 120px;">
          <canvas bind:this={modelChartCanvas}></canvas>
        </div>
        <div class="flex-1 space-y-2 min-w-0">
          {#each data.tokensByModel.slice(0, 5) as model, i}
            {@const percent = data.totalTokens > 0 ? (model.tokens / data.totalTokens) * 100 : 0}
            <div class="flex items-center gap-2">
              <div class="w-2 h-2 rounded-full flex-shrink-0" style="background-color: {chartColors[i % chartColors.length]}"></div>
              <span class="text-sm font-bold text-text-primary">{formatModelName(model.model)}</span>
              <span class="text-sm font-bold text-text-primary">({percent.toFixed(1)}%)</span>
            </div>
          {/each}
        </div>
      </div>
    </div>

    <!-- Activity by Hour -->
    <div class="bg-bg-card rounded-md p-3">
      <div class="text-xs font-medium text-text-muted uppercase tracking-wider mb-2">Activity by Hour</div>
      <div class="h-28"><canvas bind:this={hourlyChartCanvas}></canvas></div>
    </div>
  {/if}
</div>
