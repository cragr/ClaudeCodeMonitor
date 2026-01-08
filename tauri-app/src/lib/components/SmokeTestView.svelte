<script lang="ts">
  import { invoke } from '@tauri-apps/api/core';
  import { ViewHeader } from '$lib/components';
  import { settings } from '$lib/stores/settings';
  import { isConnected } from '$lib/stores';

  interface TestResult {
    name: string;
    status: 'pending' | 'running' | 'passed' | 'failed';
    message?: string;
  }

  let tests: TestResult[] = [
    { name: 'Prometheus Connection', status: 'pending' },
    { name: 'Metric Discovery', status: 'pending' },
    { name: 'Token Usage Query', status: 'pending' },
    { name: 'Cost Query', status: 'pending' },
  ];

  let discoveredMetrics: string[] = [];
  let isRunning = false;

  const setupCommands = [
    {
      label: 'Start Prometheus Stack',
      command: 'docker-compose up -d',
    },
    {
      label: 'Enable Claude Code Telemetry',
      command: 'claude config set telemetryEnabled true',
    },
    {
      label: 'Set Prometheus Endpoint',
      command: 'export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318',
    },
  ];

  async function runTests() {
    isRunning = true;
    tests = tests.map(t => ({ ...t, status: 'pending' as const }));
    discoveredMetrics = [];

    // Test 1: Prometheus Connection
    tests[0].status = 'running';
    tests = [...tests];
    try {
      const connected = await invoke<boolean>('test_connection', { url: $settings.prometheusUrl });
      tests[0].status = connected ? 'passed' : 'failed';
      tests[0].message = connected ? 'Connected successfully' : 'Connection refused';
      isConnected.set(connected);
    } catch (e) {
      tests[0].status = 'failed';
      tests[0].message = e as string;
      isConnected.set(false);
    }
    tests = [...tests];

    // If connection failed, skip remaining tests
    if (tests[0].status === 'failed') {
      tests[1].status = 'failed';
      tests[1].message = 'Skipped - no connection';
      tests[2].status = 'failed';
      tests[2].message = 'Skipped - no connection';
      tests[3].status = 'failed';
      tests[3].message = 'Skipped - no connection';
      tests = [...tests];
      isRunning = false;
      return;
    }

    // Test 2: Metric Discovery
    tests[1].status = 'running';
    tests = [...tests];
    try {
      discoveredMetrics = await invoke<string[]>('discover_metrics', { url: $settings.prometheusUrl });
      tests[1].status = discoveredMetrics.length > 0 ? 'passed' : 'failed';
      tests[1].message = discoveredMetrics.length > 0
        ? `Found ${discoveredMetrics.length} metrics`
        : 'No claude_code_ metrics found';
    } catch (e) {
      tests[1].status = 'failed';
      tests[1].message = e as string;
    }
    tests = [...tests];

    // Test 3: Token Usage Query
    tests[2].status = 'running';
    tests = [...tests];
    try {
      const metrics = await invoke('get_dashboard_metrics', {
        timeRange: '24h',
        prometheusUrl: $settings.prometheusUrl,
      });
      tests[2].status = 'passed';
      tests[2].message = 'Query executed successfully';
    } catch (e) {
      tests[2].status = 'failed';
      tests[2].message = e as string;
    }
    tests = [...tests];

    // Test 4: Cost Query
    tests[3].status = 'running';
    tests = [...tests];
    try {
      const metrics = await invoke('get_dashboard_metrics', {
        timeRange: '1h',
        prometheusUrl: $settings.prometheusUrl,
      });
      tests[3].status = 'passed';
      tests[3].message = 'Query executed successfully';
    } catch (e) {
      tests[3].status = 'failed';
      tests[3].message = e as string;
    }
    tests = [...tests];

    isRunning = false;
  }

  function copyToClipboard(text: string) {
    navigator.clipboard.writeText(text);
  }

  function getStatusIcon(status: TestResult['status']): string {
    switch (status) {
      case 'pending': return '○';
      case 'running': return '◌';
      case 'passed': return '✓';
      case 'failed': return '✗';
    }
  }

  function getStatusColor(status: TestResult['status']): string {
    switch (status) {
      case 'pending': return 'text-text-muted';
      case 'running': return 'text-accent-cyan';
      case 'passed': return 'text-accent-green';
      case 'failed': return 'text-accent-red';
    }
  }
</script>

<div>
  <ViewHeader category="diagnostics" title="Smoke Test" subtitle="Verify Prometheus connection and metrics">
    <button
      slot="actions"
      class="px-4 py-2 bg-accent-cyan text-bg-primary rounded-lg font-medium hover:bg-accent-cyan/90 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
      on:click={runTests}
      disabled={isRunning}
    >
      {isRunning ? 'Running...' : 'Run Tests'}
    </button>
  </ViewHeader>

  <!-- Test Results -->
  <div class="mb-6">
    <div class="flex items-center gap-4 mb-4">
      <div class="h-px flex-1 bg-border-secondary"></div>
      <span class="text-xs font-medium text-text-muted uppercase tracking-wider">Test Results</span>
      <div class="h-px flex-1 bg-border-secondary"></div>
    </div>
    <div class="bg-bg-card rounded-lg divide-y divide-border-secondary">
      {#each tests as test}
        <div class="flex items-center justify-between p-4">
          <div class="flex items-center gap-3">
            <span class="text-lg {getStatusColor(test.status)}">{getStatusIcon(test.status)}</span>
            <span class="text-text-primary">{test.name}</span>
          </div>
          {#if test.message}
            <span class="text-sm text-text-secondary">{test.message}</span>
          {/if}
        </div>
      {/each}
    </div>
  </div>

  <!-- Discovered Metrics -->
  {#if discoveredMetrics.length > 0}
    <div class="mb-6">
      <div class="flex items-center gap-4 mb-4">
        <div class="h-px flex-1 bg-border-secondary"></div>
        <span class="text-xs font-medium text-text-muted uppercase tracking-wider">Discovered Metrics ({discoveredMetrics.length})</span>
        <div class="h-px flex-1 bg-border-secondary"></div>
      </div>
      <div class="bg-bg-card rounded-lg p-4">
        <div class="grid grid-cols-2 gap-2">
          {#each discoveredMetrics as metric}
            <div class="flex items-center gap-2 text-sm">
              <span class="text-accent-green">●</span>
              <code class="text-text-secondary font-mono text-xs">{metric}</code>
            </div>
          {/each}
        </div>
      </div>
    </div>
  {/if}

  <!-- Setup Guide -->
  <div>
    <div class="flex items-center gap-4 mb-4">
      <div class="h-px flex-1 bg-border-secondary"></div>
      <span class="text-xs font-medium text-text-muted uppercase tracking-wider">Setup Guide</span>
      <div class="h-px flex-1 bg-border-secondary"></div>
    </div>
    <div class="bg-bg-card rounded-lg p-6 space-y-4">
      <p class="text-text-secondary text-sm mb-4">
        To collect Claude Code metrics, you need to set up a Prometheus stack with an OpenTelemetry collector.
        Follow these steps to get started:
      </p>
      {#each setupCommands as cmd, i}
        <div class="space-y-2">
          <div class="flex items-center gap-2">
            <span class="flex items-center justify-center w-6 h-6 rounded-full bg-accent-cyan/10 text-accent-cyan text-xs font-medium">{i + 1}</span>
            <span class="text-text-primary text-sm">{cmd.label}</span>
          </div>
          <div class="flex items-center gap-2 ml-8">
            <code class="flex-1 bg-bg-primary px-3 py-2 rounded text-text-secondary font-mono text-sm">{cmd.command}</code>
            <button
              class="p-2 text-text-muted hover:text-text-primary transition-colors"
              on:click={() => copyToClipboard(cmd.command)}
              title="Copy to clipboard"
            >
              <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
              </svg>
            </button>
          </div>
        </div>
      {/each}
      <div class="mt-6 pt-4 border-t border-border-secondary">
        <p class="text-text-muted text-xs">
          Current Prometheus URL: <code class="text-text-secondary">{$settings.prometheusUrl}</code>
        </p>
      </div>
    </div>
  </div>
</div>
