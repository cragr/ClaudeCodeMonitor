<script lang="ts">
  import { onMount } from 'svelte';
  import { invoke } from '@tauri-apps/api/core';
  import {
    MetricCard,
    StatusIndicator,
    TimeRangePicker,
    TokensChart,
    ModelBreakdown,
  } from '$lib/components';
  import { metrics, isLoading, error, timeRange, isConnected } from '$lib/stores';
  import { settings } from '$lib/stores/settings';
  import type { DashboardMetrics, TimeRange } from '$lib/types';

  let showSettings = false;

  async function fetchMetrics() {
    $isLoading = true;
    $error = null;

    try {
      const result = await invoke<DashboardMetrics>('get_dashboard_metrics', {
        timeRange: $timeRange,
        prometheusUrl: $settings.prometheusUrl,
      });
      $metrics = result;
      $isConnected = true;
    } catch (e) {
      $error = e as string;
      $isConnected = false;
    } finally {
      $isLoading = false;
    }
  }

  function handleTimeRangeChange(value: TimeRange) {
    $timeRange = value;
    fetchMetrics();
  }

  function formatTokens(n: number): string {
    if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(2)}M`;
    if (n >= 1_000) return `${(n / 1_000).toFixed(1)}K`;
    return n.toString();
  }

  function formatCost(n: number): string {
    if (n >= 1) return `$${n.toFixed(2)}`;
    if (n >= 0.01) return `$${n.toFixed(3)}`;
    return `$${n.toFixed(4)}`;
  }

  function formatTime(seconds: number): string {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    if (hours > 0) return `${hours}h ${minutes}m`;
    return `${minutes}m`;
  }

  onMount(() => {
    fetchMetrics();
    const interval = setInterval(fetchMetrics, $settings.refreshInterval * 1000);
    return () => clearInterval(interval);
  });
</script>

<main class="min-h-screen bg-surface p-6">
  <!-- Header -->
  <div class="flex items-center justify-between mb-6">
    <h1 class="text-xl font-bold text-white">Claude Code Monitor</h1>
    <div class="flex items-center gap-4">
      <TimeRangePicker value={$timeRange} onChange={handleTimeRangeChange} />
      <button
        on:click={() => (showSettings = !showSettings)}
        class="text-gray-400 hover:text-white transition-colors"
        aria-label="Settings"
      >
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"></path>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path>
        </svg>
      </button>
      <StatusIndicator connected={$isConnected} />
    </div>
  </div>

  <!-- Error Banner -->
  {#if $error}
    <div class="bg-red-900/50 border border-red-500 rounded-lg p-4 mb-6">
      <p class="text-red-200">{$error}</p>
    </div>
  {/if}

  <!-- Loading State -->
  {#if $isLoading && !$metrics}
    <div class="flex items-center justify-center h-64">
      <div class="text-gray-400">Loading metrics...</div>
    </div>
  {:else if $metrics}
    <!-- Metric Cards Grid -->
    <div class="grid grid-cols-4 gap-4 mb-6">
      <MetricCard
        label="Tokens"
        value={formatTokens($metrics.totalTokens)}
      />
      <MetricCard
        label="Cost"
        value={formatCost($metrics.totalCostUsd)}
      />
      <MetricCard
        label="Active Time"
        value={formatTime($metrics.activeTimeSeconds)}
      />
      <MetricCard
        label="Sessions"
        value={$metrics.sessionCount.toString()}
      />
    </div>

    <div class="grid grid-cols-3 gap-4 mb-6">
      <MetricCard
        label="Lines Added"
        value={`+${$metrics.linesAdded.toLocaleString()}`}
      />
      <MetricCard
        label="Lines Removed"
        value={`-${$metrics.linesRemoved.toLocaleString()}`}
      />
      <MetricCard
        label="Commits"
        value={$metrics.commitCount.toString()}
      />
    </div>

    <!-- Charts -->
    <div class="grid grid-cols-1 gap-6">
      <TokensChart data={$metrics.tokensOverTime} />
      <ModelBreakdown data={$metrics.tokensByModel} />
    </div>
  {/if}
</main>
