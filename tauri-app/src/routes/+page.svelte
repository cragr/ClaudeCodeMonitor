<script lang="ts">
  import { onMount } from 'svelte';
  import {
    Sidebar,
    SummaryView,
    TokenMetricsView,
    InsightsView,
    SessionsView,
    LocalStatsCacheView,
    SmokeTestView,
    SettingsModal,
  } from '$lib/components';
  import { isConnected } from '$lib/stores';

  let activeView = 'summary';
  let showSettings = false;
  let totalCost = 0;

  function handleNavigate(view: string) {
    activeView = view;
  }

  function handleCostUpdate(cost: number) {
    totalCost = cost;
  }

  // Listen for keyboard shortcut to open settings
  function handleKeydown(e: KeyboardEvent) {
    if ((e.metaKey || e.ctrlKey) && e.key === ',') {
      e.preventDefault();
      showSettings = !showSettings;
    }
  }

  onMount(() => {
    window.addEventListener('keydown', handleKeydown);
    return () => window.removeEventListener('keydown', handleKeydown);
  });
</script>

<div class="flex h-screen bg-bg-primary">
  <Sidebar {activeView} onNavigate={handleNavigate} {totalCost} />

  <main class="flex-1 overflow-y-auto p-6">
    {#if activeView === 'summary'}
      <SummaryView onCostUpdate={handleCostUpdate} />
    {:else if activeView === 'tokens'}
      <TokenMetricsView />
    {:else if activeView === 'insights'}
      <InsightsView />
    {:else if activeView === 'sessions'}
      <SessionsView />
    {:else if activeView === 'stats-cache'}
      <LocalStatsCacheView />
    {:else if activeView === 'smoke-test'}
      <SmokeTestView />
    {/if}
  </main>
</div>

<SettingsModal open={showSettings} onClose={() => (showSettings = false)} />
