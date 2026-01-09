<script lang="ts">
  export let label: string;
  export let value: string;
  export let subtitle: string = '';
  export let color: 'green' | 'cyan' | 'purple' | 'orange' | 'yellow' | 'red' | 'blue' | 'teal' | 'pink' = 'cyan';
  export let showBar: boolean = false;
  export let barPercent: number = 0;
  export let highlight: boolean = false;

  const colorClasses: Record<string, { dot: string; bar: string; glow: string; border: string }> = {
    green: { dot: 'bg-green', bar: 'bg-green', glow: 'rgba(0, 255, 136, 0.15)', border: 'rgba(0, 255, 136, 0.4)' },
    cyan: { dot: 'bg-sky', bar: 'bg-sky', glow: 'rgba(0, 217, 255, 0.15)', border: 'rgba(0, 217, 255, 0.4)' },
    purple: { dot: 'bg-mauve', bar: 'bg-mauve', glow: 'rgba(168, 85, 247, 0.15)', border: 'rgba(168, 85, 247, 0.4)' },
    orange: { dot: 'bg-peach', bar: 'bg-peach', glow: 'rgba(255, 179, 71, 0.15)', border: 'rgba(255, 179, 71, 0.4)' },
    yellow: { dot: 'bg-yellow', bar: 'bg-yellow', glow: 'rgba(255, 217, 61, 0.15)', border: 'rgba(255, 217, 61, 0.4)' },
    red: { dot: 'bg-red', bar: 'bg-red', glow: 'rgba(255, 107, 107, 0.15)', border: 'rgba(255, 107, 107, 0.4)' },
    blue: { dot: 'bg-blue', bar: 'bg-blue', glow: 'rgba(0, 122, 255, 0.15)', border: 'rgba(0, 122, 255, 0.4)' },
    teal: { dot: 'bg-teal', bar: 'bg-teal', glow: 'rgba(0, 217, 255, 0.15)', border: 'rgba(0, 217, 255, 0.4)' },
    pink: { dot: 'bg-pink', bar: 'bg-pink', glow: 'rgba(255, 107, 157, 0.15)', border: 'rgba(255, 107, 157, 0.4)' },
  };

  $: highlightStyle = highlight
    ? `box-shadow: 0 0 20px ${colorClasses[color].glow}, inset 0 0 15px ${colorClasses[color].glow}; border: 1px solid ${colorClasses[color].border};`
    : '';
</script>

<div
  class="bg-bg-card rounded-md p-3 hover:bg-bg-card-hover transition-colors"
  style={highlightStyle}
>
  <div class="flex items-center gap-1.5 mb-1">
    <div class="w-1.5 h-1.5 rounded-full {colorClasses[color].dot}"></div>
    <span class="text-xs font-medium text-text-muted uppercase tracking-wider">{label}</span>
  </div>
  <div class="text-lg font-bold text-text-primary leading-tight">{value}</div>
  {#if subtitle}
    <div class="text-xs text-text-muted mt-0.5">{subtitle}</div>
  {/if}
  {#if showBar}
    <div class="mt-2 h-1 bg-surface-0 rounded-full overflow-hidden">
      <div class="h-full {colorClasses[color].bar} transition-all" style="width: {barPercent}%"></div>
    </div>
  {/if}
</div>
