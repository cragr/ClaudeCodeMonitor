use crate::metrics::{DashboardMetrics, ModelTokens, TimeSeriesPoint};
use crate::prometheus::PrometheusClient;
use std::time::{SystemTime, UNIX_EPOCH};

fn time_range_to_seconds(range: &str) -> i64 {
    match range {
        "1h" => 3600,
        "8h" => 8 * 3600,
        "24h" => 24 * 3600,
        "2d" => 2 * 24 * 3600,
        "7d" => 7 * 24 * 3600,
        "30d" => 30 * 24 * 3600,
        _ => 24 * 3600,
    }
}

fn time_range_to_promql(range: &str) -> &str {
    match range {
        "1h" => "1h",
        "8h" => "8h",
        "24h" => "24h",
        "2d" => "2d",
        "7d" => "7d",
        "30d" => "30d",
        _ => "24h",
    }
}

#[tauri::command]
pub async fn get_dashboard_metrics(
    time_range: String,
    prometheus_url: String,
) -> Result<DashboardMetrics, String> {
    let client = PrometheusClient::new(&prometheus_url);
    let range = time_range_to_promql(&time_range);

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

    // Query for tokens over time
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs() as i64;
    let start = now - time_range_to_seconds(&time_range);
    let step = if time_range_to_seconds(&time_range) > 86400 {
        "1h"
    } else {
        "5m"
    };

    let range_query = "sum(rate(claude_code_token_usage_tokens_total[5m])) * 300";
    let tokens_over_time: Vec<TimeSeriesPoint> = client
        .query_range(range_query, start, now, step)
        .await
        .map_err(|e| e.to_string())?
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
    })
}

#[tauri::command]
pub async fn test_connection(url: String) -> Result<bool, String> {
    let client = PrometheusClient::new(&url);
    client.test_connection().await.map_err(|e| e.to_string())
}
