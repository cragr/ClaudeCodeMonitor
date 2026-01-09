<script lang="ts">
  import type { SessionMetrics } from '$lib/types';

  export let sessions: SessionMetrics[];
  export let onSelectSession: (session: SessionMetrics) => void;

  type SortField = 'project' | 'cost' | 'tokens' | 'time';
  type SortDirection = 'asc' | 'desc';

  let sortField: SortField = 'cost';
  let sortDirection: SortDirection = 'desc';

  function handleSort(field: SortField) {
    if (sortField === field) {
      sortDirection = sortDirection === 'asc' ? 'desc' : 'asc';
    } else {
      sortField = field;
      sortDirection = 'desc';
    }
  }

  function truncateId(id: string): string {
    return id.length > 12 ? `${id.slice(0, 6)}...${id.slice(-4)}` : id;
  }

  function formatCost(n: number): string {
    if (n >= 1) return `$${n.toFixed(2)}`;
    if (n >= 0.01) return `$${n.toFixed(3)}`;
    if (n > 0) return `$${n.toFixed(4)}`;
    return '—';
  }

  function formatTokens(n: number): string {
    if (n === 0) return '—';
    if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
    if (n >= 1_000) return `${(n / 1_000).toFixed(1)}K`;
    return n.toLocaleString();
  }

  function formatTime(timestamp: number): string {
    const date = new Date(timestamp);
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMins / 60);
    const diffDays = Math.floor(diffHours / 24);

    if (diffMins < 1) return 'just now';
    if (diffMins < 60) return `${diffMins}m ago`;
    if (diffHours < 24) return `${diffHours}h ago`;
    if (diffDays < 7) return `${diffDays}d ago`;
    return date.toLocaleDateString([], { month: 'short', day: 'numeric' });
  }

  $: sortedSessions = [...sessions].sort((a, b) => {
    let comparison = 0;
    switch (sortField) {
      case 'project':
        comparison = (a.project || '').localeCompare(b.project || '');
        break;
      case 'cost':
        comparison = a.totalCostUsd - b.totalCostUsd;
        break;
      case 'tokens':
        comparison = a.totalTokens - b.totalTokens;
        break;
      case 'time':
        comparison = a.timestamp - b.timestamp;
        break;
    }
    return sortDirection === 'asc' ? comparison : -comparison;
  });

  function getSortIcon(field: SortField): string {
    if (sortField !== field) return '↕';
    return sortDirection === 'asc' ? '↑' : '↓';
  }
</script>

<div class="bg-bg-card rounded-md overflow-hidden">
  <table class="w-full">
    <thead>
      <tr class="border-b border-border-secondary">
        <th class="text-left px-3 py-2">
          <button
            class="text-xs uppercase tracking-wider text-text-muted hover:text-text-primary flex items-center gap-1"
            on:click={() => handleSort('project')}
          >
            Project {getSortIcon('project')}
          </button>
        </th>
        <th class="text-left px-3 py-2">
          <span class="text-xs uppercase tracking-wider text-text-muted">Session</span>
        </th>
        <th class="text-right px-3 py-2">
          <button
            class="text-xs uppercase tracking-wider text-text-muted hover:text-text-primary flex items-center gap-1 ml-auto"
            on:click={() => handleSort('cost')}
          >
            Cost {getSortIcon('cost')}
          </button>
        </th>
        <th class="text-right px-3 py-2">
          <button
            class="text-xs uppercase tracking-wider text-text-muted hover:text-text-primary flex items-center gap-1 ml-auto"
            on:click={() => handleSort('tokens')}
          >
            Tokens {getSortIcon('tokens')}
          </button>
        </th>
        <th class="text-right px-3 py-2">
          <button
            class="text-xs uppercase tracking-wider text-text-muted hover:text-text-primary flex items-center gap-1 ml-auto"
            on:click={() => handleSort('time')}
          >
            Time {getSortIcon('time')}
          </button>
        </th>
      </tr>
    </thead>
    <tbody>
      {#each sortedSessions as session}
        <tr
          class="border-b border-border-secondary/50 hover:bg-bg-card-hover cursor-pointer transition-colors"
          on:click={() => onSelectSession(session)}
        >
          <td class="px-3 py-2">
            <span class="text-sky text-xs truncate max-w-[180px] block" title={session.projectPath || ''}>
              {session.project || '—'}
            </span>
          </td>
          <td class="px-3 py-2">
            <span class="text-text-muted font-mono text-xs" title={session.sessionId}>
              {truncateId(session.sessionId)}
            </span>
          </td>
          <td class="px-3 py-2 text-right text-green font-medium text-xs">
            {formatCost(session.totalCostUsd)}
          </td>
          <td class="px-3 py-2 text-right text-text-primary text-xs">
            {formatTokens(session.totalTokens)}
          </td>
          <td class="px-3 py-2 text-right text-text-muted text-xs">
            {formatTime(session.timestamp)}
          </td>
        </tr>
      {/each}
      {#if sortedSessions.length === 0}
        <tr>
          <td colspan="5" class="p-4 text-center text-text-muted text-xs">
            No sessions found for this time range
          </td>
        </tr>
      {/if}
    </tbody>
  </table>
</div>
