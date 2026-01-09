<script lang="ts">
  import { onMount, onDestroy, tick } from 'svelte';
  import { Chart, registerables } from 'chart.js';
  import type { DailyActivityPoint } from '$lib/types';

  export let title: string;
  export let data: DailyActivityPoint[];
  export let color: string = '#00d9ff'; // Cyan default

  let canvas: HTMLCanvasElement;
  let chart: Chart | null = null;
  let mounted = false;

  Chart.register(...registerables);

  $: average = data.length > 0
    ? (data.reduce((sum, d) => sum + d.value, 0) / data.length).toFixed(1)
    : '0';

  // React to data changes - create or update chart
  $: if (mounted && canvas && data.length > 0) {
    if (chart) {
      chart.data.labels = data.map((d) => d.date.slice(5));
      chart.data.datasets[0].data = data.map((d) => d.value);
      chart.update();
    } else {
      createChart();
    }
  }

  function createChart() {
    if (!canvas || data.length === 0) return;

    chart = new Chart(canvas, {
      type: 'line',
      data: {
        labels: data.map((d) => d.date.slice(5)),
        datasets: [
          {
            data: data.map((d) => d.value),
            borderColor: color,
            backgroundColor: `${color}20`,
            fill: true,
            tension: 0.4,
            pointRadius: 0,
            borderWidth: 2,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: { enabled: false },
        },
        scales: {
          x: { display: false },
          y: { display: false },
        },
      },
    });
  }

  onMount(async () => {
    await tick();
    mounted = true;
  });

  onDestroy(() => {
    chart?.destroy();
  });
</script>

<div class="bg-bg-card rounded-md p-3">
  <div class="flex items-center justify-between mb-1">
    <div class="text-text-muted text-xs uppercase tracking-wider">{title}</div>
    <div class="text-text-muted text-xs">Avg: {average}/day</div>
  </div>
  <div class="h-12">
    {#if data.length > 0}
      <canvas bind:this={canvas}></canvas>
    {:else}
      <div class="h-full bg-surface-0 rounded flex items-center justify-center text-text-muted text-xs">
        No data
      </div>
    {/if}
  </div>
</div>
