<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
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

  Chart.register(...registerables);

  async function fetchData() {
    loading = true;
    error = null;
    try {
      data = await invoke<LocalStatsCacheData>('get_local_stats_cache', {
        pricingProvider: $settings.pricingProvider,
      });
      updateCharts();
    } catch (e) {
      error = e as string;
    } finally {
      loading = false;
    }
  }

  function formatTokens(n: number): string {
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
            labels: data.dailyActivity.slice(-30).map(d => d.date.slice(5)), // MM-DD format
            datasets: [{
              data: data.dailyActivity.slice(-30).map(d => d.value),
              backgroundColor: '#5b9a8b',
              borderRadius: 2,
            }],
          },
          options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: { legend: { display: false } },
            scales: {
              x: { grid: { display: false }, ticks: { color: '#9aa0a9', maxTicksLimit: 10 } },
              y: { grid: { color: '#2f343c' }, ticks: { color: '#9aa0a9' } },
            },
          },
        });
        charts.push(chart);
      }
    }

    // Model breakdown doughnut
    if (modelChartCanvas && data.tokensByModel.length > 0) {
      const colors = ['#9b7bb8', '#5b9a8b', '#6b9b7a', '#c4896b', '#b87b9b', '#6b8fc4'];
      const chart = new Chart(modelChartCanvas, {
        type: 'doughnut',
        data: {
          labels: data.tokensByModel.map(m => m.model),
          datasets: [{
            data: data.tokensByModel.map(m => m.tokens),
            backgroundColor: colors.slice(0, data.tokensByModel.length),
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
            backgroundColor: '#9b7bb8',
            borderRadius: 2,
          }],
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: { legend: { display: false } },
          scales: {
            x: { grid: { display: false }, ticks: { color: '#9aa0a9', maxTicksLimit: 12 } },
            y: { grid: { color: '#2f343c' }, ticks: { color: '#9aa0a9' } },
          },
        },
      });
      charts.push(chart);
    }
  }

  onMount(fetchData);
  onDestroy(() => charts.forEach(c => c.destroy()));
</script>

<div>
  <ViewHeader category="stats-cache" title="Local Stats Cache" subtitle="From ~/.claude/stats-cache.json" />

  {#if loading && !data}
    <div class="flex items-center justify-center h-64">
      <div class="text-text-secondary">Loading stats cache...</div>
    </div>
  {:else if error}
    <div class="bg-bg-card rounded-lg p-8 text-center">
      <div class="text-text-secondary mb-2">Unable to load stats cache</div>
      <div class="text-text-muted text-sm">{error}</div>
    </div>
  {:else if data}
    <!-- Summary Cards -->
    <div class="mb-6">
      <div class="flex items-center gap-4 mb-4">
        <div class="h-px flex-1 bg-border-secondary"></div>
        <span class="text-xs font-medium text-text-muted uppercase tracking-wider">Summary</span>
        <div class="h-px flex-1 bg-border-secondary"></div>
      </div>
      <div class="grid grid-cols-4 gap-4 mb-4">
        <MetricCard label="Total Tokens" value={formatTokens(data.totalTokens)} subtitle="all time" color="cyan" />
        <MetricCard label="Sessions" value={data.totalSessions.toString()} subtitle="all time" color="green" />
        <MetricCard label="Active Days" value={data.activeDays.toString()} subtitle="days used" color="yellow" />
        <MetricCard label="Avg/Day" value={data.avgMessagesPerDay.toFixed(1)} subtitle="messages" color="orange" />
      </div>
      <div class="grid grid-cols-4 gap-4">
        <MetricCard label="Messages" value={data.totalMessages.toLocaleString()} subtitle="all time" color="purple" />
        <MetricCard label="Est. Cost" value={formatCost(data.estimatedCost)} subtitle="all time" color="green" />
        <MetricCard label="Peak Hour" value={formatHour(data.peakHour)} subtitle="most active" color="cyan" />
        <MetricCard label="First Session" value={formatDate(data.firstSession)} subtitle="started using" color="blue" />
      </div>
    </div>

    <!-- Charts Section -->
    <div class="space-y-6">
      <!-- Daily Activity -->
      <div class="bg-bg-card rounded-lg p-6">
        <div class="flex items-center gap-4 mb-4">
          <div class="h-px flex-1 bg-border-secondary"></div>
          <span class="text-xs font-medium text-text-muted uppercase tracking-wider">Daily Activity</span>
          <div class="h-px flex-1 bg-border-secondary"></div>
        </div>
        <div class="text-xs text-text-muted mb-4">Last 30 days</div>
        <div class="h-48"><canvas bind:this={dailyChartCanvas}></canvas></div>
      </div>

      <!-- Model & Hourly Charts -->
      <div class="grid grid-cols-2 gap-6">
        <!-- Token Usage by Model -->
        <div class="bg-bg-card rounded-lg p-6">
          <div class="text-xs font-medium text-text-muted uppercase tracking-wider mb-1">Token Usage by Model</div>
          <div class="text-xs text-text-muted mb-4">breakdown</div>
          <div class="flex items-center gap-6">
            <div class="w-36 h-36">
              <canvas bind:this={modelChartCanvas}></canvas>
            </div>
            <div class="flex-1 space-y-2">
              {#each data.tokensByModel as model, i}
                {@const colors = ['#9b7bb8', '#5b9a8b', '#6b9b7a', '#c4896b', '#b87b9b', '#6b8fc4']}
                <div class="flex items-center justify-between">
                  <div class="flex items-center gap-2">
                    <div class="w-2 h-2 rounded-full" style="background-color: {colors[i % colors.length]}"></div>
                    <span class="text-xs text-text-secondary truncate max-w-[120px]">{model.model}</span>
                  </div>
                  <span class="text-xs font-medium text-text-primary">{formatTokens(model.tokens)}</span>
                </div>
              {/each}
            </div>
          </div>
        </div>

        <!-- Activity by Hour -->
        <div class="bg-bg-card rounded-lg p-6">
          <div class="text-xs font-medium text-text-muted uppercase tracking-wider mb-1">Activity by Hour</div>
          <div class="text-xs text-text-muted mb-4">all time distribution</div>
          <div class="h-36"><canvas bind:this={hourlyChartCanvas}></canvas></div>
        </div>
      </div>
    </div>
  {/if}
</div>
