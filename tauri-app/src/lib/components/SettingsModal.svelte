<script lang="ts">
  import { invoke } from '@tauri-apps/api/core';
  import { getVersion } from '@tauri-apps/api/app';
  import { check } from '@tauri-apps/plugin-updater';
  import { relaunch } from '@tauri-apps/plugin-process';
  import { settings } from '$lib/stores/settings';
  import type { Settings } from '$lib/types';
  import { onMount } from 'svelte';

  export let open: boolean;
  export let onClose: () => void;

  let localSettings: Settings = { ...$settings };
  let testStatus: 'idle' | 'testing' | 'success' | 'error' = 'idle';
  let updateStatus: 'idle' | 'checking' | 'available' | 'downloading' | 'ready' | 'none' | 'error' = 'idle';
  let updateVersion: string = '';
  let updateError: string = '';
  let appVersion: string = '';

  onMount(async () => {
    appVersion = await getVersion();
  });

  $: if (open) {
    localSettings = { ...$settings };
    testStatus = 'idle';
  }

  async function testConnection() {
    testStatus = 'testing';
    try {
      const result = await invoke<boolean>('test_connection', {
        url: localSettings.prometheusUrl,
      });
      testStatus = result ? 'success' : 'error';
    } catch {
      testStatus = 'error';
    }
  }

  async function checkForUpdates() {
    updateStatus = 'checking';
    updateError = '';
    try {
      const update = await check();
      if (update) {
        updateVersion = update.version;
        updateStatus = 'available';
      } else {
        updateStatus = 'none';
      }
    } catch (e) {
      updateError = String(e);
      updateStatus = 'error';
    }
  }

  async function downloadAndInstall() {
    updateStatus = 'downloading';
    try {
      const update = await check();
      if (update) {
        await update.downloadAndInstall();
        updateStatus = 'ready';
      }
    } catch (e) {
      updateError = String(e);
      updateStatus = 'error';
    }
  }

  async function restartApp() {
    await relaunch();
  }

  function save() {
    $settings = { ...localSettings };
    onClose();
  }

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') onClose();
  }
</script>

<svelte:window on:keydown={handleKeydown} />

{#if open}
  <div class="fixed inset-0 bg-crust/80 flex items-center justify-center z-50">
    <div class="bg-bg-primary border border-border-secondary rounded-lg p-6 w-full max-w-md shadow-card">
      <h2 class="text-lg font-bold text-text-primary mb-4">Settings</h2>

      <div class="space-y-4">
        <!-- Prometheus URL -->
        <div>
          <label class="block text-sm text-text-secondary mb-1" for="prometheus-url">Prometheus URL</label>
          <div class="flex gap-2">
            <input
              id="prometheus-url"
              type="text"
              bind:value={localSettings.prometheusUrl}
              class="flex-1 bg-bg-card border border-border-secondary rounded-md px-3 py-2 text-text-primary focus:outline-none focus:ring-2 focus:ring-blue"
            />
            <button
              on:click={testConnection}
              class="px-3 py-2 bg-bg-card border border-border-secondary rounded-md text-text-secondary hover:bg-bg-card-hover transition-colors"
            >
              {#if testStatus === 'testing'}
                Testing...
              {:else if testStatus === 'success'}
                <span class="text-green">Pass</span>
              {:else if testStatus === 'error'}
                <span class="text-red">Fail</span>
              {:else}
                Test
              {/if}
            </button>
          </div>
        </div>

        <!-- Refresh Interval -->
        <div>
          <label class="block text-sm text-text-secondary mb-1" for="refresh-interval">Refresh Interval (seconds)</label>
          <input
            id="refresh-interval"
            type="number"
            bind:value={localSettings.refreshInterval}
            min="5"
            max="300"
            class="w-full bg-bg-card border border-border-secondary rounded-md px-3 py-2 text-text-primary focus:outline-none focus:ring-2 focus:ring-blue"
          />
        </div>

        <!-- Pricing Provider -->
        <div>
          <label class="block text-sm text-text-secondary mb-1" for="pricing-provider">Pricing Provider</label>
          <select
            id="pricing-provider"
            bind:value={localSettings.pricingProvider}
            class="w-full bg-bg-card border border-border-secondary rounded-md px-3 py-2 text-text-primary focus:outline-none focus:ring-2 focus:ring-blue"
          >
            <option value="anthropic">Anthropic (Direct API)</option>
            <option value="aws-bedrock">AWS Bedrock</option>
            <option value="google-vertex">Google Vertex AI</option>
          </select>
        </div>

        <!-- Version -->
        <div class="pt-4 border-t border-border-secondary">
          <label class="block text-sm text-text-secondary mb-1">Version</label>
          <span class="text-text-primary">{appVersion || '...'}</span>
        </div>

        <!-- Updates -->
        <div class="pt-4">
          <label class="block text-sm text-text-secondary mb-2">Software Updates</label>
          <div class="flex items-center gap-3">
            {#if updateStatus === 'idle'}
              <button
                on:click={checkForUpdates}
                class="px-3 py-2 bg-bg-card border border-border-secondary rounded-md text-text-secondary hover:bg-bg-card-hover transition-colors"
              >
                Check for Updates
              </button>
            {:else if updateStatus === 'checking'}
              <span class="text-text-muted text-sm">Checking for updates...</span>
            {:else if updateStatus === 'none'}
              <span class="text-green text-sm">You're up to date!</span>
              <button
                on:click={checkForUpdates}
                class="px-3 py-2 bg-bg-card border border-border-secondary rounded-md text-text-secondary hover:bg-bg-card-hover transition-colors text-sm"
              >
                Check Again
              </button>
            {:else if updateStatus === 'available'}
              <span class="text-text-secondary text-sm">Version {updateVersion} available</span>
              <button
                on:click={downloadAndInstall}
                class="px-3 py-2 bg-blue text-crust rounded-md hover:bg-blue/90 transition-colors text-sm font-medium"
              >
                Download & Install
              </button>
            {:else if updateStatus === 'downloading'}
              <span class="text-text-muted text-sm">Downloading update...</span>
            {:else if updateStatus === 'ready'}
              <span class="text-green text-sm">Update ready!</span>
              <button
                on:click={restartApp}
                class="px-3 py-2 bg-green text-crust rounded-md hover:bg-green/90 transition-colors text-sm font-medium"
              >
                Restart Now
              </button>
            {:else if updateStatus === 'error'}
              <span class="text-red text-sm">Error: {updateError}</span>
              <button
                on:click={checkForUpdates}
                class="px-3 py-2 bg-bg-card border border-border-secondary rounded-md text-text-secondary hover:bg-bg-card-hover transition-colors text-sm"
              >
                Retry
              </button>
            {/if}
          </div>
        </div>
      </div>

      <!-- Actions -->
      <div class="flex justify-end gap-3 mt-6">
        <button
          on:click={onClose}
          class="px-4 py-2 text-text-muted hover:text-text-primary transition-colors"
        >
          Cancel
        </button>
        <button
          on:click={save}
          class="px-4 py-2 bg-blue text-crust rounded-md hover:bg-blue/90 transition-colors font-medium"
        >
          Save
        </button>
      </div>
    </div>
  </div>
{/if}
