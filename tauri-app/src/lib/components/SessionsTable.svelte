<script lang="ts">
  import type { SessionMetrics, SessionSortField, SortDirection } from '$lib/types';

  export let sessions: SessionMetrics[];
  export let onSelectSession: (session: SessionMetrics) => void;

  let sortField: SessionSortField = 'cost';
  let sortDirection: SortDirection = 'desc';

  function handleSort(field: SessionSortField) {
    if (sortField === field) {
      sortDirection = sortDirection === 'asc' ? 'desc' : 'asc';
    } else {
      sortField = field;
      sortDirection = 'desc';
    }
  }

  function formatCost(n: number): string {
    if (n >= 1) return `$${n.toFixed(2)}`;
    if (n >= 0.01) return `$${n.toFixed(3)}`;
    return `$${n.toFixed(4)}`;
  }

  function formatTokens(n: number): string {
    if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
    if (n >= 1_000) return `${(n / 1_000).toFixed(1)}K`;
    return n.toString();
  }

  function formatDuration(seconds: number): string {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    if (hours > 0) return `${hours}h ${minutes}m`;
    if (minutes > 0) return `${minutes}m`;
    return `${Math.floor(seconds)}s`;
  }

  function truncateId(id: string): string {
    return id.length > 12 ? `${id.slice(0, 6)}...${id.slice(-4)}` : id;
  }

  $: sortedSessions = [...sessions].sort((a, b) => {
    let comparison = 0;
    switch (sortField) {
      case 'cost':
        comparison = a.totalCostUsd - b.totalCostUsd;
        break;
      case 'tokens':
        comparison = a.totalTokens - b.totalTokens;
        break;
      case 'duration':
        comparison = a.activeTimeSeconds - b.activeTimeSeconds;
        break;
      case 'sessionId':
        comparison = a.sessionId.localeCompare(b.sessionId);
        break;
    }
    return sortDirection === 'asc' ? comparison : -comparison;
  });

  function getSortIcon(field: SessionSortField): string {
    if (sortField !== field) return '↕';
    return sortDirection === 'asc' ? '↑' : '↓';
  }
</script>

<div class="bg-surface-light rounded-lg overflow-hidden">
  <table class="w-full">
    <thead>
      <tr class="border-b border-gray-700">
        <th class="text-left p-3">
          <button
            class="text-xs uppercase tracking-wide text-gray-400 hover:text-white flex items-center gap-1"
            on:click={() => handleSort('sessionId')}
          >
            Session {getSortIcon('sessionId')}
          </button>
        </th>
        <th class="text-right p-3">
          <button
            class="text-xs uppercase tracking-wide text-gray-400 hover:text-white flex items-center gap-1 ml-auto"
            on:click={() => handleSort('cost')}
          >
            Cost {getSortIcon('cost')}
          </button>
        </th>
        <th class="text-right p-3">
          <button
            class="text-xs uppercase tracking-wide text-gray-400 hover:text-white flex items-center gap-1 ml-auto"
            on:click={() => handleSort('tokens')}
          >
            Tokens {getSortIcon('tokens')}
          </button>
        </th>
        <th class="text-right p-3">
          <button
            class="text-xs uppercase tracking-wide text-gray-400 hover:text-white flex items-center gap-1 ml-auto"
            on:click={() => handleSort('duration')}
          >
            Duration {getSortIcon('duration')}
          </button>
        </th>
      </tr>
    </thead>
    <tbody>
      {#each sortedSessions as session}
        <tr
          class="border-b border-gray-700/50 hover:bg-surface cursor-pointer transition-colors"
          on:click={() => onSelectSession(session)}
        >
          <td class="p-3">
            <span class="text-gray-300 font-mono text-sm" title={session.sessionId}>
              {truncateId(session.sessionId)}
            </span>
          </td>
          <td class="p-3 text-right text-white font-medium">
            {formatCost(session.totalCostUsd)}
          </td>
          <td class="p-3 text-right text-gray-300">
            {formatTokens(session.totalTokens)}
          </td>
          <td class="p-3 text-right text-gray-400">
            {formatDuration(session.activeTimeSeconds)}
          </td>
        </tr>
      {/each}
      {#if sortedSessions.length === 0}
        <tr>
          <td colspan="4" class="p-8 text-center text-gray-500">
            No sessions found for this time range
          </td>
        </tr>
      {/if}
    </tbody>
  </table>
</div>
