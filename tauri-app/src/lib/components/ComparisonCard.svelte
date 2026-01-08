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

<div class="bg-surface-light rounded-lg p-4 hover:bg-surface-lighter transition-colors">
  <div class="text-gray-400 text-xs uppercase tracking-wide mb-2">{label}</div>
  <div class="text-2xl font-bold text-white mb-2">{formatValue(data.current)}</div>
  <div class="flex items-center gap-1 text-sm">
    {#if data.percentChange !== null}
      <span class={isPositive ? 'text-green-400' : isNegative ? 'text-red-400' : 'text-gray-400'}>
        {isPositive ? '↑' : isNegative ? '↓' : ''}
        {Math.abs(data.percentChange).toFixed(0)}%
      </span>
      <span class="text-gray-500">vs prev</span>
    {:else}
      <span class="text-gray-500">—</span>
    {/if}
  </div>
</div>
