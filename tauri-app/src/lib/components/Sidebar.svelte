<script lang="ts">
  import { isConnected } from '$lib/stores';
  import { settings } from '$lib/stores/settings';

  export let activeView: string;
  export let onNavigate: (view: string) => void;
  export let totalCost: number = 0;

  const dashboardItems = [
    { id: 'summary', label: 'Summary', icon: 'grid', description: 'Overview of key metrics and cost' },
    { id: 'tokens', label: 'Token Metrics', icon: 'activity', description: 'Token usage and model performance' },
    { id: 'insights', label: 'Insights', icon: 'lightbulb', description: 'Usage trends and comparisons' },
    { id: 'sessions', label: 'Sessions', icon: 'terminal', description: 'Session cost explorer and analysis' },
    { id: 'stats-cache', label: 'Local Stats Cache', icon: 'database', description: 'Local Claude Code usage statistics' },
  ];

  const developerItems = [
    { id: 'smoke-test', label: 'Smoke Test', icon: 'flask', description: 'Debug and test connectivity' },
  ];

  function formatCost(n: number): string {
    return `$${n.toFixed(2)}`;
  }

  function getIcon(name: string): string {
    const icons: Record<string, string> = {
      grid: 'M4 4h6v6H4V4zm10 0h6v6h-6V4zM4 14h6v6H4v-6zm10 0h6v6h-6v-6z',
      activity: 'M22 12h-4l-3 9L9 3l-3 9H2',
      lightbulb: 'M9 21h6m-3-3v3m0-18a6 6 0 016 6c0 2.22-1.21 4.16-3 5.2V17a1 1 0 01-1 1h-4a1 1 0 01-1-1v-2.8c-1.79-1.04-3-2.98-3-5.2a6 6 0 016-6z',
      terminal: 'M4 17l6-6-6-6m8 14h8',
      database: 'M12 2C6.48 2 2 4.24 2 7v10c0 2.76 4.48 5 10 5s10-2.24 10-5V7c0-2.76-4.48-5-10-5zm0 3c4.42 0 8 1.79 8 4s-3.58 4-8 4-8-1.79-8-4 3.58-4 8-4z',
      flask: 'M9 3h6v2H9V3zm1 2v5.17l-5 8.33V20h14v-1.5l-5-8.33V5h-4z',
    };
    return icons[name] || icons.grid;
  }
</script>

<aside class="w-60 h-screen bg-bg-primary border-r border-border-secondary flex flex-col">
  <!-- Logo Header -->
  <div class="p-4 flex items-center gap-3">
    <div class="w-8 h-8 rounded bg-accent-cyan flex items-center justify-center">
      <svg class="w-5 h-5 text-bg-primary" fill="currentColor" viewBox="0 0 24 24">
        <path d="M20 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 14H4V6h16v12z"/>
      </svg>
    </div>
    <div class="flex-1">
      <div class="text-xs text-text-secondary uppercase tracking-wider">Claude Code</div>
      <div class="text-sm font-semibold text-text-primary">Monitor</div>
    </div>
    <div class="px-2 py-0.5 bg-accent-green/20 text-accent-green text-xs font-medium rounded-full">
      {formatCost(totalCost)}
    </div>
  </div>

  <!-- Navigation -->
  <nav class="flex-1 overflow-y-auto px-2 py-2">
    <!-- Dashboard Section -->
    <div class="mb-4">
      <div class="px-3 py-2 text-xs font-medium text-text-muted uppercase tracking-wider">
        Dashboard
      </div>
      {#each dashboardItems as item}
        <button
          class="w-full text-left px-3 py-2 rounded-md mb-0.5 transition-colors flex items-center gap-3
            {activeView === item.id
              ? 'bg-bg-card text-text-primary'
              : 'text-text-secondary hover:text-text-primary hover:bg-bg-card-hover'}"
          on:click={() => onNavigate(item.id)}
        >
          <svg class="w-4 h-4 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d={getIcon(item.icon)} />
          </svg>
          <div class="flex-1 min-w-0">
            <div class="text-sm font-medium">{item.label}</div>
            {#if activeView === item.id}
              <div class="text-xs text-text-muted truncate">{item.description}</div>
            {/if}
          </div>
        </button>
      {/each}
    </div>

    <!-- Developer Section -->
    <div>
      <div class="px-3 py-2 text-xs font-medium text-text-muted uppercase tracking-wider">
        Developer
      </div>
      {#each developerItems as item}
        <button
          class="w-full text-left px-3 py-2 rounded-md mb-0.5 transition-colors flex items-center gap-3
            {activeView === item.id
              ? 'bg-bg-card text-text-primary'
              : 'text-text-secondary hover:text-text-primary hover:bg-bg-card-hover'}"
          on:click={() => onNavigate(item.id)}
        >
          <svg class="w-4 h-4 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d={getIcon(item.icon)} />
          </svg>
          <div class="flex-1 min-w-0">
            <div class="text-sm font-medium">{item.label}</div>
            {#if activeView === item.id}
              <div class="text-xs text-text-muted truncate">{item.description}</div>
            {/if}
          </div>
        </button>
      {/each}
    </div>
  </nav>

  <!-- Status Footer -->
  <div class="p-4 border-t border-border-secondary">
    <div class="flex items-center gap-2 mb-1">
      <div class="w-2 h-2 rounded-full {$isConnected ? 'bg-accent-green' : 'bg-accent-red'}"></div>
      <span class="text-xs font-medium {$isConnected ? 'text-accent-green' : 'text-accent-red'}">
        {$isConnected ? 'CONNECTED' : 'DISCONNECTED'}
      </span>
      <span class="text-xs text-text-muted">(V3.8.1)</span>
    </div>
    <div class="flex items-center gap-1 text-xs text-text-muted">
      <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <circle cx="12" cy="12" r="10" stroke-width="2"/>
        <path stroke-width="2" d="M12 6v6l4 2"/>
      </svg>
      <span>Updated 0 sec ago</span>
    </div>
  </div>
</aside>
