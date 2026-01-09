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
  // Token type breakdown
  inputTokens: number;
  outputTokens: number;
  cacheReadTokens: number;
  cacheCreationTokens: number;
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

export type TimeRange = '15m' | '1h' | '4h' | '1d' | '7d' | 'custom';

export interface CustomTimeRange {
  start: number; // Unix timestamp in seconds
  end: number;   // Unix timestamp in seconds
}

export const TIME_RANGE_OPTIONS: { value: TimeRange; label: string }[] = [
  { value: '15m', label: 'Last 15 Minutes' },
  { value: '1h', label: 'Last Hour' },
  { value: '4h', label: 'Last 4 Hours' },
  { value: '1d', label: 'Last Day' },
  { value: '7d', label: 'Last Week' },
  { value: 'custom', label: 'Custom Range' },
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
  project: string | null;
  projectPath: string | null;
  timestamp: number;
  messageCount: number;
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

export interface ProjectStats {
  project: string;
  projectPath: string | null;
  sessionCount: number;
  totalCostUsd: number;
  totalTokens: number;
  activeTimeSeconds: number;
}

export interface SessionsData {
  sessions: SessionMetrics[];
  projects: ProjectStats[];
  totalCount: number;
}


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
