use serde::{Deserialize, Serialize};

use crate::prometheus::PrometheusClient;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PrometheusHealthMetrics {
    // Status
    pub is_ready: bool,
    pub uptime_seconds: f64,
    pub version: String,
    pub go_version: String,

    // Storage
    pub storage_blocks_bytes: f64,
    pub storage_wal_bytes: f64,
    pub storage_total_bytes: f64,
    pub storage_retention_limit_bytes: f64,
    pub storage_retention_limit_seconds: f64,
    pub head_series: f64,
    pub oldest_timestamp_seconds: f64,
    pub newest_timestamp_seconds: f64,
    pub blocks_loaded: f64,

    // Memory
    pub process_memory_bytes: f64,
    pub heap_inuse_bytes: f64,
    pub heap_alloc_bytes: f64,
    pub goroutines: f64,

    // CPU (rate value)
    pub cpu_seconds_rate: f64,

    // Ingestion rates
    pub samples_appended_rate: f64,
    pub series_created_rate: f64,

    // Scrape stats
    pub target_count: f64,
    pub scrape_duration_seconds: f64,
    pub scrape_samples: f64,

    // Health indicators
    pub compactions_failed: f64,
    pub compactions_total: f64,
    pub wal_corruptions: f64,
    pub config_reload_success: bool,
    pub config_reload_timestamp: f64,

    // Time series data for sparklines
    pub storage_over_time: Vec<TimeSeriesPoint>,
    pub memory_over_time: Vec<TimeSeriesPoint>,
    pub samples_rate_over_time: Vec<TimeSeriesPoint>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TimeSeriesPoint {
    pub timestamp: f64,
    pub value: f64,
}

impl Default for PrometheusHealthMetrics {
    fn default() -> Self {
        Self {
            is_ready: false,
            uptime_seconds: 0.0,
            version: String::new(),
            go_version: String::new(),
            storage_blocks_bytes: 0.0,
            storage_wal_bytes: 0.0,
            storage_total_bytes: 0.0,
            storage_retention_limit_bytes: 0.0,
            storage_retention_limit_seconds: 0.0,
            head_series: 0.0,
            oldest_timestamp_seconds: 0.0,
            newest_timestamp_seconds: 0.0,
            blocks_loaded: 0.0,
            process_memory_bytes: 0.0,
            heap_inuse_bytes: 0.0,
            heap_alloc_bytes: 0.0,
            goroutines: 0.0,
            cpu_seconds_rate: 0.0,
            samples_appended_rate: 0.0,
            series_created_rate: 0.0,
            target_count: 0.0,
            scrape_duration_seconds: 0.0,
            scrape_samples: 0.0,
            compactions_failed: 0.0,
            compactions_total: 0.0,
            wal_corruptions: 0.0,
            config_reload_success: false,
            config_reload_timestamp: 0.0,
            storage_over_time: Vec::new(),
            memory_over_time: Vec::new(),
            samples_rate_over_time: Vec::new(),
        }
    }
}

pub async fn fetch_prometheus_health(
    client: &PrometheusClient,
    start_time: i64,
    end_time: i64,
) -> Result<PrometheusHealthMetrics, String> {
    let mut metrics = PrometheusHealthMetrics::default();

    // Check if Prometheus is ready
    metrics.is_ready = client.test_connection().await.unwrap_or(false);

    // Fetch build info for version
    if let Ok(results) = client.query("prometheus_build_info").await {
        if let Some(result) = results.first() {
            metrics.version = result
                .metric
                .get("version")
                .cloned()
                .unwrap_or_default();
            metrics.go_version = result
                .metric
                .get("goversion")
                .cloned()
                .unwrap_or_default();
        }
    }

    // Uptime from process_start_time_seconds
    if let Ok(results) = client.query("time() - process_start_time_seconds").await {
        if let Some(result) = results.first() {
            if let Some((_, value)) = &result.value {
                metrics.uptime_seconds = value.parse().unwrap_or(0.0);
            }
        }
    }

    // Storage metrics
    if let Ok(results) = client.query("prometheus_tsdb_storage_blocks_bytes").await {
        if let Some(result) = results.first() {
            if let Some((_, value)) = &result.value {
                metrics.storage_blocks_bytes = value.parse().unwrap_or(0.0);
            }
        }
    }

    if let Ok(results) = client.query("prometheus_tsdb_wal_storage_size_bytes").await {
        if let Some(result) = results.first() {
            if let Some((_, value)) = &result.value {
                metrics.storage_wal_bytes = value.parse().unwrap_or(0.0);
            }
        }
    }

    metrics.storage_total_bytes = metrics.storage_blocks_bytes + metrics.storage_wal_bytes;

    if let Ok(results) = client.query("prometheus_tsdb_retention_limit_bytes").await {
        if let Some(result) = results.first() {
            if let Some((_, value)) = &result.value {
                metrics.storage_retention_limit_bytes = value.parse().unwrap_or(0.0);
            }
        }
    }

    if let Ok(results) = client.query("prometheus_tsdb_retention_limit_seconds").await {
        if let Some(result) = results.first() {
            if let Some((_, value)) = &result.value {
                metrics.storage_retention_limit_seconds = value.parse().unwrap_or(0.0);
            }
        }
    }

    if let Ok(results) = client.query("prometheus_tsdb_head_series").await {
        if let Some(result) = results.first() {
            if let Some((_, value)) = &result.value {
                metrics.head_series = value.parse().unwrap_or(0.0);
            }
        }
    }

    if let Ok(results) = client.query("prometheus_tsdb_lowest_timestamp_seconds").await {
        if let Some(result) = results.first() {
            if let Some((_, value)) = &result.value {
                metrics.oldest_timestamp_seconds = value.parse().unwrap_or(0.0);
            }
        }
    }

    if let Ok(results) = client.query("prometheus_tsdb_head_max_time_seconds").await {
        if let Some(result) = results.first() {
            if let Some((_, value)) = &result.value {
                metrics.newest_timestamp_seconds = value.parse().unwrap_or(0.0);
            }
        }
    }

    if let Ok(results) = client.query("prometheus_tsdb_blocks_loaded").await {
        if let Some(result) = results.first() {
            if let Some((_, value)) = &result.value {
                metrics.blocks_loaded = value.parse().unwrap_or(0.0);
            }
        }
    }

    // Memory metrics
    if let Ok(results) = client.query("process_resident_memory_bytes").await {
        if let Some(result) = results.first() {
            if let Some((_, value)) = &result.value {
                metrics.process_memory_bytes = value.parse().unwrap_or(0.0);
            }
        }
    }

    if let Ok(results) = client.query("go_memstats_heap_inuse_bytes").await {
        if let Some(result) = results.first() {
            if let Some((_, value)) = &result.value {
                metrics.heap_inuse_bytes = value.parse().unwrap_or(0.0);
            }
        }
    }

    if let Ok(results) = client.query("go_memstats_heap_alloc_bytes").await {
        if let Some(result) = results.first() {
            if let Some((_, value)) = &result.value {
                metrics.heap_alloc_bytes = value.parse().unwrap_or(0.0);
            }
        }
    }

    if let Ok(results) = client.query("go_goroutines").await {
        if let Some(result) = results.first() {
            if let Some((_, value)) = &result.value {
                metrics.goroutines = value.parse().unwrap_or(0.0);
            }
        }
    }

    // CPU rate (1 minute average)
    if let Ok(results) = client.query("rate(process_cpu_seconds_total[1m])").await {
        if let Some(result) = results.first() {
            if let Some((_, value)) = &result.value {
                metrics.cpu_seconds_rate = value.parse().unwrap_or(0.0);
            }
        }
    }

    // Ingestion rates
    if let Ok(results) = client
        .query("rate(prometheus_tsdb_head_samples_appended_total[1m])")
        .await
    {
        if let Some(result) = results.first() {
            if let Some((_, value)) = &result.value {
                metrics.samples_appended_rate = value.parse().unwrap_or(0.0);
            }
        }
    }

    if let Ok(results) = client
        .query("rate(prometheus_tsdb_head_series_created_total[1m])")
        .await
    {
        if let Some(result) = results.first() {
            if let Some((_, value)) = &result.value {
                metrics.series_created_rate = value.parse().unwrap_or(0.0);
            }
        }
    }

    // Scrape stats
    if let Ok(results) = client
        .query("count(up)")
        .await
    {
        if let Some(result) = results.first() {
            if let Some((_, value)) = &result.value {
                metrics.target_count = value.parse().unwrap_or(0.0);
            }
        }
    }

    if let Ok(results) = client.query("scrape_duration_seconds").await {
        if let Some(result) = results.first() {
            if let Some((_, value)) = &result.value {
                metrics.scrape_duration_seconds = value.parse().unwrap_or(0.0);
            }
        }
    }

    if let Ok(results) = client.query("scrape_samples_scraped").await {
        if let Some(result) = results.first() {
            if let Some((_, value)) = &result.value {
                metrics.scrape_samples = value.parse().unwrap_or(0.0);
            }
        }
    }

    // Health indicators
    if let Ok(results) = client.query("prometheus_tsdb_compactions_failed_total").await {
        if let Some(result) = results.first() {
            if let Some((_, value)) = &result.value {
                metrics.compactions_failed = value.parse().unwrap_or(0.0);
            }
        }
    }

    if let Ok(results) = client.query("prometheus_tsdb_compactions_total").await {
        if let Some(result) = results.first() {
            if let Some((_, value)) = &result.value {
                metrics.compactions_total = value.parse().unwrap_or(0.0);
            }
        }
    }

    if let Ok(results) = client.query("prometheus_tsdb_wal_corruptions_total").await {
        if let Some(result) = results.first() {
            if let Some((_, value)) = &result.value {
                metrics.wal_corruptions = value.parse().unwrap_or(0.0);
            }
        }
    }

    if let Ok(results) = client.query("prometheus_config_last_reload_successful").await {
        if let Some(result) = results.first() {
            if let Some((_, value)) = &result.value {
                metrics.config_reload_success = value.parse::<f64>().unwrap_or(0.0) == 1.0;
            }
        }
    }

    if let Ok(results) = client
        .query("prometheus_config_last_reload_success_timestamp_seconds")
        .await
    {
        if let Some(result) = results.first() {
            if let Some((_, value)) = &result.value {
                metrics.config_reload_timestamp = value.parse().unwrap_or(0.0);
            }
        }
    }

    // Time series for sparklines
    // Calculate appropriate step based on time range duration
    let duration = end_time - start_time;
    let step = if duration <= 900 {
        "15s" // 15m range -> 15s steps
    } else if duration <= 3600 {
        "60s" // 1h range -> 1m steps
    } else if duration <= 4 * 3600 {
        "300s" // 4h range -> 5m steps
    } else if duration <= 24 * 3600 {
        "900s" // 1d range -> 15m steps
    } else {
        "3600s" // 7d range -> 1h steps
    };

    // Storage over time
    if let Ok(results) = client
        .query_range(
            "prometheus_tsdb_storage_blocks_bytes + prometheus_tsdb_wal_storage_size_bytes",
            start_time,
            end_time,
            step,
        )
        .await
    {
        if let Some(result) = results.first() {
            if let Some(values) = &result.values {
                metrics.storage_over_time = values
                    .iter()
                    .map(|(ts, val)| TimeSeriesPoint {
                        timestamp: *ts,
                        value: val.parse().unwrap_or(0.0),
                    })
                    .collect();
            }
        }
    }

    // Memory over time
    if let Ok(results) = client
        .query_range("process_resident_memory_bytes", start_time, end_time, step)
        .await
    {
        if let Some(result) = results.first() {
            if let Some(values) = &result.values {
                metrics.memory_over_time = values
                    .iter()
                    .map(|(ts, val)| TimeSeriesPoint {
                        timestamp: *ts,
                        value: val.parse().unwrap_or(0.0),
                    })
                    .collect();
            }
        }
    }

    // Samples rate over time
    if let Ok(results) = client
        .query_range(
            "rate(prometheus_tsdb_head_samples_appended_total[1m])",
            start_time,
            end_time,
            step,
        )
        .await
    {
        if let Some(result) = results.first() {
            if let Some(values) = &result.values {
                metrics.samples_rate_over_time = values
                    .iter()
                    .map(|(ts, val)| TimeSeriesPoint {
                        timestamp: *ts,
                        value: val.parse().unwrap_or(0.0),
                    })
                    .collect();
            }
        }
    }

    Ok(metrics)
}
