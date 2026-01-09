use crate::metrics::{DashboardMetrics, ModelTokens, TimeSeriesPoint};
use crate::prometheus::PrometheusClient;
use crate::prometheus_health::{fetch_prometheus_health, PrometheusHealthMetrics};
use std::time::{SystemTime, UNIX_EPOCH};

fn time_range_to_seconds(range: &str) -> i64 {
    match range {
        "15m" => 15 * 60,
        "1h" => 3600,
        "4h" => 4 * 3600,
        "1d" => 24 * 3600,
        "7d" => 7 * 24 * 3600,
        "30d" => 30 * 24 * 3600,
        "90d" => 90 * 24 * 3600,
        _ => 15 * 60,
    }
}

fn time_range_to_promql(range: &str) -> &str {
    match range {
        "15m" => "15m",
        "1h" => "1h",
        "4h" => "4h",
        "1d" => "1d",
        "7d" => "7d",
        "30d" => "30d",
        "90d" => "90d",
        _ => "15m",
    }
}

#[tauri::command]
pub async fn get_dashboard_metrics(
    time_range: String,
    prometheus_url: String,
    custom_start: Option<i64>,
    custom_end: Option<i64>,
) -> Result<DashboardMetrics, String> {
    let client = PrometheusClient::new(&prometheus_url);

    // Determine if we're using custom range or preset
    let (start_time, end_time, range_str) = if time_range == "custom" {
        let start = custom_start.ok_or("Custom start time required")?;
        let end = custom_end.ok_or("Custom end time required")?;
        let duration_secs = end - start;
        // Create a range string for Prometheus (e.g., "86400s" for 1 day)
        let range = format!("{}s", duration_secs);
        (start, end, range)
    } else {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs() as i64;
        let duration = time_range_to_seconds(&time_range);
        let start = now - duration;
        (start, now, time_range_to_promql(&time_range).to_string())
    };

    let range = &range_str;

    // Query for total tokens
    let tokens_query = format!(
        "sum(increase(claude_code_token_usage_tokens_total[{}]))",
        range
    );
    let total_tokens = client
        .query(&tokens_query)
        .await
        .map_err(|e| e.to_string())?
        .first()
        .and_then(|r| r.value.as_ref())
        .and_then(|(_, v)| v.parse::<f64>().ok())
        .unwrap_or(0.0) as u64;

    // Query for input tokens
    let input_query = format!(
        "sum(increase(claude_code_token_usage_tokens_total{{type=\"input\"}}[{}]))",
        range
    );
    let input_tokens = client
        .query(&input_query)
        .await
        .map_err(|e| e.to_string())?
        .first()
        .and_then(|r| r.value.as_ref())
        .and_then(|(_, v)| v.parse::<f64>().ok())
        .unwrap_or(0.0) as u64;

    // Query for output tokens
    let output_query = format!(
        "sum(increase(claude_code_token_usage_tokens_total{{type=\"output\"}}[{}]))",
        range
    );
    let output_tokens = client
        .query(&output_query)
        .await
        .map_err(|e| e.to_string())?
        .first()
        .and_then(|r| r.value.as_ref())
        .and_then(|(_, v)| v.parse::<f64>().ok())
        .unwrap_or(0.0) as u64;

    // Query for cache read tokens (try both naming conventions)
    let cache_read_query = format!(
        "sum(increase(claude_code_token_usage_tokens_total{{type=~\"cache_read|cacheRead\"}}[{}]))",
        range
    );
    let cache_read_tokens = client
        .query(&cache_read_query)
        .await
        .map_err(|e| e.to_string())?
        .first()
        .and_then(|r| r.value.as_ref())
        .and_then(|(_, v)| v.parse::<f64>().ok())
        .unwrap_or(0.0) as u64;

    // Query for cache creation tokens (try both naming conventions)
    let cache_creation_query = format!(
        "sum(increase(claude_code_token_usage_tokens_total{{type=~\"cache_creation|cacheCreation\"}}[{}]))",
        range
    );
    let cache_creation_tokens = client
        .query(&cache_creation_query)
        .await
        .map_err(|e| e.to_string())?
        .first()
        .and_then(|r| r.value.as_ref())
        .and_then(|(_, v)| v.parse::<f64>().ok())
        .unwrap_or(0.0) as u64;

    // Query for total cost
    let cost_query = format!(
        "sum(increase(claude_code_cost_usage_USD_total[{}]))",
        range
    );
    let total_cost_usd = client
        .query(&cost_query)
        .await
        .map_err(|e| e.to_string())?
        .first()
        .and_then(|r| r.value.as_ref())
        .and_then(|(_, v)| v.parse::<f64>().ok())
        .unwrap_or(0.0);

    // Query for active time
    let time_query = format!(
        "sum(increase(claude_code_active_time_seconds_total[{}]))",
        range
    );
    let active_time_seconds = client
        .query(&time_query)
        .await
        .map_err(|e| e.to_string())?
        .first()
        .and_then(|r| r.value.as_ref())
        .and_then(|(_, v)| v.parse::<f64>().ok())
        .unwrap_or(0.0);

    // Query for session count
    let session_query = format!(
        "sum(increase(claude_code_session_count_total[{}]))",
        range
    );
    let session_count = client
        .query(&session_query)
        .await
        .map_err(|e| e.to_string())?
        .first()
        .and_then(|r| r.value.as_ref())
        .and_then(|(_, v)| v.parse::<f64>().ok())
        .unwrap_or(0.0) as u32;

    // Query for lines added
    let lines_added_query = format!(
        "sum(increase(claude_code_lines_of_code_count_total{{type=\"added\"}}[{}]))",
        range
    );
    let lines_added = client
        .query(&lines_added_query)
        .await
        .map_err(|e| e.to_string())?
        .first()
        .and_then(|r| r.value.as_ref())
        .and_then(|(_, v)| v.parse::<f64>().ok())
        .unwrap_or(0.0) as u64;

    // Query for lines removed
    let lines_removed_query = format!(
        "sum(increase(claude_code_lines_of_code_count_total{{type=\"removed\"}}[{}]))",
        range
    );
    let lines_removed = client
        .query(&lines_removed_query)
        .await
        .map_err(|e| e.to_string())?
        .first()
        .and_then(|r| r.value.as_ref())
        .and_then(|(_, v)| v.parse::<f64>().ok())
        .unwrap_or(0.0) as u64;

    // Query for commit count
    let commit_query = format!(
        "sum(increase(claude_code_commit_count_total[{}]))",
        range
    );
    let commit_count = client
        .query(&commit_query)
        .await
        .map_err(|e| e.to_string())?
        .first()
        .and_then(|r| r.value.as_ref())
        .and_then(|(_, v)| v.parse::<f64>().ok())
        .unwrap_or(0.0) as u32;

    // Query for PR count
    let pr_query = format!(
        "sum(increase(claude_code_pull_request_count_total[{}]))",
        range
    );
    let pull_request_count = client
        .query(&pr_query)
        .await
        .map_err(|e| e.to_string())?
        .first()
        .and_then(|r| r.value.as_ref())
        .and_then(|(_, v)| v.parse::<f64>().ok())
        .unwrap_or(0.0) as u32;

    // Query for tokens by model
    let model_query = format!(
        "sum by (model) (increase(claude_code_token_usage_tokens_total[{}]))",
        range
    );
    let tokens_by_model: Vec<ModelTokens> = client
        .query(&model_query)
        .await
        .map_err(|e| e.to_string())?
        .iter()
        .filter_map(|r| {
            let model = r.metric.get("model")?.clone();
            let tokens = r.value.as_ref()?.1.parse::<f64>().ok()? as u64;
            Some(ModelTokens { model, tokens })
        })
        .collect();

    // Query for tokens over time with resolution based on time range
    // 15m, 1h -> 1 minute intervals with 5m rate window
    // 4h -> 5 minute intervals with 5m rate window
    // 1d -> 1 hour intervals with 1h rate window
    // 7d -> 6 hour intervals with 6h rate window
    // 30d -> 1 day intervals with 1d rate window
    // 90d -> 3 day intervals with 3d rate window
    let (step, rate_window) = match time_range.as_str() {
        "15m" => ("1m", "5m"),
        "1h" => ("1m", "5m"),
        "4h" => ("5m", "5m"),
        "1d" => ("1h", "1h"),
        "7d" => ("6h", "6h"),
        "30d" => ("1d", "1d"),
        "90d" => ("3d", "3d"),
        "custom" => {
            // For custom ranges, choose step and rate window based on duration
            let duration = end_time - start_time;
            if duration <= 3600 {
                ("1m", "5m")
            } else if duration <= 4 * 3600 {
                ("5m", "5m")
            } else if duration <= 24 * 3600 {
                ("1h", "1h")
            } else if duration <= 7 * 24 * 3600 {
                ("6h", "6h")
            } else if duration <= 30 * 24 * 3600 {
                ("1d", "1d")
            } else {
                ("3d", "3d")
            }
        }
        _ => ("1m", "5m"),
    };

    // Query rate per step interval using rate() with window matching step size
    // This gives us per-second rate, frontend does cumulative sum and scales to match total
    let range_query = format!("sum(rate(claude_code_cost_usage_USD_total[{}]))", rate_window);

    let query_result = client
        .query_range(&range_query, start_time, end_time, step)
        .await
        .map_err(|e| e.to_string())?;

    let tokens_over_time: Vec<TimeSeriesPoint> = query_result
        .first()
        .and_then(|r| r.values.as_ref())
        .map(|values| {
            values
                .iter()
                .map(|(ts, v)| TimeSeriesPoint {
                    timestamp: *ts as i64,
                    value: v.parse::<f64>().unwrap_or(0.0),
                })
                .collect()
        })
        .unwrap_or_default();

    Ok(DashboardMetrics {
        total_tokens,
        total_cost_usd,
        active_time_seconds,
        session_count,
        lines_added,
        lines_removed,
        commit_count,
        pull_request_count,
        tokens_by_model,
        tokens_over_time,
        input_tokens,
        output_tokens,
        cache_read_tokens,
        cache_creation_tokens,
    })
}

#[tauri::command]
pub async fn test_connection(url: String) -> Result<bool, String> {
    let client = PrometheusClient::new(&url);
    client.test_connection().await.map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn discover_metrics(url: String) -> Result<Vec<String>, String> {
    let client = PrometheusClient::new(&url);
    client.discover_metrics().await.map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn get_prometheus_health(
    prometheus_url: String,
    time_range: Option<String>,
    custom_start: Option<i64>,
    custom_end: Option<i64>,
) -> Result<PrometheusHealthMetrics, String> {
    println!("get_prometheus_health: starting");
    let client = PrometheusClient::new(&prometheus_url);

    // Calculate time range for sparklines
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_secs() as i64;

    let (start_time, end_time) = if time_range.as_deref() == Some("custom") {
        let start = custom_start.ok_or("Custom start time required")?;
        let end = custom_end.ok_or("Custom end time required")?;
        (start, end)
    } else {
        let duration = match time_range.as_deref() {
            Some("15m") => 15 * 60,
            Some("1h") => 3600,
            Some("4h") => 4 * 3600,
            Some("1d") => 24 * 3600,
            Some("7d") => 7 * 24 * 3600,
            Some("30d") => 30 * 24 * 3600,
            Some("90d") => 90 * 24 * 3600,
            _ => 3600, // Default to 1 hour
        };
        (now - duration, now)
    };

    println!("get_prometheus_health: calling fetch_prometheus_health");
    let result = fetch_prometheus_health(&client, start_time, end_time).await;
    println!("get_prometheus_health: fetch_prometheus_health returned");
    result
}
