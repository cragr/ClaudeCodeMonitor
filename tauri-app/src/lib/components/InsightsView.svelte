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
