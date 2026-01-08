<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { Chart, registerables } from 'chart.js';
  import type { DailyActivityPoint } from '$lib/types';

  export let title: string;
  export let data: DailyActivityPoint[];
  export let color: string = '#6366f1';

  let canvas: HTMLCanvasElement;
  let chart: Chart | null = null;

  Chart.register(...registerables);

  $: average = data.length > 0
    ? (data.reduce((sum, d) => sum + d.value, 0) / data.length).toFixed(1)
    : '0';

  $: if (chart && data) {
    chart.data.labels = data.map((d) => d.date.slice(5)); // MM-DD
    chart.data.datasets[0].data = data.map((d) => d.value);
    chart.update();
  }

  onMount(() => {
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
  });

  onDestroy(() => {
    chart?.destroy();
  });
</script>

<div class="bg-surface-light rounded-lg p-4">
  <div class="text-gray-400 text-xs uppercase tracking-wide">{title}</div>
  <div class="text-gray-500 text-xs mb-2">Avg: {average}/day</div>
  <div class="h-16">
    {#if data.length > 0}
      <canvas bind:this={canvas}></canvas>
    {:else}
      <div class="h-full bg-surface rounded flex items-center justify-center text-gray-600 text-xs">
        No data
      </div>
    {/if}
  </div>
</div>
