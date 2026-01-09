<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { Chart, registerables } from 'chart.js';
  import type { ModelTokens } from '$lib/types';

  export let data: ModelTokens[];

  let canvas: HTMLCanvasElement;
  let chart: Chart | null = null;

  Chart.register(...registerables);

  const colors = ['#a855f7', '#00d9ff', '#00ff88', '#ff8c42', '#ec4899'];

  $: if (chart && data) {
    chart.data.labels = data.map((m) => m.model);
    chart.data.datasets[0].data = data.map((m) => m.tokens);
    chart.update();
  }

  onMount(() => {
    chart = new Chart(canvas, {
      type: 'bar',
      data: {
        labels: data.map((m) => m.model),
        datasets: [
          {
            label: 'Tokens',
            data: data.map((m) => m.tokens),
            backgroundColor: colors.slice(0, data.length),
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        indexAxis: 'y',
        plugins: {
          legend: { display: false },
        },
        scales: {
          x: {
            grid: { color: '#232938' },
            ticks: { color: '#64748b' },
          },
          y: {
            grid: { display: false },
            ticks: { color: '#64748b' },
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
  <h3 class="text-gray-400 text-sm font-medium mb-4">Tokens by Model</h3>
  <div class="h-48">
    <canvas bind:this={canvas}></canvas>
  </div>
</div>
