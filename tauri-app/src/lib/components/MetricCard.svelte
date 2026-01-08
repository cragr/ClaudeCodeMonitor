<script lang="ts">
  export let label: string;
  export let value: string;
  export let subValue: string = '';
</script>

<div class="bg-surface-light rounded-lg p-4 hover:bg-surface-lighter transition-colors">
  <div class="text-gray-400 text-sm font-medium uppercase tracking-wide">
    {label}
  </div>
  <div class="text-2xl font-bold text-white mt-1">
    {value}
  </div>
  {#if subValue}
    <div class="text-gray-500 text-sm mt-1">
      {subValue}
    </div>
  {/if}
</div>
