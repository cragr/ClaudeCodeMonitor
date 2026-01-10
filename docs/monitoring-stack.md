# Monitoring Stack Setup

Claude Code Monitor displays metrics collected by an OpenTelemetry Collector and stored in Prometheus. This guide covers setting up the monitoring stack using Podman Desktop.

## Overview

The monitoring stack consists of:

- **OpenTelemetry Collector** - Receives metrics from Claude Code (ports 4317/gRPC, 4318/HTTP)
- **Prometheus** - Stores and queries metrics (port 9090)

```
Claude Code → OTel Collector → Prometheus → Claude Code Monitor
   (CLI)      (4317/4318)       (9090)           (App)
```

## Prerequisites

Install Podman Desktop for your platform:

- **macOS:** `brew install podman-desktop` or [download](https://podman-desktop.io/)
- **Windows:** [Download](https://podman-desktop.io/) (requires WSL2)
- **Linux:** `flatpak install flathub io.podman_desktop.PodmanDesktop` or [download](https://podman-desktop.io/)

See platform-specific guides for detailed installation:
- [macOS Installation](installation/macos.md)
- [Linux Installation](installation/linux.md)
- [Windows Installation](installation/windows.md)

## Initialize Podman (macOS/Windows only)

macOS and Windows require a Podman machine (lightweight VM) to run containers:

```bash
podman machine init
podman machine start
```

**Verify Podman is ready:**

```bash
podman --version
podman compose version
```

## Start the Monitoring Stack

1. Clone the repository (if you haven't already):

```bash
git clone https://github.com/cragr/ClaudeCodeMonitor.git
cd ClaudeCodeMonitor
```

2. Start the stack:

```bash
podman compose up -d
```

This uses the `compose.yaml` file in the repository root.

3. Verify services are running:

```bash
podman compose ps
```

Expected output:

```
NAME                    STATUS
prometheus              Up
otel-collector          Up
```

## Verify the Stack

### Check Prometheus

Open http://localhost:9090 in your browser.

### Check Targets

Open http://localhost:9090/targets

You should see the `otel-collector` target with state "UP".

### View Logs

```bash
# All services
podman compose logs -f

# Specific service
podman compose logs -f prometheus
podman compose logs -f otel-collector
```

## Configure Container Autostart

To ensure the monitoring stack starts automatically when the Podman machine starts (or after a reboot on Linux), the containers are configured with `restart: always` in `compose.yaml`.

**Verify restart policy:**

```bash
podman inspect prometheus --format '{{.HostConfig.RestartPolicy.Name}}'
podman inspect otel-collector --format '{{.HostConfig.RestartPolicy.Name}}'
```

Both should output `always`.

**Complete autostart requirements:**

| Platform | Podman Machine Autostart | Container Restart Policy |
|----------|-------------------------|-------------------------|
| macOS | Podman Desktop → Settings → Resources → "Start on login" | `restart: always` in compose.yaml |
| Windows | Podman Desktop → Settings → Resources → "Start on login" | `restart: always` in compose.yaml |
| Linux | `systemctl --user enable podman.socket` + lingering | `restart: always` in compose.yaml |

See platform-specific installation guides for detailed setup.

## Manage the Stack

### Stop the stack

```bash
podman compose down
```

### Restart the stack

```bash
podman compose restart
```

### Stop and remove volumes (reset data)

```bash
podman compose down -v
```

### Update container images

```bash
podman compose pull
podman compose up -d
```

## Stack Configuration

### compose.yaml

The stack is defined in `compose.yaml` at the repository root:

```yaml
services:
  otel-collector:
    image: otel/opentelemetry-collector-contrib:latest
    ports:
      - "4317:4317"   # OTLP gRPC
      - "4318:4318"   # OTLP HTTP
      - "8889:8889"   # Prometheus metrics endpoint

  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - prometheus_data:/prometheus
```

### prometheus.yml

Prometheus scrape configuration:

```yaml
scrape_configs:
  - job_name: 'otel-collector'
    static_configs:
      - targets: ['otel-collector:8889']
```

### otel-collector-config.yaml

The OpenTelemetry Collector receives OTLP metrics and exports them in Prometheus format.

## Data Retention

By default, Prometheus retains data for 30 days (`720h`). To change this, edit the `--storage.tsdb.retention.time` flag in `compose.yaml`.

## Troubleshooting

### "Cannot connect to Podman"

Ensure the Podman machine is running:

```bash
podman machine start
```

### Port already in use

Check if another service is using ports 4317, 4318, or 9090:

```bash
# macOS/Linux
lsof -i :9090

# Windows PowerShell
netstat -ano | findstr :9090
```

Stop the conflicting service or change ports in `compose.yaml`.

### Metrics not appearing

1. Verify Claude Code telemetry is enabled:
   ```bash
   echo $CLAUDE_CODE_ENABLE_TELEMETRY  # Should output: 1
   ```

2. Check OTel Collector is receiving data:
   ```bash
   podman compose logs otel-collector
   ```

3. Query Prometheus directly at http://localhost:9090/graph:
   ```
   {__name__=~"claude.*"}
   ```

See [Troubleshooting](troubleshooting.md) for more solutions.

## Next Steps

1. [Configure environment variables](configuration.md) for Claude Code
2. Run Claude Code to generate metrics
3. Launch the Claude Code Monitor app
