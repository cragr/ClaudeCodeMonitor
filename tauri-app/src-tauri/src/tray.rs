use std::sync::Mutex;
use tauri::{tray::TrayIcon, State};

/// State to hold the tray icon handle for updating stats
pub struct TrayState {
    pub tray: Mutex<Option<TrayIcon>>,
}

impl TrayState {
    pub fn new() -> Self {
        Self {
            tray: Mutex::new(None),
        }
    }
}

/// Format cost for tray display
fn format_cost_short(cost: f64) -> String {
    if cost >= 1.0 {
        format!("${:.2}", cost)
    } else {
        format!("${:.3}", cost)
    }
}

/// Update the system tray with current stats
#[tauri::command]
pub async fn update_tray_stats(
    tray_state: State<'_, TrayState>,
    total_cost: f64,
    is_connected: bool,
) -> Result<(), String> {
    let tray_guard = tray_state.tray.lock().map_err(|e| e.to_string())?;
    if let Some(tray) = tray_guard.as_ref() {
        // Green circle for connected, red for disconnected
        let status_indicator = if is_connected { "🟢" } else { "🔴" };
        let title = format!("{} {}", status_indicator, format_cost_short(total_cost));
        tray.set_title(Some(&title))
            .map_err(|e| format!("Failed to set tray title: {}", e))?;
    }
    Ok(())
}
