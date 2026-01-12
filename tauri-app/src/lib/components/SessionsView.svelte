<script lang="ts">
  import { onMount } from 'svelte';
  import { invoke } from '@tauri-apps/api/core';
  import { SessionDetailModal, TimeRangePicker, ViewHeader } from '$lib/components';
  import { settings } from '$lib/stores/settings';
  import { timeRange as timeRangeStore } from '$lib/stores';
  import type { SessionsData, SessionMetrics, TimeRange } from '$lib/types';

  let data: SessionsData | null = null;
  let loading = true;
  let error: string | null = null;
  let selectedSession: SessionMetrics | null = null;

  type SortOption = 'cost_high' | 'cost_low' | 'tokens_high' | 'duration_high';
  let sortOption: SortOption = 'cost_high';

  // Track previous URL to detect settings changes
  let previousPrometheusUrl = '';

  // Re-fetch when Prometheus URL changes (after initial load)
  $: if ($settings.prometheusUrl && previousPrometheusUrl && $settings.prometheusUrl !== previousPrometheusUrl) {
    previousPrometheusUrl = $settings.prometheusUrl;
    fetchSessions();
  }

  async function fetchSessions() {
    // Update tracked URL on each fetch
    previousPrometheusUrl = $settings.prometheusUrl;
    loading = true;
    error = null;
    try {
      data = await invoke<SessionsData>('get_sessions_data', {
        timeRange: $timeRangeStore,
        prometheusUrl: $settings.prometheusUrl,
      });
    } catch (e) {
      error = e as string;
    } finally {
      loading = false;
    }
  }

  function handleTimeRangeChange(value: TimeRange) {
    timeRangeStore.set(value);
    fetchSessions();
  }

  function handleSelectSession(session: SessionMetrics) {
    selectedSession = session;
  }

  function handleCloseModal() {
    selectedSession = null;
  }

  function truncateId(id: string): string {
    return id.length > 12 ? `${id.slice(0, 8)}...${id.slice(-4)}` : id;
  }

  function formatCost(n: number): string {
    if (n >= 1) return `$${n.toFixed(2)}`;
    if (n >= 0.01) return `$${n.toFixed(2)}`;
    if (n > 0) return `$${n.toFixed(4)}`;
    return '$0.0000';
  }

  function formatTokens(n: number): string {
    if (n === 0) return '0';
    if (n >= 1_000_000_000) return `${(n / 1_000_000_000).toFixed(2)}B`;
    if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(2)}M`;
    if (n >= 1_000) return `${(n / 1_000).toFixed(2)}K`;
    return n.toLocaleString();
  }

  function formatDuration(seconds: number): string {
    if (seconds === 0) return '0m';
    const hours = Math.floor(seconds / 3600);
    const mins = Math.floor((seconds % 3600) / 60);
    const secs = Math.floor(seconds % 60);
    if (hours > 0) return `${hours}h ${mins}m`;
    if (mins > 0) return `${mins}m ${secs}s`;
    return `${secs}s`;
  }

  function formatCostPerMin(cost: number, seconds: number): string {
    if (seconds === 0 || cost === 0) return '$0.0000';
    const costPerMin = (cost / seconds) * 60;
    return `$${costPerMin.toFixed(costPerMin >= 0.01 ? 2 : 4)}`;
  }

  // Top sessions
  $: highestCostSession = data?.sessions.slice().sort((a, b) => b.totalCostUsd - a.totalCostUsd)[0];
  $: mostTokensSession = data?.sessions.slice().sort((a, b) => b.totalTokens - a.totalTokens)[0];
  $: longestSession = data?.sessions.slice().sort((a, b) => b.activeTimeSeconds - a.activeTimeSeconds)[0];

  // Sorted sessions for table (exclude zero token sessions)
  $: sortedSessions = data?.sessions
    .filter(s => s.totalTokens > 0)
    .sort((a, b) => {
      switch (sortOption) {
        case 'cost_high': return b.totalCostUsd - a.totalCostUsd;
        case 'cost_low': return a.totalCostUsd - b.totalCostUsd;
        case 'tokens_high': return b.totalTokens - a.totalTokens;
        case 'duration_high': return b.activeTimeSeconds - a.activeTimeSeconds;
        default: return b.totalCostUsd - a.totalCostUsd;
      }
    }) ?? [];

  // Sorted projects by cost (exclude zero token projects)
  $: sortedProjects = data?.projects
    .filter(p => p.totalTokens > 0)
    .sort((a, b) => b.totalCostUsd - a.totalCostUsd) ?? [];

  onMount(fetchSessions);
</script>

<div>
  <ViewHeader category="sessions" title="Session History">
    <svelte:fragment slot="actions">
      <TimeRangePicker value={$timeRangeStore} onChange={handleTimeRangeChange} />
    </svelte:fragment>
  </ViewHeader>

  {#if loading && !data}
    <div class="flex items-center justify-center h-32">
      <div class="text-xs text-text-muted">Loading sessions...</div>
    </div>
  {:else if error}
    <div class="bg-bg-card rounded-md p-4 text-center">
      <div class="text-xs text-text-secondary mb-1">Unable to load sessions</div>
      <div class="text-xs text-text-muted">{error}</div>
    </div>
  {:else if data}
    <!-- Top Sessions -->
    <div class="mb-4">
      <div class="text-xs font-medium text-text-muted uppercase tracking-wider mb-2">Top Sessions</div>
      <div class="grid grid-cols-3 gap-3">
        <!-- Highest Cost -->
        <div class="bg-bg-card rounded-lg p-4 border border-accent-green/30 shadow-[0_0_12px_rgba(0,255,136,0.15)]">
          <div class="flex items-center gap-1.5 mb-2">
            <div class="w-1.5 h-1.5 rounded-full bg-accent-green"></div>
            <span class="text-xs text-text-muted uppercase tracking-wide">Highest Cost</span>
          </div>
          {#if highestCostSession}
            <div class="text-2xl font-bold text-accent-green mb-1">{formatCost(highestCostSession.totalCostUsd)}</div>
            <div class="text-xs text-text-muted font-mono mb-3">{truncateId(highestCostSession.sessionId)}</div>
            <div class="grid grid-cols-2 gap-4 text-xs border-t border-accent-green/20 pt-3">
              <div>
                <div class="text-text-muted">Tokens</div>
                <div class="text-text-primary">{formatTokens(highestCostSession.totalTokens)}</div>
              </div>
              <div class="border-l border-accent-green/20 pl-4">
                <div class="text-text-muted">Duration</div>
                <div class="text-text-primary">{formatDuration(highestCostSession.activeTimeSeconds)}</div>
              </div>
            </div>
          {:else}
            <div class="text-2xl font-bold text-text-muted">—</div>
          {/if}
        </div>

        <!-- Most Tokens -->
        <div class="bg-bg-card rounded-lg p-4 border border-sky/30 shadow-[0_0_12px_rgba(0,217,255,0.15)]">
          <div class="flex items-center gap-1.5 mb-2">
            <div class="w-1.5 h-1.5 rounded-full bg-sky"></div>
            <span class="text-xs text-text-muted uppercase tracking-wide">Most Tokens</span>
          </div>
          {#if mostTokensSession}
            <div class="text-2xl font-bold text-sky mb-1">{formatTokens(mostTokensSession.totalTokens)}</div>
            <div class="text-xs text-text-muted font-mono mb-3">{truncateId(mostTokensSession.sessionId)}</div>
            <div class="grid grid-cols-2 gap-4 text-xs border-t border-sky/20 pt-3">
              <div>
                <div class="text-text-muted">Tokens</div>
                <div class="text-text-primary">{formatTokens(mostTokensSession.totalTokens)}</div>
              </div>
              <div class="border-l border-sky/20 pl-4">
                <div class="text-text-muted">Duration</div>
                <div class="text-text-primary">{formatDuration(mostTokensSession.activeTimeSeconds)}</div>
              </div>
            </div>
          {:else}
            <div class="text-2xl font-bold text-text-muted">—</div>
          {/if}
        </div>

        <!-- Longest Duration -->
        <div class="bg-bg-card rounded-lg p-4 border border-peach/30 shadow-[0_0_12px_rgba(255,179,71,0.15)]">
          <div class="flex items-center gap-1.5 mb-2">
            <div class="w-1.5 h-1.5 rounded-full bg-peach"></div>
            <span class="text-xs text-text-muted uppercase tracking-wide">Longest Duration</span>
          </div>
          {#if longestSession}
            <div class="text-2xl font-bold text-peach mb-1">{formatDuration(longestSession.activeTimeSeconds)}</div>
            <div class="text-xs text-text-muted font-mono mb-3">{truncateId(longestSession.sessionId)}</div>
            <div class="grid grid-cols-2 gap-4 text-xs border-t border-peach/20 pt-3">
              <div>
                <div class="text-text-muted">Tokens</div>
                <div class="text-text-primary">{formatTokens(longestSession.totalTokens)}</div>
              </div>
              <div class="border-l border-peach/20 pl-4">
                <div class="text-text-muted">Duration</div>
                <div class="text-text-primary">{formatDuration(longestSession.activeTimeSeconds)}</div>
              </div>
            </div>
          {:else}
            <div class="text-2xl font-bold text-text-muted">—</div>
          {/if}
        </div>
      </div>
    </div>

    <!-- Cost by Project -->
    {#if sortedProjects.length > 0}
      <div class="mb-4">
        <div class="flex items-center justify-between mb-2">
          <div class="text-xs font-medium text-text-muted uppercase tracking-wider">Cost by Project</div>
          <span class="text-xs text-text-muted">{sortedProjects.length} projects</span>
        </div>
        <div class="bg-bg-card rounded-lg overflow-hidden border border-border-primary">
          <table class="w-full border-collapse">
            <thead>
              <tr class="border-b border-border-primary bg-bg-secondary/50">
                <th class="text-left px-4 py-2.5 border-r border-border-secondary">
                  <span class="text-xs uppercase tracking-wider text-text-muted">Project</span>
                </th>
                <th class="text-right px-4 py-2.5 border-r border-border-secondary">
                  <span class="text-xs uppercase tracking-wider text-text-muted">Cost</span>
                </th>
                <th class="text-right px-4 py-2.5 border-r border-border-secondary">
                  <span class="text-xs uppercase tracking-wider text-text-muted">Tokens</span>
                </th>
                <th class="text-right px-4 py-2.5 border-r border-border-secondary">
                  <span class="text-xs uppercase tracking-wider text-text-muted">Sessions</span>
                </th>
                <th class="text-right px-4 py-2.5">
                  <span class="text-xs uppercase tracking-wider text-text-muted">Time</span>
                </th>
              </tr>
            </thead>
            <tbody>
              {#each sortedProjects as project, i}
                <tr class="border-b border-border-primary hover:bg-bg-card-hover transition-colors {i === sortedProjects.length - 1 ? 'border-b-0' : ''}">
                  <td class="px-4 py-2.5 border-r border-border-secondary">
                    <div class="flex items-center gap-2">
                      <svg class="w-4 h-4 text-yellow flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                        <path d="M2 6a2 2 0 012-2h5l2 2h5a2 2 0 012 2v6a2 2 0 01-2 2H4a2 2 0 01-2-2V6z" />
                      </svg>
                      <span class="text-text-primary font-bold text-sm truncate" title={project.projectPath || ''}>
                        {project.project}
                      </span>
                    </div>
                  </td>
                  <td class="px-4 py-2.5 text-right text-accent-green font-medium text-sm border-r border-border-secondary">
                    {formatCost(project.totalCostUsd)}
                  </td>
                  <td class="px-4 py-2.5 text-right text-sky text-sm border-r border-border-secondary">
                    {formatTokens(project.totalTokens)}
                  </td>
                  <td class="px-4 py-2.5 text-right text-text-primary text-sm border-r border-border-secondary">
                    {project.sessionCount}
                  </td>
                  <td class="px-4 py-2.5 text-right text-peach text-sm">
                    {formatDuration(project.activeTimeSeconds)}
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
      </div>
    {/if}

    <!-- All Sessions Table -->
    <div>
      <div class="flex items-center justify-between mb-2">
        <div class="text-xs font-medium text-text-muted uppercase tracking-wider">All Sessions</div>
        <div class="flex items-center gap-2">
          <span class="text-xs text-text-muted">{sortedSessions.length} sessions</span>
          <select
            bind:value={sortOption}
            class="bg-bg-card text-text-primary border border-border-secondary rounded-md px-2 py-1 text-xs focus:outline-none focus:ring-1 focus:ring-accent"
          >
            <option value="cost_high">Cost (High to Low)</option>
            <option value="cost_low">Cost (Low to High)</option>
            <option value="tokens_high">Tokens (High to Low)</option>
            <option value="duration_high">Duration (Longest)</option>
          </select>
        </div>
      </div>
      <div class="bg-bg-card rounded-lg overflow-hidden border border-border-primary">
        <table class="w-full border-collapse">
          <thead>
            <tr class="border-b border-border-primary bg-bg-secondary/50">
              <th class="text-left px-4 py-2.5 border-r border-border-secondary">
                <span class="text-xs uppercase tracking-wider text-text-muted">Session ID</span>
              </th>
              <th class="text-left px-4 py-2.5 border-r border-border-secondary">
                <span class="text-xs uppercase tracking-wider text-text-muted">Project</span>
              </th>
              <th class="text-right px-4 py-2.5 border-r border-border-secondary">
                <span class="text-xs uppercase tracking-wider text-text-muted">Cost</span>
              </th>
              <th class="text-right px-4 py-2.5 border-r border-border-secondary">
                <span class="text-xs uppercase tracking-wider text-text-muted">Tokens</span>
              </th>
              <th class="text-right px-4 py-2.5 border-r border-border-secondary">
                <span class="text-xs uppercase tracking-wider text-text-muted">Duration</span>
              </th>
              <th class="text-right px-4 py-2.5 border-r border-border-secondary">
                <span class="text-xs uppercase tracking-wider text-text-muted">Cost/Min</span>
              </th>
              <th class="w-8"></th>
            </tr>
          </thead>
          <tbody>
            {#each sortedSessions as session, i}
              <tr
                class="border-b border-border-primary hover:bg-bg-card-hover cursor-pointer transition-colors {i === sortedSessions.length - 1 ? 'border-b-0' : ''}"
                on:click={() => handleSelectSession(session)}
              >
                <td class="px-4 py-2.5 border-r border-border-secondary">
                  <span class="text-text-muted font-mono text-sm" title={session.sessionId}>
                    {truncateId(session.sessionId)}
                  </span>
                </td>
                <td class="px-4 py-2.5 border-r border-border-secondary">
                  <span class="text-text-primary font-bold text-sm truncate max-w-[160px] block" title={session.projectPath || ''}>
                    {session.project || '—'}
                  </span>
                </td>
                <td class="px-4 py-2.5 text-right text-accent-green font-medium text-sm border-r border-border-secondary">
                  {formatCost(session.totalCostUsd)}
                </td>
                <td class="px-4 py-2.5 text-right text-sky text-sm border-r border-border-secondary">
                  {formatTokens(session.totalTokens)}
                </td>
                <td class="px-4 py-2.5 text-right text-peach text-sm border-r border-border-secondary">
                  {formatDuration(session.activeTimeSeconds)}
                </td>
                <td class="px-4 py-2.5 text-right text-text-muted text-sm border-r border-border-secondary">
                  {formatCostPerMin(session.totalCostUsd, session.activeTimeSeconds)}
                </td>
                <td class="px-2 py-2.5 text-right">
                  <svg class="w-4 h-4 text-text-muted" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
                  </svg>
                </td>
              </tr>
            {/each}
            {#if sortedSessions.length === 0}
              <tr>
                <td colspan="7" class="p-4 text-center text-text-muted text-sm">
                  No sessions found for this time range
                </td>
              </tr>
            {/if}
          </tbody>
        </table>
      </div>
    </div>
  {/if}
</div>

<SessionDetailModal session={selectedSession} onClose={handleCloseModal} />
