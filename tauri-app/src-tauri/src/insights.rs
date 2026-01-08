// tauri-app/src-tauri/src/insights.rs

use chrono::{Datelike, Duration, Local, NaiveDate};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;

/// Raw stats cache from ~/.claude/stats-cache.json
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct StatsCache {
    pub daily_activity: Vec<DailyActivity>,
    pub daily_model_tokens: Option<Vec<DailyModelTokens>>,
    pub model_usage: HashMap<String, ModelUsage>,
    pub total_sessions: u32,
    pub total_messages: u32,
    pub longest_session: Option<LongestSession>,
    pub first_session_date: Option<String>,
    pub hour_counts: Option<HashMap<String, u32>>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DailyActivity {
    pub date: String,
    pub message_count: u32,
    pub session_count: u32,
    pub tool_call_count: u32,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DailyModelTokens {
    pub date: String,
    pub tokens_by_model: HashMap<String, u64>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ModelUsage {
    pub input_tokens: u64,
    pub output_tokens: u64,
    pub cache_read_input_tokens: u64,
    pub cache_creation_input_tokens: u64,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LongestSession {
    pub duration: u64,
    pub message_count: u32,
}

/// Response types for frontend
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct InsightsData {
    pub period: String,
    pub comparison: PeriodComparison,
    pub daily_activity: Vec<DailyActivityPoint>,
    pub sessions_per_day: Vec<DailyActivityPoint>,
    pub peak_activity: PeakActivity,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PeriodComparison {
    pub messages: MetricComparison,
    pub sessions: MetricComparison,
    pub tokens: MetricComparison,
    pub estimated_cost: MetricComparison,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct MetricComparison {
    pub current: f64,
    pub previous: f64,
    pub percent_change: Option<f64>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DailyActivityPoint {
    pub date: String,
    pub value: f64,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PeakActivity {
    pub most_active_hour: Option<u32>,
    pub longest_session_minutes: Option<u32>,
    pub current_streak: u32,
    pub member_since: Option<String>,
}

impl MetricComparison {
    pub fn new(current: f64, previous: f64) -> Self {
        let percent_change = if previous > 0.0 {
            Some(((current - previous) / previous) * 100.0)
        } else if current > 0.0 {
            Some(100.0)
        } else {
            None
        };
        Self {
            current,
            previous,
            percent_change,
        }
    }
}

pub fn get_stats_cache_path() -> Option<PathBuf> {
    dirs::home_dir().map(|h| h.join(".claude").join("stats-cache.json"))
}

pub fn load_stats_cache() -> Result<StatsCache, String> {
    let path = get_stats_cache_path().ok_or("Could not find home directory")?;
    let contents = fs::read_to_string(&path)
        .map_err(|_| "Stats cache file not found. Use Claude Code to generate usage data.")?;
    serde_json::from_str(&contents).map_err(|e| format!("Failed to parse stats cache: {}", e))
}

fn get_period_dates(period: &str) -> (NaiveDate, NaiveDate, NaiveDate, NaiveDate) {
    let today = Local::now().date_naive();

    match period {
        "this_week" => {
            let week_start =
                today - Duration::days(today.weekday().num_days_from_monday() as i64);
            let prev_week_start = week_start - Duration::days(7);
            let prev_week_end = week_start - Duration::days(1);
            (week_start, today, prev_week_start, prev_week_end)
        }
        "this_month" => {
            let month_start = NaiveDate::from_ymd_opt(today.year(), today.month(), 1).unwrap();
            let prev_month_end = month_start - Duration::days(1);
            let prev_month_start =
                NaiveDate::from_ymd_opt(prev_month_end.year(), prev_month_end.month(), 1).unwrap();
            (month_start, today, prev_month_start, prev_month_end)
        }
        _ => {
            // last_7_days
            let start = today - Duration::days(6);
            let prev_end = start - Duration::days(1);
            let prev_start = prev_end - Duration::days(6);
            (start, today, prev_start, prev_end)
        }
    }
}

fn sum_activity_in_range(
    activities: &[DailyActivity],
    start: NaiveDate,
    end: NaiveDate,
) -> (u32, u32) {
    let mut messages = 0u32;
    let mut sessions = 0u32;

    for activity in activities {
        if let Ok(date) = NaiveDate::parse_from_str(&activity.date, "%Y-%m-%d") {
            if date >= start && date <= end {
                messages += activity.message_count;
                sessions += activity.session_count;
            }
        }
    }
    (messages, sessions)
}

fn sum_tokens_in_range(
    daily_tokens: &Option<Vec<DailyModelTokens>>,
    start: NaiveDate,
    end: NaiveDate,
) -> u64 {
    let Some(tokens) = daily_tokens else { return 0 };

    let mut total = 0u64;
    for day in tokens {
        if let Ok(date) = NaiveDate::parse_from_str(&day.date, "%Y-%m-%d") {
            if date >= start && date <= end {
                total += day.tokens_by_model.values().sum::<u64>();
            }
        }
    }
    total
}

fn calculate_cost(tokens: u64, pricing_provider: &str) -> f64 {
    // Simplified cost calculation (using average of input/output rates)
    // Opus 4.5: ~$15/1M tokens average
    let rate_per_million = match pricing_provider {
        "google-vertex" => 16.5, // 10% premium
        _ => 15.0,               // anthropic, aws-bedrock
    };
    (tokens as f64 / 1_000_000.0) * rate_per_million
}

fn find_peak_hour(hour_counts: &Option<HashMap<String, u32>>) -> Option<u32> {
    hour_counts.as_ref().and_then(|counts| {
        counts
            .iter()
            .max_by_key(|(_, &v)| v)
            .and_then(|(k, _)| k.parse().ok())
    })
}

fn get_daily_activity_points(
    activities: &[DailyActivity],
    start: NaiveDate,
    end: NaiveDate,
) -> Vec<DailyActivityPoint> {
    activities
        .iter()
        .filter_map(|a| {
            let date = NaiveDate::parse_from_str(&a.date, "%Y-%m-%d").ok()?;
            if date >= start && date <= end {
                Some(DailyActivityPoint {
                    date: a.date.clone(),
                    value: a.message_count as f64,
                })
            } else {
                None
            }
        })
        .collect()
}

fn get_sessions_per_day_points(
    activities: &[DailyActivity],
    start: NaiveDate,
    end: NaiveDate,
) -> Vec<DailyActivityPoint> {
    activities
        .iter()
        .filter_map(|a| {
            let date = NaiveDate::parse_from_str(&a.date, "%Y-%m-%d").ok()?;
            if date >= start && date <= end {
                Some(DailyActivityPoint {
                    date: a.date.clone(),
                    value: a.session_count as f64,
                })
            } else {
                None
            }
        })
        .collect()
}

pub fn compute_insights(period: &str, pricing_provider: &str) -> Result<InsightsData, String> {
    let cache = load_stats_cache()?;
    let (curr_start, curr_end, prev_start, prev_end) = get_period_dates(period);

    // Calculate comparisons
    let (curr_msgs, curr_sess) = sum_activity_in_range(&cache.daily_activity, curr_start, curr_end);
    let (prev_msgs, prev_sess) = sum_activity_in_range(&cache.daily_activity, prev_start, prev_end);

    let curr_tokens = sum_tokens_in_range(&cache.daily_model_tokens, curr_start, curr_end);
    let prev_tokens = sum_tokens_in_range(&cache.daily_model_tokens, prev_start, prev_end);

    let curr_cost = calculate_cost(curr_tokens, pricing_provider);
    let prev_cost = calculate_cost(prev_tokens, pricing_provider);

    let comparison = PeriodComparison {
        messages: MetricComparison::new(curr_msgs as f64, prev_msgs as f64),
        sessions: MetricComparison::new(curr_sess as f64, prev_sess as f64),
        tokens: MetricComparison::new(curr_tokens as f64, prev_tokens as f64),
        estimated_cost: MetricComparison::new(curr_cost, prev_cost),
    };

    // Calculate streak
    let today = Local::now().date_naive();
    let yesterday = today - Duration::days(1);
    let mut sorted_dates: Vec<NaiveDate> = cache
        .daily_activity
        .iter()
        .filter(|a| a.message_count > 0)
        .filter_map(|a| NaiveDate::parse_from_str(&a.date, "%Y-%m-%d").ok())
        .collect();
    sorted_dates.sort();
    sorted_dates.reverse();

    let mut streak = 0u32;
    let mut expected = yesterday;
    for date in &sorted_dates {
        if *date == expected || *date == today {
            streak += 1;
            expected = *date - Duration::days(1);
        } else if *date < expected {
            break;
        }
    }

    let peak_activity = PeakActivity {
        most_active_hour: find_peak_hour(&cache.hour_counts),
        longest_session_minutes: cache
            .longest_session
            .as_ref()
            .map(|s| (s.duration / 60000) as u32),
        current_streak: streak,
        member_since: cache.first_session_date.clone(),
    };

    let daily_activity = get_daily_activity_points(&cache.daily_activity, curr_start, curr_end);
    let sessions_per_day = get_sessions_per_day_points(&cache.daily_activity, curr_start, curr_end);

    Ok(InsightsData {
        period: period.to_string(),
        comparison,
        daily_activity,
        sessions_per_day,
        peak_activity,
    })
}

#[tauri::command]
pub async fn get_insights_data(
    period: String,
    pricing_provider: String,
) -> Result<InsightsData, String> {
    compute_insights(&period, &pricing_provider)
}

/// Response type for local stats cache view
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct LocalStatsCacheData {
    pub total_tokens: u64,
    pub total_sessions: u32,
    pub total_messages: u32,
    pub active_days: u32,
    pub avg_messages_per_day: f64,
    pub estimated_cost: f64,
    pub peak_hour: Option<u32>,
    pub first_session: Option<String>,
    pub daily_activity: Vec<DailyActivityPoint>,
    pub tokens_by_model: Vec<ModelTokens>,
    pub activity_by_hour: Vec<HourActivity>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ModelTokens {
    pub model: String,
    pub tokens: u64,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct HourActivity {
    pub hour: u32,
    pub count: u32,
}

#[tauri::command]
pub async fn get_local_stats_cache(pricing_provider: String) -> Result<LocalStatsCacheData, String> {
    let cache = load_stats_cache()?;

    // Calculate totals
    let total_tokens: u64 = cache.daily_model_tokens
        .as_ref()
        .map(|days| days.iter().map(|d| d.tokens_by_model.values().sum::<u64>()).sum())
        .unwrap_or(0);

    let total_messages: u32 = cache.daily_activity.iter().map(|d| d.message_count).sum();
    let total_sessions = cache.total_sessions;
    let active_days = cache.daily_activity.iter().filter(|d| d.message_count > 0).count() as u32;

    let avg_messages_per_day = if active_days > 0 {
        total_messages as f64 / active_days as f64
    } else {
        0.0
    };

    let estimated_cost = calculate_cost(total_tokens, &pricing_provider);
    let peak_hour = find_peak_hour(&cache.hour_counts);

    // Get all daily activity
    let daily_activity: Vec<DailyActivityPoint> = cache.daily_activity
        .iter()
        .map(|a| DailyActivityPoint {
            date: a.date.clone(),
            value: a.message_count as f64,
        })
        .collect();

    // Get tokens by model
    let tokens_by_model: Vec<ModelTokens> = cache.daily_model_tokens
        .as_ref()
        .map(|days| {
            let mut model_totals: HashMap<String, u64> = HashMap::new();
            for day in days {
                for (model, tokens) in &day.tokens_by_model {
                    *model_totals.entry(model.clone()).or_insert(0) += tokens;
                }
            }
            let mut result: Vec<_> = model_totals.into_iter()
                .map(|(model, tokens)| ModelTokens { model, tokens })
                .collect();
            result.sort_by(|a, b| b.tokens.cmp(&a.tokens));
            result
        })
        .unwrap_or_default();

    // Get activity by hour
    let activity_by_hour: Vec<HourActivity> = cache.hour_counts
        .as_ref()
        .map(|counts| {
            let mut result: Vec<_> = counts.iter()
                .filter_map(|(h, &count)| h.parse::<u32>().ok().map(|hour| HourActivity { hour, count }))
                .collect();
            result.sort_by_key(|a| a.hour);
            result
        })
        .unwrap_or_default();

    Ok(LocalStatsCacheData {
        total_tokens,
        total_sessions,
        total_messages,
        active_days,
        avg_messages_per_day,
        estimated_cost,
        peak_hour,
        first_session: cache.first_session_date,
        daily_activity,
        tokens_by_model,
        activity_by_hour,
    })
}
