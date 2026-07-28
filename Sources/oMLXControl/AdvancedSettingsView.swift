import SwiftUI

// MARK: - Full oMLX model settings mirror (all 23 fields from /admin/api/models/{id}/settings)

struct FullModelSettings {
    // Engine
    var modelTypeOverride: String = "llm"    // auto | llm | vlm

    // Sampling
    var forceSampling: Bool = false
    var thinkingBudgetEnabled: Bool = false
    var guidedGrammarEnabled: Bool = false
    var trustRemoteCode: Bool = false

    // Speculative decoding — MTP
    var mtpEnabled: Bool = false
    var vlmMtpEnabled: Bool = false

    // Speculative decoding — SpecPrefill
    var specprefillEnabled: Bool = false

    // Speculative decoding — DFlash
    var dflashEnabled: Bool = false
    var dflashInMemoryCache: Bool = true
    var dflashInMemoryCacheMaxEntries: Int = 4
    var dflashInMemoryCacheMaxBytes: Int = 8_589_934_592  // 8 GB
    var dflashSsdCache: Bool = false
    var dflashSsdCacheMaxBytes: Int = 21_474_836_480      // 20 GB

    // Speculative decoding — DSpark
    var dsparkEnabled: Bool = false
    var dsparkMaxDraftTokens: Int = 2

    // KV cache quantization
    var turboquantKVEnabled: Bool = false
    var turboquantKVBits: Double = 4.0
    var turboquantSkipLast: Bool = true

    // Visibility
    var isPinned: Bool = false
    var isFavorite: Bool = false
    var isHidden: Bool = false
    var isDefault: Bool = false

    static let optimal = FullModelSettings(
        modelTypeOverride: "llm",
        forceSampling: false,
        thinkingBudgetEnabled: false,
        guidedGrammarEnabled: false,
        trustRemoteCode: false,
        mtpEnabled: false,
        vlmMtpEnabled: false,
        specprefillEnabled: false,
        dflashEnabled: false,
        dflashInMemoryCache: true,
        dflashInMemoryCacheMaxEntries: 4,
        dflashInMemoryCacheMaxBytes: 8_589_934_592,
        dflashSsdCache: false,
        dflashSsdCacheMaxBytes: 21_474_836_480,
        dsparkEnabled: false,
        dsparkMaxDraftTokens: 2,
        turboquantKVEnabled: false,
        turboquantKVBits: 4.0,
        turboquantSkipLast: true,
        isPinned: false,
        isFavorite: false,
        isHidden: false,
        isDefault: false
    )

    func toPayload() -> [String: Any] {
        [
            "model_type_override":              modelTypeOverride,
            "force_sampling":                   forceSampling,
            "thinking_budget_enabled":          thinkingBudgetEnabled,
            "guided_grammar_enabled":           guidedGrammarEnabled,
            "trust_remote_code":                trustRemoteCode,
            "mtp_enabled":                      mtpEnabled,
            "vlm_mtp_enabled":                  vlmMtpEnabled,
            "specprefill_enabled":              specprefillEnabled,
            "dflash_enabled":                   dflashEnabled,
            "dflash_in_memory_cache":           dflashInMemoryCache,
            "dflash_in_memory_cache_max_entries": dflashInMemoryCacheMaxEntries,
            "dflash_in_memory_cache_max_bytes": dflashInMemoryCacheMaxBytes,
            "dflash_ssd_cache":                 dflashSsdCache,
            "dflash_ssd_cache_max_bytes":       dflashSsdCacheMaxBytes,
            "dspark_enabled":                   dsparkEnabled,
            "dspark_max_draft_tokens":          dsparkMaxDraftTokens,
            "turboquant_kv_enabled":            turboquantKVEnabled,
            "turboquant_kv_bits":               turboquantKVBits,
            "turboquant_skip_last":             turboquantSkipLast,
            "is_pinned":                        isPinned,
            "is_favorite":                      isFavorite,
            "is_hidden":                        isHidden,
            "is_default":                       isDefault,
        ]
    }
}

// MARK: - Advanced settings view

struct AdvancedSettingsView: View {
    @EnvironmentObject var state: AppState
    let model: ModelInfo
    @Binding var fullSettings: FullModelSettings
    @State private var applying = false
    @State private var result: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                engineSection
                speculativeSection
                kvCacheSection
                samplingSection
                visibilitySection
                applyRow
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.windowBackground)
    }

    // MARK: Header
    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "gearshape.2.fill")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text("Advanced — \(model.displayName)")
                    .font(.system(size: 12, weight: .semibold))
                Text("All 23 oMLX model settings")
                    .font(.system(size: 9)).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Reset Optimal") {
                fullSettings = .optimal
            }
            .buttonStyle(.bordered).controlSize(.small)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quinary))
    }

    // MARK: Engine
    private var engineSection: some View {
        section(title: "ENGINE", icon: "cpu") {
            row("Model type", detail: "auto = let oMLX decide; llm = force text-only batched engine; vlm = force vision engine") {
                Picker("", selection: $fullSettings.modelTypeOverride) {
                    Text("auto").tag("auto")
                    Text("llm").tag("llm")
                    Text("vlm").tag("vlm")
                }
                .pickerStyle(.segmented).controlSize(.small).frame(width: 170)
            }
            toggleRow("Trust remote code", detail: "Allow loading custom tokenizer code from the model repo", val: $fullSettings.trustRemoteCode)
        }
    }

    // MARK: Speculative decoding
    private var speculativeSection: some View {
        section(title: "SPECULATIVE DECODE", icon: "bolt.horizontal") {
            // MTP
            groupBox(label: "MTP (Multi-Token Prediction)") {
                toggleRow("MTP enabled", detail: "Draft + verify multiple tokens per step using embedded MTP head", val: $fullSettings.mtpEnabled)
                toggleRow("VLM MTP enabled", detail: "MTP for vision-language models", val: $fullSettings.vlmMtpEnabled)
            }
            // SpecPrefill
            groupBox(label: "SpecPrefill") {
                toggleRow("SpecPrefill enabled", detail: "Speculative prefill — draft tokens during prompt processing for faster TTFT", val: $fullSettings.specprefillEnabled)
            }
            // DFlash
            groupBox(label: "DFlash (Laguna)") {
                toggleRow("DFlash enabled", detail: "Poolside DFlash speculative decoding (Laguna models only)", val: $fullSettings.dflashEnabled)
                toggleRow("In-memory cache", detail: "Cache KV state in RAM for instant session restore", val: $fullSettings.dflashInMemoryCache)
                intRow("Cache entries", detail: "Max number of in-memory cached sessions",
                        val: fullSettings.dflashInMemoryCacheMaxEntries) {
                    Stepper("", value: $fullSettings.dflashInMemoryCacheMaxEntries, in: 1...32).labelsHidden()
                }
                bytesRow("Cache max size", bytes: $fullSettings.dflashInMemoryCacheMaxBytes, step: 1_073_741_824, label: "GB")
                toggleRow("SSD cache", detail: "Spill overflow sessions to NVMe for persistent prefix cache", val: $fullSettings.dflashSsdCache)
                bytesRow("SSD cache max", bytes: $fullSettings.dflashSsdCacheMaxBytes, step: 1_073_741_824, label: "GB")
            }
            // DSpark
            groupBox(label: "DSpark (Bonsai)") {
                toggleRow("DSpark enabled", detail: "DeepSeek-style speculative decoding for Bonsai models", val: $fullSettings.dsparkEnabled)
                intRow("Max draft tokens", detail: "Draft depth for DSpark speculative chains",
                        val: fullSettings.dsparkMaxDraftTokens) {
                    Stepper("", value: $fullSettings.dsparkMaxDraftTokens, in: 1...8).labelsHidden()
                }
            }
        }
    }

    // MARK: KV cache
    private var kvCacheSection: some View {
        section(title: "KV CACHE", icon: "memorychip") {
            toggleRow("TurboQuant KV enabled", detail: "Quantize KV cache to save GPU memory at the cost of ~1-2% quality", val: $fullSettings.turboquantKVEnabled)
            row("KV bits", detail: "Quantization precision for cached K and V tensors") {
                Picker("", selection: $fullSettings.turboquantKVBits) {
                    Text("4").tag(4.0)
                    Text("8").tag(8.0)
                }
                .pickerStyle(.segmented).controlSize(.small).frame(width: 100)
                .disabled(!fullSettings.turboquantKVEnabled)
            }
            toggleRow("Skip last KV layer", detail: "Leave the final KV layer in f16 for quality; quantize the rest", val: $fullSettings.turboquantSkipLast)
        }
    }

    // MARK: Sampling
    private var samplingSection: some View {
        section(title: "SAMPLING & REASONING", icon: "dial.medium") {
            toggleRow("Force sampling", detail: "Override model-specific sampling constraints (use with caution)", val: $fullSettings.forceSampling)
            toggleRow("Thinking budget enabled", detail: "Cap the token budget allocated to <think>…</think> reasoning blocks", val: $fullSettings.thinkingBudgetEnabled)
            toggleRow("Guided grammar enabled", detail: "Enable constrained decoding / LBNF grammar enforcement", val: $fullSettings.guidedGrammarEnabled)
        }
    }

    // MARK: Visibility
    private var visibilitySection: some View {
        section(title: "VISIBILITY", icon: "eye") {
            toggleRow("Pinned", detail: "Pin model in the server's model list so it loads on startup", val: $fullSettings.isPinned)
            toggleRow("Default", detail: "Use this model when no model ID is specified in requests", val: $fullSettings.isDefault)
            toggleRow("Favorite", detail: "Mark as favourite in the oMLX UI", val: $fullSettings.isFavorite)
            toggleRow("Hidden", detail: "Hide from /v1/models list (still accessible by ID)", val: $fullSettings.isHidden)
        }
    }

    // MARK: Apply
    private var applyRow: some View {
        HStack {
            if let r = result {
                Text(r)
                    .font(.system(size: 10))
                    .foregroundStyle(r.contains("✓") ? .green : .red)
            }
            Spacer()
            Button {
                Task { await applyAll() }
            } label: {
                HStack(spacing: 4) {
                    if applying { ProgressView().scaleEffect(0.5).frame(width: 12, height: 12) }
                    Text("Apply All Settings")
                        .font(.system(size: 11, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(!state.serverRunning || applying)
        }
    }

    private func applyAll() async {
        applying = true
        defer { applying = false }
        // Tess-server has no per-model settings API.
        // Settings are baked into the profile; use tess-switch.sh to restart with a different profile.
        // The advanced panel still exposes all knobs for reference and future tess-server versions.
        result = "ℹ️ Tess settings are profile-level — use the Settings tab context picker or tess-switch to apply."
        state.statusMessage = "Advanced settings noted (restart via Settings tab to apply context changes)"
    }

    // MARK: - Builder helpers

    @ViewBuilder
    private func section<Content: View>(title: String, icon: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 9)).foregroundStyle(.secondary)
                Text(title).font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 10).fill(.quinary))
        }
    }

    @ViewBuilder
    private func groupBox<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            content()
            Divider().padding(.top, 2)
        }
    }

    @ViewBuilder
    private func row<Control: View>(_ label: String, detail: String,
                                    @ViewBuilder control: () -> Control) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.system(size: 11))
                Text(detail).font(.system(size: 8.5)).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            control()
        }
        .padding(.vertical, 3)
    }

    private func toggleRow(_ label: String, detail: String, val: Binding<Bool>) -> some View {
        row(label, detail: detail) {
            Toggle("", isOn: val).toggleStyle(.switch).controlSize(.mini).labelsHidden()
        }
    }

    private func intRow<Control: View>(_ label: String, detail: String, val: Int,
                                       @ViewBuilder control: () -> Control) -> some View {
        row(label, detail: detail) {
            HStack(spacing: 6) {
                Text("\(val)").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                control()
            }
        }
    }

    private func bytesRow(_ label: String, bytes: Binding<Int>, step: Int, label unit: String) -> some View {
        row(label, detail: "Current: \(bytes.wrappedValue / step) \(unit)") {
            Stepper("", value: bytes, in: step...(100 * step), step: step).labelsHidden()
            Text("\(bytes.wrappedValue / step) \(unit)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
    }
}
