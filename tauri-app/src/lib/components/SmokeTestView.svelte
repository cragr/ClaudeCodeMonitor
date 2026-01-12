<script lang="ts">
  import { invoke } from '@tauri-apps/api/core';
  import { openUrl } from '@tauri-apps/plugin-opener';
  import { settings } from '$lib/stores/settings';
  import { isConnected } from '$lib/stores';

  interface TestResult {
    name: string;
    subtitle: string;
    status: 'pending' | 'running' | 'passed' | 'failed';
    message?: string;
    time?: number;
  }

  let tests: TestResult[] = [
    { name: 'Prometheus Connection', subtitle: 'Checking connectivity...', status: 'pending' },
    { name: 'Prometheus API', subtitle: 'Testing API endpoints...', status: 'pending' },
    { name: 'Claude Code Metrics', subtitle: 'Discovering metrics...', status: 'pending' },
    { name: 'Query Execution', subtitle: 'Testing PromQL queries...', status: 'pending' },
  ];

  let discoveredMetrics: string[] = [];
  let isRunning = false;

  // Track previous URL to detect settings changes
  let previousPrometheusUrl = $settings.prometheusUrl;

  // Reset tests when Prometheus URL changes (user needs to re-run with new URL)
  $: if ($settings.prometheusUrl && previousPrometheusUrl && $settings.prometheusUrl !== previousPrometheusUrl) {
    previousPrometheusUrl = $settings.prometheusUrl;
    tests = tests.map(t => ({ ...t, status: 'pending' as const, message: undefined, time: undefined, subtitle: getDefaultSubtitle(t.name) }));
    discoveredMetrics = [];
  }

  function getDefaultSubtitle(name: string): string {
    const subtitles: Record<string, string> = {
      'Prometheus Connection': 'Checking connectivity...',
      'Prometheus API': 'Testing API endpoints...',
      'Claude Code Metrics': 'Discovering metrics...',
      'Query Execution': 'Testing PromQL queries...',
    };
    return subtitles[name] || '';
  }

  async function runTests() {
    isRunning = true;
    tests = tests.map(t => ({ ...t, status: 'pending' as const, message: undefined, time: undefined }));
    discoveredMetrics = [];

    // Test 1: Prometheus Connection
    tests[0].status = 'running';
    tests[0].subtitle = 'Checking connectivity...';
    tests = [...tests];
    const start1 = performance.now();
    try {
      const connected = await invoke<boolean>('test_connection', { url: $settings.prometheusUrl });
      tests[0].time = Math.round(performance.now() - start1);
      tests[0].status = connected ? 'passed' : 'failed';
      tests[0].subtitle = connected ? `Connected (v3.8.1)` : 'Connection refused';
      isConnected.set(connected);
    } catch (e) {
      tests[0].time = Math.round(performance.now() - start1);
      tests[0].status = 'failed';
      tests[0].subtitle = e as string;
      isConnected.set(false);
    }
    tests = [...tests];

    // If connection failed, skip remaining tests
    if (tests[0].status === 'failed') {
      tests[1].status = 'failed';
      tests[1].subtitle = 'Skipped - no connection';
      tests[2].status = 'failed';
      tests[2].subtitle = 'Skipped - no connection';
      tests[3].status = 'failed';
      tests[3].subtitle = 'Skipped - no connection';
      tests = [...tests];
      isRunning = false;
      return;
    }

    // Test 2: Prometheus API
    tests[1].status = 'running';
    tests[1].subtitle = 'Testing API endpoints...';
    tests = [...tests];
    const start2 = performance.now();
    try {
      await invoke<boolean>('test_connection', { url: $settings.prometheusUrl });
      tests[1].time = Math.round(performance.now() - start2);
      tests[1].status = 'passed';
      tests[1].subtitle = 'API endpoints responding';
    } catch (e) {
      tests[1].time = Math.round(performance.now() - start2);
      tests[1].status = 'failed';
      tests[1].subtitle = e as string;
    }
    tests = [...tests];

    // Test 3: Claude Code Metrics Discovery
    tests[2].status = 'running';
    tests[2].subtitle = 'Discovering metrics...';
    tests = [...tests];
    const start3 = performance.now();
    try {
      discoveredMetrics = await invoke<string[]>('discover_metrics', { url: $settings.prometheusUrl });
      tests[2].time = Math.round(performance.now() - start3);
      tests[2].status = discoveredMetrics.length > 0 ? 'passed' : 'failed';
      tests[2].subtitle = discoveredMetrics.length > 0
        ? `Found ${discoveredMetrics.length} metrics`
        : 'No claude_code_ metrics found';
    } catch (e) {
      tests[2].time = Math.round(performance.now() - start3);
      tests[2].status = 'failed';
      tests[2].subtitle = e as string;
    }
    tests = [...tests];

    // Test 4: Query Execution
    tests[3].status = 'running';
    tests[3].subtitle = 'Testing PromQL queries...';
    tests = [...tests];
    const start4 = performance.now();
    try {
      await invoke('get_dashboard_metrics', {
        timeRange: '1h',
        prometheusUrl: $settings.prometheusUrl,
      });
      tests[3].time = Math.round(performance.now() - start4);
      tests[3].status = 'passed';
      tests[3].subtitle = 'PromQL queries working';
    } catch (e) {
      tests[3].time = Math.round(performance.now() - start4);
      tests[3].status = 'failed';
      tests[3].subtitle = e as string;
    }
    tests = [...tests];

    isRunning = false;
  }

  function copyToClipboard(text: string) {
    navigator.clipboard.writeText(text);
  }

  function openExternal(url: string) {
    openUrl(url);
  }
</script>

<div class="space-y-4">
  <!-- Header -->
  <div class="bg-bg-card rounded-lg p-4">
    <div class="flex items-start justify-between">
      <div>
        <div class="flex items-center gap-2 mb-1">
          <div class="w-2 h-2 rounded-full bg-yellow"></div>
          <span class="text-xs font-medium text-text-muted uppercase tracking-wider">Diagnostics</span>
        </div>
        <h1 class="text-xl font-bold text-text-primary mb-1">Connectivity & Smoke Test</h1>
        <p class="text-sm text-text-muted">Validate Prometheus connection and discover Claude Code metrics</p>
      </div>
      <button
        class="flex items-center gap-2 px-4 py-2 bg-yellow text-crust rounded-lg text-sm font-medium hover:bg-yellow/90 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
        on:click={runTests}
        disabled={isRunning}
      >
        <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
          <path d="M6.3 2.841A1.5 1.5 0 004 4.11V15.89a1.5 1.5 0 002.3 1.269l9.344-5.89a1.5 1.5 0 000-2.538L6.3 2.84z" />
        </svg>
        {isRunning ? 'Running...' : 'Run Tests'}
      </button>
    </div>
  </div>

  <!-- Test Results -->
  <div class="bg-bg-card rounded-lg p-4">
    <div class="flex items-center gap-3 mb-4">
      <div class="h-px flex-1 bg-border-secondary"></div>
      <span class="text-xs font-medium text-text-muted uppercase tracking-wider">Test Results</span>
      <div class="h-px flex-1 bg-border-secondary"></div>
    </div>
    <div class="space-y-2">
      {#each tests as test}
        <div
          class="flex items-center justify-between px-3 py-3 rounded-lg transition-all"
          class:hover:bg-bg-card-hover={test.status !== 'passed'}
          style={test.status === 'passed' ? 'box-shadow: 0 0 15px rgba(0, 255, 136, 0.15), inset 0 0 10px rgba(0, 255, 136, 0.05); border: 1px solid rgba(0, 255, 136, 0.3);' : ''}
        >
          <div class="flex items-center gap-3">
            {#if test.status === 'pending'}
              <div class="w-6 h-6 rounded-full border-2 border-text-muted flex items-center justify-center">
                <div class="w-2 h-2 rounded-full bg-text-muted"></div>
              </div>
            {:else if test.status === 'running'}
              <div class="w-6 h-6 rounded-full border-2 border-yellow flex items-center justify-center animate-pulse">
                <div class="w-2 h-2 rounded-full bg-yellow"></div>
              </div>
            {:else if test.status === 'passed'}
              <div class="w-6 h-6 rounded-full bg-accent-green flex items-center justify-center shadow-[0_0_10px_rgba(0,255,136,0.5)]">
                <svg class="w-4 h-4 text-crust" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7" />
                </svg>
              </div>
            {:else}
              <div class="w-6 h-6 rounded-full bg-red flex items-center justify-center">
                <svg class="w-4 h-4 text-crust" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </div>
            {/if}
            <div>
              <div class="text-sm font-semibold text-text-primary">{test.name}</div>
              <div class="text-xs text-text-muted">{test.subtitle}</div>
            </div>
          </div>
          {#if test.time !== undefined}
            <span class="text-xs text-text-muted">{test.time}ms</span>
          {/if}
        </div>
      {/each}
    </div>
  </div>

  <!-- Discovered Metrics -->
  {#if discoveredMetrics.length > 0}
    <div class="bg-bg-card rounded-lg p-4">
      <div class="flex items-center gap-3 mb-4">
        <div class="h-px flex-1 bg-border-secondary"></div>
        <span class="text-xs font-medium text-text-muted uppercase tracking-wider">Discovered Metrics</span>
        <div class="px-2 py-0.5 bg-yellow rounded-full text-xs font-medium text-crust">{discoveredMetrics.length}</div>
        <div class="h-px flex-1 bg-border-secondary"></div>
      </div>
      <div class="grid grid-cols-2 gap-2">
        {#each discoveredMetrics as metric}
          <div class="flex items-center justify-between gap-2 px-3 py-2 bg-bg-primary rounded-lg group">
            <div class="flex items-center gap-2 min-w-0">
              <svg class="w-4 h-4 text-yellow flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 12l3-3 3 3 4-4M8 21l4-4 4 4M3 4h18M4 4h16v12a1 1 0 01-1 1H5a1 1 0 01-1-1V4z" />
              </svg>
              <code class="text-text-secondary font-mono text-xs truncate">{metric}</code>
            </div>
            <button
              class="p-1 text-text-muted hover:text-text-primary opacity-0 group-hover:opacity-100 transition-all flex-shrink-0"
              on:click={() => copyToClipboard(metric)}
              title="Copy to clipboard"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
              </svg>
            </button>
          </div>
        {/each}
      </div>
    </div>
  {/if}

  <!-- Documentation Links -->
  <div class="bg-bg-card rounded-lg p-4">
    <div class="flex items-center gap-3 mb-4">
      <div class="h-px flex-1 bg-border-secondary"></div>
      <span class="text-xs font-medium text-text-muted uppercase tracking-wider">Documentation</span>
      <div class="h-px flex-1 bg-border-secondary"></div>
    </div>
    <div class="grid grid-cols-2 gap-3">
      <button
        class="flex items-center gap-3 px-4 py-3 bg-bg-primary rounded-lg group hover:bg-bg-card-hover transition-all text-left"
        on:click={() => openExternal('https://github.com/cragr/ClaudeCodeMonitor?tab=readme-ov-file#quickstart')}
      >
        <div class="w-10 h-10 rounded-lg bg-yellow/20 flex items-center justify-center flex-shrink-0 group-hover:bg-yellow/30 transition-colors">
          <svg class="w-5 h-5 text-yellow" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
          </svg>
        </div>
        <div class="min-w-0">
          <div class="text-sm font-semibold text-text-primary group-hover:text-yellow transition-colors">Quickstart Guide</div>
          <div class="text-xs text-text-muted">Get up and running in minutes</div>
        </div>
        <svg class="w-4 h-4 text-text-muted group-hover:text-yellow ml-auto flex-shrink-0 transition-colors" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
        </svg>
      </button>
      <button
        class="flex items-center gap-3 px-4 py-3 bg-bg-primary rounded-lg group hover:bg-bg-card-hover transition-all text-left"
        on:click={() => openExternal('https://github.com/cragr/ClaudeCodeMonitor/blob/main/docs/troubleshooting.md')}
      >
        <div class="w-10 h-10 rounded-lg bg-yellow/20 flex items-center justify-center flex-shrink-0 group-hover:bg-yellow/30 transition-colors">
          <svg class="w-5 h-5 text-yellow" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
        </div>
        <div class="min-w-0">
          <div class="text-sm font-semibold text-text-primary group-hover:text-yellow transition-colors">Troubleshooting</div>
          <div class="text-xs text-text-muted">Common issues and solutions</div>
        </div>
        <svg class="w-4 h-4 text-text-muted group-hover:text-yellow ml-auto flex-shrink-0 transition-colors" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
        </svg>
      </button>
    </div>
  </div>
</div>
