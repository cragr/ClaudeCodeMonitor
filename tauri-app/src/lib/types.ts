export interface DashboardMetrics {
  totalTokens: number;
  totalCostUsd: number;
  activeTimeSeconds: number;
  sessionCount: number;
  linesAdded: number;
  linesRemoved: number;
  commitCount: number;
  pullRequestCount: number;
  tokensByModel: ModelTokens[];
  tokensOverTime: TimeSeriesPoint[];
}

export interface ModelTokens {
  model: string;
  tokens: number;
}

export interface TimeSeriesPoint {
  timestamp: number;
  value: number;
}

export interface Settings {
  prometheusUrl: string;
  refreshInterval: number;
  pricingProvider: 'anthropic' | 'aws-bedrock' | 'google-vertex';
}

export type TimeRange = '1h' | '8h' | '24h' | '2d' | '7d' | '30d';

export const TIME_RANGE_OPTIONS: { value: TimeRange; label: string }[] = [
  { value: '1h', label: 'Last Hour' },
  { value: '8h', label: 'Last 8 Hours' },
  { value: '24h', label: 'Last 24 Hours' },
  { value: '2d', label: 'Last 2 Days' },
  { value: '7d', label: 'Last 7 Days' },
  { value: '30d', label: 'Last 30 Days' },
];
