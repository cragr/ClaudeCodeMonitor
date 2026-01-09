// tauri-app/src-tauri/src/sessions.rs

use crate::prometheus::PrometheusClient;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs::File;
use std::io::{BufRead, BufReader};
use std::path::PathBuf;

/// Entry from ~/.claude/history.jsonl
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct HistoryEntry {
    timestamp: i64,
    project: String,
    session_id: String,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SessionMetrics {
    pub session_id: String,
    pub project: Option<String>,
    pub project_path: Option<String>,
    pub timestamp: i64,
    pub message_count: u32,
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
pub struct ProjectStats {
    pub project: String,
    pub project_path: Option<String>,
    pub session_count: u32,
    pub total_cost_usd: f64,
    pub total_tokens: u64,
    pub active_time_seconds: f64,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SessionsData {
    pub sessions: Vec<SessionMetrics>,
    pub projects: Vec<ProjectStats>,
    pub total_count: usize,
}

fn get_history_path() -> Option<PathBuf> {
    dirs::home_dir().map(|h| h.join(".claude").join("history.jsonl"))
}

/// Extract the last folder name from a path
fn extract_project_name(path: &str) -> String {
    std::path::Path::new(path)
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or(path)
        .to_string()
}

/// Calculate how far back to look based on time range
fn time_range_to_millis(range: &str) -> i64 {
    let hours = match range {
        "1h" => 1,
        "8h" => 8,
        "24h" => 24,
        "2d" => 48,
        "7d" => 168,
        "30d" => 720,
        _ => 24,
    };
    hours * 60 * 60 * 1000
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

fn load_history_sessions(time_range: &str) -> Result<HashMap<String, SessionMetrics>, String> {
    let path = get_history_path().ok_or("Could not find home directory")?;
    let file = File::open(&path)
        .map_err(|_| "History file not found. Use Claude Code to generate usage data.")?;
    let reader = BufReader::new(file);

    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_millis() as i64;
    let cutoff = now - time_range_to_millis(time_range);

    let mut sessions_map: HashMap<String, SessionMetrics> = HashMap::new();

    for line in reader.lines() {
        let line = line.map_err(|e| format!("Failed to read line: {}", e))?;
        if line.trim().is_empty() {
            continue;
        }

        let entry: HistoryEntry = match serde_json::from_str(&line) {
            Ok(e) => e,
            Err(_) => continue,
        };

        if entry.timestamp < cutoff {
            continue;
        }

        let project_name = extract_project_name(&entry.project);

        sessions_map
            .entry(entry.session_id.clone())
            .and_modify(|s| {
                s.message_count += 1;
                if entry.timestamp > s.timestamp {
                    s.timestamp = entry.timestamp;
                }
            })
            .or_insert(SessionMetrics {
                session_id: entry.session_id,
                project: Some(project_name),
                project_path: Some(entry.project),
                timestamp: entry.timestamp,
                message_count: 1,
                total_cost_usd: 0.0,
                total_tokens: 0,
                input_tokens: 0,
                output_tokens: 0,
                cache_read_tokens: 0,
                cache_creation_tokens: 0,
                active_time_seconds: 0.0,
                tokens_by_model: vec![],
            });
    }

    Ok(sessions_map)
}

async fn enrich_with_prometheus(
    sessions_map: &mut HashMap<String, SessionMetrics>,
    prometheus_url: &str,
    time_range: &str,
) -> Result<(), String> {
    let client = PrometheusClient::new(prometheus_url);
    let range = time_range_to_promql(time_range);

    // Query cost by session
    let cost_query = format!(
        "sum by (session_id) (increase(claude_code_cost_usage_USD_total[{}]))",
        range
    );
    if let Ok(cost_results) = client.query(&cost_query).await {
        for result in &cost_results {
            if let Some(session_id) = result.metric.get("session_id") {
                if let Some(session) = sessions_map.get_mut(session_id) {
                    session.total_cost_usd = result
                        .value
                        .as_ref()
                        .and_then(|(_, v)| v.parse::<f64>().ok())
                        .unwrap_or(0.0);
                }
            }
        }
    }

    // Query total tokens by session
    let tokens_query = format!(
        "sum by (session_id) (increase(claude_code_token_usage_tokens_total[{}]))",
        range
    );
    if let Ok(tokens_results) = client.query(&tokens_query).await {
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
    }

    // Query tokens by type
    let type_query = format!(
        "sum by (session_id, type) (increase(claude_code_token_usage_tokens_total[{}]))",
        range
    );
    if let Ok(type_results) = client.query(&type_query).await {
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
    }

    // Query active time by session
    let time_query = format!(
        "sum by (session_id) (increase(claude_code_active_time_seconds_total[{}]))",
        range
    );
    if let Ok(time_results) = client.query(&time_query).await {
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
    }

    Ok(())
}

fn aggregate_by_project(sessions: &[SessionMetrics]) -> Vec<ProjectStats> {
    let mut project_map: HashMap<String, ProjectStats> = HashMap::new();

    for session in sessions {
        let project_name = session.project.clone().unwrap_or_else(|| "Unknown".to_string());

        project_map
            .entry(project_name.clone())
            .and_modify(|p| {
                p.session_count += 1;
                p.total_cost_usd += session.total_cost_usd;
                p.total_tokens += session.total_tokens;
                p.active_time_seconds += session.active_time_seconds;
            })
            .or_insert(ProjectStats {
                project: project_name,
                project_path: session.project_path.clone(),
                session_count: 1,
                total_cost_usd: session.total_cost_usd,
                total_tokens: session.total_tokens,
                active_time_seconds: session.active_time_seconds,
            });
    }

    let mut projects: Vec<ProjectStats> = project_map.into_values().collect();
    projects.sort_by(|a, b| b.total_cost_usd.partial_cmp(&a.total_cost_usd).unwrap_or(std::cmp::Ordering::Equal));
    projects
}

#[tauri::command]
pub async fn get_sessions_data(
    time_range: String,
    prometheus_url: String,
) -> Result<SessionsData, String> {
    // Load sessions from history.jsonl
    let mut sessions_map = load_history_sessions(&time_range)?;

    // Enrich with Prometheus data (cost, tokens, time)
    let _ = enrich_with_prometheus(&mut sessions_map, &prometheus_url, &time_range).await;

    // Convert to sorted vec (by cost descending, then by timestamp)
    let mut sessions: Vec<SessionMetrics> = sessions_map.into_values().collect();
    sessions.sort_by(|a, b| {
        b.total_cost_usd
            .partial_cmp(&a.total_cost_usd)
            .unwrap_or(std::cmp::Ordering::Equal)
            .then_with(|| b.timestamp.cmp(&a.timestamp))
    });

    // Aggregate by project
    let projects = aggregate_by_project(&sessions);

    let total_count = sessions.len();

    Ok(SessionsData {
        sessions,
        projects,
        total_count,
    })
}
