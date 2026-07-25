import SwiftUI

struct ModelsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(state.models) { model in
                    ModelCard(model: model)
                }
                if !state.serverRunning {
                    offlineHint
                }
            }
            .padding(12)
        }
    }

    private var offlineHint: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle")
            Text("Start the server to load and test models.")
        }
        .font(.system(size: 10))
        .foregroundStyle(.secondary)
        .padding(.top, 4)
    }
}

struct ModelCard: View {
    @EnvironmentObject var state: AppState
    let model: ModelInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title row
            HStack(spacing: 8) {
                Circle()
                    .fill(model.isLoaded ? Color.green : Color.secondary.opacity(0.35))
                    .frame(width: 9, height: 9)
                    .overlay(
                        Circle().stroke(model.isLoaded ? Color.green.opacity(0.35) : .clear, lineWidth: 3)
                    )
                Text(model.displayName)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                roleBadge
            }

            // Meta row
            HStack(spacing: 6) {
                metaChip(model.quant)
                metaChip(model.contextLabel)
                metaChip(String(format: "%.0f GB", model.weightGB))
                if let sz = model.sizeFormatted, model.isLoaded {
                    metaChip("RAM \(sz)", tint: .green)
                }
            }

            // Benchmark row
            HStack(spacing: 14) {
                benchStat("Prefill", model.ppTPS, "t/s")
                benchStat("Decode", model.tgTPS, "t/s")
                if let t = model.lastTestTPS {
                    benchStat("Live", t, "t/s", tint: .blue)
                }
            }

            // Actions
            HStack(spacing: 8) {
                Button {
                    Task { await state.toggleLoad(model) }
                } label: {
                    HStack(spacing: 4) {
                        if model.isBusy {
                            ProgressView().scaleEffect(0.5).frame(width: 12, height: 12)
                        } else {
                            Image(systemName: model.isLoaded ? "eject.fill" : "play.fill")
                                .font(.system(size: 9))
                        }
                        Text(model.isLoaded ? "Unload" : "Load")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(model.isLoaded ? .orange : .accentColor)
                .controlSize(.small)
                .disabled(!state.serverRunning || model.isBusy)

                Button {
                    Task { await state.chatTest(model) }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill").font(.system(size: 9))
                        Text("Test").font(.system(size: 11, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!state.serverRunning || model.isBusy)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.quinary)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(model.isLoaded ? Color.green.opacity(0.4) : Color.clear, lineWidth: 1)
                )
        )
    }

    private var roleBadge: some View {
        Text(model.role.uppercased())
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(model.role == "Reasoning" ? Color.purple : Color.teal)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background((model.role == "Reasoning" ? Color.purple : Color.teal).opacity(0.15))
            .clipShape(Capsule())
    }

    private func metaChip(_ text: String, tint: Color = .secondary) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundStyle(tint)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(tint.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func benchStat(_ label: String, _ value: Double, _ unit: String, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.system(size: 8, weight: .semibold)).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "%.0f", value))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
                Text(unit).font(.system(size: 8)).foregroundStyle(.secondary)
            }
        }
    }
}
