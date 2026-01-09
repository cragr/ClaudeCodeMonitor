<script lang="ts">
  import type { PeriodType } from '$lib/types';
  import { PERIOD_OPTIONS } from '$lib/types';

  export let value: PeriodType;
  export let onChange: (value: PeriodType) => void;
</script>

<div class="flex bg-bg-card rounded-md p-0.5 gap-0.5">
  {#each PERIOD_OPTIONS as option}
    <button
      class="px-2 py-1 text-xs rounded transition-colors {value === option.value
        ? 'bg-blue/20 text-blue'
        : 'text-text-muted hover:text-text-primary hover:bg-bg-card-hover'}"
      on:click={() => onChange(option.value)}
    >
      {option.label}
    </button>
  {/each}
</div>
