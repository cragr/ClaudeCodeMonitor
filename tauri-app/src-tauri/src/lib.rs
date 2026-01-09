mod commands;
mod insights;
mod metrics;
mod prometheus;
mod prometheus_health;
mod sessions;
mod tray;

use tauri::{
    menu::{Menu, MenuItem},
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
    Manager, State,
};

use tray::TrayState;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_updater::Builder::new().build())
        .manage(TrayState::new())
        .setup(|app| {
            let quit = MenuItem::with_id(app, "quit", "Quit", true, None::<&str>)?;
            let show = MenuItem::with_id(app, "show", "Open Dashboard", true, None::<&str>)?;
            let menu = Menu::with_items(app, &[&show, &quit])?;

            let tray = TrayIconBuilder::new()
                .icon(app.default_window_icon().unwrap().clone())
                .menu(&menu)
                .show_menu_on_left_click(false)
                .title("🔴 --") // Initial placeholder (red = not connected yet)
                .on_menu_event(|app, event| match event.id.as_ref() {
                    "quit" => {
                        app.exit(0);
                    }
                    "show" => {
                        if let Some(window) = app.get_webview_window("main") {
                            let _ = window.show();
                            let _ = window.set_focus();
                        }
                    }
                    _ => {}
                })
                .on_tray_icon_event(|tray, event| {
                    if let TrayIconEvent::Click {
                        button: MouseButton::Left,
                        button_state: MouseButtonState::Up,
                        ..
                    } = event
                    {
                        let app = tray.app_handle();
                        if let Some(window) = app.get_webview_window("main") {
                            let _ = window.show();
                            let _ = window.set_focus();
                        }
                    }
                })
                .build(app)?;

            // Store tray handle in state for later updates
            let tray_state: State<TrayState> = app.state();
            if let Ok(mut guard) = tray_state.tray.lock() {
                *guard = Some(tray);
            }

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            commands::get_dashboard_metrics,
            commands::test_connection,
            commands::discover_metrics,
            commands::get_prometheus_health,
            insights::get_insights_data,
            insights::get_local_stats_cache,
            sessions::get_sessions_data,
            tray::update_tray_stats,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
