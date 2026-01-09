<script lang="ts">
  import type { MetricComparison } from '$lib/types';

  export let label: string;
  export let data: MetricComparison;
  export let format: 'number' | 'compact' | 'currency' = 'number';

  function formatValue(n: number): string {
    if (format === 'currency') {
      return n >= 1 ? `$${n.toFixed(2)}` : `$${n.toFixed(3)}`;
    }
    if (format === 'compact') {
      if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
      if (n >= 1_000) return `${(n / 1_000).toFixed(1)}K`;
    }
    return Math.round(n).toLocaleString();
  }

  $: isPositive = data.percentChange !== null && data.percentChange > 0;
  $: isNegative = data.percentChange !== null && data.percentChange < 0;
</script>

<div class="bg-bg-card rounded-md p-3 hover:bg-bg-card-hover transition-colors">
  <div class="text-text-muted text-xs uppercase tracking-wider mb-1">{label}</div>
  <div class="text-lg font-bold text-text-primary mb-0.5">{formatValue(data.current)}</div>
  <div class="flex items-center gap-1 text-xs">
    {#if data.percentChange !== null}
      <span class={isPositive ? 'text-green' : isNegative ? 'text-red' : 'text-text-muted'}>
        {isPositive ? '↑' : isNegative ? '↓' : ''}
        {Math.abs(data.percentChange).toFixed(0)}%
      </span>
      <span class="text-text-muted">vs prev</span>
    {:else}
      <span class="text-text-muted">—</span>
    {/if}
  </div>
</div>
