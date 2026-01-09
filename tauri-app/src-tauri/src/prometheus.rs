use reqwest::Client;
use serde::Deserialize;
use std::collections::HashMap;

#[derive(Debug, thiserror::Error)]
pub enum PrometheusError {
    #[error("HTTP request failed: {0}")]
    Request(#[from] reqwest::Error),
    #[error("Invalid response: {0}")]
    InvalidResponse(String),
}

#[derive(Debug, Deserialize)]
pub struct QueryResponse {
    pub status: String,
    pub data: QueryData,
}

#[derive(Debug, Deserialize)]
pub struct QueryData {
    #[serde(rename = "resultType")]
    #[allow(dead_code)]
    pub result_type: String,
    pub result: Vec<QueryResult>,
}

#[derive(Debug, Deserialize)]
pub struct QueryResult {
    pub metric: HashMap<String, String>,
    pub value: Option<(f64, String)>,
    pub values: Option<Vec<(f64, String)>>,
}

pub struct PrometheusClient {
    client: Client,
    base_url: String,
}

impl PrometheusClient {
    pub fn new(base_url: &str) -> Self {
        Self {
            client: Client::new(),
            base_url: base_url.trim_end_matches('/').to_string(),
        }
    }

    pub async fn query(&self, query: &str) -> Result<Vec<QueryResult>, PrometheusError> {
        let url = format!("{}/api/v1/query", self.base_url);
        let response: QueryResponse = self
            .client
            .get(&url)
            .query(&[("query", query)])
            .send()
            .await?
            .json()
            .await?;

        if response.status != "success" {
            return Err(PrometheusError::InvalidResponse(response.status));
        }

        Ok(response.data.result)
    }

    pub async fn query_range(
        &self,
        query: &str,
        start: i64,
        end: i64,
        step: &str,
    ) -> Result<Vec<QueryResult>, PrometheusError> {
        let url = format!("{}/api/v1/query_range", self.base_url);
        let response: QueryResponse = self
            .client
            .get(&url)
            .query(&[
                ("query", query),
                ("start", &start.to_string()),
                ("end", &end.to_string()),
                ("step", step),
            ])
            .send()
            .await?
            .json()
            .await?;

        if response.status != "success" {
            return Err(PrometheusError::InvalidResponse(response.status));
        }

        Ok(response.data.result)
    }

    pub async fn test_connection(&self) -> Result<bool, PrometheusError> {
        let url = format!("{}/-/healthy", self.base_url);
        let response = self.client.get(&url).send().await?;
        Ok(response.status().is_success())
    }

    pub async fn discover_metrics(&self) -> Result<Vec<String>, PrometheusError> {
        // Query for all claude_code_ metrics
        let url = format!("{}/api/v1/label/__name__/values", self.base_url);
        let response: serde_json::Value = self.client.get(&url).send().await?.json().await?;

        if response["status"] != "success" {
            return Err(PrometheusError::InvalidResponse(
                response["status"].to_string(),
            ));
        }

        let metrics: Vec<String> = response["data"]
            .as_array()
            .map(|arr| {
                arr.iter()
                    .filter_map(|v| v.as_str())
                    .filter(|name| name.starts_with("claude_code_"))
                    .map(|s| s.to_string())
                    .collect()
            })
            .unwrap_or_default();

        Ok(metrics)
    }
}
