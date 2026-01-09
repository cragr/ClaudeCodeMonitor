use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DashboardMetrics {
    pub total_tokens: u64,
    pub total_cost_usd: f64,
    pub active_time_seconds: f64,
    pub session_count: u32,
    pub lines_added: u64,
    pub lines_removed: u64,
    pub commit_count: u32,
    pub pull_request_count: u32,
    pub tokens_by_model: Vec<ModelTokens>,
    pub tokens_over_time: Vec<TimeSeriesPoint>,
    // Token type breakdown
    pub input_tokens: u64,
    pub output_tokens: u64,
    pub cache_read_tokens: u64,
    pub cache_creation_tokens: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ModelTokens {
    pub model: String,
    pub tokens: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TimeSeriesPoint {
    pub timestamp: i64,
    pub value: f64,
}
