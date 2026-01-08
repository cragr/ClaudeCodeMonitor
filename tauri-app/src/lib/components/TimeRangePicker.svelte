<script lang="ts">
  import { TIME_RANGE_OPTIONS, type TimeRange } from '$lib/types';

  export let value: TimeRange;
  export let onChange: (value: TimeRange) => void;
</script>

<select
  bind:value
  on:change={() => onChange(value)}
  class="bg-surface-light text-white border border-gray-600 rounded-md px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-accent"
>
  {#each TIME_RANGE_OPTIONS as option}
    <option value={option.value}>{option.label}</option>
  {/each}
</select>
