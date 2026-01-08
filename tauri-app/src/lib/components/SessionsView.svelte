<script lang="ts">
  import { onMount } from 'svelte';
  import { invoke } from '@tauri-apps/api/core';
  import { SessionsTable, SessionDetailModal, TimeRangePicker } from '$lib/components';
  import { settings } from '$lib/stores/settings';
  import type { SessionsData, SessionMetrics, TimeRange } from '$lib/types';

  let data: SessionsData | null = null;
  let loading = true;
  let error: string | null = null;
  let timeRange: TimeRange = '24h';
  let selectedSession: SessionMetrics | null = null;

  async function fetchSessions() {
    loading = true;
    error = null;
    try {
      data = await invoke<SessionsData>('get_sessions_data', {
        timeRange,
        prometheusUrl: $settings.prometheusUrl,
      });
    } catch (e) {
      error = e as string;
    } finally {
      loading = false;
    }
  }

  function handleTimeRangeChange(value: TimeRange) {
    timeRange = value;
    fetchSessions();
  }

  function handleSelectSession(session: SessionMetrics) {
    selectedSession = session;
  }

  function handleCloseModal() {
    selectedSession = null;
  }

  onMount(fetchSessions);
</script>

<div>
  <!-- Header -->
  <div class="flex justify-between items-center mb-6">
    <div>
      <h2 class="text-lg font-semibold text-white">Sessions</h2>
      {#if data}
        <p class="text-sm text-gray-400">{data.totalCount} sessions found</p>
      {/if}
    </div>
    <TimeRangePicker value={timeRange} onChange={handleTimeRangeChange} />
  </div>

  {#if loading && !data}
    <div class="flex items-center justify-center h-64">
      <div class="text-gray-400">Loading sessions...</div>
    </div>
  {:else if error}
    <div class="bg-surface-light rounded-lg p-8 text-center">
      <div class="text-gray-400 mb-2">Unable to load sessions</div>
      <div class="text-gray-500 text-sm">{error}</div>
    </div>
  {:else if data}
    <SessionsTable
      sessions={data.sessions}
      onSelectSession={handleSelectSession}
    />
  {/if}
</div>

<SessionDetailModal session={selectedSession} onClose={handleCloseModal} />
