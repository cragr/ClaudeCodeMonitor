<#
.SYNOPSIS
    Configure host ports for Claude Code Monitor stack

.DESCRIPTION
    This script updates host port mappings in compose.yaml for users who have
    port conflicts with the default ports (4317, 4318, 8889, 9090).

.NOTES
    Requirements:
      - podman or docker installed
      - podman-compose, podman compose, docker-compose, or docker compose
      - compose.yaml with container_name set for each service

    What this script does:
      1. Prompts for new port numbers (Enter to keep current)
      2. Validates ports and checks for conflicts
      3. Backs up compose.yaml to compose.yaml.bak
      4. Updates host port mappings (container ports unchanged)
      5. Restarts containers and verifies Prometheus health

    Note: After changing Prometheus port, update your app settings to match.

    Known limitation: On some systems, ports may be bound by rootless networking
    proxies rather than the container process directly. The script may report
    false conflicts in these cases.

.EXAMPLE
    .\scripts\configure-ports.ps1
#>

$ErrorActionPreference = "Stop"

# Exit codes
$EXIT_SUCCESS = 0
$EXIT_ERROR = 1
$EXIT_CANCELLED = 2
$EXIT_HEALTH_FAILED = 3

# Port configuration
$PortConfig = @{
    grpc = @{ Name = "OTLP gRPC receiver"; ContainerPort = 4317 }
    http = @{ Name = "OTLP HTTP receiver"; ContainerPort = 4318 }
    metrics = @{ Name = "OTel Prometheus export"; ContainerPort = 8889 }
    prom = @{ Name = "Prometheus Web UI"; ContainerPort = 9090 }
}

# Runtime detection results
$script:Runtime = ""
$script:ComposeCmd = ""
$script:ComposeFile = ""

# Current and new ports
$script:CurrentPorts = @{}
$script:NewPorts = @{}

# Track if modified
$script:Modified = $false

#------------------------------------------------------------------------------
# Utility functions
#------------------------------------------------------------------------------

function Write-ErrorMessage {
    param([string]$Message)
    Write-Host "Error: $Message" -ForegroundColor Red
}

function Write-WarningMessage {
    param([string]$Message)
    Write-Host "Warning: $Message" -ForegroundColor Yellow
}

#------------------------------------------------------------------------------
# Runtime detection
#------------------------------------------------------------------------------

function Find-ContainerRuntime {
    # Check for podman first
    if (Get-Command "podman" -ErrorAction SilentlyContinue) {
        $script:Runtime = "podman"
    }
    elseif (Get-Command "docker" -ErrorAction SilentlyContinue) {
        $script:Runtime = "docker"
    }
    else {
        Write-ErrorMessage "Neither podman nor docker found. Please install one."
        exit $EXIT_ERROR
    }

    # Detect compose command
    try {
        $null = & $script:Runtime compose version 2>$null
        $script:ComposeCmd = "$script:Runtime compose"
    }
    catch {
        if (Get-Command "$script:Runtime-compose" -ErrorAction SilentlyContinue) {
            $script:ComposeCmd = "$script:Runtime-compose"
        }
        else {
            Write-ErrorMessage "No compose command found for $script:Runtime"
            Write-Host "Please install $script:Runtime-compose or ensure '$script:Runtime compose' works."
            exit $EXIT_ERROR
        }
    }

    Write-Host "Detected runtime: $script:Runtime"
    Write-Host "Compose command: $script:ComposeCmd"
    Write-Host ""
}

#------------------------------------------------------------------------------
# Locate compose.yaml
#------------------------------------------------------------------------------

function Find-ComposeFile {
    $scriptDir = Split-Path -Parent $MyInvocation.ScriptName
    if (-not $scriptDir) {
        $scriptDir = $PWD.Path
    }
    $projectRoot = Split-Path -Parent $scriptDir

    $candidates = @(
        "compose.yaml",
        "compose.yml",
        "docker-compose.yaml",
        "docker-compose.yml"
    )

    foreach ($candidate in $candidates) {
        $path = Join-Path $projectRoot $candidate
        if (Test-Path $path) {
            $script:ComposeFile = $path
            Write-Host "Using compose file: $script:ComposeFile"
            Write-Host ""
            return
        }
    }

    Write-ErrorMessage "Could not find compose.yaml in $projectRoot"
    exit $EXIT_ERROR
}

#------------------------------------------------------------------------------
# Read current ports from compose.yaml
#------------------------------------------------------------------------------

function Read-CurrentPorts {
    $content = Get-Content -Raw $script:ComposeFile

    foreach ($key in $PortConfig.Keys) {
        $containerPort = $PortConfig[$key].ContainerPort
        $pattern = '"(\d+):' + $containerPort + '"'

        if ($content -match $pattern) {
            $script:CurrentPorts[$key] = $Matches[1]
        }
        else {
            Write-ErrorMessage "Could not find port mapping for $($PortConfig[$key].Name) in compose.yaml"
            Write-Host "Expected a ports entry like `"$containerPort`:$containerPort`" under the service."
            Write-Host "The file may have been manually modified."
            exit $EXIT_ERROR
        }
    }
}

#------------------------------------------------------------------------------
# Port prompts and validation
#------------------------------------------------------------------------------

function Test-ValidPort {
    param([string]$Port)

    if ($Port -notmatch '^\d+$') {
        return $false
    }

    $portNum = [int]$Port
    if ($portNum -lt 1 -or $portNum -gt 65535) {
        return $false
    }

    return $true
}

function Read-PortInputs {
    Write-Host "Current port configuration:"
    foreach ($key in @("grpc", "http", "metrics", "prom")) {
        $name = $PortConfig[$key].Name
        $current = $script:CurrentPorts[$key]
        Write-Host ("  {0,-25} {1}" -f "${name}:", $current)
    }
    Write-Host ""
    Write-Host "Enter new port values (press Enter to keep current):"

    foreach ($key in @("grpc", "http", "metrics", "prom")) {
        $name = $PortConfig[$key].Name
        $current = $script:CurrentPorts[$key]
        $valid = $false

        while (-not $valid) {
            $input = Read-Host "  $name [$current]"

            if ([string]::IsNullOrWhiteSpace($input)) {
                $script:NewPorts[$key] = $current
                $valid = $true
            }
            elseif (Test-ValidPort $input) {
                $script:NewPorts[$key] = $input
                $valid = $true

                if ([int]$input -lt 1024) {
                    Write-WarningMessage "Port $input requires administrator privileges"
                }
            }
            else {
                Write-Host "    Invalid port. Enter a number between 1 and 65535."
            }
        }
    }
    Write-Host ""
}

#------------------------------------------------------------------------------
# Duplicate port validation
#------------------------------------------------------------------------------

function Test-NoDuplicates {
    $portUsage = @{}
    $duplicates = @()

    foreach ($key in @("grpc", "http", "metrics", "prom")) {
        $port = $script:NewPorts[$key]
        if ($portUsage.ContainsKey($port)) {
            if ($port -notin $duplicates) {
                $duplicates += $port
            }
            $portUsage[$port] += ", $($PortConfig[$key].Name)"
        }
        else {
            $portUsage[$port] = $PortConfig[$key].Name
        }
    }

    if ($duplicates.Count -gt 0) {
        Write-Host "Error: Duplicate ports detected"
        foreach ($port in $duplicates) {
            Write-Host "  Port $port is assigned to:"
            $services = $portUsage[$port] -split ", "
            foreach ($service in $services) {
                Write-Host "    - $service"
            }
        }
        Write-Host ""
        return $false
    }

    return $true
}

function Read-DuplicatePorts {
    # Find which keys have duplicate ports
    $portUsage = @{}
    $duplicateKeys = @()

    foreach ($key in @("grpc", "http", "metrics", "prom")) {
        $port = $script:NewPorts[$key]
        if ($portUsage.ContainsKey($port)) {
            if ($key -notin $duplicateKeys) {
                $duplicateKeys += $key
            }
            # Add the first key that used this port
            $firstKey = $portUsage[$port]
            if ($firstKey -notin $duplicateKeys) {
                $duplicateKeys += $firstKey
            }
        }
        else {
            $portUsage[$port] = $key
        }
    }

    Write-Host "Please re-enter conflicting ports:"
    foreach ($key in $duplicateKeys) {
        $name = $PortConfig[$key].Name
        $current = $script:NewPorts[$key]
        $valid = $false

        while (-not $valid) {
            $input = Read-Host "  $name [$current]"

            if ([string]::IsNullOrWhiteSpace($input)) {
                $valid = $true
            }
            elseif (Test-ValidPort $input) {
                $script:NewPorts[$key] = $input
                $valid = $true
            }
            else {
                Write-Host "    Invalid port. Enter a number between 1 and 65535."
            }
        }
    }
    Write-Host ""
}

#------------------------------------------------------------------------------
# Port conflict detection
#------------------------------------------------------------------------------

function Get-ContainerPids {
    $pids = @()
    foreach ($container in @("otel-collector", "prometheus")) {
        try {
            $pid = & $script:Runtime inspect --format '{{.State.Pid}}' $container 2>$null
            if ($pid -and $pid -ne "0") {
                $pids += $pid
            }
        }
        catch { }
    }
    return $pids
}

function Test-PortInUse {
    param(
        [string]$Port,
        [array]$ContainerPids
    )

    # Get listening processes on this port
    $netstat = netstat -ano | Select-String ":$Port\s" | Select-String "LISTENING"

    if (-not $netstat) {
        return $null
    }

    # Parse first match
    $line = $netstat[0].ToString().Trim()
    $parts = $line -split '\s+'
    $address = $parts[1]
    $pid = $parts[-1]

    # Check if it's one of our containers
    if ($pid -in $ContainerPids) {
        return $null
    }

    # Get process name
    $processName = "unknown"
    try {
        $proc = Get-Process -Id $pid -ErrorAction SilentlyContinue
        if ($proc) {
            $processName = $proc.ProcessName
        }
    }
    catch { }

    return @{
        Port = $Port
        PID = $pid
        Process = $processName
        Address = $address
    }
}

function Test-PortConflicts {
    $containerPids = Get-ContainerPids
    $conflicts = @()

    foreach ($key in @("grpc", "http", "metrics", "prom")) {
        $port = $script:NewPorts[$key]
        $current = $script:CurrentPorts[$key]

        # Only check changed ports
        if ($port -ne $current) {
            $result = Test-PortInUse -Port $port -ContainerPids $containerPids
            if ($result) {
                $conflicts += @{
                    Key = $key
                    Details = $result
                }
            }
        }
    }

    if ($conflicts.Count -eq 0) {
        return $true
    }

    Write-Host "Port conflicts detected:"
    foreach ($conflict in $conflicts) {
        $d = $conflict.Details
        Write-Host "  Port $($d.Port): $($d.Process) (PID $($d.PID)) on $($d.Address)"
    }
    Write-Host ""

    $conflictingPorts = ($conflicts | ForEach-Object { $_.Details.Port }) -join ", "

    Write-Host "Options:"
    Write-Host "  [c] Continue anyway (container start may fail)"
    Write-Host "  [r] Re-enter conflicting ports ($conflictingPorts)"
    Write-Host "  [q] Quit without changes"
    Write-Host ""

    while ($true) {
        $choice = Read-Host "Choice [c/r/q]"

        switch ($choice.ToLower()) {
            "c" {
                Write-WarningMessage "Continuing with port conflicts. Container startup may fail if ports are unavailable."
                return $true
            }
            "r" {
                Write-Host ""
                Write-Host "Please re-enter conflicting ports:"
                foreach ($conflict in $conflicts) {
                    $key = $conflict.Key
                    $name = $PortConfig[$key].Name
                    $current = $script:NewPorts[$key]
                    $valid = $false

                    while (-not $valid) {
                        $input = Read-Host "  $name [$current]"

                        if ([string]::IsNullOrWhiteSpace($input)) {
                            $valid = $true
                        }
                        elseif (Test-ValidPort $input) {
                            $script:NewPorts[$key] = $input
                            $valid = $true
                        }
                        else {
                            Write-Host "    Invalid port. Enter a number between 1 and 65535."
                        }
                    }
                }
                Write-Host ""
                return $false  # Signal to re-check
            }
            "q" {
                Write-Host "Exiting without changes."
                exit $EXIT_CANCELLED
            }
            default {
                Write-Host "Please enter c, r, or q."
            }
        }
    }
}

#------------------------------------------------------------------------------
# Running container check
#------------------------------------------------------------------------------

function Test-RunningContainers {
    $otelStatus = "not found"
    $promStatus = "not found"

    try {
        $otelStatus = & $script:Runtime inspect --format '{{.State.Status}}' otel-collector 2>$null
    }
    catch { }

    try {
        $promStatus = & $script:Runtime inspect --format '{{.State.Status}}' prometheus 2>$null
    }
    catch { }

    if ($otelStatus -eq "running" -or $promStatus -eq "running") {
        Write-Host "Containers are currently running:"
        Write-Host "  otel-collector: $otelStatus"
        Write-Host "  prometheus: $promStatus"
        Write-Host ""

        $choice = Read-Host "Stop and restart with new ports? [y/n]"

        if ($choice.ToLower() -ne "y") {
            Write-Host "Exiting without changes."
            exit $EXIT_CANCELLED
        }
        Write-Host ""
        return $true
    }

    return $false
}

#------------------------------------------------------------------------------
# Summary and confirmation
#------------------------------------------------------------------------------

function Show-Summary {
    $changes = @()

    foreach ($key in @("grpc", "http", "metrics", "prom")) {
        $current = $script:CurrentPorts[$key]
        $new = $script:NewPorts[$key]
        if ($current -ne $new) {
            $name = $PortConfig[$key].Name
            $changes += "$name`: $current -> $new"
        }
    }

    if ($changes.Count -eq 0) {
        Write-Host "No port changes requested."
        exit $EXIT_SUCCESS
    }

    # Check container status
    $otelStatus = "not found"
    $promStatus = "not found"
    try { $otelStatus = & $script:Runtime inspect --format '{{.State.Status}}' otel-collector 2>$null } catch { }
    try { $promStatus = & $script:Runtime inspect --format '{{.State.Status}}' prometheus 2>$null } catch { }

    if ($otelStatus -eq "running" -or $promStatus -eq "running") {
        $containerAction = "running -> will be restarted"
    }
    else {
        $containerAction = "not running -> will be started"
    }

    Write-Host "Runtime: $script:Runtime"
    Write-Host "Containers: $containerAction"
    Write-Host ""
    Write-Host "Ports to update:"
    foreach ($change in $changes) {
        Write-Host "  $change"
    }
    Write-Host ""
    Write-Host "Files that will be modified:"
    Write-Host "  - compose.yaml"
    Write-Host ""

    $choice = Read-Host "Proceed? [y/n]"

    if ($choice.ToLower() -ne "y") {
        Write-Host "Exiting without changes."
        exit $EXIT_CANCELLED
    }
    Write-Host ""
}

#------------------------------------------------------------------------------
# Backup and update
#------------------------------------------------------------------------------

function Invoke-BackupAndUpdate {
    $composeDir = Split-Path -Parent $script:ComposeFile

    # Create backup
    Write-Host "Creating backup: compose.yaml.bak"
    Copy-Item $script:ComposeFile "$script:ComposeFile.bak"

    # Read content
    $content = Get-Content -Raw $script:ComposeFile

    foreach ($key in @("grpc", "http", "metrics", "prom")) {
        $current = $script:CurrentPorts[$key]
        $new = $script:NewPorts[$key]
        $containerPort = $PortConfig[$key].ContainerPort

        if ($current -ne $new) {
            $oldPattern = "`"$current`:$containerPort`""
            $newPattern = "`"$new`:$containerPort`""

            # Verify pattern exists exactly once
            $matches = [regex]::Matches($content, [regex]::Escape($oldPattern))

            if ($matches.Count -ne 1) {
                Write-ErrorMessage "Expected 1 match for '$oldPattern', found $($matches.Count)"
                Write-Host "Restoring from backup..."
                Copy-Item "$script:ComposeFile.bak" $script:ComposeFile
                exit $EXIT_ERROR
            }

            # Perform replacement
            $content = $content -replace [regex]::Escape($oldPattern), $newPattern

            Write-Host "  Updated $($PortConfig[$key].Name): $current -> $new"
            $script:Modified = $true
        }
    }

    # Write updated content
    $content | Set-Content $script:ComposeFile -NoNewline
    Write-Host ""
}

#------------------------------------------------------------------------------
# Start and verify
#------------------------------------------------------------------------------

function Start-AndVerify {
    $composeDir = Split-Path -Parent $script:ComposeFile

    # Stop containers if running
    Write-Host "Stopping containers..."
    Push-Location $composeDir
    try {
        $cmdParts = $script:ComposeCmd -split ' '
        if ($cmdParts.Count -eq 2) {
            & $cmdParts[0] $cmdParts[1] down 2>$null
        }
        else {
            & $script:ComposeCmd down 2>$null
        }
    }
    catch { }

    # Start containers
    Write-Host "Starting containers..."
    try {
        $cmdParts = $script:ComposeCmd -split ' '
        if ($cmdParts.Count -eq 2) {
            & $cmdParts[0] $cmdParts[1] up -d
        }
        else {
            & $script:ComposeCmd up -d
        }
    }
    finally {
        Pop-Location
    }
    Write-Host ""

    # Wait for prometheus container to be running
    Write-Host "Verifying health..."
    $running = $false
    for ($i = 1; $i -le 30; $i++) {
        try {
            $status = & $script:Runtime inspect --format '{{.State.Status}}' prometheus 2>$null
            if ($status -eq "running") {
                $running = $true
                break
            }
        }
        catch { }
        Start-Sleep -Seconds 1
    }

    if (-not $running) {
        Write-Host "X Prometheus container failed to start" -ForegroundColor Red
        Write-Host ""
        Write-Host "Container logs:"
        try { & $script:Runtime logs prometheus --tail 20 } catch { }
        Write-Host ""
        Write-Host "To restore original config: Copy-Item compose.yaml.bak compose.yaml"
        exit $EXIT_HEALTH_FAILED
    }

    # Test Prometheus health endpoint
    $promPort = $script:NewPorts["prom"]
    $healthy = $false

    Write-Host -NoNewline "  Waiting for Prometheus on port $promPort..."
    for ($i = 1; $i -le 30; $i++) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:$promPort/-/healthy" -UseBasicParsing -TimeoutSec 2
            if ($response.StatusCode -eq 200) {
                $healthy = $true
                break
            }
        }
        catch { }
        Start-Sleep -Seconds 1
    }

    if (-not $healthy) {
        Write-Host " X failed" -ForegroundColor Red
        Write-Host ""
        Write-Host "Prometheus container is running but not responding."
        Write-Host ""
        Write-Host "Troubleshooting:"
        Write-Host "  1. Check container logs: $script:Runtime logs prometheus"
        Write-Host "  2. Verify port is not blocked by firewall"
        Write-Host "  3. Restore original config: Copy-Item compose.yaml.bak compose.yaml"
        exit $EXIT_HEALTH_FAILED
    }

    Write-Host " OK healthy" -ForegroundColor Green
    Write-Host ""
}

#------------------------------------------------------------------------------
# Print final summary
#------------------------------------------------------------------------------

function Write-FinalSummary {
    Write-Host "Configuration complete!"
    Write-Host ""
    Write-Host "New port configuration:"
    foreach ($key in @("grpc", "http", "metrics", "prom")) {
        $name = $PortConfig[$key].Name
        $port = $script:NewPorts[$key]
        Write-Host ("  {0,-25} {1}" -f "${name}:", $port)
    }
    Write-Host ""

    # Only show note if Prometheus port changed
    if ($script:CurrentPorts["prom"] -ne $script:NewPorts["prom"]) {
        Write-Host "Note: Update your Claude Code Monitor app settings to use:"
        Write-Host "  http://localhost:$($script:NewPorts['prom'])"
    }
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

function Main {
    Write-Host "Claude Code Monitor - Port Configuration"
    Write-Host "========================================="
    Write-Host ""

    # Step 1: Detect runtime
    Find-ContainerRuntime

    # Step 2: Find compose file
    Find-ComposeFile

    # Step 3: Read current ports
    Read-CurrentPorts

    # Step 4: Prompt for new ports
    Read-PortInputs

    # Step 5: Validate no duplicates (loop until valid)
    while (-not (Test-NoDuplicates)) {
        Read-DuplicatePorts
    }

    # Step 6: Check port conflicts (loop if user chooses to re-enter)
    while (-not (Test-PortConflicts)) {
        while (-not (Test-NoDuplicates)) {
            Read-DuplicatePorts
        }
    }

    # Step 7: Check running containers
    $null = Test-RunningContainers

    # Step 8: Show summary and confirm
    Show-Summary

    # Step 9: Backup and update
    Invoke-BackupAndUpdate

    # Step 10: Start and verify
    Start-AndVerify

    # Step 11: Print final summary
    Write-FinalSummary

    exit $EXIT_SUCCESS
}

# Run main
Main
