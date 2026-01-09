<script lang="ts">
  export let category: string;
  export let title: string;
  export let subtitle: string = '';

  function getCategoryColor(cat: string): string {
    const colors: Record<string, string> = {
      summary: 'bg-green',
      tokens: 'bg-sky',
      insights: 'bg-yellow',
      sessions: 'bg-peach',
      'stats-cache': 'bg-sky',
      diagnostics: 'bg-yellow',
    };
    return colors[cat] || 'bg-sky';
  }
</script>

<div class="flex items-center justify-between mb-4">
  <div class="flex items-center gap-3">
    <div class="w-2 h-2 rounded-full {getCategoryColor(category)}"></div>
    <div>
      <h1 class="text-lg font-semibold text-text-primary leading-tight">{title}</h1>
      {#if subtitle}
        <p class="text-xs text-text-muted">{subtitle}</p>
      {/if}
    </div>
  </div>
  <slot name="actions" />
</div>
