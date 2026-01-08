<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { Chart, registerables } from 'chart.js';
  import type { SessionMetrics } from '$lib/types';

  export let session: SessionMetrics | null;
  export let onClose: () => void;

  let modelChartCanvas: HTMLCanvasElement;
  let typeChartCanvas: HTMLCanvasElement;
  let modelChart: Chart | null = null;
  let typeChart: Chart | null = null;

  Chart.register(...registerables);

  function formatCost(n: number): string {
    if (n >= 1) return `$${n.toFixed(2)}`;
    if (n >= 0.01) return `$${n.toFixed(3)}`;
    return `$${n.toFixed(4)}`;
  }

  function formatTokens(n: number): string {
    if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(2)}M`;
    if (n >= 1_000) return `${(n / 1_000).toFixed(1)}K`;
    return n.toLocaleString();
  }

  function formatDuration(seconds: number): string {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = Math.floor(seconds % 60);
    if (hours > 0) return `${hours}h ${minutes}m`;
    if (minutes > 0) return `${minutes}m ${secs}s`;
    return `${secs}s`;
  }

  const typeColors: Record<string, string> = {
    input: '#5b9a8b',
    output: '#9b7bb8',
    cache_read: '#6b9b7a',
    cache_creation: '#c9a855',
  };

  const modelColors = ['#6b8fc4', '#b87b9b', '#5b9a8b', '#c4896b', '#9b7bb8'];

  function createCharts() {
    if (!session) return;

    // Type breakdown chart
    if (typeChartCanvas) {
      const typeData = [
        { label: 'Input', value: session.inputTokens, color: typeColors.input },
        { label: 'Output', value: session.outputTokens, color: typeColors.output },
        { label: 'Cache Read', value: session.cacheReadTokens, color: typeColors.cache_read },
        { label: 'Cache Creation', value: session.cacheCreationTokens, color: typeColors.cache_creation },
      ].filter(d => d.value > 0);

      typeChart = new Chart(typeChartCanvas, {
        type: 'doughnut',
        data: {
          labels: typeData.map(d => d.label),
          datasets: [{
            data: typeData.map(d => d.value),
            backgroundColor: typeData.map(d => d.color),
            borderWidth: 0,
          }],
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: {
              position: 'bottom',
              labels: { color: '#9ca3af', font: { size: 11 } },
            },
          },
        },
      });
    }

    // Model breakdown chart
    if (modelChartCanvas && session.tokensByModel.length > 0) {
      modelChart = new Chart(modelChartCanvas, {
        type: 'doughnut',
        data: {
          labels: session.tokensByModel.map(m => m.model),
          datasets: [{
            data: session.tokensByModel.map(m => m.tokens),
            backgroundColor: modelColors.slice(0, session.tokensByModel.length),
            borderWidth: 0,
          }],
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: {
              position: 'bottom',
              labels: { color: '#9ca3af', font: { size: 11 } },
            },
          },
        },
      });
    }
  }

  function destroyCharts() {
    typeChart?.destroy();
    modelChart?.destroy();
    typeChart = null;
    modelChart = null;
  }

  $: if (session) {
    destroyCharts();
    // Use setTimeout to ensure canvas is rendered
    setTimeout(createCharts, 0);
  }

  onDestroy(destroyCharts);

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') onClose();
  }

  function handleBackdropClick(e: MouseEvent) {
    if (e.target === e.currentTarget) onClose();
  }
</script>

<svelte:window on:keydown={handleKeydown} />

{#if session}
  <div
    class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4"
    on:click={handleBackdropClick}
    on:keydown={handleKeydown}
    role="dialog"
    aria-modal="true"
    tabindex="-1"
  >
    <div class="bg-surface rounded-lg max-w-2xl w-full max-h-[90vh] overflow-y-auto">
      <!-- Header -->
      <div class="flex items-center justify-between p-4 border-b border-gray-700">
        <div>
          <h2 class="text-lg font-semibold text-white">Session Details</h2>
          <p class="text-sm text-gray-400 font-mono">{session.sessionId}</p>
        </div>
        <button
          on:click={onClose}
          class="text-gray-400 hover:text-white transition-colors"
          aria-label="Close"
        >
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>

      <!-- Summary Stats -->
      <div class="grid grid-cols-3 gap-4 p-4 border-b border-gray-700">
        <div class="text-center">
          <div class="text-2xl font-bold text-white">{formatCost(session.totalCostUsd)}</div>
          <div class="text-xs text-gray-400 uppercase">Total Cost</div>
        </div>
        <div class="text-center">
          <div class="text-2xl font-bold text-white">{formatTokens(session.totalTokens)}</div>
          <div class="text-xs text-gray-400 uppercase">Total Tokens</div>
        </div>
        <div class="text-center">
          <div class="text-2xl font-bold text-white">{formatDuration(session.activeTimeSeconds)}</div>
          <div class="text-xs text-gray-400 uppercase">Duration</div>
        </div>
      </div>

      <!-- Charts -->
      <div class="grid grid-cols-2 gap-4 p-4">
        <div>
          <h3 class="text-sm font-medium text-gray-400 mb-2">Tokens by Type</h3>
          <div class="h-48">
            <canvas bind:this={typeChartCanvas}></canvas>
          </div>
        </div>
        <div>
          <h3 class="text-sm font-medium text-gray-400 mb-2">Tokens by Model</h3>
          <div class="h-48">
            {#if session.tokensByModel.length > 0}
              <canvas bind:this={modelChartCanvas}></canvas>
            {:else}
              <div class="h-full flex items-center justify-center text-gray-500 text-sm">
                No model data
              </div>
            {/if}
          </div>
        </div>
      </div>

      <!-- Token Details -->
      <div class="p-4 border-t border-gray-700">
        <h3 class="text-sm font-medium text-gray-400 mb-3">Token Breakdown</h3>
        <div class="grid grid-cols-2 gap-2 text-sm">
          <div class="flex justify-between">
            <span class="text-gray-400">Input</span>
            <span class="text-white">{formatTokens(session.inputTokens)}</span>
          </div>
          <div class="flex justify-between">
            <span class="text-gray-400">Output</span>
            <span class="text-white">{formatTokens(session.outputTokens)}</span>
          </div>
          <div class="flex justify-between">
            <span class="text-gray-400">Cache Read</span>
            <span class="text-white">{formatTokens(session.cacheReadTokens)}</span>
          </div>
          <div class="flex justify-between">
            <span class="text-gray-400">Cache Creation</span>
            <span class="text-white">{formatTokens(session.cacheCreationTokens)}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
{/if}
