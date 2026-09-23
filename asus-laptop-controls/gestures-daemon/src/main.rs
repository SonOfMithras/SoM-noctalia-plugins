use evdev::{AbsoluteAxisCode, Device, EventSummary, KeyCode};
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;
use tokio::process::Command;

const EDGE_PERCENT: f64 = 0.04;
const STEP_THRESHOLD: i32 = 300;

#[derive(Debug, Serialize, Deserialize, Clone)]
struct GesturesConfig {
    gestures_enabled: bool,
    left_edge_up: String,
    left_edge_down: String,
    right_edge_up: String,
    right_edge_down: String,
    top_edge_left: String,
    top_edge_right: String,
}

impl Default for GesturesConfig {
    fn default() -> Self {
        Self {
            gestures_enabled: true,
            left_edge_up: "pactl set-sink-volume @DEFAULT_SINK@ +5%".to_string(),
            left_edge_down: "pactl set-sink-volume @DEFAULT_SINK@ -5%".to_string(),
            right_edge_up: "brightnessctl set 5%+".to_string(),
            right_edge_down: "brightnessctl set 5%-".to_string(),
            top_edge_left: "playerctl previous".to_string(),
            top_edge_right: "playerctl next".to_string(),
        }
    }
}

fn load_config() -> GesturesConfig {
    let mut config_path = dirs::data_local_dir().unwrap_or_else(|| PathBuf::from("~/.local/share"));
    config_path.push("noctalia");
    config_path.push("plugins");
    config_path.push("asus-laptop-controls");
    config_path.push("config.json");

    if let Ok(data) = fs::read_to_string(&config_path) {
        if let Ok(config) = serde_json::from_str(&data) {
            return config;
        }
    }
    
    // Create default config if it doesn't exist
    let default_config = GesturesConfig::default();
    if let Some(parent) = config_path.parent() {
        let _ = fs::create_dir_all(parent);
    }
    if let Ok(json) = serde_json::to_string_pretty(&default_config) {
        let _ = fs::write(&config_path, json);
    }
    
    default_config
}

enum GestureState {
    Idle,
    Classifying { x: Option<i32>, y: Option<i32> },
    LeftEdge { last_y: i32 },
    RightEdge { last_y: i32 },
    TopEdge { start_x: i32, done: bool },
    Other,
}

fn try_classify(state: &mut GestureState, left: i32, right: i32, top: i32) {
    if let GestureState::Classifying { x: Some(x), y: Some(y) } = *state {
        *state = if x < left {
            GestureState::LeftEdge { last_y: y }
        } else if x > right {
            GestureState::RightEdge { last_y: y }
        } else if y < top {
            GestureState::TopEdge { start_x: x, done: false }
        } else {
            GestureState::Other
        };
    }
}

fn find_touchpad() -> Option<Device> {
    for (_, device) in evdev::enumerate() {
        let name = device.name().unwrap_or_default().to_lowercase();
        if !name.contains("touchpad") {
            continue;
        }
        if let Some(axes) = device.supported_absolute_axes() {
            if axes.contains(AbsoluteAxisCode::ABS_X) && axes.contains(AbsoluteAxisCode::ABS_Y) {
                return Some(device);
            }
        }
    }
    None
}

async fn run_action(cmd_string: &str) {
    if cmd_string.trim().is_empty() { return; }
    let _ = Command::new("sh")
        .arg("-c")
        .arg(cmd_string)
        .status()
        .await;
}

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt::init();
    
    let config = load_config();
    if !config.gestures_enabled {
        tracing::info!("Gestures are disabled in config. Exiting.");
        return;
    }

    let device = match find_touchpad() {
        Some(d) => d,
        None => {
            tracing::warn!("No touchpad found! Ensure you have read access to /dev/input/ (e.g. via udev rules).");
            return;
        }
    };

    tracing::info!("Found touchpad: {}", device.name().unwrap_or("Unknown"));

    let abs_state = match device.get_abs_state() {
        Ok(states) => states,
        Err(e) => {
            tracing::error!("Failed to get absolute state: {}", e);
            return;
        }
    };
    
    let x_info = abs_state[AbsoluteAxisCode::ABS_X.0 as usize];
    let y_info = abs_state[AbsoluteAxisCode::ABS_Y.0 as usize];

    let x_max = x_info.maximum;
    let y_max = y_info.maximum;
    let left_bound = (x_max as f64 * EDGE_PERCENT) as i32;
    let right_bound = (x_max as f64 * (1.0 - EDGE_PERCENT)) as i32;
    let top_bound = (y_max as f64 * EDGE_PERCENT) as i32;

    tracing::info!("Bounds - Left: < {}, Right: > {}, Top: < {}", left_bound, right_bound, top_bound);

    let mut stream = match device.into_event_stream() {
        Ok(s) => s,
        Err(e) => {
            tracing::error!("Failed to open event stream (Permission denied?): {}", e);
            return;
        }
    };

    let mut state = GestureState::Idle;

    loop {
        let event = match stream.next_event().await {
            Ok(ev) => ev,
            Err(e) => {
                tracing::error!("Event read error: {}", e);
                break;
            }
        };

        match event.destructure() {
            EventSummary::Key(_, KeyCode::BTN_TOUCH, value) => {
                if value == 1 {
                    state = GestureState::Classifying { x: None, y: None };
                } else {
                    state = GestureState::Idle;
                }
            }
            EventSummary::AbsoluteAxis(_, AbsoluteAxisCode::ABS_X, value) => {
                if let GestureState::Classifying { x, .. } = &mut state {
                    *x = Some(value);
                    try_classify(&mut state, left_bound, right_bound, top_bound);
                } else if let GestureState::TopEdge { start_x, done } = &mut state {
                    if !*done {
                        let dx = value - *start_x;
                        if dx.abs() >= STEP_THRESHOLD {
                            *done = true;
                            if dx < 0 {
                                run_action(&config.top_edge_left).await;
                            } else {
                                run_action(&config.top_edge_right).await;
                            }
                        }
                    }
                }
            }
            EventSummary::AbsoluteAxis(_, AbsoluteAxisCode::ABS_Y, value) => {
                if let GestureState::Classifying { y, .. } = &mut state {
                    *y = Some(value);
                    try_classify(&mut state, left_bound, right_bound, top_bound);
                } else {
                    match &mut state {
                        GestureState::LeftEdge { last_y } => {
                            let dy = value - *last_y;
                            if dy.abs() >= STEP_THRESHOLD {
                                *last_y = value;
                                if dy < 0 {
                                    run_action(&config.left_edge_up).await;
                                } else {
                                    run_action(&config.left_edge_down).await;
                                }
                            }
                        }
                        GestureState::RightEdge { last_y } => {
                            let dy = value - *last_y;
                            if dy.abs() >= STEP_THRESHOLD {
                                *last_y = value;
                                if dy < 0 {
                                    run_action(&config.right_edge_up).await;
                                } else {
                                    run_action(&config.right_edge_down).await;
                                }
                            }
                        }
                        _ => {}
                    }
                }
            }
            _ => {}
        }
    }
}
