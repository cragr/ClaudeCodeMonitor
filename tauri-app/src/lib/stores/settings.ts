import { writable } from 'svelte/store';
import type { Settings } from '$lib/types';

const defaultSettings: Settings = {
  prometheusUrl: 'http://localhost:9090',
  refreshInterval: 30,
  pricingProvider: 'anthropic',
};

export const settings = writable<Settings>(defaultSettings);
