<script lang="ts">
  import { onMount } from 'svelte';
  import { invoke } from '@tauri-apps/api/core';
  import { PeriodSelector, ComparisonCard, SparklineChart, ViewHeader } from '$lib/components';
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

  function getPeriodLabel(p: PeriodType): string {
    const labels: Record<PeriodType, string> = {
      'this_week': 'This week',
      'last_7_days': 'Last 7 days',
      'this_month': 'This month',
    };
    return labels[p];
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

  // macOS dark theme colors
  const colors = {
    sky: '#00d9ff',
    mauve: '#a855f7',
    green: '#00ff88',
    yellow: '#ffd93d',
    peach: '#ffb347',
  };

  onMount(fetchInsights);
</script>

<div class="flex flex-col h-full">
  <!-- Header Row: Title + Time Range Picker -->
  <div class="flex items-start justify-between mb-4">
    <div>
      <div class="flex items-center gap-2 mb-0.5">
        <span class="text-xs font-medium text-yellow uppercase tracking-wider">Insights</span>
      </div>
      <h1 class="text-lg font-semibold text-text-primary">Usage Trends</h1>
      <p class="text-xs text-text-muted">{getPeriodLabel(period)}</p>
    </div>
    <PeriodSelector value={period} onChange={handlePeriodChange} />
  </div>

  {#if loading && !data}
    <div class="flex items-center justify-center h-32">
      <div class="text-xs text-text-muted">Loading insights...</div>
    </div>
  {:else if error}
    <div class="bg-bg-card rounded-md p-4 text-center">
      <div class="text-xs text-text-secondary mb-1">No usage data yet</div>
      <div class="text-xs text-text-muted">Use Claude Code to start tracking</div>
    </div>
  {:else if data}
    <!-- PERIOD COMPARISON Section -->
    <div class="mb-4">
      <div class="flex items-center gap-3 mb-2">
        <span class="text-xs font-medium text-text-muted uppercase tracking-wider">Period Comparison</span>
        <div class="flex-1 h-px bg-border-secondary"></div>
      </div>
      <div class="grid grid-cols-4 gap-2">
        <ComparisonCard label="Messages" data={data.comparison.messages} />
        <ComparisonCard label="Sessions" data={data.comparison.sessions} />
        <ComparisonCard label="Tokens" data={data.comparison.tokens} format="compact" />
        <ComparisonCard label="Est. Cost" data={data.comparison.estimatedCost} format="currency" />
      </div>
    </div>

    <!-- TRENDS Section -->
    <div class="mb-4">
      <div class="flex items-center gap-3 mb-2">
        <span class="text-xs font-medium text-text-muted uppercase tracking-wider">Trends</span>
        <div class="flex-1 h-px bg-border-secondary"></div>
      </div>
      <div class="grid grid-cols-2 gap-2">
        <SparklineChart title="Daily Activity" data={data.dailyActivity} color={colors.sky} />
        <SparklineChart title="Sessions/Day" data={data.sessionsPerDay} color={colors.mauve} />
      </div>
    </div>

    <!-- PEAK ACTIVITY Section -->
    <div>
      <div class="flex items-center gap-3 mb-2">
        <span class="text-xs font-medium text-text-muted uppercase tracking-wider">Peak Activity</span>
        <div class="flex-1 h-px bg-border-secondary"></div>
      </div>
      <div class="bg-bg-card rounded-md p-3">
        <div class="space-y-2">
          <div class="flex items-center justify-between">
            <span class="text-xs text-text-muted">Most Active Hour</span>
            <span class="text-sm font-medium text-text-primary">{formatHour(data.peakActivity.mostActiveHour)}</span>
          </div>
          <div class="flex items-center justify-between">
            <span class="text-xs text-text-muted">Longest Session</span>
            <span class="text-sm font-medium text-text-primary">{formatDuration(data.peakActivity.longestSessionMinutes)}</span>
          </div>
          <div class="flex items-center justify-between">
            <span class="text-xs text-text-muted">Current Streak</span>
            <span class="text-sm font-medium text-text-primary">{data.peakActivity.currentStreak} days</span>
          </div>
          <div class="flex items-center justify-between">
            <span class="text-xs text-text-muted">Member Since</span>
            <span class="text-sm font-medium text-text-primary">{formatDate(data.peakActivity.memberSince)}</span>
          </div>
        </div>
      </div>
    </div>
  {/if}
</div>
