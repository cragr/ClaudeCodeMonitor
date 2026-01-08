import { writable } from 'svelte/store';
import type { DashboardMetrics, TimeRange } from '$lib/types';

export const metrics = writable<DashboardMetrics | null>(null);
export const isLoading = writable(false);
export const error = writable<string | null>(null);
export const timeRange = writable<TimeRange>('24h');
export const isConnected = writable(false);
