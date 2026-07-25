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

// MARK: - /admin/api/models

struct AdminModelsResponse: Decodable {
    let models: [AdminModel]
}

struct AdminModel: Decodable {
    let id: String
    let loaded: Bool
    let isLoading: Bool
    let estimatedSizeFormatted: String?
    let actualSizeFormatted: String?
    let modelType: String?
    let engineType: String?

    enum CodingKeys: String, CodingKey {
        case id, loaded
        case isLoading              = "is_loading"
        case estimatedSizeFormatted = "estimated_size_formatted"
        case actualSizeFormatted    = "actual_size_formatted"
        case modelType              = "model_type"
        case engineType             = "engine_type"
    }
}

// MARK: - /admin/api/stats

struct AdminStats: Decodable {
    var totalTokensServed: Int
    var totalRequests: Int
    var avgPrefillTPS: Double
    var avgGenerationTPS: Double
    var cacheEfficiency: Double
    var uptimeSeconds: Double
    var memoryUsedBytes: Int
    var memoryMaxBytes: Int
    var memoryCurrentFormatted: String
    var memorySoftFormatted: String
    var memoryHardFormatted: String
    var pressureLevel: String
    var activeRequests: Int
    var waitingRequests: Int
    var loadedModelIDs: [String]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        totalTokensServed = (try? c.decode(Int.self,    forKey: .totalTokensServed)) ?? 0
        totalRequests     = (try? c.decode(Int.self,    forKey: .totalRequests))     ?? 0
        avgPrefillTPS     = (try? c.decode(Double.self, forKey: .avgPrefillTPS))     ?? 0
        avgGenerationTPS  = (try? c.decode(Double.self, forKey: .avgGenerationTPS))  ?? 0
        cacheEfficiency   = (try? c.decode(Double.self, forKey: .cacheEfficiency))   ?? 0
        uptimeSeconds     = (try? c.decode(Double.self, forKey: .uptimeSeconds))     ?? 0

        // active_models nesting
        var used = 0, maxB = 0, active = 0, waiting = 0
        var curFmt = "0 GB", softFmt = "—", hardFmt = "—", level = "unknown"
        var ids: [String] = []
        if let am = try? c.nestedContainer(keyedBy: ActiveModelsKeys.self, forKey: .activeModels) {
            used    = (try? am.decode(Int.self, forKey: .modelMemoryUsed)) ?? 0
            maxB    = (try? am.decode(Int.self, forKey: .modelMemoryMax)) ?? 0
            active  = (try? am.decode(Int.self, forKey: .totalActiveRequests)) ?? 0
            waiting = (try? am.decode(Int.self, forKey: .totalWaitingRequests)) ?? 0
            if let list = try? am.decode([ActiveModelEntry].self, forKey: .models) {
                ids = list.map { $0.id }
            }
            if let mp = try? am.nestedContainer(keyedBy: PressureKeys.self, forKey: .memoryPressure) {
                curFmt  = (try? mp.decode(String.self, forKey: .currentFormatted)) ?? curFmt
                softFmt = (try? mp.decode(String.self, forKey: .softFormatted)) ?? softFmt
                hardFmt = (try? mp.decode(String.self, forKey: .hardFormatted)) ?? hardFmt
                level   = (try? mp.decode(String.self, forKey: .pressureLevel)) ?? level
            }
        }
        memoryUsedBytes = used
        memoryMaxBytes  = maxB
        activeRequests  = active
        waitingRequests = waiting
        memoryCurrentFormatted = curFmt
        memorySoftFormatted    = softFmt
        memoryHardFormatted    = hardFmt
        pressureLevel          = level
        loadedModelIDs         = ids
    }

    enum CodingKeys: String, CodingKey {
        case totalTokensServed = "total_tokens_served"
        case totalRequests     = "total_requests"
        case avgPrefillTPS     = "avg_prefill_tps"
        case avgGenerationTPS  = "avg_generation_tps"
        case cacheEfficiency   = "cache_efficiency"
        case uptimeSeconds     = "uptime_seconds"
        case activeModels      = "active_models"
    }
    enum ActiveModelsKeys: String, CodingKey {
        case models
        case modelMemoryUsed      = "model_memory_used"
        case modelMemoryMax       = "model_memory_max"
        case memoryPressure       = "memory_pressure"
        case totalActiveRequests  = "total_active_requests"
        case totalWaitingRequests = "total_waiting_requests"
    }
    enum PressureKeys: String, CodingKey {
        case currentFormatted = "current_formatted"
        case softFormatted    = "soft_formatted"
        case hardFormatted    = "hard_formatted"
        case pressureLevel    = "pressure_level"
    }
    struct ActiveModelEntry: Decodable { let id: String }
}

// MARK: - Settings apply response

struct SettingsApplyResponse: Decodable {
    let success: Bool
    let modelType: String?
    let requiresReload: Bool?
    enum CodingKeys: String, CodingKey {
        case success
        case modelType      = "model_type"
        case requiresReload = "requires_reload"
    }
}

// MARK: - Chat test result

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

    // ── Detailed model list ────────────────────────────────────────────
    static func fetchModels(baseURL: String) async throws -> [AdminModel] {
        let data = try await get("\(baseURL)/admin/api/models")
        return try decode(AdminModelsResponse.self, data).models
    }

    // ── Server stats ───────────────────────────────────────────────────
    static func fetchStats(baseURL: String) async throws -> AdminStats {
        let data = try await get("\(baseURL)/admin/api/stats")
        return try decode(AdminStats.self, data)
    }

    // ── Load / unload (POST, verified) ─────────────────────────────────
    static func loadModel(id: String, baseURL: String) async throws {
        _ = try await post("\(baseURL)/admin/api/models/\(id)/load", body: [:])
    }
    static func unloadModel(id: String, baseURL: String) async throws {
        _ = try await post("\(baseURL)/admin/api/models/\(id)/unload", body: [:])
    }

    // ── Apply per-model settings (PUT, verified fields) ────────────────
    @discardableResult
    static func applyModelSettings(
        id: String, baseURL: String,
        modelTypeOverride: String, mtpEnabled: Bool, turboquantKVEnabled: Bool
    ) async throws -> SettingsApplyResponse {
        let payload: [String: Any] = [
            "model_type_override": modelTypeOverride,
            "mtp_enabled": mtpEnabled,
            "turboquant_kv_enabled": turboquantKVEnabled
        ]
        let data = try await put("\(baseURL)/admin/api/models/\(id)/settings", body: payload)
        return try decode(SettingsApplyResponse.self, data)
    }

    // ── Chat test — measures real tok/s ────────────────────────────────
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
    private static func post(_ s: String, body: [String: Any]) async throws -> Data {
        try await send(s, method: "POST", body: body, timeout: 120)
    }
    private static func put(_ s: String, body: [String: Any]) async throws -> Data {
        try await send(s, method: "PUT", body: body, timeout: 15)
    }
    private static func send(_ s: String, method: String, body: [String: Any], timeout: TimeInterval) async throws -> Data {
        guard let url = URL(string: s) else { throw APIError.connectionRefused }
        var r = URLRequest(url: url)
        r.httpMethod = method
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try? JSONSerialization.data(withJSONObject: body)
        r.timeoutInterval = timeout
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
