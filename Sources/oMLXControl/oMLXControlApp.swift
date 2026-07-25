import SwiftUI

@main
struct oMLXControlApp: App {
    @StateObject var state = AppState()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(state)
                .frame(width: 380, height: 560)
        } label: {
            Image(systemName: menuIcon)
                .foregroundStyle(state.serverRunning ? Color.primary : Color.secondary)
        }
        .menuBarExtraStyle(.window)
    }

    private var menuIcon: String {
        if state.serverStarting { return "hourglass" }
        if !state.serverRunning { return "memorychip" }
        return state.loadedCount > 0 ? "memorychip.fill" : "memorychip"
    }
}

// MARK: - Root

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @State private var tab: Tab = .models

    enum Tab: String, CaseIterable {
        case models = "Models", stats = "Stats", settings = "Settings"
        var icon: String {
            switch self {
            case .models:   return "square.stack.3d.up"
            case .stats:    return "chart.line.uptrend.xyaxis"
            case .settings: return "slider.horizontal.3"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HeaderView()
            Divider()

            Picker("", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { t in
                    Label(t.rawValue, systemImage: t.icon).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            Group {
                switch tab {
                case .models:   ModelsView()
                case .stats:    StatsView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            FooterView()
        }
        .background(.windowBackground)
    }
}

// MARK: - Header

struct HeaderView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.18))
                    .frame(width: 30, height: 30)
                Image(systemName: state.serverStarting ? "hourglass" : "memorychip.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(statusColor)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("oMLX Control")
                    .font(.system(size: 13, weight: .bold))
                Text(statusText)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Quick server toggle
            Button {
                if state.serverRunning { state.stopServer() } else { state.startServer() }
            } label: {
                Text(state.serverRunning ? "Stop" : "Start")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 46)
            }
            .buttonStyle(.borderedProminent)
            .tint(state.serverRunning ? .red : .green)
            .controlSize(.small)
            .disabled(state.serverStarting)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var statusColor: Color {
        if state.serverStarting { return .yellow }
        return state.serverRunning ? .green : .secondary
    }
    private var statusText: String {
        if state.serverStarting { return "Starting…" }
        if !state.serverRunning { return "Server stopped" }
        let up = state.stats.map { Self.uptime($0.uptimeSeconds) } ?? ""
        return "Running · \(state.loadedCount)/\(state.models.count) loaded\(up.isEmpty ? "" : " · up \(up)")"
    }
    static func uptime(_ s: Double) -> String {
        let h = Int(s) / 3600, m = (Int(s) % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m" }
        return "\(Int(s))s"
    }
}

// MARK: - Footer (status line)

struct FooterView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack(spacing: 6) {
            if let err = state.lastError {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9)).foregroundStyle(.red)
                Text(err).font(.system(size: 10)).foregroundStyle(.red).lineLimit(1)
            } else {
                Text(state.statusMessage.isEmpty ? "Ready" : state.statusMessage)
                    .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Button { NSApp.terminate(nil) } label: {
                Image(systemName: "power").font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Quit oMLX Control")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }
}
