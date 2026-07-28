import Foundation

// MARK: - Errors

enum APIError: Error, CustomStringConvertible {
    case connectionRefused
    case httpError(Int)
    case decodingError(Error)
    case notFound

    var description: String {
        switch self {
        case .connectionRefused: return "connection refused"
        case .httpError(let c):  return "HTTP \(c)"
        case .decodingError:     return "decode error"
        case .notFound:          return "not found"
        }
    }
}

// MARK: - /v1/models (tess-server OpenAI-compat)

struct TessModelMeta: Decodable {
    let n_ctx: Int?
    let n_params: Int?
    let size: Int?
    let ftype: String?
}

struct TessModel: Decodable {
    let id: String
    let meta: TessModelMeta?
}

struct TessModelsResponse: Decodable {
    let data: [TessModel]
}

// MARK: - Stats (parsed from /metrics Prometheus text)

struct TessStats {
    var prefillTPS: Double = 0
    var decodeTPS: Double = 0
    var tokensPrompt: Int = 0
    var tokensPredicted: Int = 0
    var requestsProcessing: Int = 0
    var requestsDeferred: Int = 0
    var loadedModelIDs: [String] = []

    // Derived for UI compatibility
    var totalTokensServed: Int { tokensPrompt + tokensPredicted }
    var totalRequests: Int { tokensPrompt > 0 ? 1 : 0 }   // tess doesn't report req count directly
    var avgPrefillTPS: Double { prefillTPS }
    var avgGenerationTPS: Double { decodeTPS }
    var cacheEfficiency: Double { 0 }
    var activeRequests: Int { requestsProcessing }
    var waitingRequests: Int { requestsDeferred }

    // Memory — tess exposes no memory stats in /metrics; derive from model size
    var memoryUsedBytes: Int = 0
    var memoryMaxBytes: Int = 0
    var pressureLevel: String = "ok"
    var memoryCurrentFormatted: String = "—"
    var memorySoftFormatted: String = "—"
    var memoryHardFormatted: String = "—"
}

// MARK: - ChatTestResult

struct ChatTestResult {
    let ok: Bool
    let content: String
    let tgTPS: Double
    let latencySeconds: Double
}

// MARK: - Client

enum APIClient {
    private static let session: URLSession = {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest  = 5
        cfg.timeoutIntervalForResource = 15
        cfg.waitsForConnectivity = false
        return URLSession(configuration: cfg)
    }()

    // ── Model list ────────────────────────────────────────────────────
    static func fetchModels(baseURL: String) async throws -> [TessModel] {
        let data = try await get("\(baseURL)/v1/models")
        return try decode(TessModelsResponse.self, data).data
    }

    // ── Stats from Prometheus /metrics ────────────────────────────────
    static func fetchStats(baseURL: String) async throws -> TessStats {
        let data = try await get("\(baseURL)/metrics")
        guard let text = String(data: data, encoding: .utf8) else {
            throw APIError.decodingError(NSError(domain: "utf8", code: 0))
        }
        return parseMetrics(text)
    }

    private static func parseMetrics(_ text: String) -> TessStats {
        var s = TessStats()
        for line in text.split(separator: "\n") {
            let l = String(line)
            guard !l.hasPrefix("#") else { continue }
            let parts = l.split(separator: " ", maxSplits: 1)
            guard parts.count == 2, let val = Double(parts[1].trimmingCharacters(in: .whitespaces)) else { continue }
            let key = String(parts[0])
            switch key {
            case "llamacpp:prompt_tokens_seconds":       s.prefillTPS = val
            case "llamacpp:predicted_tokens_seconds":    s.decodeTPS = val
            case "llamacpp:prompt_tokens_total":         s.tokensPrompt = Int(val)
            case "llamacpp:tokens_predicted_total":      s.tokensPredicted = Int(val)
            case "llamacpp:requests_processing":         s.requestsProcessing = Int(val)
            case "llamacpp:requests_deferred":           s.requestsDeferred = Int(val)
            default: break
            }
        }
        return s
    }

    // ── Profile switch (via tess-switch.sh shell script) ──────────────
    /// Switches the running Tess profile by executing tess-switch.sh and
    /// restarting com.omp.tess via launchctl. Non-blocking; completion is
    /// polled via the existing refresh loop.
    static func switchProfile(_ profileID: String) async throws {
        let script = "\(FileManager.default.homeDirectoryForCurrentUser.path)/projects/omp-stack/gateway/scripts/tess-switch.sh"
        guard FileManager.default.fileExists(atPath: script) else {
            throw APIError.notFound
        }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = [script, profileID]
        p.standardOutput = FileHandle.nullDevice
        p.standardError  = FileHandle.nullDevice
        try p.run()
        // Don't wait — the script restarts the server; polling will detect the new model
    }

    /// Switch profile AND override the context window. Updates the launchd plist
    /// directly then calls tess-switch so the new context takes effect on restart.
    static func switchProfileWithContext(_ profileID: String, context: Int) async throws {
        let script = "\(FileManager.default.homeDirectoryForCurrentUser.path)/projects/omp-stack/gateway/scripts/tess-switch.sh"
        guard FileManager.default.fileExists(atPath: script) else { throw APIError.notFound }
        // Patch the context arg in the plist via PlistBuddy before calling the switch
        let plist = "\(FileManager.default.homeDirectoryForCurrentUser.path)/Library/LaunchAgents/com.omp.tess.plist"
        let pb = Process()
        pb.executableURL = URL(fileURLWithPath: "/usr/libexec/PlistBuddy")
        pb.arguments = ["-c", "Set :ProgramArguments:7 \(context)", plist]
        pb.standardOutput = FileHandle.nullDevice
        pb.standardError  = FileHandle.nullDevice
        try? pb.run(); pb.waitUntilExit()
        try await switchProfile(profileID)
    }

    // ── Server control via launchctl ──────────────────────────────────
    static func startServer() {
        launchctl("kickstart", "-k", "gui/\(getuid())/com.omp.tess")
    }

    static func stopServer() {
        launchctl("kill", "SIGTERM", "gui/\(getuid())/com.omp.tess")
    }

    private static func launchctl(_ args: String...) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError  = FileHandle.nullDevice
        try? p.run()
    }

    // ── Chat test ─────────────────────────────────────────────────────
    static func chatTest(id: String, baseURL: String) async throws -> ChatTestResult {
        guard let url = URL(string: "\(baseURL)/v1/chat/completions") else {
            throw APIError.connectionRefused
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 60
        let body: [String: Any] = [
            "model": id,
            "messages": [["role": "user",
                          "content": "Count from 1 to 40 separated by spaces. Output only the numbers."]],
            "max_tokens": 80,
            "temperature": 0
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let start = Date()
        let data = try await perform(req)
        let latency = Date().timeIntervalSince(start)
        struct ChatResp: Decodable {
            struct Choice: Decodable { struct Msg: Decodable { let content: String? }; let message: Msg }
            struct Usage: Decodable { let completion_tokens: Int? }
            let choices: [Choice]
            let usage: Usage?
        }
        let resp = try decode(ChatResp.self, data)
        let content = resp.choices.first?.message.content ?? ""
        let ct = Double(resp.usage?.completion_tokens ?? 0)
        let tps = latency > 0 ? ct / latency : 0
        return ChatTestResult(ok: !content.isEmpty, content: content, tgTPS: tps, latencySeconds: latency)
    }

    // MARK: - HTTP primitives

    private static func get(_ s: String) async throws -> Data {
        guard let url = URL(string: s) else { throw APIError.connectionRefused }
        var r = URLRequest(url: url); r.timeoutInterval = 5
        return try await perform(r)
    }
    private static func perform(_ req: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse else { return data }
            switch http.statusCode {
            case 200...299: return data
            case 404:       throw APIError.notFound
            default:        throw APIError.httpError(http.statusCode)
            }
        } catch let e as APIError { throw e }
        catch { throw APIError.connectionRefused }
    }
    private static func decode<T: Decodable>(_ t: T.Type, _ data: Data) throws -> T {
        do { return try JSONDecoder().decode(t, from: data) }
        catch { throw APIError.decodingError(error) }
    }
}
