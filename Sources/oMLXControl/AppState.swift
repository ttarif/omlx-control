import Foundation
import SwiftUI

// MARK: - Data models

struct ModelInfo: Identifiable {
    let id: String                // tess alias e.g. "tess-qwen36-35b-a3b"
    let profileID: String         // tess-server profile id e.g. "qwen36-a3b-q8-q4mtp"
    let displayName: String
    let role: String              // "Reasoning" | "Coding"
    let quant: String
    let contextLabel: String      // Human label for optimal context
    let contextTokens: Int        // Optimal context token count
    let ppTPS: Double             // Benchmark prefill t/s
    let tgTPS: Double             // Benchmark decode t/s
    let weightGB: Double
    var isActive: Bool = false    // true when this profile is currently loaded
    var isBusy: Bool = false
    var lastTestTPS: Double? = nil
}

struct ProfileSettings: Equatable {
    var contextPreset: Int
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
    @Published var serverRunning  = false
    @Published var serverStarting = false
    @Published var statusMessage  = ""
    @Published var lastError: String? = nil

    // Models
    @Published var models: [ModelInfo] = AppState.knownModels
    @Published var activeProfileID: String = ""

    // Per-profile context preset
    @Published var profileSettings: [String: ProfileSettings] = {
        Dictionary(uniqueKeysWithValues: AppState.knownModels.map {
            ($0.profileID, ProfileSettings(contextPreset: $0.contextTokens))
        })
    }()

    // Stats
    @Published var stats: TessStats? = nil
    @Published var genTPSHistory: [Double] = []

    // Connection
    @Published var host = "127.0.0.1"
    @Published var port = "8020"

    var baseURL: String { "http://\(host):\(port)" }

    private var pollTask: Task<Void, Never>? = nil

    // ── Two Tess profiles — benchmark numbers from /metrics on this machine ──
    static let knownModels: [ModelInfo] = [
        ModelInfo(
            id:            "tess-qwen36-35b-a3b",
            profileID:     "qwen36-a3b-q8-q4mtp",
            displayName:   "Tess-4-35B-A3B",
            role:          "Reasoning",
            quant:         "Q8 + MTP n=5",
            contextLabel:  "128K",
            contextTokens: 131_072,
            ppTPS:         1052,
            tgTPS:         103,
            weightGB:      37.7
        ),
        ModelInfo(
            id:            "laguna-s21",
            profileID:     "laguna-s21-q4km-dflash",
            displayName:   "Laguna S.2",
            role:          "Coding",
            quant:         "Q4_K_M + DFlash n=15",
            contextLabel:  "256K",
            contextTokens: 262_144,
            ppTPS:         840,
            tgTPS:         85,
            weightGB:      70.5
        ),
    ]

    // ── Context presets per profile (from tess-server profiles --json) ──
    static let contextPresets: [String: [(label: String, tokens: Int)]] = [
        "qwen36-a3b-q8-q4mtp": [
            ("32K",        32_768),
            ("64K",        65_536),
            ("128K ★",    131_072),   // recommended
            ("256K",      262_144),
            ("512K YaRN", 524_288),
        ],
        "laguna-s21-q4km-dflash": [
            ("8K",   8_192),
            ("16K",  16_384),
            ("32K",  32_768),
            ("64K",  65_536),
            ("128K", 131_072),
            ("256K ★", 262_144),     // full native qualification
        ],
    ]

    init() { startPolling() }

    // MARK: - Polling

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
            let liveIDs = Set(list.map { $0.id })
            serverRunning  = true
            serverStarting = false
            for i in models.indices { models[i].isActive = liveIDs.contains(models[i].id) }
            if let active = models.first(where: { $0.isActive }) { activeProfileID = active.profileID }
            if let s = try? await APIClient.fetchStats(baseURL: baseURL) {
                stats = s
                genTPSHistory.append(s.decodeTPS)
                if genTPSHistory.count > 60 { genTPSHistory.removeFirst() }
            }
            lastError = nil
        } catch {
            serverRunning = false
            stats = nil
            for i in models.indices { models[i].isActive = false }
        }
    }

    // MARK: - Profile switch

    func switchProfile(_ model: ModelInfo) async {
        guard let idx = models.firstIndex(where: { $0.id == model.id }) else { return }
        guard !models[idx].isActive else { statusMessage = "\(model.displayName) already active"; return }
        for i in models.indices { models[i].isBusy = models[i].id == model.id }
        statusMessage = "Switching to \(model.displayName)…"
        do {
            try await APIClient.switchProfile(model.profileID)
            statusMessage = "\(model.displayName) loading…"
            serverStarting = true
            try? await Task.sleep(nanoseconds: 3_000_000_000)
        } catch {
            lastError = "Switch failed: \(describe(error))"
            statusMessage = ""
        }
        for i in models.indices { models[i].isBusy = false }
    }

    // MARK: - Chat test

    func chatTest(_ model: ModelInfo) async {
        guard let idx = models.firstIndex(where: { $0.id == model.id }) else { return }
        models[idx].isBusy = true
        statusMessage = "Testing \(model.displayName)…"
        defer { Task { @MainActor in
            if let i = self.models.firstIndex(where: { $0.id == model.id }) { self.models[i].isBusy = false }
        }}
        do {
            let r = try await APIClient.chatTest(id: model.id, baseURL: baseURL)
            models[idx].lastTestTPS = r.tgTPS
            statusMessage = String(format: "%@: %.0f t/s · \"%@\"",
                                   model.displayName, r.tgTPS,
                                   String(r.content.prefix(24)).trimmingCharacters(in: .whitespacesAndNewlines))
        } catch {
            lastError = "Test failed: \(describe(error))"
            statusMessage = ""
        }
        await refresh()
    }

    // MARK: - Server control

    func startServer() {
        serverStarting = true
        statusMessage = "Starting Tess server…"
        APIClient.startServer()
    }

    func stopServer() {
        APIClient.stopServer()
        serverRunning = false; serverStarting = false
        for i in models.indices { models[i].isActive = false }
        statusMessage = "Server stopped"
    }

    func detectTailscaleIP() {
        let candidates = ["/usr/local/bin/tailscale",
                          "/opt/homebrew/bin/tailscale",
                          "/Applications/Tailscale.app/Contents/MacOS/Tailscale"]
        guard let bin = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            lastError = "Tailscale CLI not found"; return
        }
        let p = Process(); p.executableURL = URL(fileURLWithPath: bin); p.arguments = ["ip", "-4"]
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = FileHandle.nullDevice
        do {
            try p.run(); p.waitUntilExit()
            let ip = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: "\n").first.map(String.init) ?? ""
            if ip.isEmpty { lastError = "No Tailscale IP" } else { host = ip; statusMessage = "Host → \(ip)" }
        } catch { lastError = "Tailscale query failed" }
    }

    // MARK: - Derived

    var pressure: PressureLevel { PressureLevel(rawValue: stats?.pressureLevel ?? "ok") ?? .ok }
    var memoryFraction: Double {
        guard let s = stats, s.memoryMaxBytes > 0 else { return 0 }
        return Double(s.memoryUsedBytes) / Double(s.memoryMaxBytes)
    }
    private func describe(_ e: Error) -> String {
        (e as? APIError).map(String.init(describing:)) ?? e.localizedDescription
    }
}
