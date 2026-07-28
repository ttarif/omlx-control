import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                profileSwitcher
                ForEach(state.models) { model in
                    contextCard(model)
                }
                serverConfig
            }
            .padding(12)
        }
    }

    // ── Profile switcher banner ──────────────────────────────────────
    private var profileSwitcher: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "cpu").font(.system(size: 13)).foregroundStyle(.accentColor)
                Text("Active Profile").font(.system(size: 12, weight: .semibold))
                Spacer()
                if state.serverRunning {
                    let active = state.models.first(where: { $0.isActive })
                    Text(active?.displayName ?? "—")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 8) {
                ForEach(state.models) { model in
                    Button {
                        Task { await state.switchProfile(model) }
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: model.isActive ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 14))
                                .foregroundStyle(model.isActive ? .green : .secondary)
                            Text(model.displayName)
                                .font(.system(size: 10, weight: .medium))
                            Text(model.quant)
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .tint(model.isActive ? .green : .primary)
                    .disabled(!state.serverRunning || model.isActive || model.isBusy)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quinary))
    }

    // ── Context preset per profile ───────────────────────────────────
    private func contextCard(_ model: ModelInfo) -> some View {
        let presets = AppState.contextPresets[model.profileID] ?? []
        let binding = Binding<Int>(
            get: { state.profileSettings[model.profileID]?.contextPreset ?? model.contextTokens },
            set: { state.profileSettings[model.profileID] = ProfileSettings(contextPreset: $0) }
        )
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(model.displayName).font(.system(size: 12, weight: .semibold))
                Spacer()
                if model.isActive {
                    Text("ACTIVE").font(.system(size: 8, weight: .bold)).foregroundStyle(.green)
                }
            }
            Text("Context window").font(.system(size: 10)).foregroundStyle(.secondary)
            Picker("Context", selection: binding) {
                ForEach(presets, id: \.tokens) { preset in
                    Text(preset.label).tag(preset.tokens)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
            HStack(spacing: 4) {
                Image(systemName: "info.circle").font(.system(size: 9)).foregroundStyle(.secondary)
                if model.profileID == "qwen36-a3b-q8-q4mtp" {
                    Text("128K = profile recommended · 512K uses YaRN (speculation off)")
                } else {
                    Text("All presets fully qualified · 256K = max native context")
                }
            }
            .font(.system(size: 8)).foregroundStyle(.secondary)
            Button("Apply & Restart") {
                Task {
                    let ctx = state.profileSettings[model.profileID]?.contextPreset ?? model.contextTokens
                    state.statusMessage = "Restarting \(model.displayName) at \(ctx / 1024)K…"
                    // Rewrite plist context and restart via tess-switch
                    try? await APIClient.switchProfileWithContext(model.profileID, context: ctx)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!state.serverRunning || !model.isActive)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quinary))
    }

    // ── Server config ────────────────────────────────────────────────
    private var serverConfig: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TESS SERVER").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
            HStack {
                Text("Host").font(.system(size: 11)).frame(width: 50, alignment: .leading)
                TextField("127.0.0.1", text: $state.host).textFieldStyle(.roundedBorder).controlSize(.small)
                Button { state.detectTailscaleIP() } label: {
                    Image(systemName: "network").font(.system(size: 10))
                }
                .buttonStyle(.bordered).controlSize(.small)
                .help("Set to Tailscale IP for tailnet access")
            }
            HStack {
                Text("Port").font(.system(size: 11)).frame(width: 50, alignment: .leading)
                TextField("8020", text: $state.port).textFieldStyle(.roundedBorder).controlSize(.small)
                Text("default: 8020").font(.system(size: 9)).foregroundStyle(.secondary)
            }
            Text("Profile switches via ~/projects/omp-stack/gateway/scripts/tess-switch.sh")
                .font(.system(size: 8, design: .monospaced)).foregroundStyle(.secondary)
            Button {
                state.serverRunning ? state.stopServer() : state.startServer()
            } label: {
                Label(state.serverRunning ? "Stop Tess" : "Start Tess",
                      systemImage: state.serverRunning ? "stop.fill" : "play.fill")
                    .font(.system(size: 11, weight: .medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(state.serverRunning ? .red : .green)
            .controlSize(.small)
            .disabled(state.serverStarting)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quinary))
    }
}
