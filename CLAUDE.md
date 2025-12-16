# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Claude Code Monitor is a native macOS SwiftUI application for monitoring Claude Code usage via Prometheus telemetry data. It displays real-time and historical metrics including tokens, cost, active time, sessions, lines of code, commits, and pull requests.

## Repository Structure

- `macos-app/` - Native macOS SwiftUI application
- `monitoring-stack/` - Docker Compose with Prometheus, Grafana, and OTel collector

## Build Commands

```bash
# Build the project
cd macos-app && swift build

# Run the application
cd macos-app && swift run ClaudeCodeMonitor

# Run tests
cd macos-app && swift test
```

In Xcode: Open `macos-app/Package.swift` directly, then ⌘R to run, ⌘U to test.

## Architecture

**Swift Package structure with SwiftUI app:**

- `macos-app/ClaudeCodeMonitor/Sources/App/` - App entry point with `@main`, AppDelegate for lifecycle management
- `macos-app/ClaudeCodeMonitor/Sources/Models/` - Data models for Prometheus API responses and app state
  - `ClaudeCodeMetrics.swift` - Canonical metric names (`ClaudeCodeMetric` enum) with mapping from OTel/Prometheus variants
  - `PrometheusModels.swift` - Decodable response types for Prometheus API
  - `AppState.swift` - `@MainActor` observable state for UI binding
- `macos-app/ClaudeCodeMonitor/Sources/Services/` - Business logic layer
  - `PrometheusClient.swift` - Actor-based async HTTP client with caching, query methods (`query`, `queryRange`), and PromQL query builder
  - `MetricsService.swift` - Aggregates raw Prometheus data into dashboard metrics
  - `SettingsManager.swift` - UserDefaults-backed settings with `@Published` properties
- `macos-app/ClaudeCodeMonitor/Sources/Views/` - SwiftUI views for dashboard, settings, menu bar
- `macos-app/ClaudeCodeMonitorTests/` - Unit tests for query building and JSON decoding

**Key patterns:**
- `PrometheusClient` is an `actor` for thread-safe network operations
- `PromQLQueryBuilder` uses builder pattern for constructing Prometheus queries with fluent API (`.rate()`, `.sum()`, `.withLabel()`)
- State management via `@StateObject`/`@EnvironmentObject` with `AppState` and `SettingsManager`
- Menu bar extra using SwiftUI's `MenuBarExtra` scene
- `ClaudeCodeMetric.normalize(_:)` handles various metric name formats (dot notation, underscore, with/without `_total` suffix)

## Requirements

- macOS 14.0+ (Sonoma)
- Swift 5.9 / Xcode 15+
- Docker for running Prometheus stack (see `monitoring-stack/docker-compose.yml`)

## Prometheus Metric Names

The app queries metrics prefixed with `claude_code_`. Actual metric names from OTel have `_total` suffix for counters (e.g., `claude_code_token_usage_tokens_total`). The `PromQLQueryBuilder` helper methods in `PrometheusClient.swift` construct the full metric names with proper suffixes.

Common metrics:
- `claude_code_token_usage_tokens_total` - Token consumption
- `claude_code_cost_usage_USD_total` - Cost in USD
- `claude_code_active_time_seconds_total` - Active coding time
- `claude_code_session_count_total` - Session count
- `claude_code_lines_of_code_count_total` - Lines added/removed (has `type` label)
- `claude_code_commit_count_total` - Git commits
- `claude_code_pull_request_count_total` - Pull requests created
