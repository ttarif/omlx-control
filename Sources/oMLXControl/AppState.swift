import Foundation
import SwiftUI

// MARK: - Data models

struct ModelInfo: Identifiable {
    let id: String
    let displayName: String
    let role: String          // "Reasoning" | "Coding"
    let quant: String
    let contextLabel: String
    let ppTPS: Double
    let tgTPS: Double
    let weightGB: Double
    var isLoaded: Bool = false
    var isBusy: Bool = false
    var sizeFormatted: String? = nil
    var lastTestTPS: Double? = nil
}

struct ModelSettings: Equatable {
    var modelTypeOverride: String = "llm"    // auto | llm | vlm
    var mtpEnabled: Bool = false
    var turboquantKV: Bool = false

    /// The benchmark-verified optimal config for every local model.
    static let optimal = ModelSettings(modelTypeOverride: "llm",
                                       mtpEnabled: false,
                                       turboquantKV: false)
}

enum PressureLevel: String {
    case ok, warn = "warning", high, critical, unknown
    var color: Color {
        switch self {
        case .ok:       return .green
        case .warn:     return .yellow
        case .high:     return .orange
        case .critical: return .red
        case .unknown:  return .secondary
        }
    }
}

// MARK: - AppState

@MainActor
final class AppState: ObservableObject {

    // Server
    @Published var serverRunning = false
    @Published var serverStarting = false
    @Published var statusMessage = ""
    @Published var lastError: String? = nil

    // Models
    @Published var models: [ModelInfo] = AppState.knownModels
    @Published var modelSettings: [String: ModelSettings] = {
        Dictionary(uniqueKeysWithValues: AppState.knownModels.map { ($0.id, ModelSettings.optimal) })
    }()

    // Stats
    @Published var stats: AdminStats? = nil
    @Published var genTPSHistory: [Double] = []

    // Server config — host defaults to loopback; set to your Tailscale IP for tailnet access
    @Published var host = "127.0.0.1"
    @Published var port = "9900"
    @Published var modelDir = ""
    @Published var memoryGuard = "balanced"

    var baseURL: String { "http://\(host):\(port)" }

    private var serverProcess: Process? = nil
    private var pollTask: Task<Void, Never>? = nil

    // Two production models — benchmark-verified numbers
    static let knownModels: [ModelInfo] = [
        ModelInfo(id: "qwen36-35b-mtplx", displayName: "Qwen36 35B-A3B",
                  role: "Reasoning", quant: "FP16", contextLabel: "256K",
                  ppTPS: 1037, tgTPS: 63.1, weightGB: 20.5),
        ModelInfo(id: "laguna-oq2e", displayName: "Laguna S-2.1 oQ2e",
                  role: "Coding", quant: "2-bit", contextLabel: "1M",
                  ppTPS: 289, tgTPS: 29.2, weightGB: 35.4),
    ]

    init() {
        modelDir = "\(FileManager.default.homeDirectoryForCurrentUser.path)/.local/share/omlx-models"
        startPolling()
    }

    // MARK: - Polling (single unified loop, 2s)

    private func startPolling() {
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    func refresh() async {
        do {
            let list = try await APIClient.fetchModels(baseURL: baseURL)
            let byID = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
            serverRunning = true
            serverStarting = false
            for i in models.indices {
                if let a = byID[models[i].id] {
                    models[i].isLoaded = a.loaded
                    models[i].isBusy = a.isLoading
                    models[i].sizeFormatted = a.actualSizeFormatted ?? a.estimatedSizeFormatted
                }
            }
            // Stats
            if let s = try? await APIClient.fetchStats(baseURL: baseURL) {
                stats = s
                genTPSHistory.append(s.avgGenerationTPS)
                if genTPSHistory.count > 60 { genTPSHistory.removeFirst() }
            }
            lastError = nil
        } catch {
            serverRunning = false
            stats = nil
            for i in models.indices { models[i].isLoaded = false; models[i].isBusy = false }
        }
    }

    // MARK: - Model actions

    func toggleLoad(_ model: ModelInfo) async {
        guard let idx = models.firstIndex(where: { $0.id == model.id }) else { return }
        models[idx].isBusy = true
        defer { Task { @MainActor in if let i = self.models.firstIndex(where: {$0.id == model.id}) { self.models[i].isBusy = false } } }
        do {
            if model.isLoaded {
                try await APIClient.unloadModel(id: model.id, baseURL: baseURL)
                statusMessage = "\(model.displayName) unloaded"
            } else {
                statusMessage = "Loading \(model.displayName)…"
                try await APIClient.loadModel(id: model.id, baseURL: baseURL)
                statusMessage = "\(model.displayName) loaded"
            }
            await refresh()
        } catch {
            lastError = "\(model.displayName): \(describe(error))"
            statusMessage = ""
        }
    }

    func chatTest(_ model: ModelInfo) async {
        guard let idx = models.firstIndex(where: { $0.id == model.id }) else { return }
        models[idx].isBusy = true
        statusMessage = "Testing \(model.displayName)…"
        defer { Task { @MainActor in if let i = self.models.firstIndex(where: {$0.id == model.id}) { self.models[i].isBusy = false } } }
        do {
            let r = try await APIClient.chatTest(id: model.id, baseURL: baseURL)
            models[idx].lastTestTPS = r.tgTPS
            statusMessage = String(format: "%@: %.0f t/s · \"%@\"", model.displayName, r.tgTPS,
                                   r.content.trimmingCharacters(in: .whitespacesAndNewlines).prefix(20).description)
            await refresh()
        } catch {
            lastError = "Test failed: \(describe(error))"
            statusMessage = ""
        }
    }

    // MARK: - Settings

    func applySettings(for id: String) async {
        guard let s = modelSettings[id] else { return }
        do {
            let r = try await APIClient.applyModelSettings(
                id: id, baseURL: baseURL,
                modelTypeOverride: s.modelTypeOverride,
                mtpEnabled: s.mtpEnabled,
                turboquantKVEnabled: s.turboquantKV)
            statusMessage = r.success ? "Settings applied for \(id)" : "Settings rejected for \(id)"
            if r.requiresReload == true { statusMessage += " (reload pending)" }
        } catch {
            lastError = "Settings: \(describe(error))"
        }
    }

    func applyOptimalToAll() async {
        for id in models.map(\.id) {
            modelSettings[id] = .optimal
            await applySettings(for: id)
        }
        statusMessage = "Optimal settings applied to all models"
    }

    var allSettingsOptimal: Bool {
        models.allSatisfy { modelSettings[$0.id] == .optimal }
    }

    // MARK: - Server control

    func startServer() {
        guard !(serverProcess?.isRunning ?? false) else { return }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let binary = "\(home)/.local/share/omlx-0.5.3/bin/omlx"
        guard FileManager.default.fileExists(atPath: binary) else {
            lastError = "omlx binary not found"; return
        }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: binary)
        p.arguments = ["serve", "--model-dir", modelDir,
                       "--host", host.isEmpty ? "127.0.0.1" : host,
                       "--port", port.isEmpty ? "9900" : port,
                       "--max-concurrent-requests", "1",
                       "--memory-guard", memoryGuard,
                       "--no-cache", "--log-level", "warning"]
        p.standardOutput = FileHandle.nullDevice
        p.standardError  = FileHandle.nullDevice
        p.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                self?.serverProcess = nil
                self?.serverRunning = false
                self?.serverStarting = false
            }
        }
        do {
            try p.run()
            serverProcess = p
            serverStarting = true
            statusMessage = "Server starting on :\(port)…"
        } catch {
            lastError = "Start failed: \(error.localizedDescription)"
        }
    }

    func stopServer() {
        if let p = serverProcess, p.isRunning { p.terminate(); serverProcess = nil }
        else {
            let k = Process()
            k.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
            k.arguments = ["-f", "omlx-server"]
            try? k.run()
        }
        serverRunning = false
        serverStarting = false
        statusMessage = "Server stopped"
    }

    /// Query the Tailscale CLI for this machine's tailnet IP and set it as the host.
    func detectTailscaleIP() {
        let candidates = ["/usr/local/bin/tailscale",
                          "/opt/homebrew/bin/tailscale",
                          "/Applications/Tailscale.app/Contents/MacOS/Tailscale"]
        guard let bin = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            lastError = "Tailscale CLI not found"; return
        }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: bin)
        p.arguments = ["ip", "-4"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        do {
            try p.run()
            p.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let ip = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: "\n").first.map(String.init) ?? ""
            if ip.isEmpty { lastError = "No Tailscale IP returned" }
            else { host = ip; statusMessage = "Host set to Tailscale IP \(ip)" }
        } catch {
            lastError = "Tailscale query failed"
        }
    }

    // MARK: - Derived

    var pressure: PressureLevel {
        PressureLevel(rawValue: stats?.pressureLevel ?? "unknown") ?? .unknown
    }
    var memoryFraction: Double {
        guard let s = stats, s.memoryMaxBytes > 0 else { return 0 }
        return Double(s.memoryUsedBytes) / Double(s.memoryMaxBytes)
    }
    var loadedCount: Int { models.filter { $0.isLoaded }.count }

    private func describe(_ e: Error) -> String {
        (e as? APIError).map(String.init(describing:)) ?? e.localizedDescription
    }
}
