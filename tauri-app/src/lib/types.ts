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

// Insights types
export type PeriodType = 'this_week' | 'last_7_days' | 'this_month';

export interface InsightsData {
  period: string;
  comparison: PeriodComparison;
  dailyActivity: DailyActivityPoint[];
  sessionsPerDay: DailyActivityPoint[];
  peakActivity: PeakActivity;
}

export interface PeriodComparison {
  messages: MetricComparison;
  sessions: MetricComparison;
  tokens: MetricComparison;
  estimatedCost: MetricComparison;
}

export interface MetricComparison {
  current: number;
  previous: number;
  percentChange: number | null;
}

export interface DailyActivityPoint {
  date: string;
  value: number;
}

export interface PeakActivity {
  mostActiveHour: number | null;
  longestSessionMinutes: number | null;
  currentStreak: number;
  memberSince: string | null;
}

export const PERIOD_OPTIONS: { value: PeriodType; label: string }[] = [
  { value: 'this_week', label: 'This Week' },
  { value: 'last_7_days', label: 'Last 7 Days' },
  { value: 'this_month', label: 'This Month' },
];

// Sessions types
export interface SessionMetrics {
  sessionId: string;
  totalCostUsd: number;
  totalTokens: number;
  inputTokens: number;
  outputTokens: number;
  cacheReadTokens: number;
  cacheCreationTokens: number;
  activeTimeSeconds: number;
  tokensByModel: ModelTokenCount[];
}

export interface ModelTokenCount {
  model: string;
  tokens: number;
}

export interface SessionsData {
  sessions: SessionMetrics[];
  totalCount: number;
}

export type SessionSortField = 'cost' | 'tokens' | 'duration' | 'sessionId';
export type SortDirection = 'asc' | 'desc';

// Local Stats Cache types
export interface LocalStatsCacheData {
  totalTokens: number;
  totalSessions: number;
  totalMessages: number;
  activeDays: number;
  avgMessagesPerDay: number;
  estimatedCost: number;
  peakHour: number | null;
  firstSession: string | null;
  dailyActivity: DailyActivityPoint[];
  tokensByModel: ModelTokensData[];
  activityByHour: HourActivity[];
}

export interface ModelTokensData {
  model: string;
  tokens: number;
}

export interface HourActivity {
  hour: number;
  count: number;
}
