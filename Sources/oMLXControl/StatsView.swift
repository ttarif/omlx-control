import SwiftUI
import Charts

struct StatsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let s = state.stats {
                    memorySection(s)
                    metricsGrid(s)
                    throughputChart
                } else {
                    unavailable
                }
            }
            .padding(12)
        }
    }

    // ── Memory pressure ──────────────────────────────────────────────
    private func memorySection(_ s: AdminStats) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("GPU MEMORY").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
                Spacer()
                Text(state.pressure.rawValue.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(state.pressure.color)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(state.pressure.color.opacity(0.15))
                    .clipShape(Capsule())
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(.quaternary).frame(height: 10)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(state.pressure.color.gradient)
                        .frame(width: max(4, geo.size.width * state.memoryFraction), height: 10)
                }
            }
            .frame(height: 10)
            HStack {
                Text(s.memoryCurrentFormatted).font(.system(size: 10, weight: .semibold, design: .monospaced))
                Spacer()
                Text("soft \(s.memorySoftFormatted) · hard \(s.memoryHardFormatted)")
                    .font(.system(size: 9)).foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quinary))
    }

    // ── Metrics grid ─────────────────────────────────────────────────
    private func metricsGrid(_ s: AdminStats) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            card("Prefill", String(format: "%.0f", s.avgPrefillTPS), "t/s avg", "arrow.down.forward")
            card("Decode", String(format: "%.0f", s.avgGenerationTPS), "t/s avg", "arrow.up.forward")
            card("Requests", "\(s.totalRequests)", "total", "tray.full")
            card("Active", "\(s.activeRequests)", "\(s.waitingRequests) waiting", "bolt.horizontal")
            card("Tokens", fmt(s.totalTokensServed), "served", "number")
            card("Cache", String(format: "%.0f%%", s.cacheEfficiency * 100), "hit rate", "externaldrive")
        }
    }

    private func card(_ title: String, _ value: String, _ sub: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 9)).foregroundStyle(.secondary)
                Text(title).font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
            }
            Text(value).font(.system(size: 18, weight: .bold, design: .rounded))
            Text(sub).font(.system(size: 8)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quinary))
    }

    // ── Throughput chart ─────────────────────────────────────────────
    private var throughputChart: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DECODE THROUGHPUT").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
            if state.genTPSHistory.count < 2 {
                Text("Collecting samples…")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                Chart(Array(state.genTPSHistory.enumerated()), id: \.offset) { i, v in
                    AreaMark(x: .value("t", i), y: .value("t/s", v))
                        .foregroundStyle(.linearGradient(colors: [.accentColor.opacity(0.4), .accentColor.opacity(0.02)],
                                                         startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("t", i), y: .value("t/s", v))
                        .foregroundStyle(Color.accentColor)
                        .interpolationMethod(.catmullRom)
                }
                .chartYAxis { AxisMarks(position: .leading) }
                .chartXAxis(.hidden)
                .frame(height: 90)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quinary))
    }

    private var unavailable: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.downtrend.xyaxis")
                .font(.system(size: 26)).foregroundStyle(.secondary)
            Text(state.serverRunning ? "Stats loading…" : "Server offline")
                .font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private func fmt(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n)/1e6) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n)/1e3) }
        return "\(n)"
    }
}
