<script lang="ts">
  import { onMount, onDestroy, tick } from 'svelte';
  import { invoke } from '@tauri-apps/api/core';
  import { Chart, registerables } from 'chart.js';
  import { ViewHeader, MetricCard, TimeRangePicker } from '$lib/components';
  import { settings } from '$lib/stores/settings';
  import { isConnected, lastUpdated, timeRange as timeRangeStore, customTimeRange as customTimeRangeStore, totalCost } from '$lib/stores';
  import type { DashboardMetrics, TimeRange, CustomTimeRange } from '$lib/types';

  let metrics: DashboardMetrics | null = null;
  let loading = true;
  let error: string | null = null;

  let costChartCanvas: HTMLCanvasElement;
  let modelChartCanvas: HTMLCanvasElement;
  let costChart: Chart | null = null;
  let modelChart: Chart | null = null;

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
      const params: Record<string, unknown> = {
        timeRange: $timeRangeStore,
        prometheusUrl: $settings.prometheusUrl,
      };

      // Add custom range timestamps if using custom time range
      if ($timeRangeStore === 'custom' && $customTimeRangeStore) {
        params.customStart = $customTimeRangeStore.start;
        params.customEnd = $customTimeRangeStore.end;
      }

      metrics = await invoke<DashboardMetrics>('get_dashboard_metrics', params);
      totalCost.set(metrics.totalCostUsd);
      isConnected.set(true);
      lastUpdated.set(new Date());
      await tick();
      updateCharts();
    } catch (e) {
      error = e as string;
      isConnected.set(false);
    } finally {
      loading = false;
    }
  }

  function handleTimeRangeChange(value: TimeRange) {
    timeRangeStore.set(value);
    if (value !== 'custom') {
      // Clear custom range when switching to preset
      customTimeRangeStore.set(null);
    }
    fetchMetrics();
  }

  function handleCustomRangeChange(range: CustomTimeRange) {
    customTimeRangeStore.set(range);
  }

  function formatCost(n: number): string {
    if (n >= 1) return `$${n.toFixed(2)}`;
    return `$${n.toFixed(4)}`;
  }

  function formatTokens(n: number): string {
    if (n >= 1_000_000_000) return `${(n / 1_000_000_000).toFixed(2)}B`;
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
    if (range === 'custom' && $customTimeRangeStore) {
      const start = new Date($customTimeRangeStore.start * 1000);
      const end = new Date($customTimeRangeStore.end * 1000);
      const formatDate = (d: Date) => d.toLocaleDateString([], { month: 'short', day: 'numeric' });
      return `${formatDate(start)} - ${formatDate(end)}`;
    }
    const labels: Record<Exclude<TimeRange, 'custom'>, string> = {
      '15m': 'Past 15 minutes',
      '1h': 'Past hour',
      '4h': 'Past 4 hours',
      '1d': 'Past day',
      '7d': 'Past week',
    };
    return labels[range as Exclude<TimeRange, 'custom'>] || 'Custom range';
  }

  function getCostByModel(model: { model: string; tokens: number }): number {
    if (!metrics || metrics.totalTokens === 0) return 0;
    const proportion = model.tokens / metrics.totalTokens;
    return metrics.totalCostUsd * proportion;
  }

  function formatModelName(modelName: string): string {
    // Extract friendly name like "Haiku 4.5" or "Opus 4.5" from full model name
    // Model names look like: "claude-3-5-haiku-20241022" or "claude-opus-4-5-20251101"
    const lower = modelName.toLowerCase();

    // Extract version like "3-5" or "4-5" and convert to "3.5" or "4.5"
    const versionMatch = lower.match(/(\d)-(\d)/);
    const version = versionMatch ? `${versionMatch[1]}.${versionMatch[2]}` : '';

    if (lower.includes('haiku')) {
      return version ? `Haiku ${version}` : 'Haiku';
    }
    if (lower.includes('opus')) {
      return version ? `Opus ${version}` : 'Opus';
    }
    if (lower.includes('sonnet')) {
      return version ? `Sonnet ${version}` : 'Sonnet';
    }
    // Fallback: return last part of model name
    return modelName.split('.').pop() || modelName;
  }

  function updateCharts() {
    if (!metrics) return;

    // Cumulative cost over period chart
    if (costChartCanvas && metrics.tokensOverTime.length > 0) {
      costChart?.destroy();
      const ctx = costChartCanvas.getContext('2d');
      if (ctx) {
        const gradient = ctx.createLinearGradient(0, 0, 0, 128);
        gradient.addColorStop(0, 'rgba(0, 217, 255, 0.4)');   // Cyan accent
        gradient.addColorStop(1, 'rgba(0, 217, 255, 0)');

        // Backend returns rate per step via rate()
        // Compute cumulative sum then scale to match total (matching Swift app)
        let cumulative = 0;
        const rawCumulativeData = metrics.tokensOverTime.map(p => {
          cumulative += p.value;
          return cumulative;
        });

        // Scale cumulative values so final value matches totalCostUsd
        const rawTotal = rawCumulativeData[rawCumulativeData.length - 1] || 0;
        const targetTotal = metrics.totalCostUsd;
        const scaleFactor = (rawTotal > 0 && targetTotal > 0) ? targetTotal / rawTotal : 1;
        const cumulativeData = rawCumulativeData.map(v => v * scaleFactor);

        costChart = new Chart(costChartCanvas, {
          type: 'line',
          data: {
            labels: metrics.tokensOverTime.map(p => {
              const date = new Date(p.timestamp * 1000);
              return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
            }),
            datasets: [{
              data: cumulativeData,
              borderColor: colors.sky,
              backgroundColor: gradient,
              fill: true,
              tension: 0,  // Angular lines like Swift version
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
                grid: {
                  color: 'rgba(142, 142, 147, 0.2)',  // Semi-transparent grid lines
                  drawTicks: true,
                },
                ticks: {
                  color: colors.overlay0,
                  maxTicksLimit: 6,
                  font: { size: 10 },
                },
              },
              y: {
                grid: {
                  color: 'rgba(142, 142, 147, 0.2)',  // Semi-transparent grid lines
                },
                ticks: {
                  color: colors.overlay0,
                  callback: (v) => `$${Number(v).toFixed(2)}`,
                  font: { size: 10 },
                  maxTicksLimit: 5,
                },
                position: 'right',
                beginAtZero: true,
              },
            },
          },
        });
      }
    }

    // Model breakdown chart
    if (modelChartCanvas && metrics.tokensByModel.length > 0) {
      modelChart?.destroy();
      const chartColors = [colors.mauve, colors.sky, colors.green, colors.peach, colors.pink];
      const costData = metrics.tokensByModel.map(m => getCostByModel(m));

      modelChart = new Chart(modelChartCanvas, {
        type: 'doughnut',
        data: {
          labels: metrics.tokensByModel.map(m => m.model),
          datasets: [{
            data: costData,
            backgroundColor: chartColors.slice(0, metrics.tokensByModel.length),
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

  const chartColors = [colors.mauve, colors.sky, colors.green, colors.peach, colors.pink];
</script>

<div class="flex flex-col h-full">
  <!-- Header Row: Title (left) + Time Range (right) -->
  <div class="flex items-center justify-between mb-4">
    <!-- Left: Dashboard title -->
    <div class="flex-shrink-0">
      <h1 class="text-lg font-semibold text-text-primary">Dashboard</h1>
      <p class="text-xs text-text-muted">{getTimeRangeLabel($timeRangeStore)}</p>
    </div>

    <!-- Right: Time range picker -->
    <div class="flex-shrink-0">
      <TimeRangePicker
        value={$timeRangeStore}
        onChange={handleTimeRangeChange}
        customRange={$customTimeRangeStore}
        onCustomRangeChange={handleCustomRangeChange}
      />
    </div>
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
    <!-- Key Metrics Section -->
    <div class="mb-4">
      <div class="flex items-center justify-between mb-2">
        <span class="text-xs font-medium text-text-muted uppercase tracking-wider">Key Metrics</span>
        <span class="text-xs text-text-muted">Double-click to copy</span>
      </div>
      <!-- First row: Total Spend, Active Time, Total Tokens -->
      <div class="grid grid-cols-3 gap-2 mb-2">
        <MetricCard label="Total Spend" value={formatCost(metrics.totalCostUsd)} subtitle={getTimeRangeLabel($timeRangeStore)} color="green" highlight={true} />
        <MetricCard label="Active Time" value={formatTime(metrics.activeTimeSeconds)} subtitle="coding with Claude" color="cyan" highlight={true} />
        <MetricCard label="Total Tokens" value={formatTokens(metrics.totalTokens)} subtitle="all models" color="purple" highlight={true} />
      </div>
      <!-- Second row: Lines Added, Lines Removed, Commits, PRs -->
      <div class="grid grid-cols-4 gap-2">
        <MetricCard label="Lines Added" value={`+${metrics.linesAdded.toLocaleString()}`} subtitle="code added" color="green" />
        <MetricCard label="Lines Removed" value={`-${metrics.linesRemoved.toLocaleString()}`} subtitle="code removed" color="red" />
        <MetricCard label="Commits" value={metrics.commitCount.toString()} subtitle="git commits" color="purple" />
        <MetricCard label="Pull Requests" value={metrics.pullRequestCount?.toString() || '0'} subtitle="PRs created" color="orange" />
      </div>
    </div>

    <!-- Total Cost Over Period Chart -->
    <div class="bg-bg-card rounded-md p-4 mb-4">
      <div class="flex items-center justify-between mb-1">
        <span class="text-xs font-medium text-text-muted uppercase tracking-wider">Total Cost Over Period</span>
        <span class="text-xs text-text-muted">{getTimeRangeLabel($timeRangeStore)}</span>
      </div>
      <div class="h-40">
        <canvas bind:this={costChartCanvas}></canvas>
      </div>
    </div>

    <!-- Cost By Model Section -->
    <div class="bg-bg-card rounded-md p-4">
      <div class="mb-3 text-center">
        <span class="text-xs font-medium text-text-muted uppercase tracking-wider">Cost By Model</span>
        <span class="text-xs text-text-muted ml-2">breakdown</span>
      </div>
      <div class="flex items-center justify-center gap-8">
        <!-- Larger donut chart (25% bigger: 128px -> 160px) -->
        <div class="w-40 h-40 flex-shrink-0">
          <canvas bind:this={modelChartCanvas}></canvas>
        </div>
        <div class="space-y-3">
          {#each metrics.tokensByModel.slice(0, 5) as model, i}
            {@const modelCost = getCostByModel(model)}
            <div class="flex items-center justify-between gap-4">
              <div class="flex items-center gap-2">
                <div class="w-2.5 h-2.5 rounded-full flex-shrink-0" style="background-color: {chartColors[i % chartColors.length]}"></div>
                <span class="text-lg font-bold text-text-secondary min-w-[120px]">{formatModelName(model.model)}</span>
              </div>
              <span class="text-lg font-bold text-text-primary flex-shrink-0">{formatCost(modelCost)}</span>
            </div>
          {/each}
        </div>
      </div>
    </div>
  {/if}
</div>
