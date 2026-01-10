import { writable } from 'svelte/store';
import { load } from '@tauri-apps/plugin-store';
import type { Settings } from '$lib/types';

const STORE_PATH = 'settings.json';

const defaultSettings: Settings = {
  prometheusUrl: 'http://localhost:9090',
  refreshInterval: 30,
  pricingProvider: 'anthropic',
};

export const settings = writable<Settings>(defaultSettings);

let storeInstance: Awaited<ReturnType<typeof load>> | null = null;

async function getStore() {
  if (!storeInstance) {
    storeInstance = await load(STORE_PATH, {
      defaults: { settings: defaultSettings },
      autoSave: false
    });
  }
  return storeInstance;
}

export async function loadSettings(): Promise<void> {
  try {
    const store = await getStore();
    const saved = await store.get<Settings>('settings');
    if (saved) {
      settings.set({ ...defaultSettings, ...saved });
    }
  } catch (error) {
    console.error('Failed to load settings:', error);
  }
}

export async function saveSettings(newSettings: Settings): Promise<void> {
  try {
    const store = await getStore();
    await store.set('settings', newSettings);
    await store.save();
    settings.set(newSettings);
  } catch (error) {
    console.error('Failed to save settings:', error);
  }
}
