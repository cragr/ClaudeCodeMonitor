# Port Configuration Scripts Design

Scripts to configure host ports for the Claude Code Monitor stack.

## Problem

Users with port conflicts cannot run the monitoring stack without manually editing multiple config files. The default ports (4317, 4318, 8889, 9090) may conflict with other services.

## Solution

Two scripts that prompt users for new port numbers, validate inputs, update `compose.yaml`, and verify the stack starts correctly:

- `scripts/configure-ports.sh` — Bash for macOS/Linux
- `scripts/configure-ports.ps1` — PowerShell for Windows

## Scope

**In scope:**
- Host port configuration (left side of `HOST:CONTAINER` mapping)
- Container runtime auto-detection (Podman, Docker)
- Port conflict detection
- Health verification after restart

**Out of scope:**
- App settings updates (users change manually)
- Internal container port changes
- Changes to `otel-collector-config.yaml` or `prometheus.yml`

## Ports Managed

| Port | Purpose |
|------|---------|
| 4317 | OTLP gRPC receiver |
| 4318 | OTLP HTTP receiver |
| 8889 | OTel Prometheus metrics export |
| 9090 | Prometheus web UI |

Only `compose.yaml` requires updates. Internal container networking uses fixed ports regardless of host mapping.

## Script Flow

```
1. detect_runtime()           # Find podman/docker and compose command
2. read_current_ports()       # Parse compose.yaml for current host ports
3. prompt_for_ports()         # Interactive prompts with validation
4. validate_no_duplicates()   # Reject duplicate port assignments
5. check_port_conflicts()     # Detect ports in use (ignore our containers)
6. check_running_containers() # Prompt to stop/restart if running
7. backup_and_update()        # Create .bak, update compose.yaml
8. start_and_verify()         # Start containers, health check Prometheus
9. print_summary()            # Show new configuration
```

## User Interaction

### Port Prompts

```
Current port configuration:
  OTLP gRPC receiver:     4317
  OTLP HTTP receiver:     4318
  OTel Prometheus export: 8889
  Prometheus Web UI:      9090

Enter new port values (press Enter to keep current):
  OTLP gRPC receiver [4317]:
  OTLP HTTP receiver [4318]:
  OTel Prometheus export [8889]:
  Prometheus Web UI [9090]: 9091
```

### Validation Rules

- Empty input keeps current value
- Non-numeric input triggers re-prompt
- Port must be 1–65535
- Port < 1024 warns about root/admin requirement
- Duplicate ports across services rejected

### Duplicate Detection

```
Error: Duplicate ports detected
  Port 8889 assigned to both:
    - OTel Prometheus export
    - Prometheus Web UI

Please re-enter:
  OTel Prometheus export [8889]:
  Prometheus Web UI [8889]: 9090
```

### Summary Before Changes

```
Runtime: podman
Containers: running → will be restarted

Ports to update:
  Prometheus Web UI: 9090 → 9091

Files that will be modified:
  - compose.yaml

Proceed? [y/n]
```

## Port Conflict Detection

### Detection Method

| Platform | Command | Filter |
|----------|---------|--------|
| macOS/Linux | `lsof -i :<port> -sTCP:LISTEN` | Any output = conflict |
| Windows | `netstat -ano \| findstr :<port>` | LISTENING state only |

### Ignoring Our Containers

Before flagging a conflict, check if the process belongs to our containers:

```bash
container_pids=$(${runtime} inspect --format '{{.State.Pid}}' otel-collector prometheus 2>/dev/null)
```

If the port-holding PID matches a container PID, skip the warning.

**Known limitation:** Rootless networking proxies (slirp4netns, gvproxy, vpnkit) may hold ports instead of the container process. The script may report false conflicts in these cases.

### Conflict Prompt

```
Port conflicts detected:
  Port 9091: node (PID 12345) on 0.0.0.0:9091
  Port 8889: python (PID 67890) on 127.0.0.1:8889

Options:
  [c] Continue anyway (container start may fail)
  [r] Re-enter conflicting ports (9091, 8889)
  [q] Quit without changes

Choice [c/r/q]:
```

Selecting `[c]` prints: "Warning: Continuing with port conflicts. Container startup may fail if ports are unavailable."

## Container Management

### Runtime Detection

```bash
# Detect runtime
if command -v podman &>/dev/null; then
    runtime="podman"
elif command -v docker &>/dev/null; then
    runtime="docker"
else
    echo "Error: Neither podman nor docker found"
    exit 1
fi

# Detect compose command
if ${runtime} compose version &>/dev/null; then
    compose_cmd="${runtime} compose"
elif command -v ${runtime}-compose &>/dev/null; then
    compose_cmd="${runtime}-compose"
else
    echo "Error: No compose command found for ${runtime}"
    exit 1
fi
```

### Running Container Check

```bash
otel_status=$(${runtime} inspect --format '{{.State.Status}}' otel-collector 2>/dev/null || echo "not found")
prom_status=$(${runtime} inspect --format '{{.State.Status}}' prometheus 2>/dev/null || echo "not found")
```

### Prompt When Running

```
Containers are currently running:
  otel-collector: running
  prometheus: running

Stop and restart with new ports? [y/n]:
```

User selects `n` → exit without changes. User selects `y` → proceed.

### Requirement

Script requires `compose.yaml` to define explicit container names:

```yaml
services:
  otel-collector:
    container_name: otel-collector
  prometheus:
    container_name: prometheus
```

## File Updates

### Backup Strategy

Create single backup before modifying:

```bash
cp compose.yaml compose.yaml.bak
```

Backup overwrites each run. Git provides full history.

### Update Patterns

| Port | Pattern | Replacement |
|------|---------|-------------|
| 4317 | `"4317:4317"` | `"${NEW_GRPC}:4317"` |
| 4318 | `"4318:4318"` | `"${NEW_HTTP}:4318"` |
| 8889 | `"8889:8889"` | `"${NEW_METRICS}:8889"` |
| 9090 | `"9090:9090"` | `"${NEW_PROM}:9090"` |

Container port (right side) stays unchanged.

### Update Method

macOS/Linux:
```bash
sed 's/"4317:4317"/"'"${NEW_GRPC}"':4317"/' compose.yaml > compose.yaml.tmp
mv compose.yaml.tmp compose.yaml
```

Windows PowerShell:
```powershell
(Get-Content -Raw compose.yaml) -replace '"4317:4317"', "`"${NEW_GRPC}:4317`"" |
    Set-Content compose.yaml -NoNewline
```

### Match Validation

Each pattern must appear exactly once:

```bash
matches=$(grep -c '"4317:4317"' compose.yaml)
if [ "$matches" -ne 1 ]; then
    echo "Error: Expected 1 match for '4317:4317', found $matches"
    echo "Config file may have been manually modified."
    exit 1
fi
```

### Parse Failure

If expected pattern not found:

```
Error: Could not find port mapping for OTLP gRPC in compose.yaml.
Expected a ports entry like "4317:4317" under otel-collector service.
The file may have been manually modified. Please check compose.yaml.
```

## Health Verification

### Container Start Check

```bash
running=false
for i in {1..30}; do
    status=$(${runtime} inspect --format '{{.State.Status}}' prometheus 2>/dev/null)
    if [ "$status" = "running" ]; then
        running=true
        break
    fi
    sleep 1
done

if [ "$running" = false ]; then
    echo "✗ Prometheus container failed to start"
    echo ""
    echo "Container logs:"
    ${runtime} logs prometheus --tail 20
    exit 1
fi
```

### Prometheus Health Check

```bash
healthy=false
for i in {1..30}; do
    if curl -s --fail "http://localhost:${NEW_PROM}/-/healthy" >/dev/null 2>&1; then
        healthy=true
        break
    fi
    sleep 1
done

if [ "$healthy" = false ]; then
    echo "✗ Prometheus health check failed on port ${NEW_PROM}"
    echo ""
    echo "Container is running but not responding. Check logs:"
    echo "  ${runtime} logs prometheus"
    exit 1
fi

echo "✓ Prometheus healthy on port ${NEW_PROM}"
```

### Windows Health Check

```powershell
$healthy = $false
for ($i = 1; $i -le 30; $i++) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:${NEW_PROM}/-/healthy" -UseBasicParsing -TimeoutSec 2
        if ($response.StatusCode -eq 200) {
            $healthy = $true
            break
        }
    } catch { }
    Start-Sleep -Seconds 1
}
```

### Success Output

```
Starting containers...
  otel-collector: started
  prometheus: started

Verifying health...
  Waiting for Prometheus on port 9091... ✓ healthy

Configuration complete!

New port configuration:
  OTLP gRPC receiver:     4317
  OTLP HTTP receiver:     4318
  OTel Prometheus export: 8889
  Prometheus Web UI:      9091

Note: Update your Claude Code Monitor app settings to use:
  http://localhost:9091
```

### Failure Handling

On health check failure, the script:
1. Prints error with troubleshooting steps
2. Leaves containers running for debugging
3. Does NOT auto-restore backup

User decides whether to restore manually or debug further.

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error (runtime not found, parse failure, etc.) |
| 2 | User cancelled |
| 3 | Health check failed |

## Script Header

```bash
#!/usr/bin/env bash
#
# configure-ports.sh - Configure host ports for Claude Code Monitor stack
#
# Usage: ./scripts/configure-ports.sh
#
# This script updates host port mappings in compose.yaml for users who have
# port conflicts with the default ports (4317, 4318, 8889, 9090).
#
# Requirements:
#   - podman or docker installed
#   - podman-compose, podman compose, docker-compose, or docker compose
#   - compose.yaml with container_name set for each service
#
# What this script does:
#   1. Prompts for new port numbers (Enter to keep current)
#   2. Validates ports and checks for conflicts
#   3. Backs up compose.yaml to compose.yaml.bak
#   4. Updates host port mappings (container ports unchanged)
#   5. Restarts containers and verifies Prometheus health
#
# Note: After changing Prometheus port, update your app settings to match.
```

## Idempotency

The script runs safely multiple times:
- Reads current ports from `compose.yaml`, not hardcoded defaults
- Overwrites single `.bak` file each run
- Clean stop/start cycle via compose
