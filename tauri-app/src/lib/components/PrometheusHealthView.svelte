<script lang="ts">
  import { onMount, onDestroy, tick } from 'svelte';
  import { invoke } from '@tauri-apps/api/core';
  import { Chart, registerables } from 'chart.js';
  import { settings } from '$lib/stores/settings';
  import { timeRange as timeRangeStore, customTimeRange as customTimeRangeStore } from '$lib/stores';
  import { TimeRangePicker } from '$lib/components';
  import type { PrometheusHealthMetrics, TimeRange, CustomTimeRange } from '$lib/types';

  let chartsRegistered = false;

  let storageChartCanvas: HTMLCanvasElement;
  let memoryChartCanvas: HTMLCanvasElement;
  let storageChart: Chart | null = null;
  let memoryChart: Chart | null = null;

  // Chart colors
  const chartColors = {
    storage: '#00d9ff',    // Cyan
    memory: '#a855f7',     // Purple
    overlay0: '#8e8e93',   // Muted text
  };

  let metrics: PrometheusHealthMetrics | null = null;
  let loading = true;
  let error: string | null = null;
  let refreshInterval: ReturnType<typeof setInterval>;

  async function fetchHealth() {
    console.log('PrometheusHealthView: fetchHealth starting');
    loading = true;
    error = null;
    try {
      console.log('PrometheusHealthView: calling invoke...');
      metrics = await invoke<PrometheusHealthMetrics>('get_prometheus_health', {
        prometheusUrl: $settings.prometheusUrl,
        timeRange: $timeRangeStore,
        customStart: $customTimeRangeStore?.start,
        customEnd: $customTimeRangeStore?.end,
      });
      console.log('PrometheusHealthView: invoke returned', metrics);
      await tick();
      updateCharts();
    } catch (e) {
      console.error('PrometheusHealthView: Failed to fetch prometheus health:', e);
      error = String(e);
    } finally {
      console.log('PrometheusHealthView: fetchHealth complete, loading=false');
      loading = false;
    }
  }

  function updateCharts() {
    if (!metrics) return;

    // Register Chart.js once
    if (!chartsRegistered) {
      Chart.register(...registerables);
      chartsRegistered = true;
    }

    // Storage over time chart
    if (storageChartCanvas && metrics.storageOverTime.length > 0) {
      storageChart?.destroy();
      const ctx = storageChartCanvas.getContext('2d');
      if (ctx) {
        const gradient = ctx.createLinearGradient(0, 0, 0, 128);
        gradient.addColorStop(0, 'rgba(0, 217, 255, 0.4)');
        gradient.addColorStop(1, 'rgba(0, 217, 255, 0)');

        storageChart = new Chart(storageChartCanvas, {
          type: 'line',
          data: {
            labels: metrics.storageOverTime.map(p => {
              const date = new Date(p.timestamp * 1000);
              return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
            }),
            datasets: [{
              data: metrics.storageOverTime.map(p => p.value),
              borderColor: chartColors.storage,
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
                ticks: { color: chartColors.overlay0, maxTicksLimit: 6, font: { size: 10 } },
              },
              y: {
                grid: { color: 'rgba(142, 142, 147, 0.2)' },
                ticks: {
                  color: chartColors.overlay0,
                  callback: (v) => formatBytes(Number(v)),
                  font: { size: 10 },
                  maxTicksLimit: 5,
                },
                position: 'right',
              },
            },
          },
        });
      }
    }

    // Memory over time chart
    if (memoryChartCanvas && metrics.memoryOverTime.length > 0) {
      memoryChart?.destroy();
      const ctx = memoryChartCanvas.getContext('2d');
      if (ctx) {
        const gradient = ctx.createLinearGradient(0, 0, 0, 128);
        gradient.addColorStop(0, 'rgba(168, 85, 247, 0.4)');
        gradient.addColorStop(1, 'rgba(168, 85, 247, 0)');

        memoryChart = new Chart(memoryChartCanvas, {
          type: 'line',
          data: {
            labels: metrics.memoryOverTime.map(p => {
              const date = new Date(p.timestamp * 1000);
              return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
            }),
            datasets: [{
              data: metrics.memoryOverTime.map(p => p.value),
              borderColor: chartColors.memory,
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
                ticks: { color: chartColors.overlay0, maxTicksLimit: 6, font: { size: 10 } },
              },
              y: {
                grid: { color: 'rgba(142, 142, 147, 0.2)' },
                ticks: {
                  color: chartColors.overlay0,
                  callback: (v) => formatBytes(Number(v)),
                  font: { size: 10 },
                  maxTicksLimit: 5,
                },
                position: 'right',
              },
            },
          },
        });
      }
    }
  }

  function handleTimeRangeChange(value: TimeRange) {
    timeRangeStore.set(value);
    if (value !== 'custom') {
      customTimeRangeStore.set(null);
    }
    fetchHealth();
  }

  function handleCustomRangeChange(range: CustomTimeRange) {
    customTimeRangeStore.set(range);
  }

  function getTimeRangeLabel(): string {
    if ($timeRangeStore === 'custom' && $customTimeRangeStore) {
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
      '30d': 'Past month',
      '90d': 'Past 3 months',
    };
    return labels[$timeRangeStore as Exclude<TimeRange, 'custom'>] || 'Custom range';
  }

  onMount(() => {
    fetchHealth();
    refreshInterval = setInterval(fetchHealth, $settings.refreshInterval * 1000);
    return () => {
      clearInterval(refreshInterval);
      storageChart?.destroy();
      memoryChart?.destroy();
    };
  });

  onDestroy(() => {
    if (refreshInterval) clearInterval(refreshInterval);
    storageChart?.destroy();
    memoryChart?.destroy();
  });

  // Card highlight styles (matching MetricCard)
  const cardHighlights = {
    storage: {
      glow: 'rgba(0, 217, 255, 0.15)',
      border: 'rgba(0, 217, 255, 0.4)',
    },
    memory: {
      glow: 'rgba(168, 85, 247, 0.15)',
      border: 'rgba(168, 85, 247, 0.4)',
    },
  };

  // Format bytes to human readable
  function formatBytes(bytes: number): string {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return `${(bytes / Math.pow(k, i)).toFixed(1)} ${sizes[i]}`;
  }

  // Format duration
  function formatDuration(seconds: number): string {
    if (seconds < 60) return `${Math.floor(seconds)}s`;
    if (seconds < 3600) return `${Math.floor(seconds / 60)}m`;
    if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ${Math.floor((seconds % 3600) / 60)}m`;
    const days = Math.floor(seconds / 86400);
    const hours = Math.floor((seconds % 86400) / 3600);
    return `${days}d ${hours}h`;
  }

  // Format rate
  function formatRate(rate: number): string {
    if (rate >= 1000000) return `${(rate / 1000000).toFixed(1)}M/s`;
    if (rate >= 1000) return `${(rate / 1000).toFixed(1)}K/s`;
    return `${rate.toFixed(1)}/s`;
  }

  // Calculate storage percentage
  function getStoragePercent(metrics: PrometheusHealthMetrics): number {
    if (metrics.storageRetentionLimitBytes <= 0) return 0;
    return Math.min(100, (metrics.storageTotalBytes / metrics.storageRetentionLimitBytes) * 100);
  }

  // Get retention period from timestamps
  function getRetentionPeriod(metrics: PrometheusHealthMetrics): string {
    if (!metrics.oldestTimestampSeconds || !metrics.newestTimestampSeconds) return 'N/A';
    const duration = metrics.newestTimestampSeconds - metrics.oldestTimestampSeconds;
    return formatDuration(duration);
  }

  // Get status color
  function getStatusColor(isReady: boolean): string {
    return isReady ? '#00ff88' : '#ff6b6b';
  }

  // Get health indicator status
  function getHealthStatus(metrics: PrometheusHealthMetrics): { label: string; color: string; issues: string[] } {
    const issues: string[] = [];

    if (metrics.compactionsFailed > 0) {
      issues.push(`${metrics.compactionsFailed} compaction failures`);
    }
    if (metrics.walCorruptions > 0) {
      issues.push(`${metrics.walCorruptions} WAL corruptions`);
    }
    if (!metrics.configReloadSuccess) {
      issues.push('Config reload failed');
    }

    if (issues.length === 0) {
      return { label: 'Healthy', color: '#00ff88', issues: [] };
    } else if (issues.length === 1) {
      return { label: 'Warning', color: '#ffd93d', issues };
    } else {
      return { label: 'Degraded', color: '#ff6b6b', issues };
    }
  }

  // CPU percentage (rate is fraction of a core)
  function getCpuPercent(rate: number): number {
    return Math.min(100, rate * 100);
  }
</script>

<div class="flex flex-col h-full">
  <!-- Header -->
  <div class="flex items-center justify-between mb-4">
    <div class="flex-shrink-0">
      <h1 class="text-lg font-semibold text-text-primary">Prometheus Health</h1>
      <p class="text-xs text-text-muted">{getTimeRangeLabel()}</p>
    </div>
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
      <div class="text-xs text-text-muted">Loading health metrics...</div>
    </div>
  {:else if error}
    <div class="bg-red/10 border border-red/50 rounded-md p-3 mb-4">
      <p class="text-xs text-red">{error}</p>
    </div>
  {:else if metrics}
    <!-- Main Grid: 2 columns -->
    <div class="grid grid-cols-2 gap-3 mb-3">
      <!-- Storage Card (with highlight) -->
      <div
        class="bg-bg-card rounded-md p-3"
        style="box-shadow: 0 0 20px {cardHighlights.storage.glow}, inset 0 0 15px {cardHighlights.storage.glow}; border: 1px solid {cardHighlights.storage.border};"
      >
        <div class="flex items-center gap-1.5 mb-2">
          <div class="w-1.5 h-1.5 rounded-full bg-sky"></div>
          <span class="text-xs font-medium text-text-muted uppercase tracking-wider">Storage</span>
        </div>

        <div class="flex items-baseline gap-2 mb-2">
          <span class="text-2xl font-bold text-text-primary">{formatBytes(metrics.storageTotalBytes)}</span>
          {#if metrics.storageRetentionLimitBytes > 0}
            <span class="text-xs text-text-muted">/ {formatBytes(metrics.storageRetentionLimitBytes)}</span>
          {/if}
        </div>

        <!-- Storage gauge bar -->
        {#if metrics.storageRetentionLimitBytes > 0}
          {@const percent = getStoragePercent(metrics)}
          <div class="h-2 bg-surface-0 rounded-full overflow-hidden mb-2">
            <div
              class="h-full rounded-full transition-all"
              style="width: {percent}%; background-color: {percent > 80 ? '#ff6b6b' : percent > 60 ? '#ffd93d' : '#00d9ff'}"
            ></div>
          </div>
          <div class="text-xs text-text-muted mb-2">{percent.toFixed(1)}% used</div>
        {/if}

        <!-- Storage breakdown -->
        <div class="grid grid-cols-2 gap-2 text-xs">
          <div>
            <span class="text-text-muted">Blocks:</span>
            <span class="text-text-secondary ml-1">{formatBytes(metrics.storageBlocksBytes)}</span>
          </div>
          <div>
            <span class="text-text-muted">WAL:</span>
            <span class="text-text-secondary ml-1">{formatBytes(metrics.storageWalBytes)}</span>
          </div>
        </div>
      </div>

      <!-- Memory Card (with highlight) -->
      <div
        class="bg-bg-card rounded-md p-3"
        style="box-shadow: 0 0 20px {cardHighlights.memory.glow}, inset 0 0 15px {cardHighlights.memory.glow}; border: 1px solid {cardHighlights.memory.border};"
      >
        <div class="flex items-center gap-1.5 mb-2">
          <div class="w-1.5 h-1.5 rounded-full bg-mauve"></div>
          <span class="text-xs font-medium text-text-muted uppercase tracking-wider">Memory</span>
        </div>

        <div class="flex items-baseline gap-2 mb-2">
          <span class="text-2xl font-bold text-text-primary">{formatBytes(metrics.processMemoryBytes)}</span>
          <span class="text-xs text-text-muted">RSS</span>
        </div>

        <!-- Memory breakdown -->
        <div class="grid grid-cols-2 gap-2 text-xs mb-2">
          <div>
            <span class="text-text-muted">Heap:</span>
            <span class="text-text-secondary ml-1">{formatBytes(metrics.heapInuseBytes)}</span>
          </div>
          <div>
            <span class="text-text-muted">Alloc:</span>
            <span class="text-text-secondary ml-1">{formatBytes(metrics.heapAllocBytes)}</span>
          </div>
        </div>

        <!-- CPU & Goroutines -->
        <div class="grid grid-cols-2 gap-2 text-xs">
          <div>
            <span class="text-text-muted">CPU:</span>
            <span class="text-text-secondary ml-1">{getCpuPercent(metrics.cpuSecondsRate).toFixed(1)}%</span>
          </div>
          <div>
            <span class="text-text-muted">Goroutines:</span>
            <span class="text-text-secondary ml-1">{metrics.goroutines.toLocaleString()}</span>
          </div>
        </div>
      </div>
    </div>

    <!-- Storage Over Time Chart -->
    <div class="bg-bg-card rounded-md p-3 mb-3">
      <div class="flex items-center justify-between mb-1">
        <div class="flex items-center gap-1.5">
          <div class="w-1.5 h-1.5 rounded-full bg-sky"></div>
          <span class="text-xs font-medium text-text-muted uppercase tracking-wider">Storage Over Time</span>
        </div>
        <span class="text-xs text-text-muted">{getTimeRangeLabel()}</span>
      </div>
      <div class="h-32">
        <canvas bind:this={storageChartCanvas}></canvas>
      </div>
    </div>

    <!-- Memory Over Time Chart -->
    <div class="bg-bg-card rounded-md p-3 mb-3">
      <div class="flex items-center justify-between mb-1">
        <div class="flex items-center gap-1.5">
          <div class="w-1.5 h-1.5 rounded-full bg-mauve"></div>
          <span class="text-xs font-medium text-text-muted uppercase tracking-wider">Memory Over Time</span>
        </div>
        <span class="text-xs text-text-muted">{getTimeRangeLabel()}</span>
      </div>
      <div class="h-32">
        <canvas bind:this={memoryChartCanvas}></canvas>
      </div>
    </div>

    <!-- Second Row: Ingestion & TSDB -->
    <div class="grid grid-cols-2 gap-3 mb-3">
      <!-- Ingestion Card -->
      <div class="bg-bg-card rounded-md p-3">
        <div class="flex items-center gap-1.5 mb-2">
          <div class="w-1.5 h-1.5 rounded-full bg-green"></div>
          <span class="text-xs font-medium text-text-muted uppercase tracking-wider">Ingestion</span>
        </div>

        <div class="flex items-baseline gap-2 mb-2">
          <span class="text-2xl font-bold text-text-primary">{formatRate(metrics.samplesAppendedRate)}</span>
          <span class="text-xs text-text-muted">samples</span>
        </div>

        <div class="grid grid-cols-2 gap-2 text-xs mb-2">
          <div>
            <span class="text-text-muted">New series:</span>
            <span class="text-text-secondary ml-1">{formatRate(metrics.seriesCreatedRate)}</span>
          </div>
          <div>
            <span class="text-text-muted">Active series:</span>
            <span class="text-text-secondary ml-1">{metrics.headSeries.toLocaleString()}</span>
          </div>
        </div>
      </div>

      <!-- Scrape & Retention Card -->
      <div class="bg-bg-card rounded-md p-3">
        <div class="flex items-center gap-1.5 mb-2">
          <div class="w-1.5 h-1.5 rounded-full bg-peach"></div>
          <span class="text-xs font-medium text-text-muted uppercase tracking-wider">Scraping</span>
        </div>

        <div class="flex items-baseline gap-2 mb-2">
          <span class="text-2xl font-bold text-text-primary">{metrics.targetCount.toLocaleString()}</span>
          <span class="text-xs text-text-muted">targets</span>
        </div>

        <div class="grid grid-cols-2 gap-2 text-xs mb-2">
          <div>
            <span class="text-text-muted">Scrape time:</span>
            <span class="text-text-secondary ml-1">{(metrics.scrapeDurationSeconds * 1000).toFixed(0)}ms</span>
          </div>
          <div>
            <span class="text-text-muted">Samples/scrape:</span>
            <span class="text-text-secondary ml-1">{metrics.scrapeSamples.toLocaleString()}</span>
          </div>
        </div>

        <div class="grid grid-cols-2 gap-2 text-xs">
          <div>
            <span class="text-text-muted">Retention:</span>
            <span class="text-text-secondary ml-1">{getRetentionPeriod(metrics)}</span>
          </div>
          <div>
            <span class="text-text-muted">Blocks:</span>
            <span class="text-text-secondary ml-1">{metrics.blocksLoaded.toLocaleString()}</span>
          </div>
        </div>
      </div>
    </div>

    <!-- Health Indicators -->
    {@const health = getHealthStatus(metrics)}
    {@const healthGlow = health.label === 'Healthy' ? 'rgba(0, 255, 136, 0.15)' : 'rgba(255, 107, 107, 0.15)'}
    {@const healthBorder = health.label === 'Healthy' ? 'rgba(0, 255, 136, 0.4)' : 'rgba(255, 107, 107, 0.4)'}
    <div
      class="bg-bg-card rounded-md p-3"
      style="box-shadow: 0 0 20px {healthGlow}, inset 0 0 15px {healthGlow}; border: 1px solid {healthBorder};"
    >
      <div class="flex items-center justify-between mb-3">
        <div class="flex items-center gap-1.5">
          <div class="w-2 h-2 rounded-full" style="background-color: {health.color}; box-shadow: 0 0 8px {health.color};"></div>
          <span class="text-xs font-medium text-text-muted uppercase tracking-wider">Health Indicators</span>
        </div>
      </div>

      <div class="grid grid-cols-5 gap-3">
        <!-- Overall Health Status -->
        <div class="text-center">
          <div class="text-lg font-bold" style="color: {health.color}">
            {health.label === 'Healthy' ? 'OK' : health.label}
          </div>
          <div class="text-xs text-text-muted">{health.label === 'Healthy' ? 'Healthy' : 'Unhealthy'}</div>
          <div class="text-xs text-text-muted mt-1">v{metrics.version || 'N/A'}</div>
        </div>

        <!-- Uptime -->
        <div class="text-center">
          <div class="text-lg font-bold text-text-primary">{formatDuration(metrics.uptimeSeconds)}</div>
          <div class="text-xs text-text-muted">Uptime</div>
          <div class="text-xs text-text-muted mt-1">running</div>
        </div>

        <!-- Compactions -->
        <div class="text-center">
          <div class="text-lg font-bold text-text-primary">{metrics.compactionsTotal.toLocaleString()}</div>
          <div class="text-xs text-text-muted">Compactions</div>
          {#if metrics.compactionsFailed > 0}
            <div class="text-xs text-red mt-1">{metrics.compactionsFailed} failed</div>
          {:else}
            <div class="text-xs text-green mt-1">0 failed</div>
          {/if}
        </div>

        <!-- WAL Health -->
        <div class="text-center">
          <div class="text-lg font-bold" style="color: {metrics.walCorruptions === 0 ? '#00ff88' : '#ff6b6b'}">
            {metrics.walCorruptions === 0 ? 'OK' : metrics.walCorruptions}
          </div>
          <div class="text-xs text-text-muted">WAL Health</div>
          <div class="text-xs text-text-muted mt-1">{metrics.walCorruptions === 0 ? 'No corruptions' : 'corruptions'}</div>
        </div>

        <!-- Config Status -->
        <div class="text-center">
          <div class="text-lg font-bold" style="color: {metrics.configReloadSuccess ? '#00ff88' : '#ff6b6b'}">
            {metrics.configReloadSuccess ? 'OK' : 'Failed'}
          </div>
          <div class="text-xs text-text-muted">Config</div>
          {#if metrics.configReloadTimestamp > 0}
            <div class="text-xs text-text-muted mt-1">
              {new Date(metrics.configReloadTimestamp * 1000).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
            </div>
          {/if}
        </div>
      </div>
    </div>
  {/if}
</div>
