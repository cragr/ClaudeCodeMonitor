# Configuration

This guide covers environment variables for Claude Code telemetry and app settings.

## Environment Variables

Claude Code must be configured to send telemetry to the OpenTelemetry Collector.

### Required Variables

| Variable | Value | Description |
|----------|-------|-------------|
| `CLAUDE_CODE_ENABLE_TELEMETRY` | `1` | Enable telemetry export |
| `OTEL_METRICS_EXPORTER` | `otlp` | Use OTLP exporter |
| `OTEL_EXPORTER_OTLP_PROTOCOL` | `grpc` | Use gRPC protocol |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `http://localhost:4317` | OTel Collector endpoint |

### Shell Configuration

#### Zsh (macOS default)

Add to `~/.zshrc`:

```bash
# Claude Code Telemetry
export CLAUDE_CODE_ENABLE_TELEMETRY=1
export OTEL_METRICS_EXPORTER=otlp
export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
```

Reload:

```bash
source ~/.zshrc
```

#### Bash (Linux default)

Add to `~/.bashrc`:

```bash
# Claude Code Telemetry
export CLAUDE_CODE_ENABLE_TELEMETRY=1
export OTEL_METRICS_EXPORTER=otlp
export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
```

Reload:

```bash
source ~/.bashrc
```

#### Fish

Add to `~/.config/fish/config.fish`:

```fish
# Claude Code Telemetry
set -gx CLAUDE_CODE_ENABLE_TELEMETRY 1
set -gx OTEL_METRICS_EXPORTER otlp
set -gx OTEL_EXPORTER_OTLP_PROTOCOL grpc
set -gx OTEL_EXPORTER_OTLP_ENDPOINT http://localhost:4317
```

Reload:

```fish
source ~/.config/fish/config.fish
```

#### PowerShell (Windows)

Add to your PowerShell profile (`$PROFILE`):

```powershell
# Claude Code Telemetry
$env:CLAUDE_CODE_ENABLE_TELEMETRY = "1"
$env:OTEL_METRICS_EXPORTER = "otlp"
$env:OTEL_EXPORTER_OTLP_PROTOCOL = "grpc"
$env:OTEL_EXPORTER_OTLP_ENDPOINT = "http://localhost:4317"
```

To find your profile path:

```powershell
echo $PROFILE
```

Create the file if it doesn't exist:

```powershell
New-Item -Path $PROFILE -ItemType File -Force
notepad $PROFILE
```

Reload:

```powershell
. $PROFILE
```

#### Windows Command Prompt

For permanent variables, use System Properties:

1. Press `Win + R`, type `sysdm.cpl`, press Enter
2. Go to **Advanced** tab → **Environment Variables**
3. Under **User variables**, click **New** for each variable

Or set temporarily in the current session:

```cmd
set CLAUDE_CODE_ENABLE_TELEMETRY=1
set OTEL_METRICS_EXPORTER=otlp
set OTEL_EXPORTER_OTLP_PROTOCOL=grpc
set OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
```

### Verify Configuration

After setting up, verify the variables are set:

**macOS/Linux:**

```bash
echo $CLAUDE_CODE_ENABLE_TELEMETRY    # Should output: 1
echo $OTEL_METRICS_EXPORTER           # Should output: otlp
echo $OTEL_EXPORTER_OTLP_PROTOCOL     # Should output: grpc
echo $OTEL_EXPORTER_OTLP_ENDPOINT     # Should output: http://localhost:4317
```

**Windows PowerShell:**

```powershell
echo $env:CLAUDE_CODE_ENABLE_TELEMETRY
echo $env:OTEL_METRICS_EXPORTER
echo $env:OTEL_EXPORTER_OTLP_PROTOCOL
echo $env:OTEL_EXPORTER_OTLP_ENDPOINT
```

## App Settings

Claude Code Monitor stores settings in a platform-specific location:

| Platform | Settings Path |
|----------|---------------|
| macOS | `~/Library/Application Support/com.cragr.claudecodemonitor/` |
| Linux | `~/.config/com.cragr.claudecodemonitor/` |
| Windows | `%APPDATA%\com.cragr.claudecodemonitor\` |

### Available Settings

Access settings via the gear icon in the app:

| Setting | Default | Description |
|---------|---------|-------------|
| Prometheus URL | `http://localhost:9090` | Prometheus server address |
| Refresh Interval | `30` seconds | How often to fetch new metrics |

### Connection Test

In Settings, use the **Test Connection** button to verify the app can reach Prometheus.

## Prometheus Metrics

Claude Code exports the following metrics:

| Metric | Type | Description |
|--------|------|-------------|
| `claude_code_token_usage_tokens_total` | Counter | Total tokens used |
| `claude_code_cost_usage_USD_total` | Counter | Cost in USD |
| `claude_code_active_time_seconds_total` | Counter | Active coding time |
| `claude_code_session_count_total` | Counter | Number of sessions |
| `claude_code_lines_of_code_count_total` | Counter | Lines added/removed |
| `claude_code_commit_count_total` | Counter | Git commits |
| `claude_code_pull_request_count_total` | Counter | Pull requests created |

### Labels

Metrics include these labels for filtering:

| Label | Description |
|-------|-------------|
| `session_id` | Unique session identifier |
| `model` | Claude model used (e.g., `claude-sonnet-4-20250514`) |
| `terminal_type` | Terminal application (e.g., `iTerm`, `Terminal`, `Windows Terminal`) |
| `app_version` | Claude Code version |

## Troubleshooting

### Variables not persisting

Ensure you added them to the correct shell config file and reloaded it:

```bash
# Check which shell you're using
echo $SHELL
```

### Claude Code not sending metrics

1. Restart Claude Code after setting environment variables
2. Ensure the monitoring stack is running: `podman compose ps`
3. Check OTel Collector logs: `podman compose logs otel-collector`

See [Troubleshooting](troubleshooting.md) for more solutions.
