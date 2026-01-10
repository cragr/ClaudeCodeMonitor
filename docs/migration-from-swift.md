# Migration from Swift

This guide is for contributors familiar with the legacy macOS SwiftUI app who want to understand the new Tauri codebase.

## What Changed

The Claude Code Monitor was originally a **native macOS SwiftUI application** (~17,000 lines of Swift). It has been rewritten as a **cross-platform Tauri application** supporting macOS, Linux, and Windows.

| Aspect | Swift Version | Tauri Version |
|--------|---------------|---------------|
| UI Framework | SwiftUI | Svelte 5 |
| Backend | Swift actors | Rust |
| Styling | Custom DesignSystem.swift | Tailwind CSS |
| Charts | Apple Charts | Chart.js |
| HTTP Client | URLSession (actor) | reqwest (async) |
| State Management | @StateObject/@Published | Svelte stores |
| Build System | Swift Package Manager | Cargo + pnpm + Vite |
| Platforms | macOS only | macOS, Linux, Windows |

## Directory Mapping

| Swift Path | Tauri Path |
|------------|------------|
| `macos-app/` | `tauri-app/` |
| `ClaudeCodeMonitor/Sources/App/` | `src-tauri/src/main.rs` |
| `ClaudeCodeMonitor/Sources/Models/` | `src-tauri/src/metrics.rs` |
| `ClaudeCodeMonitor/Sources/Services/PrometheusClient.swift` | `src-tauri/src/prometheus.rs` |
| `ClaudeCodeMonitor/Sources/Services/MetricsService.swift` | `src-tauri/src/commands.rs` |
| `ClaudeCodeMonitor/Sources/Services/SettingsManager.swift` | `src/lib/stores/settings.ts` |
| `ClaudeCodeMonitor/Sources/Views/` | `src/lib/components/` |
| `ClaudeCodeMonitorTests/` | (tests TBD) |

## Code Patterns

### HTTP Client

**Swift (actor-based):**

```swift
actor PrometheusClient {
    func query(_ query: String) async throws -> QueryResponse {
        let url = URL(string: "\(baseURL)/api/v1/query")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(QueryResponse.self, from: data)
    }
}
```

**Rust (async):**

```rust
pub struct PrometheusClient {
    client: reqwest::Client,
    base_url: String,
}

impl PrometheusClient {
    pub async fn query(&self, query: &str) -> Result<QueryResponse, Error> {
        let url = format!("{}/api/v1/query", self.base_url);
        let resp = self.client.get(&url)
            .query(&[("query", query)])
            .send()
            .await?
            .json()
            .await?;
        Ok(resp)
    }
}
```

### State Management

**Swift (@Published):**

```swift
class AppState: ObservableObject {
    @Published var metrics: DashboardMetrics?
    @Published var isConnected = false
    @Published var isLoading = false
}
```

**Svelte (stores):**

```typescript
import { writable } from 'svelte/store';

export const metrics = writable<DashboardMetrics | null>(null);
export const isConnected = writable(false);
export const isLoading = writable(false);
```

### UI Components

**SwiftUI:**

```swift
struct MetricCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
        }
        .padding()
        .background(Color.surfaceLight)
        .cornerRadius(8)
    }
}
```

**Svelte:**

```svelte
<script lang="ts">
    export let label: string;
    export let value: string;
</script>

<div class="bg-bg-card rounded-lg p-4">
    <div class="text-xs text-text-secondary uppercase">{label}</div>
    <div class="text-2xl font-bold text-text-primary">{value}</div>
</div>
```

### Tauri IPC (replaces direct service calls)

**Swift (direct call):**

```swift
let metrics = try await metricsService.fetchDashboard(timeRange: "24h")
```

**Svelte + Tauri (IPC):**

```typescript
import { invoke } from '@tauri-apps/api/core';

const metrics = await invoke<DashboardMetrics>('get_dashboard_metrics', {
    timeRange: '24h',
    prometheusUrl: 'http://localhost:9090',
});
```

## What Carries Over

These concepts remain the same:

1. **PromQL queries** - Same metric names and query patterns
2. **Prometheus API** - Same HTTP endpoints (`/api/v1/query`, `/api/v1/query_range`)
3. **Metric names** - `claude_code_token_usage_tokens_total`, etc.
4. **Labels** - `session_id`, `model`, `terminal_type`, etc.
5. **Dashboard layout** - Similar KPI cards and charts
6. **Monitoring stack** - Same `compose.yaml` (works with `podman compose`)

## What's New

1. **Cross-platform** - Runs on macOS, Linux, and Windows
2. **Tauri updater** - Replaces Sparkle for auto-updates
3. **System tray** - Cross-platform tray support via Tauri
4. **Tailwind CSS** - Utility-first styling replaces DesignSystem.swift
5. **Chart.js** - Web-based charts replace Apple Charts
6. **Svelte reactivity** - Fine-grained reactivity vs SwiftUI's view diffing

## Build Commands

**Swift:**

```bash
cd macos-app
swift build
swift run ClaudeCodeMonitor
swift test
```

**Tauri:**

```bash
cd tauri-app
pnpm install
pnpm tauri dev      # Development with hot reload
pnpm tauri build    # Production build
pnpm check          # TypeScript/Svelte validation
```

## Contributing

The Swift codebase (`macos-app/`) has been removed. All development now happens in `tauri-app/`.

Key files to understand:

1. `src-tauri/src/commands.rs` - Backend API (start here)
2. `src/routes/+page.svelte` - Main app layout
3. `src/lib/components/` - UI components
4. `src/lib/stores/` - State management
5. `tauri.conf.json` - Tauri configuration

See [Architecture](architecture.md) for a complete technical overview.
