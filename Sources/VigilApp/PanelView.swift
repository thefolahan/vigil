import SwiftUI
import VigilKit

struct PanelView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.openSettings) private var openSettings
    @State private var showHistory = false
    @State private var window: NSWindow?
    @State private var panelHeight: CGFloat = 0
    /// Height of the header, footer and padding around the scrolling middle.
    @State private var chrome: CGFloat = 150
    @State private var headerHeight: CGFloat = 0
    @State private var footerHeight: CGFloat = 0
    /// The tallest the window can be on its screen, below its top edge.
    @State private var room: CGFloat = NSScreen.main?.visibleFrame.height ?? 800

    var body: some View {
        GlassGroup(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                header
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0; updateChrome() }
                // The menu bar cannot scroll its window, so everything between
                // the header and the footer scrolls once it is taller than
                // the screen allows, such as with history open.
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            agentsSection
                            lidSection
                            holdSection
                            if showHistory {
                                HistoryList(sessions: model.sessions)
                                    .glassCard()
                                    .id("history")
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                        }
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .scrollIndicators(.automatic)
                    .modifier(CappedHeight(limit: maxScrollHeight))
                    .onChange(of: showHistory) { _, shown in
                        guard shown else { return }
                        DispatchQueue.main.async {
                            withAnimation(.smooth) { proxy.scrollTo("history", anchor: .bottom) }
                        }
                    }
                }
                footer
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { footerHeight = $0; updateChrome() }
            }
            .padding(12)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 360)
        .background(PanelBackdrop(lit: model.isAwake))
        .background(WindowReader { window = $0; fitWindow() })
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { panelHeight = $0; fitWindow() }
        .onAppear { model.tick() }
    }

    /// Room for the scrolling middle: what the screen allows below the
    /// window's top edge, less the header and footer.
    private var maxScrollHeight: CGFloat {
        max(200, room - chrome)
    }

    private func updateChrome() {
        chrome = headerHeight + footerHeight + 12 * 2 + 10 * 2
    }

    /// The menu bar sizes its window once, when it opens, and does not
    /// reliably follow the panel after that. Opening history then left the
    /// bottom cut off with nothing to scroll, and a shrinking panel left
    /// empty glass above and below it. So the panel sizes its own window,
    /// keeping the top edge under the menu bar where it is.
    private func fitWindow() {
        guard let window, panelHeight > 0 else { return }
        if let screen = window.screen {
            room = window.frame.maxY - screen.visibleFrame.minY - 12
        }
        var frame = window.frame
        let target = window.frameRect(forContentRect: NSRect(x: 0, y: 0, width: frame.width, height: panelHeight)).height
        guard abs(frame.height - target) > 0.5 else { return }
        frame.origin.y = frame.maxY - target
        frame.size.height = target
        window.setFrame(frame, display: true)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            CandleView(lit: model.isAwake)
                .frame(width: 52, height: 52)
                .glassDisc(tint: model.isAwake ? .flame : nil)
            VStack(alignment: .leading, spacing: 3) {
                Text(model.headline)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .contentTransition(.numericText())
                Text(model.detail)
                    .font(.system(size: 12))
                    .foregroundStyle(model.trip == nil ? .secondary : Color.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
            AmberToggle(isOn: $model.watchAgents, help: model.watchAgents ? "Stop watching agents" : "Watch agents")
        }
        .padding(.horizontal, 6)
        .padding(.top, 4)
        .padding(.bottom, 2)
        .animation(.smooth, value: model.headline)
    }

    // MARK: Agents

    private var agentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: "Agents", trailing: model.agents.isEmpty ? nil : "\(model.workingAgents.count) of \(model.agents.count) working")
                .padding(.horizontal, 6)
            if model.agents.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                    Text("No agents running. Start Claude Code, Codex, Gemini CLI or another agent and Vigil keeps the Mac awake while it works.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()
            } else {
                let held = model.agents.filter { model.heldBy.contains($0) }
                    .sorted { ($0.activity == .working ? 0 : 1, $0.started) < ($1.activity == .working ? 0 : 1, $1.started) }
                let idle = model.agents.filter { !held.contains($0) }
                let rows = VStack(spacing: 8) {
                    ForEach(held) { agent in
                        AgentRow(agent: agent, now: model.now, holding: true)
                    }
                    if !idle.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(idle) { agent in
                                IdleAgentRow(agent: agent, now: model.now)
                            }
                        }
                        .padding(.vertical, 4)
                        .glassCard(cornerRadius: 12)
                    }
                }
                rows
            }
        }
        .opacity(model.watchAgents ? 1 : 0.5)
        .animation(.smooth, value: model.agents.map(\.id))
    }

    // MARK: Lid mode

    private var lidSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: model.lidHeldOpen ? "laptopcomputer.and.arrow.down" : "laptopcomputer")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(model.lidHeldOpen ? Color.flame : .secondary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(model.lidHeldOpen ? Color.flame.opacity(0.18) : Color.primary.opacity(0.07)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Keep running with the lid closed")
                        .font(.system(size: 13, weight: .medium))
                    Text(lidStatus)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if model.lidModeInstalled {
                    AmberToggle(isOn: $model.lidMode, help: model.lidMode ? "Turn off lid mode" : "Turn on lid mode")
                } else {
                    Button(model.settingUp ? "Setting up" : "Set up") { model.setUpLidMode() }
                        .controlSize(.small)
                        .glassButton()
                        .disabled(model.settingUp)
                }
            }
            HStack(spacing: 6) {
                Gauge(symbol: "thermometer.medium", text: model.thermal.label, warning: model.thermal.rawValue >= ProcessInfo.ThermalState.serious.rawValue)
                if let battery = model.battery {
                    Gauge(symbol: battery.onBattery ? "battery.75percent" : "powerplug.fill",
                          text: battery.onBattery ? "\(battery.percent)%" : "\(battery.percent)%, charging",
                          warning: battery.onBattery && battery.percent < model.batteryFloor)
                }
                Gauge(symbol: model.lidClosed ? "laptopcomputer.slash" : "laptopcomputer",
                      text: model.lidClosed ? "Lid closed" : "Lid open", warning: false)
            }
            if let error = model.setupError {
                Text(error).font(.system(size: 11)).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .glassCard()
    }

    private var lidStatus: String {
        if !model.lidModeInstalled { return "Needs your password once" }
        if !model.lidMode { return "Off: closing the lid sleeps the Mac" }
        if model.trip != nil { return "Paused by a safety guard" }
        if model.lidHeldOpen { return model.lidClosed ? "Lid closed, still working" : "Safe to close the lid now" }
        return "Turns on while an agent works"
    }

    // MARK: Hold

    private var holdSection: some View {
        HStack(spacing: 10) {
            Image(systemName: model.holdActive ? "hourglass" : "hourglass.bottomhalf.filled")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(model.holdActive ? Color.flame : .secondary)
                .symbolEffect(.pulse, isActive: model.holdActive)
                .frame(width: 28, height: 28)
                .background(Circle().fill(model.holdActive ? Color.flame.opacity(0.18) : Color.primary.opacity(0.07)))
            VStack(alignment: .leading, spacing: 2) {
                Text("Hold awake").font(.system(size: 13, weight: .medium))
                Text(holdStatus).font(.system(size: 11)).foregroundStyle(.secondary).monospacedDigit()
            }
            Spacer(minLength: 0)
            if model.holdActive {
                Button("Stop") { model.stopHold() }
                    .controlSize(.small)
                    .glassButton()
            } else {
                Menu("Start") {
                    Button("30 minutes") { model.hold(for: 30) }
                    Button("1 hour") { model.hold(for: 60) }
                    Button("2 hours") { model.hold(for: 120) }
                    Button("4 hours") { model.hold(for: 240) }
                    Divider()
                    Button("Until I stop it") { model.hold(for: nil) }
                }
                .menuStyle(.button)
                .glassButton()
                .controlSize(.small)
                .fixedSize()
            }
        }
        .padding(12)
        .glassCard()
    }

    private var holdStatus: String {
        guard model.holdActive, let until = model.holdUntil else { return "For work Vigil cannot see, like a download" }
        if until == .distantFuture { return "On until you stop it" }
        return "\(Format.countdown(until.timeIntervalSince(model.now))) left"
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(.smooth(duration: 0.3)) { showHistory.toggle() }
            } label: {
                Label(showHistory ? "Hide history" : "History", systemImage: "clock.arrow.circlepath")
            }
            Spacer()
            Button {
                // A menu bar app is never frontmost on its own, so without
                // this the Settings window opens behind other apps.
                NSApp.activate()
                openSettings()
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .help("Quit Vigil")
        }
        .labelStyle(.titleAndIcon)
        .font(.system(size: 12))
        .controlSize(.regular)
        .glassButton()
        .padding(.top, 2)
    }
}

/// Hands back the window a view is in, once it is in one.
struct WindowReader: NSViewRepresentable {
    var found: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView { Probe(found: found) }
    func updateNSView(_ view: NSView, context: Context) {}

    private final class Probe: NSView {
        let found: (NSWindow) -> Void
        init(found: @escaping (NSWindow) -> Void) {
            self.found = found
            super.init(frame: .zero)
        }
        required init?(coder: NSCoder) { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            DispatchQueue.main.async { [found] in found(window) }
        }
    }
}

/// Sizes a scroll view to its content, up to a limit. The height is worked
/// out in one layout pass rather than measured and stored, so the menu bar
/// window never opens at a stale size with empty glass above and below.
struct CappedHeight: ViewModifier {
    var limit: CGFloat

    func body(content: Content) -> some View {
        CappedHeightLayout(limit: limit) { content }
    }
}

private struct CappedHeightLayout: Layout {
    var limit: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let view = subviews.first else { return .zero }
        let ideal = view.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil))
        return CGSize(width: proposal.width ?? ideal.width, height: min(ideal.height, limit))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
    }
}

struct SectionTitle: View {
    var title: String
    var trailing: String?

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            Spacer()
            if let trailing {
                Text(trailing).font(.system(size: 10)).foregroundStyle(.tertiary)
            }
        }
    }
}

struct Gauge: View {
    var symbol: String
    var text: String
    var warning: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 10))
            Text(text).font(.system(size: 11))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(warning ? Color.orange : Color.secondary)
        .glassCapsule(tint: warning ? .orange : nil)
    }
}

struct AgentRow: View {
    var agent: AgentSnapshot
    var now: Date
    var holding: Bool

    var body: some View {
        HStack(spacing: 10) {
            AgentBadge(kind: agent.kind)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(agent.kind.name).font(.system(size: 13, weight: .medium))
                    Text(agent.project).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                }
                HStack(spacing: 5) {
                    Circle()
                        .fill(agent.activity == .working ? Color.working : (holding ? Color.flame : Color.secondary.opacity(0.5)))
                        .frame(width: 6, height: 6)
                        .shadow(color: agent.activity == .working ? Color.working.opacity(0.8) : .clear, radius: 3)
                    Text(status).font(.system(size: 11)).foregroundStyle(.secondary).monospacedDigit()
                }
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 1) {
                Sparkline(values: agent.history, active: agent.activity == .working)
                    .frame(width: 64, height: 20)
                Text(Format.rate(agent.traffic)).font(.system(size: 9)).foregroundStyle(.tertiary).monospacedDigit()
            }
        }
        .padding(10)
        .glassCard(cornerRadius: 12, tint: agent.activity == .working ? .working : nil)
        .help("PID \(agent.pid), \(agent.directory ?? "unknown folder")")
    }

    private var status: String {
        if let since = agent.workingSince {
            return "Working for \(Format.duration(now.timeIntervalSince(since)))"
        }
        if let last = agent.lastActive {
            return "Quiet for \(Format.duration(now.timeIntervalSince(last))), still held"
        }
        return "Idle"
    }
}

/// An agent idle at its prompt, on one quiet line.
struct IdleAgentRow: View {
    var agent: AgentSnapshot
    var now: Date

    var body: some View {
        HStack(spacing: 8) {
            AgentBadge(kind: agent.kind, size: 18)
            Text(agent.kind.name).font(.system(size: 12))
            Text(agent.project).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 4)
            Text(idleText).font(.system(size: 11)).foregroundStyle(.tertiary).monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .help("PID \(agent.pid), \(agent.directory ?? "unknown folder")")
    }

    private var idleText: String {
        if let last = agent.lastActive { return "idle \(Format.duration(now.timeIntervalSince(last)))" }
        return "idle"
    }
}

struct AgentBadge: View {
    var kind: AgentKind
    var size: CGFloat = 28

    var body: some View {
        let tile = RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
        Group {
            if let logo = AgentLogo.shape(for: kind.id) {
                logo.fill(.white).frame(width: size * 0.6, height: size * 0.6)
            } else {
                Text(String(kind.name.prefix(1)))
                    .font(.system(size: size * 0.47, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .background(tile.fill(fill))
        .overlay(
            tile.strokeBorder(LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom), lineWidth: 0.75)
        )
        .shadow(color: shadow.opacity(0.35), radius: size * 0.15, y: size * 0.05)
        .accessibilityHidden(true)
    }

    private var fill: AnyShapeStyle {
        if kind.id == "gemini" {
            return AnyShapeStyle(LinearGradient(colors: [Color(red: 0.26, green: 0.52, blue: 0.96), Color(red: 0.61, green: 0.45, blue: 0.80)],
                                                startPoint: .bottomLeading, endPoint: .topTrailing))
        }
        return AnyShapeStyle(color.gradient)
    }

    private var shadow: Color { kind.id == "gemini" ? Color(red: 0.4, green: 0.5, blue: 0.9) : color }

    private var color: Color {
        switch kind.id {
        case "claude": return Color(red: 0.85, green: 0.47, blue: 0.34)
        case "codex": return Color(red: 0.13, green: 0.14, blue: 0.16)
        case "copilot": return Color(red: 0.14, green: 0.16, blue: 0.20)
        case "cursor": return Color(red: 0.10, green: 0.10, blue: 0.11)
        case "opencode": return Color(red: 0.20, green: 0.20, blue: 0.22)
        case "qwen": return Color(red: 0.41, green: 0.31, blue: 0.94)
        case "amp": return Color(red: 0.89, green: 0.27, blue: 0.27)
        case "aider": return Color(red: 0.16, green: 0.62, blue: 0.40)
        case "goose": return Color(red: 0.86, green: 0.62, blue: 0.10)
        case "droid": return Color(red: 0.95, green: 0.45, blue: 0.15)
        default: return Color(red: 0.40, green: 0.45, blue: 0.55)
        }
    }
}

struct Sparkline: View {
    var values: [Double]
    var active: Bool

    var body: some View {
        Canvas { context, size in
            let points = Array(values.suffix(24))
            guard points.count > 1 else { return }
            let top = max(points.max() ?? 0, 600)
            let step = size.width / CGFloat(23)
            let offset = size.width - step * CGFloat(points.count - 1)
            var line = Path()
            for (index, value) in points.enumerated() {
                let point = CGPoint(x: offset + CGFloat(index) * step, y: size.height - 1 - CGFloat(value / top) * (size.height - 3))
                index == 0 ? line.move(to: point) : line.addLine(to: point)
            }
            var fill = line
            fill.addLine(to: CGPoint(x: size.width, y: size.height))
            fill.addLine(to: CGPoint(x: offset, y: size.height))
            fill.closeSubpath()
            let color = active ? Color.working : Color.secondary
            context.fill(fill, with: .linearGradient(Gradient(colors: [color.opacity(0.28), color.opacity(0)]),
                                                     startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            context.stroke(line, with: .color(color.opacity(active ? 1 : 0.6)), style: StrokeStyle(lineWidth: 1.4, lineJoin: .round))
        }
    }
}

struct HistoryList: View {
    var sessions: [SessionRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: "Recent sessions", trailing: nil)
            if sessions.isEmpty {
                Text("Sessions longer than a minute appear here.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            } else {
                ForEach(sessions.prefix(5)) { session in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(session.started.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 12, weight: .medium))
                            Spacer()
                            Text(Format.duration(session.length)).font(.system(size: 12)).monospacedDigit()
                        }
                        Text(summary(session)).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func summary(_ session: SessionRecord) -> String {
        var parts: [String] = []
        parts.append(session.agents.isEmpty ? "Held awake" : session.agents.joined(separator: ", "))
        if session.lidClosed >= 60 { parts.append("lid closed \(Format.duration(session.lidClosed))") }
        parts.append(session.endReason)
        return parts.joined(separator: ". ")
    }
}
