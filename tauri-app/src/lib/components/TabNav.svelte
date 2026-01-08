<script lang="ts">
  export let activeTab: 'dashboard' | 'insights' | 'sessions';
  export let onTabChange: (tab: 'dashboard' | 'insights' | 'sessions') => void;

  const tabs = [
    { id: 'dashboard' as const, label: 'Dashboard' },
    { id: 'insights' as const, label: 'Insights' },
    { id: 'sessions' as const, label: 'Sessions' },
  ];
</script>

<nav class="flex border-b border-gray-700 mb-6">
  {#each tabs as tab}
    <button
      class="px-4 py-2 text-sm font-medium transition-colors relative {activeTab === tab.id
        ? 'text-white'
        : 'text-gray-400 hover:text-gray-200'}"
      on:click={() => onTabChange(tab.id)}
    >
      {tab.label}
      {#if activeTab === tab.id}
        <div class="absolute bottom-0 left-0 right-0 h-0.5 bg-accent"></div>
      {/if}
    </button>
  {/each}
</nav>
