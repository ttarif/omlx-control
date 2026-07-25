# oMLX Control

> A native macOS menu bar control panel for local LLM inference via [oMLX](https://github.com/jundot/omlx). Manage models, monitor real-time GPU stats, and tune settings — all from the menu bar.

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![Swift](https://img.shields.io/badge/swift-5.9%2B-orange)
![License](https://img.shields.io/badge/license-MIT-green)

---

## Screenshots

### Models Tab
Displays both models with live load status, role badges (Reasoning / Coding), benchmark PP/TG numbers, and a live t/s measurement from the last test run.

```
┌─────────────────────────────────────────────┐
│ ◉  oMLX Control  · Running · 1/2 loaded     │ [Stop]
├─────────────────────────────────────────────┤
│    Models  │    Stats    │    Settings       │
├─────────────────────────────────────────────┤
│ ● Qwen36 35B-A3B               [REASONING]  │
│   FP16  256K  20.5GB                        │
│   Prefill  1037      Decode  63             │
│   [  Unload  ]          [  ⚡ Test  ]        │
├ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─┤
│ ○ Laguna S-2.1 oQ2e              [CODING]   │
│   2-bit  1M  35.4GB                         │
│   Prefill   289      Decode  29             │
│   [   Load   ]          [  ⚡ Test  ]        │
└─────────────────────────────────────────────┘
│ Ready                                   [⏻] │
└─────────────────────────────────────────────┘
```

### Stats Tab
Live polling every 2 seconds. Shows GPU memory pressure bar (ok → warning → high → critical), a 6-metric grid, and a rolling decode throughput chart.

```
┌─────────────────────────────────────────────┐
│ GPU MEMORY                              [OK] │
│ ████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░   │
│ 18.6GB              soft 87.7GB · hard 105GB │
├──────────────┬──────────────────────────────┤
│ ↓ Prefill    │ ↑ Decode                     │
│   1037 t/s   │   63.1 t/s                   │
├──────────────┼──────────────────────────────┤
│ ⊞ Requests   │ ⚡ Active                     │
│   2 total    │   0 · 0 waiting              │
├──────────────┼──────────────────────────────┤
│ # Tokens     │ ⊟ Cache                      │
│   63.2K      │   0% hit rate                │
├──────────────┴──────────────────────────────┤
│ DECODE THROUGHPUT                           │
│  70 ┤                                       │
│  35 ┤    ╭──╮   ╭─╮                        │
│   0 ┤────╯  ╰───╯ ╰────────────────        │
└─────────────────────────────────────────────┘
```

### Settings Tab
One-click "Apply Optimal" preset (benchmark-validated), per-model engine type / MTP / TurboKV toggles, and server host/port/guard configuration with Tailscale IP auto-detection.

```
┌─────────────────────────────────────────────┐
│ ✓  All models optimal           [  Apply  ] │
│    llm engine · MTP off · f16 KV            │
├─────────────────────────────────────────────┤
│ Qwen36 35B-A3B                              │
│ Engine  [ auto | llm | vlm ]                │
│ ○  MTP speculative decode                   │
│ ○  TurboQuant KV cache              ✓ opt  │
├─────────────────────────────────────────────┤
│ Laguna S-2.1 oQ2e                           │
│ Engine  [ auto | llm | vlm ]                │
│ ○  MTP speculative decode                   │
│ ○  TurboQuant KV cache              ✓ opt  │
├─────────────────────────────────────────────┤
│ SERVER                                      │
│ Host    [127.0.0.1         ] [🌐]           │
│         127.0.0.1 = local · Tailscale = net │
│ Port    [9900]                              │
│ Guard   [ safe | balanced | aggressive ]    │
│         [         Stop Server         ]     │
└─────────────────────────────────────────────┘
```

---

## Features

| Feature | Detail |
|---|---|
| **Server control** | Start / Stop oMLX with configurable host, port, and memory-guard tier |
| **Tailscale support** | One-click Tailscale IP detection — serve models across your tailnet without public exposure |
| **Model load/unload** | POST to oMLX Admin API; shows live loaded status with green indicator dot |
| **Live test** | Fires a real inference call and reports measured decode t/s |
| **GPU memory bar** | Color-coded pressure gauge (ok → warning → high → critical) |
| **Throughput chart** | Rolling 60-sample decode t/s line+area chart via Swift Charts |
| **Optimal preset** | One button applies all benchmark-validated settings to every model |
| **Per-model config** | Engine override (auto/llm/vlm), MTP speculative decode, TurboKV cache |

---

## Benchmark Results

All benchmarks run on **Apple M1 Ultra (128 GB unified memory)**, oMLX 0.5.3, 64K context, clean GPU state (0 B active before each run).

| Model | Quant | Weights | Prefill t/s | Decode t/s | Context |
|---|---|---|---|---|---|
| Qwen3.6-35B-A3B | FP16 | 20.5 GB | **1037** | **63.1** | 256K native |
| Laguna S-2.1 oQ2e | 2-bit | 35.4 GB | 289 | 29.2 | 1M (sliding) |

**Combined footprint:** 55.9 GB — fits comfortably within the 107.5 GB Metal cap at 64K context with room for both models loaded simultaneously.

Full benchmark scripts and results: [ttarif/local-model-benchmarks](https://github.com/ttarif/local-model-benchmarks)

---

## Requirements

- macOS 14.0+
- Xcode (full, not just Command Line Tools) — required for SwiftUI `MenuBarExtra` macros
- [oMLX](https://github.com/jundot/omlx) installed at `~/.local/share/omlx-*/bin/omlx`

---

## Build & Install

```bash
git clone https://github.com/ttarif/omlx-control
cd omlx-control
./build.sh
```

The script:
1. Detects your installed Xcode automatically
2. Compiles a release binary with `swift build -c release`
3. Assembles the `.app` bundle with `Info.plist` and `AppIcon.icns`
4. Installs to `~/Applications/oMLX Control.app`
5. Launches the app

To rebuild after code changes:
```bash
./build.sh          # build, install, and relaunch
./build.sh --no-open  # build and install without launching
```

To regenerate the icon:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  swift Scripts/make-icon.swift /tmp/iconbuild
```

---

## Configuration

The app connects to the oMLX Admin API at `http://<host>:<port>`. Defaults to `127.0.0.1:9900`.

### Local only (default)
No configuration needed. Start the server from the Settings tab.

### Tailscale (access from other devices on your tailnet)
1. Open the Settings tab
2. Click the **🌐** button next to the Host field — the app calls `tailscale ip -4` and sets your tailnet IP automatically
3. Restart the server — it will now bind to the Tailscale interface only (not public)
4. Other devices on your tailnet can reach it at `http://<your-tailscale-ip>:9900/v1`

### omp integration (oh-my-pi)
Add to `~/.omp/agent/models.yml`:
```yaml
  omlx:
    baseUrl: "http://127.0.0.1:9900/v1"   # or your Tailscale IP
    apiKey: "local"
    compat:
      supportsEagerToolInputStreaming: false
    models:
      - id: "qwen36-35b-mtplx"
        name: "Qwen36-35B [local · FP16 · 256K]"
        api: "openai-completions"
        contextWindow: 262144
        maxTokens: 16384
      - id: "laguna-oq2e"
        name: "Laguna S-2.1 oQ2e [local · 2bit · 1M]"
        api: "openai-completions"
        contextWindow: 1048576
        maxTokens: 16384
```

Add to `~/.omp/agent/config.yml`:
```yaml
modelRoles:
  smol: omlx/laguna-oq2e        # fast coding / direct output
  slow: omlx/qwen36-35b-mtplx   # reasoning / architecture
```

---

## Project Structure

```
omlx-control/
├── Sources/oMLXControl/
│   ├── oMLXControlApp.swift   # @main entry, MenuBarExtra, Header, Footer
│   ├── AppState.swift         # ObservableObject: server state, polling, actions
│   ├── APIClient.swift        # oMLX Admin API wrappers (load, unload, stats, settings)
│   ├── ModelsView.swift       # Model cards with status, benchmarks, load/test buttons
│   ├── StatsView.swift        # GPU memory pressure bar, metrics grid, throughput chart
│   └── SettingsView.swift     # Optimal preset, per-model config, server settings
├── Resources/
│   ├── AppIcon.icns           # Generated by Scripts/make-icon.swift
│   └── Info.plist             # Bundle metadata (LSUIElement=true, no Dock icon)
├── Scripts/
│   └── make-icon.swift        # CoreGraphics icon generator (circular, gradient + glyph)
├── Package.swift
└── build.sh                   # Build + bundle + install script
```

---

## License

MIT
