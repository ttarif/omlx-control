import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                optimalBanner
                ForEach(state.models) { model in
                    modelConfig(model)
                }
                serverConfig
            }
            .padding(12)
        }
    }

    // ── Optimal preset banner ────────────────────────────────────────
    private var optimalBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: state.allSettingsOptimal ? "checkmark.seal.fill" : "wand.and.stars")
                .font(.system(size: 16))
                .foregroundStyle(state.allSettingsOptimal ? .green : .accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(state.allSettingsOptimal ? "All models optimal" : "Optimal preset available")
                    .font(.system(size: 12, weight: .semibold))
                Text("llm engine · MTP off · f16 KV — benchmark-verified")
                    .font(.system(size: 9)).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Apply") { Task { await state.applyOptimalToAll() } }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!state.serverRunning || state.allSettingsOptimal)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quinary))
    }

    // ── Per-model config ─────────────────────────────────────────────
    private func modelConfig(_ model: ModelInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.displayName).font(.system(size: 12, weight: .semibold))

            Picker("Engine", selection: bind(model.id, \.modelTypeOverride)) {
                Text("auto").tag("auto"); Text("llm").tag("llm"); Text("vlm").tag("vlm")
            }
            .pickerStyle(.segmented).controlSize(.small)

            Toggle("MTP speculative decode", isOn: bind(model.id, \.mtpEnabled))
                .font(.system(size: 11)).toggleStyle(.switch).controlSize(.mini)
            Toggle("TurboQuant KV cache", isOn: bind(model.id, \.turboquantKV))
                .font(.system(size: 11)).toggleStyle(.switch).controlSize(.mini)

            HStack {
                if state.modelSettings[model.id] == .optimal {
                    Label("optimal", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 9)).foregroundStyle(.green)
                }
                Spacer()
                Button("Apply") { Task { await state.applySettings(for: model.id) } }
                    .buttonStyle(.bordered).controlSize(.small)
                    .disabled(!state.serverRunning)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quinary))
    }

    // ── Server config ────────────────────────────────────────────────
    private var serverConfig: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SERVER").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)

            HStack {
                Text("Host").font(.system(size: 11)).frame(width: 70, alignment: .leading)
                TextField("127.0.0.1", text: $state.host).textFieldStyle(.roundedBorder).controlSize(.small)
                Button {
                    state.detectTailscaleIP()
                } label: {
                    Image(systemName: "network").font(.system(size: 10))
                }
                .buttonStyle(.bordered).controlSize(.small)
                .help("Detect this machine's Tailscale IP")
            }
            Text("127.0.0.1 = local only · Tailscale IP = reachable across your tailnet")
                .font(.system(size: 8)).foregroundStyle(.secondary)

            HStack {
                Text("Port").font(.system(size: 11)).frame(width: 70, alignment: .leading)
                TextField("9900", text: $state.port).textFieldStyle(.roundedBorder).controlSize(.small)
            }
            HStack {
                Text("Guard").font(.system(size: 11)).frame(width: 70, alignment: .leading)
                Picker("", selection: $state.memoryGuard) {
                    Text("safe").tag("safe"); Text("balanced").tag("balanced"); Text("aggressive").tag("aggressive")
                }.pickerStyle(.segmented).controlSize(.small)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Model dir").font(.system(size: 11))
                Text(state.modelDir).font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }

            HStack(spacing: 8) {
                Button {
                    state.serverRunning ? state.stopServer() : state.startServer()
                } label: {
                    Label(state.serverRunning ? "Stop Server" : "Start Server",
                          systemImage: state.serverRunning ? "stop.fill" : "play.fill")
                        .font(.system(size: 11, weight: .medium)).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(state.serverRunning ? .red : .green)
                .controlSize(.small)
                .disabled(state.serverStarting)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quinary))
    }

    private func bind(_ id: String, _ kp: WritableKeyPath<ModelSettings, String>) -> Binding<String> {
        Binding(get: { state.modelSettings[id]?[keyPath: kp] ?? "auto" },
                set: { var s = state.modelSettings[id] ?? .optimal; s[keyPath: kp] = $0; state.modelSettings[id] = s })
    }
    private func bind(_ id: String, _ kp: WritableKeyPath<ModelSettings, Bool>) -> Binding<Bool> {
        Binding(get: { state.modelSettings[id]?[keyPath: kp] ?? false },
                set: { var s = state.modelSettings[id] ?? .optimal; s[keyPath: kp] = $0; state.modelSettings[id] = s })
    }
}
