# Insights View Design

## Overview

Add an Insights view to the Tauri app that displays usage analytics from the local stats cache file (`~/.claude/stats-cache.json`), providing feature parity with the SwiftUI macOS app.

## Architecture & Data Flow

### Data Source

The Insights view reads from `~/.claude/stats-cache.json`, a file Claude Code maintains locally. This contains:
- `dailyActivity`: Array of `{date, messageCount, sessionCount, toolCallCount}`
- `dailyModelTokens`: Token usage per model per day
- `modelUsage`: Aggregate tokens/cost by model
- `hourCounts`: Array of 24 integers (activity by hour)
- `longestSession`: Duration, message count, timestamp
- `memberSince`: ISO date string

### Rust Backend

New Tauri command `get_insights_data` that:
1. Reads `~/.claude/stats-cache.json` using `dirs` crate for home directory
2. Parses JSON into Rust structs
3. Computes period comparisons (this week vs last week, this month vs last month)
4. Returns structured data to frontend

### Frontend Flow

```
InsightsView.svelte
  → invoke('get_insights_data', { period: '7d' | '1w' | '1m' })
  → Display comparison cards + sparklines + peak stats
```

### Period Selector Logic

- "This Week" - Current week (Mon-Sun) vs previous week
- "Last 7 Days" - Last 7 days vs prior 7 days
- "This Month" - Current month vs previous month

The Rust backend handles all date math and comparison calculations.

## UI Components & Layout

### Tab Navigation

Add a tab bar below the header, above the content area:
```
[Dashboard] [Insights] [Sessions]
```
Active tab has accent color underline. Clicking switches the view.

### Insights View Layout

```
┌─────────────────────────────────────────────────┐
│ Period: [This Week ▼] [Last 7 Days] [This Month]│  ← Segmented control
├─────────────────────────────────────────────────┤
│ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
│ │ Messages │ │ Sessions │ │  Tokens  │ │Est. Cost │  ← 4-card grid
│ │   142    │ │    23    │ │  1.2M    │ │  $4.50   │
│ │ ↑ +12%   │ │ ↓ -5%    │ │ ↑ +8%    │ │ ↑ +15%   │
│ └──────────┘ └──────────┘ └──────────┘ └──────────┘
├─────────────────────────────────────────────────┤
│ ┌─────────────────────┐ ┌─────────────────────┐ │
│ │ Daily Activity      │ │ Sessions/Day        │ │  ← 2 sparkline cards
│ │ Avg: 20 msgs/day    │ │ Avg: 3.2/day        │ │
│ │ ~~~~~~~~~~~         │ │ ~~~~~~~~~~~         │ │
│ └─────────────────────┘ └─────────────────────┘ │
├─────────────────────────────────────────────────┤
│ Peak Activity                                   │
│ Most Active Hour: 2 PM    Longest Session: 45m │  ← Detail rows
│ Current Streak: 5 days    Member Since: Dec 24 │
└─────────────────────────────────────────────────┘
```

### Components to Create

- `TabNav.svelte` - Tab navigation bar
- `InsightsView.svelte` - Main insights page
- `ComparisonCard.svelte` - Metric card with trend indicator
- `SparklineChart.svelte` - Mini area chart (reuse Chart.js)
- `PeriodSelector.svelte` - Segmented button group

## Data Models

### TypeScript Types

```typescript
interface InsightsData {
  period: PeriodType;
  comparison: PeriodComparison;
  dailyActivity: DailyActivityPoint[];
  sessionsPerDay: DailyActivityPoint[];
  peakActivity: PeakActivity;
}

type PeriodType = 'this_week' | 'last_7_days' | 'this_month';

interface PeriodComparison {
  messages: MetricComparison;
  sessions: MetricComparison;
  tokens: MetricComparison;
  estimatedCost: MetricComparison;
}

interface MetricComparison {
  current: number;
  previous: number;
  percentChange: number | null;  // null if no previous data
}

interface DailyActivityPoint {
  date: string;  // YYYY-MM-DD
  value: number;
}

interface PeakActivity {
  mostActiveHour: number | null;  // 0-23
  longestSessionMinutes: number | null;
  currentStreak: number;
  memberSince: string | null;  // ISO date
}
```

### Rust Structs

Mirror the TypeScript types with serde for JSON serialization. The `StatsCache` struct matches the shape of `~/.claude/stats-cache.json` for deserialization.

### Pricing Calculation

Reuse the existing `pricingProvider` setting. Cost calculation uses the same model pricing table as SwiftUI (Opus, Sonnet, Haiku variants).

## Error Handling & Edge Cases

### File Not Found

If `~/.claude/stats-cache.json` doesn't exist (user hasn't used Claude Code yet), show empty state:
```
"No usage data yet"
"Use Claude Code to start tracking your activity"
```

### Empty Data

If file exists but has no daily activity, show zero values with "—" for percentage change (no previous data to compare).

### Date Edge Cases

- "This Week" on Monday: Current week has 1 day, previous week has 7
- "This Month" on 1st: Current month has 1 day, compare to full previous month
- Streak calculation: Consecutive days with `messageCount > 0`, ending at yesterday (today may be incomplete)

### Loading State

Show skeleton cards while loading. The file read should be fast (<100ms) but keeps UI responsive.

### Refresh Behavior

- Insights data refreshes when tab becomes active
- No auto-refresh interval (unlike Dashboard) since stats cache updates less frequently
- Manual refresh button in header

### Pricing Provider

Read from settings store. When provider changes, recalculate cost on next view.

## Implementation Tasks

1. Add `dirs` crate to Cargo.toml for home directory resolution
2. Create `insights.rs` with StatsCache structs and `get_insights_data` command
3. Add Insights types to `types.ts`
4. Create `TabNav.svelte` component
5. Create `PeriodSelector.svelte` component
6. Create `ComparisonCard.svelte` component
7. Create `SparklineChart.svelte` component
8. Create `InsightsView.svelte` main view
9. Update `+page.svelte` to use TabNav and route between views
10. Add insights store for state management
