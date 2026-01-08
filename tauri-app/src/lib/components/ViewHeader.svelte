<script lang="ts">
  export let category: string;
  export let title: string;
  export let subtitle: string = '';

  function getCategoryColor(cat: string): string {
    const colors: Record<string, string> = {
      summary: 'bg-accent-green',
      tokens: 'bg-accent-cyan',
      insights: 'bg-accent-yellow',
      sessions: 'bg-accent-orange',
      'stats-cache': 'bg-accent-cyan',
      diagnostics: 'bg-accent-yellow',
    };
    return colors[cat] || 'bg-accent-cyan';
  }
</script>

<div class="bg-bg-card rounded-lg p-6 mb-6">
  <div class="flex items-start justify-between">
    <div>
      <div class="flex items-center gap-2 mb-2">
        <div class="w-2 h-2 rounded-full {getCategoryColor(category)}"></div>
        <span class="text-xs font-medium text-text-secondary uppercase tracking-wider">{category}</span>
      </div>
      <h1 class="text-2xl font-bold text-text-primary">{title}</h1>
      {#if subtitle}
        <p class="text-sm text-text-secondary mt-1">{subtitle}</p>
      {/if}
    </div>
    <slot name="actions" />
  </div>
</div>
