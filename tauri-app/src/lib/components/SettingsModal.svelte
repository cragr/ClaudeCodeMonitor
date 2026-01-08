<script lang="ts">
  import { invoke } from '@tauri-apps/api/core';
  import { settings } from '$lib/stores/settings';
  import type { Settings } from '$lib/types';

  export let open: boolean;
  export let onClose: () => void;

  let localSettings: Settings = { ...$settings };
  let testStatus: 'idle' | 'testing' | 'success' | 'error' = 'idle';

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
  <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
    <div class="bg-surface-light rounded-lg p-6 w-full max-w-md">
      <h2 class="text-lg font-bold text-white mb-4">Settings</h2>

      <div class="space-y-4">
        <!-- Prometheus URL -->
        <div>
          <label class="block text-sm text-gray-400 mb-1" for="prometheus-url">Prometheus URL</label>
          <div class="flex gap-2">
            <input
              id="prometheus-url"
              type="text"
              bind:value={localSettings.prometheusUrl}
              class="flex-1 bg-surface border border-gray-600 rounded px-3 py-2 text-white focus:outline-none focus:ring-2 focus:ring-accent"
            />
            <button
              on:click={testConnection}
              class="px-3 py-2 bg-surface border border-gray-600 rounded text-gray-300 hover:bg-surface-lighter"
            >
              {#if testStatus === 'testing'}
                Testing...
              {:else if testStatus === 'success'}
                Pass
              {:else if testStatus === 'error'}
                Fail
              {:else}
                Test
              {/if}
            </button>
          </div>
        </div>

        <!-- Refresh Interval -->
        <div>
          <label class="block text-sm text-gray-400 mb-1" for="refresh-interval">Refresh Interval (seconds)</label>
          <input
            id="refresh-interval"
            type="number"
            bind:value={localSettings.refreshInterval}
            min="5"
            max="300"
            class="w-full bg-surface border border-gray-600 rounded px-3 py-2 text-white focus:outline-none focus:ring-2 focus:ring-accent"
          />
        </div>

        <!-- Pricing Provider -->
        <div>
          <label class="block text-sm text-gray-400 mb-1" for="pricing-provider">Pricing Provider</label>
          <select
            id="pricing-provider"
            bind:value={localSettings.pricingProvider}
            class="w-full bg-surface border border-gray-600 rounded px-3 py-2 text-white focus:outline-none focus:ring-2 focus:ring-accent"
          >
            <option value="anthropic">Anthropic (Direct API)</option>
            <option value="aws-bedrock">AWS Bedrock</option>
            <option value="google-vertex">Google Vertex AI</option>
          </select>
        </div>
      </div>

      <!-- Actions -->
      <div class="flex justify-end gap-3 mt-6">
        <button
          on:click={onClose}
          class="px-4 py-2 text-gray-400 hover:text-white"
        >
          Cancel
        </button>
        <button
          on:click={save}
          class="px-4 py-2 bg-accent text-white rounded hover:bg-accent-light"
        >
          Save
        </button>
      </div>
    </div>
  </div>
{/if}
