<script lang="ts">
  export let label: string;
  export let value: string;
  export let subtitle: string = '';
  export let color: 'green' | 'cyan' | 'purple' | 'orange' | 'yellow' | 'red' | 'blue' = 'cyan';
  export let showBar: boolean = false;
  export let barPercent: number = 0;

  const colorClasses: Record<string, { dot: string; bar: string }> = {
    green: { dot: 'bg-accent-green', bar: 'bg-accent-green' },
    cyan: { dot: 'bg-accent-cyan', bar: 'bg-accent-cyan' },
    purple: { dot: 'bg-accent-purple', bar: 'bg-accent-purple' },
    orange: { dot: 'bg-accent-orange', bar: 'bg-accent-orange' },
    yellow: { dot: 'bg-accent-yellow', bar: 'bg-accent-yellow' },
    red: { dot: 'bg-accent-red', bar: 'bg-accent-red' },
    blue: { dot: 'bg-accent-blue', bar: 'bg-accent-blue' },
  };
</script>

<div class="bg-bg-card rounded-lg p-4 hover:bg-bg-card-hover transition-colors">
  <div class="flex items-center gap-2 mb-2">
    <div class="w-1.5 h-1.5 rounded-full {colorClasses[color].dot}"></div>
    <span class="text-xs font-medium text-text-secondary uppercase tracking-wider">{label}</span>
  </div>
  <div class="text-2xl font-bold text-text-primary mb-1">{value}</div>
  {#if subtitle}
    <div class="text-xs text-text-muted">{subtitle}</div>
  {/if}
  {#if showBar}
    <div class="mt-2 h-1 bg-bg-tertiary rounded-full overflow-hidden">
      <div class="h-full {colorClasses[color].bar} transition-all" style="width: {barPercent}%"></div>
    </div>
  {/if}
</div>
