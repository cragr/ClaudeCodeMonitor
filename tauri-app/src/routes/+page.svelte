<script lang="ts">
  import { onMount } from 'svelte';
  import {
    Sidebar,
    SummaryView,
    TokenMetricsView,
    SessionsView,
    LocalStatsCacheView,
    SmokeTestView,
    PrometheusHealthView,
    SettingsModal,
  } from '$lib/components';
  import { isConnected } from '$lib/stores';
  import { loadSettings } from '$lib/stores/settings';

  let activeView = 'summary';
  let showSettings = false;

  function handleNavigate(view: string) {
    activeView = view;
  }

  // Listen for keyboard shortcut to open settings
  function handleKeydown(e: KeyboardEvent) {
    if ((e.metaKey || e.ctrlKey) && e.key === ',') {
      e.preventDefault();
      showSettings = !showSettings;
    }
  }

  onMount(() => {
    loadSettings();
    window.addEventListener('keydown', handleKeydown);
    return () => window.removeEventListener('keydown', handleKeydown);
  });
</script>

<div class="flex h-screen bg-bg-primary">
  <Sidebar {activeView} onNavigate={handleNavigate} onOpenSettings={() => (showSettings = true)} />

  <main class="flex-1 overflow-y-auto p-4">
    {#if activeView === 'summary'}
      <SummaryView />
    {:else if activeView === 'tokens'}
      <TokenMetricsView />
    {:else if activeView === 'sessions'}
      <SessionsView />
    {:else if activeView === 'stats-cache'}
      <LocalStatsCacheView />
    {:else if activeView === 'prometheus-health'}
      <PrometheusHealthView />
    {:else if activeView === 'smoke-test'}
      <SmokeTestView />
    {/if}
  </main>
</div>

<SettingsModal open={showSettings} onClose={() => (showSettings = false)} />
