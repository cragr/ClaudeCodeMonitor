// tauri-app/src-tauri/src/sessions.rs

use crate::prometheus::PrometheusClient;
use serde::Serialize;
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SessionMetrics {
    pub session_id: String,
    pub total_cost_usd: f64,
    pub total_tokens: u64,
    pub input_tokens: u64,
    pub output_tokens: u64,
    pub cache_read_tokens: u64,
    pub cache_creation_tokens: u64,
    pub active_time_seconds: f64,
    pub tokens_by_model: Vec<ModelTokenCount>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ModelTokenCount {
    pub model: String,
    pub tokens: u64,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SessionsData {
    pub sessions: Vec<SessionMetrics>,
    pub total_count: usize,
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

pub async fn fetch_sessions(
    prometheus_url: &str,
    time_range: &str,
) -> Result<SessionsData, String> {
    let client = PrometheusClient::new(prometheus_url);
    let range = time_range_to_promql(time_range);

    // Query cost by session
    let cost_query = format!(
        "sum by (session_id) (increase(claude_code_cost_usage_USD_total[{}]))",
        range
    );
    let cost_results = client.query(&cost_query).await.map_err(|e| e.to_string())?;

    // Build session map from cost results (cost identifies active sessions)
    let mut sessions_map: HashMap<String, SessionMetrics> = HashMap::new();
    for result in &cost_results {
        if let Some(session_id) = result.metric.get("session_id") {
            if session_id.is_empty() {
                continue;
            }
            let cost = result
                .value
                .as_ref()
                .and_then(|(_, v)| v.parse::<f64>().ok())
                .unwrap_or(0.0);

            if cost > 0.0 {
                sessions_map.insert(
                    session_id.clone(),
                    SessionMetrics {
                        session_id: session_id.clone(),
                        total_cost_usd: cost,
                        total_tokens: 0,
                        input_tokens: 0,
                        output_tokens: 0,
                        cache_read_tokens: 0,
                        cache_creation_tokens: 0,
                        active_time_seconds: 0.0,
                        tokens_by_model: vec![],
                    },
                );
            }
        }
    }

    // Query total tokens by session
    let tokens_query = format!(
        "sum by (session_id) (increase(claude_code_token_usage_tokens_total[{}]))",
        range
    );
    let tokens_results = client.query(&tokens_query).await.map_err(|e| e.to_string())?;
    for result in &tokens_results {
        if let Some(session_id) = result.metric.get("session_id") {
            if let Some(session) = sessions_map.get_mut(session_id) {
                session.total_tokens = result
                    .value
                    .as_ref()
                    .and_then(|(_, v)| v.parse::<f64>().ok())
                    .unwrap_or(0.0) as u64;
            }
        }
    }

    // Query tokens by type
    let type_query = format!(
        "sum by (session_id, type) (increase(claude_code_token_usage_tokens_total[{}]))",
        range
    );
    let type_results = client.query(&type_query).await.map_err(|e| e.to_string())?;
    for result in &type_results {
        if let (Some(session_id), Some(token_type)) =
            (result.metric.get("session_id"), result.metric.get("type"))
        {
            if let Some(session) = sessions_map.get_mut(session_id) {
                let tokens = result
                    .value
                    .as_ref()
                    .and_then(|(_, v)| v.parse::<f64>().ok())
                    .unwrap_or(0.0) as u64;

                match token_type.as_str() {
                    "input" => session.input_tokens = tokens,
                    "output" => session.output_tokens = tokens,
                    "cache_read" => session.cache_read_tokens = tokens,
                    "cache_creation" => session.cache_creation_tokens = tokens,
                    _ => {}
                }
            }
        }
    }

    // Query active time by session
    let time_query = format!(
        "sum by (session_id) (increase(claude_code_active_time_seconds_total[{}]))",
        range
    );
    let time_results = client.query(&time_query).await.map_err(|e| e.to_string())?;
    for result in &time_results {
        if let Some(session_id) = result.metric.get("session_id") {
            if let Some(session) = sessions_map.get_mut(session_id) {
                session.active_time_seconds = result
                    .value
                    .as_ref()
                    .and_then(|(_, v)| v.parse::<f64>().ok())
                    .unwrap_or(0.0);
            }
        }
    }

    // Query tokens by model per session
    let model_query = format!(
        "sum by (session_id, model) (increase(claude_code_token_usage_tokens_total[{}]))",
        range
    );
    let model_results = client.query(&model_query).await.map_err(|e| e.to_string())?;
    for result in &model_results {
        if let (Some(session_id), Some(model)) =
            (result.metric.get("session_id"), result.metric.get("model"))
        {
            if let Some(session) = sessions_map.get_mut(session_id) {
                let tokens = result
                    .value
                    .as_ref()
                    .and_then(|(_, v)| v.parse::<f64>().ok())
                    .unwrap_or(0.0) as u64;

                if tokens > 0 {
                    session.tokens_by_model.push(ModelTokenCount {
                        model: model.clone(),
                        tokens,
                    });
                }
            }
        }
    }

    // Convert map to sorted vec (by cost descending)
    let mut sessions: Vec<SessionMetrics> = sessions_map.into_values().collect();
    sessions.sort_by(|a, b| b.total_cost_usd.partial_cmp(&a.total_cost_usd).unwrap());

    let total_count = sessions.len();

    Ok(SessionsData {
        sessions,
        total_count,
    })
}

#[tauri::command]
pub async fn get_sessions_data(
    time_range: String,
    prometheus_url: String,
) -> Result<SessionsData, String> {
    fetch_sessions(&prometheus_url, &time_range).await
}
