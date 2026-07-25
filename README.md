# oMLX Control

> A native macOS menu bar control panel for local LLM inference via [oMLX](https://github.com/jundot/omlx). Manage models, monitor real-time GPU stats, tune all 23 oMLX settings — all from the menu bar.

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![Swift](https://img.shields.io/badge/swift-5.9%2B-orange)
![License](https://img.shields.io/badge/license-MIT-green)

---

## Screenshots

| Models | Stats | Settings |
|:---:|:---:|:---:|
| ![Models tab](Screenshots/models-tab.png) | ![Stats tab](Screenshots/stats-tab.png) | ![Settings tab](Screenshots/settings-tab.png) |

---

## Features

| Feature | Detail |
|---|---|
| **Server control** | Start / Stop oMLX with configurable host, port, and memory-guard tier |
| **Tailscale support** | One-click Tailscale IP detection — serve models across your tailnet, not public |
| **Model cards** | Role badge, quant/context/weight chips, Prefill + Decode + Live t/s, load status |
| **Load / Unload** | POST to oMLX Admin API; green indicator + border when loaded |
| **Live test** | Fires a real inference call and measures decode t/s inline |
| **GPU memory bar** | Color-coded pressure gauge (ok → warning → high → critical) |
| **Throughput chart** | Rolling 60-sample decode t/s line+area chart via Swift Charts |
| **Optimal preset** | One button applies all benchmark-validated settings to every model |
| **Basic settings** | Per-model engine override (auto/llm/vlm), MTP, TurboKV |
| **Advanced settings** | Full panel covering all 23 oMLX settings — see [Advanced](#advanced-settings) |

---

## Benchmark Results

All benchmarks run on **Apple M1 Ultra (128 GB unified memory)**, oMLX 0.5.3, 64K context, clean GPU state (0 B active before each run).

| Model | Quant | Weights | Prefill t/s | Decode t/s | Context |
|---|---|---|---|---|---|
| Qwen3.6-35B-A3B | FP16 | 20.5 GB | **1037** | **63.1** | 256K native |
| Laguna S-2.1 oQ2e | 2-bit | 35.4 GB | 289 | 29.2 | 1M (sliding) |

**Combined footprint:** 55.9 GB — both models fit simultaneously within the 107.5 GB Metal cap at 64K context.

Full benchmark scripts and results: [ttarif/local-model-benchmarks](https://github.com/ttarif/local-model-benchmarks)

---

## Advanced Settings

Click the **⚙️ Advanced** button on any model card in the Settings tab to open the full settings panel. Every oMLX model setting is exposed with descriptions:

### Engine
| Field | Description |
|---|---|
| `model_type_override` | `auto` = let oMLX decide · `llm` = force batched text engine · `vlm` = force vision engine |
| `trust_remote_code` | Allow loading custom tokenizer code from the model repository |

### Speculative Decode — MTP
| Field | Description |
|---|---|
| `mtp_enabled` | Draft + verify multiple tokens per step using the embedded MTP head |
| `vlm_mtp_enabled` | MTP for vision-language models |

### Speculative Decode — SpecPrefill
| Field | Description |
|---|---|
| `specprefill_enabled` | Speculative prefill — draft tokens during prompt processing for faster TTFT |

### Speculative Decode — DFlash (Laguna)
| Field | Description |
|---|---|
| `dflash_enabled` | Poolside DFlash speculative decoding (Laguna models only) |
| `dflash_in_memory_cache` | Cache KV state in RAM for instant session restore |
| `dflash_in_memory_cache_max_entries` | Max in-memory cached sessions (default: 4) |
| `dflash_in_memory_cache_max_bytes` | In-memory cache size limit (default: 8 GB) |
| `dflash_ssd_cache` | Spill overflow sessions to NVMe for persistent prefix cache |
| `dflash_ssd_cache_max_bytes` | SSD cache size limit (default: 20 GB) |

### Speculative Decode — DSpark (Bonsai)
| Field | Description |
|---|---|
| `dspark_enabled` | DeepSeek-style speculative decoding for Bonsai models |
| `dspark_max_draft_tokens` | Draft depth for DSpark speculative chains (default: 2) |

### KV Cache Quantization
| Field | Description |
|---|---|
| `turboquant_kv_enabled` | Quantize KV cache to save GPU memory (~1–2% quality cost) |
| `turboquant_kv_bits` | KV quantization precision: `4` or `8` bits |
| `turboquant_skip_last` | Leave the final KV layer in f16; quantize the rest |

### Sampling & Reasoning
| Field | Description |
|---|---|
| `force_sampling` | Override model-specific sampling constraints |
| `thinking_budget_enabled` | Cap the token budget for `<think>…</think>` reasoning blocks |
| `guided_grammar_enabled` | Enable constrained decoding / LBNF grammar enforcement |

### Visibility
| Field | Description |
|---|---|
| `is_pinned` | Pin model to load on server startup |
| `is_default` | Use this model when no model ID is specified |
| `is_favorite` | Mark as favourite in the oMLX UI |
| `is_hidden` | Hide from `/v1/models` (still accessible by ID) |

---

## Requirements

- macOS 14.0+
- Xcode (full install, not just Command Line Tools) — required for SwiftUI `MenuBarExtra` macros
- [oMLX](https://github.com/jundot/omlx) installed at `~/.local/share/omlx-*/bin/omlx`

---

## Build & Install

```bash
git clone https://github.com/ttarif/omlx-control
cd omlx-control
./build.sh
```

The script automatically detects Xcode, compiles a release binary, assembles the `.app` bundle with `Info.plist` and `AppIcon.icns`, installs to `~/Applications/oMLX Control.app`, and launches it.

```bash
./build.sh            # build, install, relaunch
./build.sh --no-open  # build and install only
```

To regenerate the icon from source:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  swift Scripts/make-icon.swift /tmp/iconbuild
```

---

## Configuration

Defaults to `http://127.0.0.1:9900`. Change in the **Settings → Server** section.

### Tailscale (access from other devices on your tailnet)
1. Open **Settings → Host** and click the **🌐** button — the app queries `tailscale ip -4` and sets your tailnet IP automatically.
2. Restart the server — it binds to the Tailscale interface only, not public networks.
3. Other tailnet devices reach it at `http://<your-tailscale-ip>:9900/v1`.

### omp integration
Add to `~/.omp/agent/models.yml`:
```yaml
  omlx:
    baseUrl: "http://127.0.0.1:9900/v1"
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
  smol: omlx/laguna-oq2e
  slow: omlx/qwen36-35b-mtplx
```

---

## Project Structure

```
omlx-control/
├── Sources/oMLXControl/
│   ├── oMLXControlApp.swift      # @main entry, MenuBarExtra, Header, Footer
│   ├── AppState.swift            # ObservableObject: server state, polling, all actions
│   ├── APIClient.swift           # oMLX Admin API — load, unload, stats, settings (POST/PUT)
│   ├── ModelsView.swift          # Model cards: status, bench numbers, load/test buttons
│   ├── StatsView.swift           # GPU memory bar, 6-metric grid, decode throughput chart
│   ├── SettingsView.swift        # Optimal preset, per-model config, server settings
│   └── AdvancedSettingsView.swift # Full 23-field oMLX settings panel with descriptions
├── Screenshots/
│   ├── models-tab.png
│   ├── stats-tab.png
│   └── settings-tab.png
├── Resources/
│   ├── AppIcon.icns              # Generated by Scripts/make-icon.swift
│   └── Info.plist                # Bundle metadata (LSUIElement=true — no Dock icon)
├── Scripts/
│   └── make-icon.swift           # CoreGraphics icon generator (circle, gradient + glyph)
├── Package.swift
└── build.sh                      # Build + bundle + install + optional launch
```

---

## License

MIT
