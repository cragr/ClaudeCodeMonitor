<script lang="ts">
  export let connected: boolean;
</script>

<div class="flex items-center gap-2">
  <div
    class="w-2 h-2 rounded-full {connected ? 'bg-green-500' : 'bg-red-500'}"
  ></div>
  <span class="text-sm text-gray-400">
    {connected ? 'Connected' : 'Disconnected'}
  </span>
</div>
