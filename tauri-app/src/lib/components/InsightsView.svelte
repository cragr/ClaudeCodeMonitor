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

  onMount(fetchInsights);
</script>

<div>
  <ViewHeader category="insights" title="Usage Insights" subtitle={getPeriodLabel(period)}>
    <svelte:fragment slot="actions">
      <PeriodSelector value={period} onChange={handlePeriodChange} />
    </svelte:fragment>
  </ViewHeader>

  {#if loading && !data}
    <div class="flex items-center justify-center h-64">
      <div class="text-text-secondary">Loading insights...</div>
    </div>
  {:else if error}
    <div class="bg-bg-card rounded-lg p-8 text-center">
      <div class="text-text-secondary mb-2">No usage data yet</div>
      <div class="text-text-muted text-sm">Use Claude Code to start tracking your activity</div>
    </div>
  {:else if data}
    <!-- Period Comparison Section -->
    <div class="mb-6">
      <div class="flex items-center gap-4 mb-4">
        <div class="h-px flex-1 bg-border-secondary"></div>
        <span class="text-xs font-medium text-text-muted uppercase tracking-wider">Period Comparison</span>
        <div class="h-px flex-1 bg-border-secondary"></div>
      </div>
      <div class="grid grid-cols-4 gap-4">
        <ComparisonCard label="Messages" data={data.comparison.messages} />
        <ComparisonCard label="Sessions" data={data.comparison.sessions} />
        <ComparisonCard label="Tokens" data={data.comparison.tokens} format="compact" />
        <ComparisonCard label="Est. Cost" data={data.comparison.estimatedCost} format="currency" />
      </div>
    </div>

    <!-- Trends Section -->
    <div class="mb-6">
      <div class="flex items-center gap-4 mb-4">
        <div class="h-px flex-1 bg-border-secondary"></div>
        <span class="text-xs font-medium text-text-muted uppercase tracking-wider">Trends</span>
        <div class="h-px flex-1 bg-border-secondary"></div>
      </div>
      <div class="grid grid-cols-2 gap-4">
        <SparklineChart title="Daily Activity" data={data.dailyActivity} color="#22d3ee" />
        <SparklineChart title="Sessions/Day" data={data.sessionsPerDay} color="#a855f7" />
      </div>
    </div>

    <!-- Peak Activity Section -->
    <div>
      <div class="flex items-center gap-4 mb-4">
        <div class="h-px flex-1 bg-border-secondary"></div>
        <span class="text-xs font-medium text-text-muted uppercase tracking-wider">Peak Activity</span>
        <div class="h-px flex-1 bg-border-secondary"></div>
      </div>
      <div class="bg-bg-card rounded-lg p-4">
        <div class="grid grid-cols-4 gap-4">
          <div>
            <div class="flex items-center gap-2 mb-2">
              <div class="w-1.5 h-1.5 rounded-full bg-accent-yellow"></div>
              <span class="text-xs text-text-muted uppercase">Most Active Hour</span>
            </div>
            <div class="text-xl font-bold text-text-primary">{formatHour(data.peakActivity.mostActiveHour)}</div>
          </div>
          <div>
            <div class="flex items-center gap-2 mb-2">
              <div class="w-1.5 h-1.5 rounded-full bg-accent-orange"></div>
              <span class="text-xs text-text-muted uppercase">Longest Session</span>
            </div>
            <div class="text-xl font-bold text-text-primary">{formatDuration(data.peakActivity.longestSessionMinutes)}</div>
          </div>
          <div>
            <div class="flex items-center gap-2 mb-2">
              <div class="w-1.5 h-1.5 rounded-full bg-accent-green"></div>
              <span class="text-xs text-text-muted uppercase">Current Streak</span>
            </div>
            <div class="text-xl font-bold text-text-primary">{data.peakActivity.currentStreak} days</div>
          </div>
          <div>
            <div class="flex items-center gap-2 mb-2">
              <div class="w-1.5 h-1.5 rounded-full bg-accent-cyan"></div>
              <span class="text-xs text-text-muted uppercase">Member Since</span>
            </div>
            <div class="text-xl font-bold text-text-primary">{formatDate(data.peakActivity.memberSince)}</div>
          </div>
        </div>
      </div>
    </div>
  {/if}
</div>
