// tauri-app/src-tauri/src/insights.rs

use chrono::NaiveDate;
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
