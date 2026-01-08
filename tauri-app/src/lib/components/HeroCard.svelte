<script lang="ts">
  export let label: string;
  export let value: string;
  export let subtitle: string = '';
  export let color: 'green' | 'cyan' | 'purple' | 'orange' | 'yellow' = 'green';

  const colorClasses: Record<string, { dot: string; text: string }> = {
    green: { dot: 'bg-accent-green', text: 'text-accent-green' },
    cyan: { dot: 'bg-accent-cyan', text: 'text-accent-cyan' },
    purple: { dot: 'bg-accent-purple', text: 'text-accent-purple' },
    orange: { dot: 'bg-accent-orange', text: 'text-accent-orange' },
    yellow: { dot: 'bg-accent-yellow', text: 'text-accent-yellow' },
  };
</script>

<div class="bg-bg-card rounded-lg p-6">
  <div class="flex items-center gap-2 mb-2">
    <div class="w-2 h-2 rounded-full {colorClasses[color].dot}"></div>
    <span class="text-xs font-medium text-text-secondary uppercase tracking-wider">{label}</span>
  </div>
  <div class="text-4xl font-bold {colorClasses[color].text} mb-1">{value}</div>
  {#if subtitle}
    <div class="text-sm text-text-muted">{subtitle}</div>
  {/if}
</div>
