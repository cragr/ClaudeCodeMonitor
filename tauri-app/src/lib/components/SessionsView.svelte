<script lang="ts">
  import { onMount } from 'svelte';
  import { invoke } from '@tauri-apps/api/core';
  import { SessionsTable, SessionDetailModal, TimeRangePicker, ViewHeader, HeroCard } from '$lib/components';
  import { settings } from '$lib/stores/settings';
  import type { SessionsData, SessionMetrics, TimeRange } from '$lib/types';

  let data: SessionsData | null = null;
  let loading = true;
  let error: string | null = null;
  let timeRange: TimeRange = '24h';
  let selectedSession: SessionMetrics | null = null;

  async function fetchSessions() {
    loading = true;
    error = null;
    try {
      data = await invoke<SessionsData>('get_sessions_data', {
        timeRange,
        prometheusUrl: $settings.prometheusUrl,
      });
    } catch (e) {
      error = e as string;
    } finally {
      loading = false;
    }
  }

  function handleTimeRangeChange(value: TimeRange) {
    timeRange = value;
    fetchSessions();
  }

  function handleSelectSession(session: SessionMetrics) {
    selectedSession = session;
  }

  function handleCloseModal() {
    selectedSession = null;
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

  function formatCost(n: number): string {
    if (n >= 1) return `$${n.toFixed(2)}`;
    return `$${n.toFixed(4)}`;
  }

  function formatTokens(n: number): string {
    if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(2)}M`;
    if (n >= 1_000) return `${(n / 1_000).toFixed(1)}K`;
    return n.toString();
  }

  function formatDuration(seconds: number): string {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    if (hours > 0) return `${hours}h ${minutes}m`;
    return `${minutes}m`;
  }

  // Get top sessions
  $: topByCost = data?.sessions.slice().sort((a, b) => b.totalCostUsd - a.totalCostUsd)[0];
  $: topByTokens = data?.sessions.slice().sort((a, b) => b.totalTokens - a.totalTokens)[0];
  $: topByDuration = data?.sessions.slice().sort((a, b) => b.activeTimeSeconds - a.activeTimeSeconds)[0];

  onMount(fetchSessions);
</script>

<div>
  <ViewHeader category="sessions" title="Session Explorer" subtitle={getTimeRangeLabel(timeRange)}>
    <svelte:fragment slot="actions">
      <TimeRangePicker value={timeRange} onChange={handleTimeRangeChange} />
    </svelte:fragment>
  </ViewHeader>

  {#if loading && !data}
    <div class="flex items-center justify-center h-64">
      <div class="text-text-secondary">Loading sessions...</div>
    </div>
  {:else if error}
    <div class="bg-bg-card rounded-lg p-8 text-center">
      <div class="text-text-secondary mb-2">Unable to load sessions</div>
      <div class="text-text-muted text-sm">{error}</div>
    </div>
  {:else if data}
    <!-- Top Sessions Section -->
    <div class="mb-6">
      <div class="flex items-center gap-4 mb-4">
        <div class="h-px flex-1 bg-border-secondary"></div>
        <span class="text-xs font-medium text-text-muted uppercase tracking-wider">Top Sessions</span>
        <div class="h-px flex-1 bg-border-secondary"></div>
      </div>
      <div class="grid grid-cols-3 gap-4">
        <div class="bg-bg-card rounded-lg p-4">
          <div class="flex items-center gap-2 mb-2">
            <div class="w-1.5 h-1.5 rounded-full bg-accent-green"></div>
            <span class="text-xs text-text-muted uppercase">Highest Cost</span>
          </div>
          {#if topByCost}
            <div class="text-2xl font-bold text-accent-green mb-1">{formatCost(topByCost.totalCostUsd)}</div>
            <div class="text-xs text-text-muted font-mono truncate">{topByCost.sessionId.slice(0, 8)}...</div>
          {:else}
            <div class="text-xl font-bold text-text-muted">—</div>
          {/if}
        </div>
        <div class="bg-bg-card rounded-lg p-4">
          <div class="flex items-center gap-2 mb-2">
            <div class="w-1.5 h-1.5 rounded-full bg-accent-cyan"></div>
            <span class="text-xs text-text-muted uppercase">Most Tokens</span>
          </div>
          {#if topByTokens}
            <div class="text-2xl font-bold text-accent-cyan mb-1">{formatTokens(topByTokens.totalTokens)}</div>
            <div class="text-xs text-text-muted font-mono truncate">{topByTokens.sessionId.slice(0, 8)}...</div>
          {:else}
            <div class="text-xl font-bold text-text-muted">—</div>
          {/if}
        </div>
        <div class="bg-bg-card rounded-lg p-4">
          <div class="flex items-center gap-2 mb-2">
            <div class="w-1.5 h-1.5 rounded-full bg-accent-orange"></div>
            <span class="text-xs text-text-muted uppercase">Longest Duration</span>
          </div>
          {#if topByDuration}
            <div class="text-2xl font-bold text-accent-orange mb-1">{formatDuration(topByDuration.activeTimeSeconds)}</div>
            <div class="text-xs text-text-muted font-mono truncate">{topByDuration.sessionId.slice(0, 8)}...</div>
          {:else}
            <div class="text-xl font-bold text-text-muted">—</div>
          {/if}
        </div>
      </div>
    </div>

    <!-- All Sessions Table -->
    <div>
      <div class="flex items-center gap-4 mb-4">
        <div class="h-px flex-1 bg-border-secondary"></div>
        <span class="text-xs font-medium text-text-muted uppercase tracking-wider">All Sessions</span>
        <div class="h-px flex-1 bg-border-secondary"></div>
        <span class="text-xs text-text-muted">{data.totalCount} sessions</span>
      </div>
      <SessionsTable
        sessions={data.sessions}
        onSelectSession={handleSelectSession}
      />
    </div>
  {/if}
</div>

<SessionDetailModal session={selectedSession} onClose={handleCloseModal} />
