# oMLX Control

A macOS native menu bar control panel for the [oMLX](https://github.com/jundot/omlx) inference server.

## Overview
This application provides a native, lightweight interface to manage your local AI model hosting. It runs in the menu bar, giving you:
- **Server Lifecycle:** Start/Stop the oMLX server with customized arguments.
- **Model Management:** Load/Unload models, see live status, and benchmark performance.
- **Real-time Stats:** Live performance metrics (tokens/sec, memory pressure) via Swift Charts.
- **Configuration:** Fine-tune per-model settings (MTP, TurboKV) with an "Apply Optimal" preset.

## Benchmark Results (64K context)
| Model | Role | PP (t/s) | TG (t/s) | Weights |
|---|---|---|---|---|
| **Qwen36-35B** | Reasoning | 1037 | 63.1 | 21 GB |
| **Laguna S-2.1 oQ2e** | Coding | 289 | 29.2 | 36 GB |

## Setup Instructions

### 1. Build
Requires Xcode (for SwiftUI macros) and Swift 5.9+.
```bash
git clone https://github.com/ttarif/omlx-control
cd omlx-control
./build.sh
```
This builds a release binary and bundles it into `~/Applications/oMLX Control.app`.

### 2. Configuration
The app expects the oMLX binary at `~/.local/share/omlx-0.5.3/bin/omlx` and model data at `~/.local/share/omlx-models`.
Ensure your local `~/.omlx/model_settings.json` matches your server's deployment.

### 3. Usage
- The app resides in your menu bar (no Dock icon).
- Start the server using the "Start Server" button in the Settings tab.
- Click the icon to open the popover, switch between Models, Stats, and Settings.
- Use the "Apply Optimal" button to lock in the benchmark-validated configurations.
