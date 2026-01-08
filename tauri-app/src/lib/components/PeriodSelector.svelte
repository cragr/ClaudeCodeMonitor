<script lang="ts">
  import type { PeriodType } from '$lib/types';
  import { PERIOD_OPTIONS } from '$lib/types';

  export let value: PeriodType;
  export let onChange: (value: PeriodType) => void;
</script>

<div class="flex bg-surface-light rounded-lg p-1 gap-1">
  {#each PERIOD_OPTIONS as option}
    <button
      class="px-3 py-1.5 text-sm rounded-md transition-colors {value === option.value
        ? 'bg-accent text-white'
        : 'text-gray-400 hover:text-white hover:bg-surface'}"
      on:click={() => onChange(option.value)}
    >
      {option.label}
    </button>
  {/each}
</div>
