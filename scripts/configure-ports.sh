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
#
# Known limitation: On some systems, ports may be bound by rootless networking
# proxies (slirp4netns, gvproxy, vpnkit) rather than the container process
# directly. The script may report false conflicts in these cases.

set -euo pipefail

# Exit codes
EXIT_SUCCESS=0
EXIT_ERROR=1
EXIT_CANCELLED=2
EXIT_HEALTH_FAILED=3

# Port names and container ports (fixed)
declare -A PORT_NAMES=(
    ["grpc"]="OTLP gRPC receiver"
    ["http"]="OTLP HTTP receiver"
    ["metrics"]="OTel Prometheus export"
    ["prom"]="Prometheus Web UI"
)

declare -A CONTAINER_PORTS=(
    ["grpc"]=4317
    ["http"]=4318
    ["metrics"]=8889
    ["prom"]=9090
)

# Current and new host ports (populated at runtime)
declare -A CURRENT_PORTS
declare -A NEW_PORTS

# Runtime detection results
RUNTIME=""
COMPOSE_CMD=""
COMPOSE_FILE=""

# Track if compose.yaml was modified
MODIFIED=false

#------------------------------------------------------------------------------
# Utility functions
#------------------------------------------------------------------------------

print_error() {
    echo "Error: $1" >&2
}

print_warning() {
    echo "Warning: $1" >&2
}

#------------------------------------------------------------------------------
# Runtime detection
#------------------------------------------------------------------------------

detect_runtime() {
    if command -v podman &>/dev/null; then
        RUNTIME="podman"
    elif command -v docker &>/dev/null; then
        RUNTIME="docker"
    else
        print_error "Neither podman nor docker found. Please install one."
        exit $EXIT_ERROR
    fi

    # Detect compose command
    if $RUNTIME compose version &>/dev/null; then
        COMPOSE_CMD="$RUNTIME compose"
    elif command -v "${RUNTIME}-compose" &>/dev/null; then
        COMPOSE_CMD="${RUNTIME}-compose"
    else
        print_error "No compose command found for $RUNTIME"
        echo "Please install ${RUNTIME}-compose or ensure '$RUNTIME compose' works."
        exit $EXIT_ERROR
    fi

    echo "Detected runtime: $RUNTIME"
    echo "Compose command: $COMPOSE_CMD"
    echo ""
}

#------------------------------------------------------------------------------
# Locate compose.yaml
#------------------------------------------------------------------------------

find_compose_file() {
    # Look for compose.yaml in script's parent directory (project root)
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local project_root
    project_root="$(dirname "$script_dir")"

    if [[ -f "$project_root/compose.yaml" ]]; then
        COMPOSE_FILE="$project_root/compose.yaml"
    elif [[ -f "$project_root/compose.yml" ]]; then
        COMPOSE_FILE="$project_root/compose.yml"
    elif [[ -f "$project_root/docker-compose.yaml" ]]; then
        COMPOSE_FILE="$project_root/docker-compose.yaml"
    elif [[ -f "$project_root/docker-compose.yml" ]]; then
        COMPOSE_FILE="$project_root/docker-compose.yml"
    else
        print_error "Could not find compose.yaml in $project_root"
        exit $EXIT_ERROR
    fi

    echo "Using compose file: $COMPOSE_FILE"
    echo ""
}

#------------------------------------------------------------------------------
# Read current ports from compose.yaml
#------------------------------------------------------------------------------

read_current_ports() {
    local port_key container_port pattern matches

    for port_key in grpc http metrics prom; do
        container_port="${CONTAINER_PORTS[$port_key]}"
        # Match pattern like "4317:4317" or "1234:4317"
        pattern="\"([0-9]+):${container_port}\""

        if matches=$(grep -oE "$pattern" "$COMPOSE_FILE" 2>/dev/null); then
            # Extract host port (left side of colon)
            CURRENT_PORTS[$port_key]=$(echo "$matches" | head -1 | sed 's/"//g' | cut -d: -f1)
        else
            print_error "Could not find port mapping for ${PORT_NAMES[$port_key]} in compose.yaml"
            echo "Expected a ports entry like \"${container_port}:${container_port}\" under the service."
            echo "The file may have been manually modified."
            exit $EXIT_ERROR
        fi
    done
}

#------------------------------------------------------------------------------
# Port prompts and validation
#------------------------------------------------------------------------------

validate_port() {
    local port=$1

    # Check if numeric
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        return 1
    fi

    # Check range
    if (( port < 1 || port > 65535 )); then
        return 1
    fi

    return 0
}

prompt_for_ports() {
    echo "Current port configuration:"
    for port_key in grpc http metrics prom; do
        printf "  %-25s %s\n" "${PORT_NAMES[$port_key]}:" "${CURRENT_PORTS[$port_key]}"
    done
    echo ""
    echo "Enter new port values (press Enter to keep current):"

    for port_key in grpc http metrics prom; do
        local current="${CURRENT_PORTS[$port_key]}"
        local input
        local valid=false

        while [[ "$valid" == "false" ]]; do
            read -rp "  ${PORT_NAMES[$port_key]} [$current]: " input

            # Empty input keeps current value
            if [[ -z "$input" ]]; then
                NEW_PORTS[$port_key]="$current"
                valid=true
            elif validate_port "$input"; then
                NEW_PORTS[$port_key]="$input"
                valid=true

                # Warn about privileged ports
                if (( input < 1024 )); then
                    print_warning "Port $input requires root/admin privileges"
                fi
            else
                echo "    Invalid port. Enter a number between 1 and 65535."
            fi
        done
    done
    echo ""
}

#------------------------------------------------------------------------------
# Duplicate port validation
#------------------------------------------------------------------------------

validate_no_duplicates() {
    local -A port_usage
    local duplicates=()

    for port_key in grpc http metrics prom; do
        local port="${NEW_PORTS[$port_key]}"
        if [[ -n "${port_usage[$port]:-}" ]]; then
            duplicates+=("$port")
            port_usage[$port]="${port_usage[$port]}, ${PORT_NAMES[$port_key]}"
        else
            port_usage[$port]="${PORT_NAMES[$port_key]}"
        fi
    done

    if (( ${#duplicates[@]} > 0 )); then
        echo "Error: Duplicate ports detected"
        for port in "${duplicates[@]}"; do
            echo "  Port $port is assigned to:"
            IFS=',' read -ra services <<< "${port_usage[$port]}"
            for service in "${services[@]}"; do
                echo "    - $service"
            done
        done
        echo ""
        return 1
    fi

    return 0
}

prompt_for_duplicates() {
    local -A port_usage
    local duplicates=()

    # Find which ports are duplicated
    for port_key in grpc http metrics prom; do
        local port="${NEW_PORTS[$port_key]}"
        if [[ -n "${port_usage[$port]:-}" ]]; then
            duplicates+=("$port_key")
            # Also add the first one that used this port
            for first_key in grpc http metrics prom; do
                if [[ "${NEW_PORTS[$first_key]}" == "$port" && "$first_key" != "$port_key" ]]; then
                    if [[ ! " ${duplicates[*]} " =~ " $first_key " ]]; then
                        duplicates+=("$first_key")
                    fi
                    break
                fi
            done
        fi
        port_usage[$port]="$port_key"
    done

    echo "Please re-enter conflicting ports:"
    for port_key in "${duplicates[@]}"; do
        local current="${NEW_PORTS[$port_key]}"
        local input
        local valid=false

        while [[ "$valid" == "false" ]]; do
            read -rp "  ${PORT_NAMES[$port_key]} [$current]: " input

            if [[ -z "$input" ]]; then
                # Keep current (still might be duplicate, will check again)
                valid=true
            elif validate_port "$input"; then
                NEW_PORTS[$port_key]="$input"
                valid=true
            else
                echo "    Invalid port. Enter a number between 1 and 65535."
            fi
        done
    done
    echo ""
}

#------------------------------------------------------------------------------
# Port conflict detection
#------------------------------------------------------------------------------

get_container_pids() {
    local pids=""
    for container in otel-collector prometheus; do
        local pid
        pid=$($RUNTIME inspect --format '{{.State.Pid}}' "$container" 2>/dev/null || echo "")
        if [[ -n "$pid" && "$pid" != "0" ]]; then
            pids="$pids $pid"
        fi
    done
    echo "$pids"
}

check_port_in_use() {
    local port=$1
    local container_pids=$2

    # Get process info for port
    local lsof_output
    lsof_output=$(lsof -i :"$port" -sTCP:LISTEN -n -P 2>/dev/null || true)

    if [[ -z "$lsof_output" ]]; then
        return 1  # Port not in use
    fi

    # Parse PID from lsof output (skip header line)
    local pid
    pid=$(echo "$lsof_output" | tail -n +2 | awk '{print $2}' | head -1)

    if [[ -z "$pid" ]]; then
        return 1
    fi

    # Check if it's one of our container PIDs
    for container_pid in $container_pids; do
        if [[ "$pid" == "$container_pid" ]]; then
            return 1  # It's our container, not a conflict
        fi
    done

    # Get process details for output
    local process_name address
    process_name=$(echo "$lsof_output" | tail -n +2 | awk '{print $1}' | head -1)
    address=$(echo "$lsof_output" | tail -n +2 | awk '{print $9}' | head -1)

    echo "$pid|$process_name|$address"
    return 0
}

check_port_conflicts() {
    local container_pids
    container_pids=$(get_container_pids)

    local conflicts=()
    local conflict_details=()

    for port_key in grpc http metrics prom; do
        local port="${NEW_PORTS[$port_key]}"
        local current="${CURRENT_PORTS[$port_key]}"

        # Only check changed ports
        if [[ "$port" != "$current" ]]; then
            local result
            if result=$(check_port_in_use "$port" "$container_pids"); then
                conflicts+=("$port_key")
                conflict_details+=("$port|$result")
            fi
        fi
    done

    if (( ${#conflicts[@]} == 0 )); then
        return 0
    fi

    echo "Port conflicts detected:"
    for detail in "${conflict_details[@]}"; do
        IFS='|' read -r port pid process address <<< "$detail"
        echo "  Port $port: $process (PID $pid) on $address"
    done
    echo ""

    local conflicting_ports
    conflicting_ports=$(printf "%s, " "${conflicts[@]}" | sed 's/, $//')

    echo "Options:"
    echo "  [c] Continue anyway (container start may fail)"
    echo "  [r] Re-enter conflicting ports ($conflicting_ports)"
    echo "  [q] Quit without changes"
    echo ""

    local choice
    while true; do
        read -rp "Choice [c/r/q]: " choice
        case "$choice" in
            c|C)
                print_warning "Continuing with port conflicts. Container startup may fail if ports are unavailable."
                return 0
                ;;
            r|R)
                echo ""
                echo "Please re-enter conflicting ports:"
                for port_key in "${conflicts[@]}"; do
                    local current="${NEW_PORTS[$port_key]}"
                    local input
                    local valid=false

                    while [[ "$valid" == "false" ]]; do
                        read -rp "  ${PORT_NAMES[$port_key]} [$current]: " input

                        if [[ -z "$input" ]]; then
                            valid=true
                        elif validate_port "$input"; then
                            NEW_PORTS[$port_key]="$input"
                            valid=true
                        else
                            echo "    Invalid port. Enter a number between 1 and 65535."
                        fi
                    done
                done
                echo ""
                # Return special code to indicate re-check needed
                return 2
                ;;
            q|Q)
                echo "Exiting without changes."
                exit $EXIT_CANCELLED
                ;;
            *)
                echo "Please enter c, r, or q."
                ;;
        esac
    done
}

#------------------------------------------------------------------------------
# Running container check
#------------------------------------------------------------------------------

check_running_containers() {
    local otel_status prom_status
    otel_status=$($RUNTIME inspect --format '{{.State.Status}}' otel-collector 2>/dev/null || echo "not found")
    prom_status=$($RUNTIME inspect --format '{{.State.Status}}' prometheus 2>/dev/null || echo "not found")

    if [[ "$otel_status" == "running" || "$prom_status" == "running" ]]; then
        echo "Containers are currently running:"
        echo "  otel-collector: $otel_status"
        echo "  prometheus: $prom_status"
        echo ""

        local choice
        read -rp "Stop and restart with new ports? [y/n]: " choice

        if [[ "$choice" != "y" && "$choice" != "Y" ]]; then
            echo "Exiting without changes."
            exit $EXIT_CANCELLED
        fi
        echo ""
        return 0  # Containers running, will restart
    fi

    return 1  # Containers not running
}

#------------------------------------------------------------------------------
# Summary and confirmation
#------------------------------------------------------------------------------

show_summary() {
    local changes=()

    for port_key in grpc http metrics prom; do
        local current="${CURRENT_PORTS[$port_key]}"
        local new="${NEW_PORTS[$port_key]}"
        if [[ "$current" != "$new" ]]; then
            changes+=("${PORT_NAMES[$port_key]}: $current → $new")
        fi
    done

    if (( ${#changes[@]} == 0 )); then
        echo "No port changes requested."
        exit $EXIT_SUCCESS
    fi

    # Check container status for summary
    local otel_status prom_status container_action
    otel_status=$($RUNTIME inspect --format '{{.State.Status}}' otel-collector 2>/dev/null || echo "not found")
    prom_status=$($RUNTIME inspect --format '{{.State.Status}}' prometheus 2>/dev/null || echo "not found")

    if [[ "$otel_status" == "running" || "$prom_status" == "running" ]]; then
        container_action="running → will be restarted"
    else
        container_action="not running → will be started"
    fi

    echo "Runtime: $RUNTIME"
    echo "Containers: $container_action"
    echo ""
    echo "Ports to update:"
    for change in "${changes[@]}"; do
        echo "  $change"
    done
    echo ""
    echo "Files that will be modified:"
    echo "  - compose.yaml"
    echo ""

    local choice
    read -rp "Proceed? [y/n]: " choice

    if [[ "$choice" != "y" && "$choice" != "Y" ]]; then
        echo "Exiting without changes."
        exit $EXIT_CANCELLED
    fi
    echo ""
}

#------------------------------------------------------------------------------
# Backup and update
#------------------------------------------------------------------------------

backup_and_update() {
    local compose_dir
    compose_dir="$(dirname "$COMPOSE_FILE")"

    # Create backup
    echo "Creating backup: compose.yaml.bak"
    cp "$COMPOSE_FILE" "$COMPOSE_FILE.bak"

    # Update each changed port
    for port_key in grpc http metrics prom; do
        local current="${CURRENT_PORTS[$port_key]}"
        local new="${NEW_PORTS[$port_key]}"
        local container_port="${CONTAINER_PORTS[$port_key]}"

        if [[ "$current" != "$new" ]]; then
            local old_pattern="\"${current}:${container_port}\""
            local new_pattern="\"${new}:${container_port}\""

            # Verify pattern exists exactly once
            local matches
            matches=$(grep -c "$old_pattern" "$COMPOSE_FILE" || echo "0")

            if [[ "$matches" != "1" ]]; then
                print_error "Expected 1 match for '$old_pattern', found $matches"
                echo "Restoring from backup..."
                cp "$COMPOSE_FILE.bak" "$COMPOSE_FILE"
                exit $EXIT_ERROR
            fi

            # Perform replacement using temp file
            sed "s/$old_pattern/$new_pattern/" "$COMPOSE_FILE" > "$COMPOSE_FILE.tmp"
            mv "$COMPOSE_FILE.tmp" "$COMPOSE_FILE"

            echo "  Updated ${PORT_NAMES[$port_key]}: $current → $new"
            MODIFIED=true
        fi
    done
    echo ""
}

#------------------------------------------------------------------------------
# Start and verify
#------------------------------------------------------------------------------

start_and_verify() {
    local compose_dir
    compose_dir="$(dirname "$COMPOSE_FILE")"

    # Stop containers if running
    echo "Stopping containers..."
    (cd "$compose_dir" && $COMPOSE_CMD down 2>/dev/null || true)

    # Start containers
    echo "Starting containers..."
    (cd "$compose_dir" && $COMPOSE_CMD up -d)
    echo ""

    # Wait for prometheus container to be running
    echo "Verifying health..."
    local running=false
    for i in {1..30}; do
        local status
        status=$($RUNTIME inspect --format '{{.State.Status}}' prometheus 2>/dev/null || echo "")
        if [[ "$status" == "running" ]]; then
            running=true
            break
        fi
        sleep 1
    done

    if [[ "$running" == "false" ]]; then
        echo "✗ Prometheus container failed to start"
        echo ""
        echo "Container logs:"
        $RUNTIME logs prometheus --tail 20 2>/dev/null || true
        echo ""
        echo "To restore original config: cp compose.yaml.bak compose.yaml"
        exit $EXIT_HEALTH_FAILED
    fi

    # Test Prometheus health endpoint
    local prom_port="${NEW_PORTS[prom]}"
    local healthy=false

    printf "  Waiting for Prometheus on port %s..." "$prom_port"
    for i in {1..30}; do
        if curl -s --fail "http://localhost:${prom_port}/-/healthy" >/dev/null 2>&1; then
            healthy=true
            break
        fi
        sleep 1
    done

    if [[ "$healthy" == "false" ]]; then
        echo " ✗ failed"
        echo ""
        echo "Prometheus container is running but not responding."
        echo ""
        echo "Troubleshooting:"
        echo "  1. Check container logs: $RUNTIME logs prometheus"
        echo "  2. Verify port is not blocked by firewall"
        echo "  3. Restore original config: cp compose.yaml.bak compose.yaml"
        exit $EXIT_HEALTH_FAILED
    fi

    echo " ✓ healthy"
    echo ""
}

#------------------------------------------------------------------------------
# Print final summary
#------------------------------------------------------------------------------

print_final_summary() {
    echo "Configuration complete!"
    echo ""
    echo "New port configuration:"
    for port_key in grpc http metrics prom; do
        printf "  %-25s %s\n" "${PORT_NAMES[$port_key]}:" "${NEW_PORTS[$port_key]}"
    done
    echo ""

    # Only show note if Prometheus port changed
    if [[ "${CURRENT_PORTS[prom]}" != "${NEW_PORTS[prom]}" ]]; then
        echo "Note: Update your Claude Code Monitor app settings to use:"
        echo "  http://localhost:${NEW_PORTS[prom]}"
    fi
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

main() {
    echo "Claude Code Monitor - Port Configuration"
    echo "========================================="
    echo ""

    # Step 1: Detect runtime
    detect_runtime

    # Step 2: Find compose file
    find_compose_file

    # Step 3: Read current ports
    read_current_ports

    # Step 4: Prompt for new ports
    prompt_for_ports

    # Step 5: Validate no duplicates (loop until valid)
    while ! validate_no_duplicates; do
        prompt_for_duplicates
    done

    # Step 6: Check port conflicts (loop if user chooses to re-enter)
    while true; do
        local result=0
        check_port_conflicts || result=$?
        if [[ "$result" == "2" ]]; then
            # User chose to re-enter, also re-check duplicates
            while ! validate_no_duplicates; do
                prompt_for_duplicates
            done
            continue
        fi
        break
    done

    # Step 7: Check running containers
    check_running_containers || true

    # Step 8: Show summary and confirm
    show_summary

    # Step 9: Backup and update
    backup_and_update

    # Step 10: Start and verify
    start_and_verify

    # Step 11: Print final summary
    print_final_summary

    exit $EXIT_SUCCESS
}

main "$@"
