import { writable } from 'svelte/store';
import type { DashboardMetrics, TimeRange, CustomTimeRange } from '$lib/types';

export const metrics = writable<DashboardMetrics | null>(null);
export const isLoading = writable(false);
export const error = writable<string | null>(null);
export const timeRange = writable<TimeRange>('1d');
export const customTimeRange = writable<CustomTimeRange | null>(null);
export const isConnected = writable(false);
export const lastUpdated = writable<Date | null>(null);
export const totalCost = writable<number>(0);
