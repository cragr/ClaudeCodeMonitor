<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { Chart, registerables } from 'chart.js';
  import type { TimeSeriesPoint } from '$lib/types';

  export let data: TimeSeriesPoint[];

  let canvas: HTMLCanvasElement;
  let chart: Chart | null = null;

  Chart.register(...registerables);

  function formatTime(timestamp: number): string {
    return new Date(timestamp * 1000).toLocaleTimeString([], {
      hour: '2-digit',
      minute: '2-digit',
    });
  }

  $: if (chart && data) {
    chart.data.labels = data.map((p) => formatTime(p.timestamp));
    chart.data.datasets[0].data = data.map((p) => p.value);
    chart.update();
  }

  onMount(() => {
    chart = new Chart(canvas, {
      type: 'line',
      data: {
        labels: data.map((p) => formatTime(p.timestamp)),
        datasets: [
          {
            label: 'Tokens',
            data: data.map((p) => p.value),
            borderColor: '#6366f1',
            backgroundColor: 'rgba(99, 102, 241, 0.1)',
            fill: true,
            tension: 0.3,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
        },
        scales: {
          x: {
            grid: { color: 'rgba(255,255,255,0.1)' },
            ticks: { color: '#9ca3af' },
          },
          y: {
            grid: { color: 'rgba(255,255,255,0.1)' },
            ticks: { color: '#9ca3af' },
          },
        },
      },
    });
  });

  onDestroy(() => {
    chart?.destroy();
  });
</script>

<div class="bg-surface-light rounded-lg p-4">
  <h3 class="text-gray-400 text-sm font-medium mb-4">Tokens Over Time</h3>
  <div class="h-48">
    <canvas bind:this={canvas}></canvas>
  </div>
</div>
