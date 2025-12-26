# Insights View & Pricing Presets Design

## Overview

Add a new "Insights" view to Claude Code Monitor that automatically surfaces usage comparisons and trends. Also add configurable pricing provider presets and extended time range options.

## Features

### 1. Insights View - Comparison & Trends

A new sidebar tab that shows automatic insights from usage data without requiring user configuration.

#### Data Sources

- **Local Stats Cache** (`~/.claude/stats-cache.json`): `dailyActivity`, `dailyModelTokens`, `hourCounts`, `modelUsage`
- **Prometheus**: Current session metrics, today's running totals

All comparisons can be computed from local data - no new infrastructure needed.

#### Location

New sidebar tab "Insights" between "Token Metrics" and "Local Stats Cache", using a lightbulb or trending chart icon.

### 2. UI Layout

Three main sections stacked vertically:

#### Period Comparison Cards (Top)

A row of 4 metric cards showing "this period vs last period":

| Metric | Example Display |
|--------|-----------------|
| Messages | **847** ↑ 23% vs last week |
| Sessions | **12** ↓ 8% vs last week |
| Tokens | **1.2M** ↑ 45% vs last week |
| Est. Cost | **$4.82** ↑ 31% vs last week |

Each card shows:
- Current period value (large, prominent)
- Trend arrow with percentage (green up / red down / gray neutral)
- Comparison text ("vs last week")

**Period Selector** (segmented control above cards):
- "This Week" (default)
- "This Month"
- "Last 7 Days" (rolling)

#### Trend Sparklines (Middle)

Horizontal row of 2-3 mini charts (approximately 150x60px each):

| Chart | What it shows |
|-------|---------------|
| Daily Activity | Bar chart of messages per day |
| Model Mix | Stacked area showing Opus vs Sonnet vs Haiku over time |
| Session Length | Line chart of average session duration trend |

Each sparkline has:
- Small title label
- The chart (no axis labels, just the shape)
- Single summary stat below ("Avg: 142/day")

Clicking a sparkline navigates to the relevant detailed view.

#### Peak Activity (Bottom)

Simple insights panel:

```
PEAK ACTIVITY
Most active day     Tuesday
Most active hour    2:00 PM - 3:00 PM
Longest session     4h 28m (Dec 25)
Current streak      3 days
```

### 3. Pricing Provider Presets

#### Location

- Settings > Pricing section (primary)
- Quick-switch dropdown in Insights view header

#### Presets

| Provider | Notes |
|----------|-------|
| **Anthropic** (default) | Direct API pricing |
| **AWS Bedrock** | Same as Anthropic for most models |
| **Google Vertex AI** | ~10% premium over Anthropic |

#### Pricing Data (per 1M tokens)

**Base Input/Output:**

| Model | Anthropic | AWS Bedrock | Google Vertex |
|-------|-----------|-------------|---------------|
| Opus 4.5 | $5 / $25 | $5 / $25 | $5.50 / $27.50 |
| Opus 4.1 | $15 / $75 | $15 / $75 | - |
| Opus 4 | $15 / $75 | $15 / $75 | - |
| Sonnet 4.5 | $3 / $15 | $3 / $15 | $3.30 / $16.50 |
| Sonnet 4 | $3 / $15 | $3 / $15 | - |
| Haiku 4.5 | $1 / $5 | $1 / $5 | $1.10 / $5.50 |
| Haiku 3.5 | $0.80 / $4 | $0.80 / $4 | - |

**Cache Pricing:**

| Model | Provider | Cache Read | Cache Write (5m) | Cache Write (1h) |
|-------|----------|------------|------------------|------------------|
| Opus 4.5 | Anthropic | $0.50 | $6.25 | $10 |
| Opus 4.5 | Bedrock | $0.50 | $6.25 | $10 |
| Opus 4.5 | Vertex | $0.55 | $6.875 | $11 |
| Sonnet 4.5 | Anthropic | $0.30 | $3.75 | $6 |
| Sonnet 4.5 | Bedrock | $0.30 | $3.75 | $6 |
| Sonnet 4.5 | Vertex | $0.33 | $4.13 | $6.60 |
| Haiku 4.5 | Anthropic | $0.10 | $1.25 | $2 |
| Haiku 4.5 | Bedrock | $0.10 | $1.25 | $2 |
| Haiku 4.5 | Vertex | $0.11 | $1.375 | $2.20 |

#### Implementation

Replace hardcoded pricing in `ModelUsage.estimatedCost(for:)` with a `PricingProvider` enum and lookup table. Selected provider stored in `SettingsManager`.

### 4. Extended Time Range Selector

#### New Options

| Existing | New |
|----------|-----|
| Last 15 Minutes | **Past 8 Hours** |
| Last 1 Hour | **Past 2 Days** |
| Last 12 Hours | **Custom Range** |
| Last 1 Day | |
| Last 1 Week | |
| Last 2 Weeks | |
| Last 1 Month | |

#### Custom Range Picker

Popover with:
- Start date/time picker (native macOS DatePicker)
- End date/time picker
- Cancel / Apply buttons

Validation: end must be after start. Custom range persists in `SettingsManager`.

#### Step Intervals

| Range | Step | Approx Buckets |
|-------|------|----------------|
| Past 8 Hours | 5 min | 96 |
| Past 2 Days | 1 hour | 48 |
| Custom | Auto-calculated based on duration | Variable |

## Edge Cases & Error Handling

| Situation | Behavior |
|-----------|----------|
| First week of usage | Show current stats, gray out comparison: "Not enough data yet" |
| Missing days in period | Calculate from available days, note "Based on X active days" |
| No stats-cache.json | Empty state: "Use Claude Code to generate usage data" |
| Stats cache stale (>24h) | Show data with warning: "Data from [date]" |
| Zero to non-zero change | Show "New" instead of infinity percentage |
| Custom range validation | Disable Apply button if end <= start |

## Calculation Notes

- Percentage changes handle zero gracefully
- Cost increases show red (spending more = warning)
- Activity decreases are neutral (coding less might be intentional)
- Rolling "Last 7 Days" uses calendar days
- Streak counts consecutive days with at least 1 message

## Performance

- All calculations use already-loaded stats cache
- No additional file reads or network calls
- Compute derived values when: tab selected, cache refreshed, period changes
- Memoize computed comparisons to avoid recalculating on render

## Files to Modify/Create

### New Files

- `Sources/Views/InsightsView.swift` - Main insights view
- `Sources/Models/PricingProvider.swift` - Pricing enum and lookup tables
- `Sources/Views/Components/ComparisonCard.swift` - Period comparison card component
- `Sources/Views/Components/TrendSparkline.swift` - Mini chart component
- `Sources/Views/Components/CustomDateRangePicker.swift` - Date range popover

### Modified Files

- `Sources/Views/ContentView.swift` - Add Insights tab to sidebar
- `Sources/Models/StatsCache.swift` - Add comparison computation methods
- `Sources/Models/TimeRangePreset.swift` - Add new presets and custom range
- `Sources/Views/SettingsView.swift` - Add pricing provider picker
- `Sources/Services/SettingsManager.swift` - Store pricing provider and custom range
- `Sources/Models/ModelUsage.swift` - Use PricingProvider for cost calculation

## Testing

- Unit tests for comparison calculations (week-over-week, month-over-month)
- Unit tests for pricing calculations across all providers
- Unit tests for edge cases (zero values, missing data, first week)
- UI tests for custom date range validation
