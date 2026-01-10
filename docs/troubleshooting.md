# Troubleshooting

This guide covers common issues across all platforms.

## Connection Issues

### "Not Connected" in the app

1. **Check if Prometheus is running:**

   ```bash
   podman compose ps
   ```

   If not running:

   ```bash
   podman compose up -d
   ```

2. **Verify Prometheus URL in Settings:**

   Default: `http://localhost:9090`

3. **Test connection in Settings:**

   Click the "Test Connection" button.

4. **Check Prometheus directly:**

   Open http://localhost:9090 in your browser.

### Cannot connect to Podman

**macOS/Windows:**

```bash
podman machine start
```

**If machine is corrupted:**

```bash
podman machine stop
podman machine rm
podman machine init
podman machine start
```

### Port conflicts

Check if ports 4317, 4318, or 9090 are in use:

**macOS/Linux:**

```bash
lsof -i :9090
lsof -i :4317
```

**Windows:**

```powershell
netstat -ano | findstr :9090
netstat -ano | findstr :4317
```

Stop conflicting services or change ports in `compose.yaml`.

## No Metrics Showing

### 1. Verify telemetry is enabled

```bash
echo $CLAUDE_CODE_ENABLE_TELEMETRY
```

Should output `1`. If not, see [Configuration](configuration.md).

### 2. Verify OTel settings

```bash
echo $OTEL_METRICS_EXPORTER          # Should be: otlp
echo $OTEL_EXPORTER_OTLP_PROTOCOL    # Should be: grpc
echo $OTEL_EXPORTER_OTLP_ENDPOINT    # Should be: http://localhost:4317
```

### 3. Restart Claude Code

After setting environment variables, you must restart Claude Code for them to take effect.

### 4. Use Claude Code to generate metrics

Metrics are only created when you use Claude Code. Run a few commands to generate data.

### 5. Check Prometheus targets

Open http://localhost:9090/targets

The `otel-collector` target should show state "UP".

### 6. Query Prometheus directly

Open http://localhost:9090/graph and run:

```
{__name__=~"claude.*"}
```

This shows all Claude-related metrics.

### 7. Check OTel Collector logs

```bash
podman compose logs otel-collector
```

Look for connection errors or dropped metrics.

## Build Issues

### macOS

**"xcrun: error: invalid active developer path"**

Install Xcode Command Line Tools:

```bash
xcode-select --install
```

**Rust compilation errors**

Update Rust:

```bash
rustup update
```

### Linux

**WebKit/GTK errors**

Install development packages:

```bash
# Debian/Ubuntu
sudo apt install -y libwebkit2gtk-4.1-dev libgtk-3-dev libappindicator3-dev librsvg2-dev patchelf

# Fedora
sudo dnf install -y webkit2gtk4.1-devel gtk3-devel libappindicator-gtk3-devel librsvg2-devel patchelf
```

**"error: linker `cc` not found"**

Install build essentials:

```bash
# Debian/Ubuntu
sudo apt install -y build-essential

# Fedora
sudo dnf install -y @development-tools
```

### Windows

**"LINK : fatal error LNK1181: cannot open input file"**

Install Visual Studio Build Tools with C++ workload:

1. Download [Build Tools](https://visualstudio.microsoft.com/visual-cpp-build-tools/)
2. Select "Desktop development with C++"
3. Restart your terminal

**"VCRUNTIME140.dll not found"**

Install Visual C++ Redistributable:
- [Download vc_redist.x64.exe](https://aka.ms/vs/17/release/vc_redist.x64.exe)

## App-Specific Issues

### macOS: "App is damaged and can't be opened"

Remove quarantine attribute:

```bash
xattr -cr /Applications/Claude\ Code\ Monitor.app
```

### macOS: App crashes on launch

Check Console.app for crash logs or try running from terminal:

```bash
/Applications/Claude\ Code\ Monitor.app/Contents/MacOS/Claude\ Code\ Monitor
```

### Linux: AppImage won't run

Install FUSE:

```bash
# Debian/Ubuntu
sudo apt install -y fuse libfuse2

# Fedora
sudo dnf install -y fuse fuse-libs
```

Make it executable:

```bash
chmod +x Claude.Code.Monitor_*.AppImage
```

### Linux: System tray icon not showing

Install app indicator support:

```bash
# Debian/Ubuntu
sudo apt install -y libayatana-appindicator3-1

# Fedora
sudo dnf install -y libappindicator-gtk3
```

### Windows: App fails to start (WebView2)

Install Microsoft Edge WebView2 Runtime:
- [Download WebView2](https://developer.microsoft.com/en-us/microsoft-edge/webview2/)

### Windows: Environment variables not working

PowerShell and Command Prompt use different syntax. See [Configuration](configuration.md) for platform-specific instructions.

## Podman-Specific Issues

### "Error: cannot connect to Podman"

**macOS/Windows:** Start the Podman machine:

```bash
podman machine start
```

**Linux:** Ensure Podman service is running:

```bash
systemctl --user start podman.socket
```

### "Image not found" errors

Pull images manually:

```bash
podman pull otel/opentelemetry-collector-contrib:latest
podman pull prom/prometheus:latest
```

### Containers exit immediately

Check logs for errors:

```bash
podman compose logs
```

Common causes:
- Port conflicts
- Missing config files
- Permission issues

### Volume permission errors (Linux)

Run with user namespace mapping:

```bash
podman compose down
podman compose up -d
```

Or use rootless Podman (default on most systems).

## Getting Help

If you're still having issues:

1. Check existing [GitHub Issues](https://github.com/cragr/ClaudeCodeMonitor/issues)
2. Open a new issue with:
   - Operating system and version
   - Output of `podman --version`
   - Output of `podman compose ps`
   - Relevant error messages
   - Steps to reproduce
