import SwiftUI
import os

// MARK: - Home

/// Desktop state pill for the Home header. "Ready" is reported only when the
/// session says the desktop passed its readiness checks and painted a frame; a
/// running X server alone is "Starting".
struct HomeStatus: View {
    enum Phase: Equatable { case off, stopped, starting, ready, degraded }
    let phase: Phase
    var open: (() -> Void)?
    var stop: (() -> Void)?
    private var tone: DS.Tone {
        switch phase { case .ready: return .success; case .degraded: return .warning; case .starting: return .accent; case .stopped: return .neutral; case .off: return .danger }
    }
    private var title: String {
        switch phase { case .ready: return "Ready"; case .degraded: return "Limited"; case .starting: return "Starting"; case .stopped: return "Stopped"; case .off: return "Linux off" }
    }
    var body: some View {
        Menu {
            if let open { Button { open() } label: { Label(phase == .stopped ? "Open Desktop" : "Show Desktop", systemImage: "desktopcomputer") } }
            if let stop { Button(role: .destructive) { stop() } label: { Label("Stop Desktop", systemImage: "power") } }
        } label: {
            HStack(spacing: 6) {
                if phase == .starting { ProgressView().scaleEffect(0.55).frame(width: 8, height: 8).tint(tone.color) }
                else { Circle().fill(tone.color).frame(width: 7, height: 7) }
                Text(title).font(DS.Font.label).foregroundColor(DS.Palette.textPrimary)
                if open != nil || stop != nil { Image(systemName: "chevron.down").font(.caption2.weight(.bold)).foregroundColor(DS.Palette.textTertiary) }
            }
            .padding(.horizontal, DS.Space.sm).frame(minHeight: 32)
            .background(Capsule().fill(DS.Palette.surface))
            .overlay(Capsule().stroke(DS.Palette.border, lineWidth: 1))
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .disabled(open == nil && stop == nil)
        .accessibilityLabel("Desktop status: \(title)")
        .animation(.easeInOut(duration: 0.2), value: phase)
    }
}

/// Everything Home shows, as plain values: the screen holds no runtime logic.
struct HomeModel {
    var environmentName: String?
    var distributionID: String?
    var environmentDetail: String?
    var phase: HomeStatus.Phase
    var stateText: String
    var running: Bool
    var starting: Bool
    var desktopAlive: Bool
    var canStart: Bool
    var gpuInUse: Bool
    var warning: String?
    var runtimeStatus: String?
    var hasEnvironment: Bool { environmentName != nil }
}

enum HomeDestination { case appStore, files, gpu, devices, diagnostics, resources }

/// The Home tab: environment header, desktop hero, quick actions and tools.
struct HomeScreen<Tasks: View>: View {
    let model: HomeModel
    var primary: () -> Void
    var stop: (() -> Void)?
    var openTerminal: () -> Void
    /// Shown instead of Start Linux when nothing is installed yet.
    var addDistribution: () -> Void
    /// Opens Task Manager; available while Linux runs.
    var openTaskManager: () -> Void
    var destination: (HomeDestination) -> AnyView
    @ViewBuilder var tasks: () -> Tasks
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.xl) {
                header
                hero
                if let warning = model.warning {
                    DSNotice(text: warning, symbol: "person.crop.circle.badge.exclamationmark", tone: .warning)
                }
                quickActions
                VStack(alignment: .leading, spacing: DS.Space.sm) {
                    DSSectionHeader("Tools")
                    // Plain rows, not a LazyVGrid: navigation links inside lazily
                    // recycled grid cells stop responding after repeated push/pop.
                    let tools = toolCards
                    let columns = sizeClass == .regular ? 3 : 2
                    VStack(spacing: DS.Space.sm) {
                        ForEach(0..<(tools.count + columns - 1) / columns, id: \.self) { row in
                            HStack(spacing: DS.Space.sm) {
                                ForEach(0..<columns, id: \.self) { column in
                                    let index = row * columns + column
                                    if index < tools.count { tools[index] } else { Color.clear.frame(maxWidth: .infinity, maxHeight: 0) }
                                }
                            }
                        }
                    }
                }
                tasks()
                if let status = model.runtimeStatus, model.hasEnvironment {
                    Text(status).font(DS.Font.caption).foregroundColor(DS.Palette.textTertiary)
                }
            }
            .padding(.horizontal, DS.Space.screen).padding(.top, DS.Space.xs).padding(.bottom, 96)
            .dsReadableWidth()
        }
        .dsScreenBackground()
        .navigationBarHidden(true)
    }

    private var header: some View {
        HStack(spacing: DS.Space.sm) {
            DistroBadge(distributionID: model.distributionID, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.environmentName ?? "No Linux installed").font(DS.Font.cardTitle).foregroundColor(DS.Palette.textPrimary).lineLimit(1)
                Text(model.environmentDetail ?? "Choose a distribution").font(DS.Font.data).foregroundColor(DS.Palette.textSecondary).lineLimit(1)
            }
            Spacer(minLength: DS.Space.xs)
            if model.hasEnvironment { HomeStatus(phase: model.phase, open: model.running ? primary : nil, stop: stop) }
            else { DSBadge(text: "Not set up", tone: .neutral) }
        }
        .padding(.top, DS.Space.xs)
    }

    /// The card is titled "Desktop", so the button names only the action.
    private var primaryTitle: String {
        model.running ? (model.desktopAlive ? "Resume" : "Open") : model.starting ? "Starting…" : "Start Linux"
    }
    private var heroSubtitle: String {
        if !model.hasEnvironment { return "Not installed" }
        if !model.running { return model.starting ? "Booting the Linux runtime" : "Linux is not running" }
        switch model.phase {
        case .starting: return "Starting the desktop"
        case .ready: return "Your session is running"
        case .degraded: return "Running with limited features"
        default: return "Start a graphical session"
        }
    }

    /// Preview and action. iPhone: preview above the action bar. iPad (regular
    /// width): side by side, so the preview does not push everything below the fold.
    private var hero: some View {
        Group {
            if sizeClass == .regular {
                HStack(spacing: 0) {
                    DesktopPreviewCard(phase: model.phase, stateText: model.stateText, open: model.hasEnvironment ? primary : addDistribution,
                                       emptyMessage: model.hasEnvironment ? nil : "No distribution installed")
                        .frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: DS.Space.md) {
                        heroText
                        Spacer(minLength: 0)
                        primaryButton
                    }
                    .padding(DS.Space.lg)
                    .frame(width: 280, alignment: .leading)
                    .frame(maxHeight: .infinity)
                }
            } else {
                VStack(spacing: 0) {
                    DesktopPreviewCard(phase: model.phase, stateText: model.stateText, open: model.hasEnvironment ? primary : addDistribution,
                                       emptyMessage: model.hasEnvironment ? nil : "No distribution installed")
                    HStack(spacing: DS.Space.sm) {
                        heroText
                        Spacer(minLength: DS.Space.xs)
                        primaryButton
                    }
                    .padding(DS.Space.md)
                }
            }
        }
        .background(RoundedRectangle.ds(DS.Radius.xl).fill(DS.Palette.surface))
        .clipShape(RoundedRectangle.ds(DS.Radius.xl))
        .overlay(RoundedRectangle.ds(DS.Radius.xl).stroke(DS.Palette.border, lineWidth: 1))
    }

    private var heroText: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Desktop").font(DS.Font.cardTitle).foregroundColor(DS.Palette.textPrimary)
            Text(heroSubtitle).font(DS.Font.caption).foregroundColor(DS.Palette.textSecondary).lineLimit(sizeClass == .regular ? 3 : 1)
        }
    }

    @ViewBuilder private var primaryButton: some View {
        if !model.hasEnvironment {
            Button(action: addDistribution) {
                HStack(spacing: DS.Space.xs) { Image(systemName: "plus").font(.subheadline.weight(.bold)); Text("Add Distribution").lineLimit(1) }.fixedSize()
            }
            .buttonStyle(DSButtonStyle(.primary, fullWidth: sizeClass == .regular))
            .accessibilityIdentifier("Add Distribution")
        } else {
            Button(action: primary) {
                HStack(spacing: DS.Space.xs) {
                    if model.starting { ProgressView().tint(DS.Palette.textTertiary) }
                    else { Image(systemName: model.running ? "play.fill" : "power").font(.subheadline.weight(.bold)) }
                    Text(primaryTitle).lineLimit(1)
                }
                .fixedSize()
            }
            .buttonStyle(DSButtonStyle(.primary, fullWidth: sizeClass == .regular))
            .disabled(model.running ? false : (model.starting || !model.canStart))
            .accessibilityLabel(model.running ? (model.desktopAlive ? "Resume Desktop" : "Open Desktop") : "Start Linux")
            .accessibilityIdentifier(model.running ? "Open Desktop" : "Start Linux Runtime")
        }
    }

    private var quickActions: some View {
        HStack(spacing: DS.Space.sm) {
            Button(action: openTerminal) {
                QuickActionCard(title: "Terminal", detail: "Shell", symbol: "terminal")
            }
            .buttonStyle(DSPressableStyle()).disabled(!model.hasEnvironment)
            .accessibilityIdentifier("Terminal")
            NavigationLink(destination: destination(.appStore)) {
                QuickActionCard(title: "App Store", detail: "Linux apps", symbol: "bag")
            }
            .buttonStyle(DSPressableStyle()).disabled(!model.hasEnvironment)
            .accessibilityIdentifier("App Store")
        }
    }

    private var toolCards: [AnyView] {
        [
            AnyView(toolLink(.files, "Files", "folder", detail: "Shared files", enabled: model.hasEnvironment)),
            AnyView(toolLink(.gpu, "Graphics", "cpu", detail: model.gpuInUse ? "Metal active" : "Renderer", tone: model.gpuInUse ? .success : .neutral)),
            AnyView(toolLink(.devices, "Devices", "cable.connector", detail: "Hardware")),
            AnyView(toolLink(.diagnostics, "Diagnostics", "stethoscope", detail: "Crash reports")),
            AnyView(toolLink(.resources, "CPU & Memory", "memorychip", detail: "Cores and RAM")),
            AnyView(Button(action: openTaskManager) {
                ToolCard(title: "Task Manager", detail: model.running ? "Linux processes" : "Linux not running", symbol: "chart.line.uptrend.xyaxis")
            }
            .buttonStyle(DSPressableStyle()).disabled(!model.running).opacity(model.running ? 1 : 0.45)
            .accessibilityIdentifier("Task Manager")),
        ]
    }

    @ViewBuilder private func toolLink(_ target: HomeDestination, _ title: String, _ symbol: String, detail: String, tone: DS.Tone = .neutral, enabled: Bool = true) -> some View {
        NavigationLink(destination: destination(target)) {
            ToolCard(title: title, detail: detail, symbol: symbol, tone: tone)
        }
        .buttonStyle(DSPressableStyle()).disabled(!enabled).opacity(enabled ? 1 : 0.45)
        .accessibilityIdentifier(title == "Graphics" ? "GPU" : title)
    }
}

/// Large Home action: Terminal, App Store.
struct QuickActionCard: View {
    let title: String, detail: String, symbol: String
    @Environment(\.isEnabled) private var enabled
    var body: some View {
        HStack(spacing: DS.Space.sm) {
            DSIconTile(symbol: symbol, tone: .accent, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(DS.Font.cardTitle).foregroundColor(DS.Palette.textPrimary).lineLimit(1)
                Text(detail).font(DS.Font.caption).foregroundColor(DS.Palette.textSecondary).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .dsCard(padding: DS.Space.sm + 2)
        .opacity(enabled ? 1 : 0.45)
        .accessibilityElement(children: .combine)
    }
}

/// Compact Home tool: icon, title and a one-line detail.
struct ToolCard: View {
    let title: String, detail: String, symbol: String
    var tone: DS.Tone = .neutral
    var body: some View {
        HStack(spacing: DS.Space.sm) {
            DSIconTile(symbol: symbol, tone: tone, size: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(DS.Font.label).foregroundColor(DS.Palette.textPrimary).lineLimit(1).minimumScaleFactor(0.85)
                Text(detail).font(DS.Font.caption).foregroundColor(tone == .neutral ? DS.Palette.textSecondary : tone.color).lineLimit(1).minimumScaleFactor(0.85)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard(padding: DS.Space.sm)
        .accessibilityElement(children: .combine)
    }
}

/// Earlier tile used by other screens: same visual language as ToolCard.
struct HomeTile: View {
    let title: String
    let symbol: String
    var colors: [Color] = []
    var large = false
    var badge = false
    var body: some View {
        ToolCard(title: title, detail: badge ? "Active" : " ", symbol: outlineSymbol(symbol), tone: badge ? .success : .neutral)
    }
}

/// Earlier name of DSPressableStyle.
typealias HomeTileStyle = DSPressableStyle

// MARK: - Activity

/// One long task as plain values.
struct ActivityItem: Identifiable {
    enum State { case running, background, paused, completed, failed }
    let id: String
    let title: String
    let detail: String
    let state: State
    let stateText: String
    let fraction: Double?
    let started: Date
    let ended: Date?
}

/// Running and recent long tasks with their real state and elapsed time.
struct HomeTasks: View {
    @ObservedObject var center: LongTaskCenter
    var body: some View {
        ActivityList(items: center.entries.prefix(4).map { entry in
            let state: ActivityItem.State
            switch entry.state {
            case .completed: state = .completed
            case .failed: state = .failed
            case .pausedByIOS: state = .paused
            case .backgroundGranted: state = .background
            case .running: state = .running
            }
            return ActivityItem(id: "\(entry.id)", title: entry.title, detail: entry.detail, state: state, stateText: entry.state.rawValue,
                                fraction: entry.fraction, started: entry.started, ended: entry.ended)
        })
    }
}

struct ActivityList: View {
    let items: [ActivityItem]
    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                DSSectionHeader("Activity")
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { Divider().overlay(DS.Palette.border).padding(.leading, 52) }
                        ActivityRow(item: item)
                    }
                }
                .dsCard(padding: 0)
            }
        }
    }
}

struct ActivityRow: View {
    let item: ActivityItem
    private var tone: DS.Tone {
        switch item.state { case .completed: return .success; case .failed: return .danger; case .paused: return .warning; case .background: return .info; case .running: return .accent }
    }
    private var symbol: String {
        switch item.state { case .completed: return "checkmark"; case .failed: return "xmark"; case .paused: return "pause.fill"; default: return "arrow.down" }
    }
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(alignment: .top, spacing: DS.Space.sm) {
                ZStack {
                    RoundedRectangle.ds(DS.Radius.sm).fill(tone.fill).frame(width: 28, height: 28)
                    if item.ended == nil && item.state != .paused { ProgressView().scaleEffect(0.6).tint(tone.color) }
                    else { Image(systemName: symbol).font(.caption.weight(.bold)).foregroundColor(tone.color) }
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.title).font(DS.Font.label).foregroundColor(DS.Palette.textPrimary).lineLimit(1)
                        Spacer(minLength: DS.Space.xs)
                        Text(elapsed(now: context.date)).font(DS.Font.dataSmall).foregroundColor(DS.Palette.textTertiary)
                    }
                    Text(item.detail).font(DS.Font.caption).foregroundColor(DS.Palette.textSecondary).lineLimit(2)
                    if let fraction = item.fraction, item.ended == nil {
                        ProgressView(value: fraction).tint(tone.color).padding(.top, 2)
                    }
                    if item.state != .running { Text(item.stateText).font(DS.Font.overline).foregroundColor(tone.color) }
                }
            }
            .padding(DS.Space.sm)
        }
        .accessibilityElement(children: .combine)
    }
    private func elapsed(now: Date) -> String {
        let seconds = Int((item.ended ?? now).timeIntervalSince(item.started))
        return seconds >= 3600 ? String(format: "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60) : String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

// MARK: - Desktop preview

/// Live preview of the running desktop on Home. It shows the session's own
/// frames (no second X server, no fake animation), refreshes at most 5 times a
/// second and only while visible, and only when a new frame arrived.
struct DesktopPreviewCard: View {
    let phase: HomeStatus.Phase
    let stateText: String
    var open: () -> Void
    /// Replaces the stopped/off caption, e.g. when nothing is installed yet.
    var emptyMessage: String?
    @State private var image: UIImage?
    @State private var generation: UInt64 = 0
    @State private var visible = false
    private let tick = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()
    var body: some View {
        Button(action: open) {
            ZStack {
                Color(UIColor(hex: 0x050506))
                if let image, phase != .off, phase != .stopped {
                    Image(uiImage: image).resizable().interpolation(.high).aspectRatio(contentMode: .fit)
                } else if let last = image ?? DesktopPreviewCard.lastFrame {
                    // The last frame of your desktop, dimmed: what Open Desktop brings back.
                    Image(uiImage: last).resizable().interpolation(.high).aspectRatio(contentMode: .fit)
                        .saturation(0.4).opacity(0.35)
                    caption
                } else {
                    MiniDesktopArt()
                    caption
                }
                if phase == .starting {
                    VStack { Spacer(); HStack(spacing: DS.Space.xs) { ProgressView().tint(.white); Text(stateText).font(DS.Font.overline).foregroundColor(.white).lineLimit(1) }
                        .padding(.horizontal, DS.Space.sm).padding(.vertical, 6).background(Capsule().fill(.black.opacity(0.7))).padding(DS.Space.sm) }
                }
            }
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
        }
        .buttonStyle(DSPressableStyle())
        .accessibilityLabel(phase == .ready || phase == .degraded ? "Live desktop preview. Opens the desktop." : "Desktop. \(stateText)")
        .onAppear { visible = true; LRRuntimeBridge.setDesktopPreviewWanted(true); refresh() }
        .onDisappear { visible = false; LRRuntimeBridge.setDesktopPreviewWanted(false) }
        .onReceive(tick) { _ in if visible { refresh() } }
        .onChange(of: phase) { p in if p == .stopped || p == .off { if let image { DesktopPreviewCard.remember(image) }; image = nil; generation = 0 } else { LRRuntimeBridge.setDesktopPreviewWanted(visible) } }
    }
    private func refresh() {
        guard phase != .stopped, phase != .off else { return }
        var g = generation
        if let next = LRRuntimeBridge.desktopPreviewImageIfChanged(since: &g) { image = next; generation = g; DesktopPreviewCard.remember(next) }
    }
    // Last desktop frame, kept across launches (Caches; never synced or shared).
    private static let lastFrameURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("LinuxRunnerDesktopLastFrame.jpg")
    static var lastFrame: UIImage? = UIImage(contentsOfFile: lastFrameURL.path)
    private static var lastSaved = Date.distantPast
    static func remember(_ image: UIImage) {
        lastFrame = image
        guard Date().timeIntervalSince(lastSaved) > 10 else { return }
        lastSaved = Date()
        DispatchQueue.global(qos: .utility).async { try? image.jpegData(compressionQuality: 0.7)?.write(to: lastFrameURL, options: .atomic) }
    }
    private var caption: some View {
        ZStack {
        Color.black.opacity(0.45)
        VStack(spacing: DS.Space.xs) {
            Image(systemName: emptyMessage != nil ? "plus" : phase == .off ? "power" : "play.fill").font(.title3.weight(.semibold)).foregroundColor(.white.opacity(0.9))
                .frame(width: 48, height: 48).background(Circle().fill(.black.opacity(0.55))).overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))
            Text(emptyMessage ?? (phase == .off ? "Linux is not running" : phase == .starting ? "Starting desktop…" : "Desktop stopped")).font(DS.Font.label).foregroundColor(.white)
        }
        }
    }
}

/// A drawn miniature desktop (wallpaper, two windows, a panel) for when no
/// frame of the user's desktop exists yet. Pure shapes: no images, no icons.
struct MiniDesktopArt: View {
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: [Color(UIColor(hex: 0x17171B)), Color(UIColor(hex: 0x0C0C0E))], startPoint: .top, endPoint: .bottom)
                window(width: w * 0.46, height: h * 0.48).offset(x: w * 0.08, y: h * 0.12)
                window(width: w * 0.40, height: h * 0.42).offset(x: w * 0.46, y: h * 0.30)
                VStack { Spacer()
                    HStack(spacing: 6) {
                        Capsule().fill(Color(UIColor(hex: 0xFF7A1A)).opacity(0.8)).frame(width: 18, height: 5)
                        ForEach(0..<3) { _ in RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.18)).frame(width: 14, height: 5) }
                        Spacer()
                        Capsule().fill(Color.white.opacity(0.25)).frame(width: 26, height: 5)
                    }.padding(.horizontal, 10).frame(height: max(14, h * 0.08)).background(Color.black.opacity(0.5))
                }
            }
        }
    }
    private func window(width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) { ForEach(0..<3) { _ in Circle().fill(Color.white.opacity(0.22)).frame(width: 5, height: 5) }; Spacer() }
                .padding(.horizontal, 7).frame(height: 12).background(Color.white.opacity(0.07))
            Rectangle().fill(Color.white.opacity(0.03))
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color.white.opacity(0.09), lineWidth: 0.5))
    }
}

// MARK: - Distributions

/// Distributions LinuxRunner can actually install, in setup order.
struct CatalogDistribution: Identifiable {
    let id: String, name: String, summary: String, detail: String
    let experimental: Bool
    static let all: [CatalogDistribution] = [
        .init(id: "debian", name: "Debian 13", summary: "Recommended", detail: "Stable, widest app support, all desktops", experimental: false),
        .init(id: "arch", name: "Arch Linux ARM", summary: "Rolling release", detail: "pacman, X11 and Wayland desktops, KDE Plasma", experimental: false),
        .init(id: "fedora", name: "Fedora 44", summary: "DNF userspace", detail: "Lightweight desktop and KDE Plasma", experimental: false),
        .init(id: "ubuntu", name: "Ubuntu 24.04", summary: "Ubuntu Base · Experimental", detail: "APT, i3 and experimental Ubuntu GNOME", experimental: true),
        .init(id: "pop", name: "Pop!_OS 24.04", summary: "By System76 · Experimental", detail: "Ubuntu base with Pop!_OS's repository and look", experimental: true),
        .init(id: "zorin", name: "Zorin OS 18", summary: "Windows-like · Experimental", detail: "Ubuntu base with Zorin OS's repositories and look", experimental: true),
        .init(id: "void", name: "Void Linux", summary: "Independent · Experimental", detail: "Independent rolling release with xbps; very light", experimental: true),
        .init(id: "kali", name: "Kali Linux", summary: "Security tools", detail: "Kali's Xfce desktop and tool sets", experimental: false),
        .init(id: "alpine", name: "Alpine 3.24", summary: "Small and fast", detail: "Mainly for the terminal", experimental: false),
        .init(id: "steamos", name: "SteamOS ARM64", summary: "Valve SteamFrame image", detail: "Downloads Valve's ARM64 recovery image; not official SteamOS support, no Steam games", experimental: true),
    ]
}

/// The distribution's own logo (DistroLogos.bundle, see its SOURCES.md) on a
/// light tile, so cut-out marks (Alpine, Fedora) keep their real colours.
struct DistroBadge: View {
    let distributionID: String?
    var size: CGFloat = 44
    private static var cache: [String: UIImage] = [:]
    private var file: String {
        switch distributionID ?? "alpine" {
        case "debian": return "debian"
        case "arch", "archarm": return "arch"
        case "fedora": return "fedora"
        case "ubuntu": return "ubuntu"
        case "kali": return "kali"
        case "steamos": return "steamos"
        case "pop": return "pop"
        case "zorin": return "zorin"
        case "void": return "void"
        case "opensuse", "opensuse-tumbleweed": return "opensuse"
        default: return "alpine"
        }
    }
    private var logo: UIImage? {
        if let image = Self.cache[file] { return image }
        guard let bundle = Bundle.main.url(forResource: "DistroLogos", withExtension: "bundle"),
              let image = UIImage(contentsOfFile: bundle.appendingPathComponent(file + ".png").path) else { return nil }
        Self.cache[file] = image
        return image
    }
    var body: some View {
        RoundedRectangle.ds(size * 0.26)
            .fill(Color(white: 0.97))
            .frame(width: size, height: size)
            .overlay {
                if distributionID == nil { Image(systemName: "plus").font(.system(size: size * 0.38, weight: .semibold)).foregroundColor(Color(white: 0.45)) }
                else if let logo { Image(uiImage: logo).resizable().interpolation(.high).scaledToFit().padding(size * 0.16) }
                else { Image(systemName: "shippingbox").foregroundColor(.gray) }
            }
            .overlay(RoundedRectangle.ds(size * 0.26).stroke(Color.black.opacity(0.06), lineWidth: 1))
            .accessibilityHidden(true)
    }
}

/// A desktop environment's mark, in the same rounded tile as DistroBadge:
/// the icon theme's logo where one exists (DesktopLogos.bundle/SOURCES.md),
/// otherwise a symbol tile drawn by the app.
struct DesktopBadge: View {
    let desktopID: String
    var size: CGFloat = 46
    private static var cache: [String: UIImage] = [:]
    private var logo: UIImage? {
        guard ["linuxrunner", "gnome", "plasma", "lxqt", "xfce"].contains(desktopID) else { return nil }
        if let image = Self.cache[desktopID] { return image }
        guard let bundle = Bundle.main.url(forResource: "DesktopLogos", withExtension: "bundle"),
              let image = UIImage(contentsOfFile: bundle.appendingPathComponent(desktopID + ".png").path) else { return nil }
        Self.cache[desktopID] = image
        return image
    }
    private var tile: (symbol: String, colors: [Color]) {
        switch desktopID {
        case "i3": return ("square.grid.2x2.fill", [Color(red: 0.20, green: 0.24, blue: 0.30), Color(red: 0.36, green: 0.44, blue: 0.54)])
        case "wayfire": return ("flame.fill", [Color(red: 1.00, green: 0.58, blue: 0.20), Color(red: 0.90, green: 0.25, blue: 0.20)])
        case "hyprland": return ("square.grid.3x2.fill", [Color(red: 0.20, green: 0.80, blue: 0.90), Color(red: 0.25, green: 0.40, blue: 0.95)])
        case "enlightenment": return ("sparkles", [Color(red: 0.62, green: 0.36, blue: 0.95), Color(red: 0.95, green: 0.35, blue: 0.62)])
        case "mate": return ("leaf.fill", [Color(red: 0.45, green: 0.75, blue: 0.30), Color(red: 0.20, green: 0.55, blue: 0.25)])
        case "cinnamon": return ("circle.grid.cross.fill", [Color(red: 0.85, green: 0.55, blue: 0.30), Color(red: 0.60, green: 0.35, blue: 0.20)])
        case "cosmic": return ("sparkle", [Color(red: 0.28, green: 0.75, blue: 0.85), Color(red: 0.55, green: 0.40, blue: 0.95)])
        case "budgie": return ("circle.hexagongrid.fill", [Color(red: 0.30, green: 0.60, blue: 0.95), Color(red: 0.55, green: 0.35, blue: 0.85)])
        default: return ("macwindow.on.rectangle", [Color(red: 0.25, green: 0.50, blue: 1.00), Color(red: 0.36, green: 0.30, blue: 0.90)])
        }
    }
    var body: some View {
        Group {
            if let logo, desktopID == "linuxrunner" {
                // The app's own icon: full-bleed, like on the Home Screen.
                Image(uiImage: logo).resizable().interpolation(.high).scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            } else if let logo {
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous).fill(Color(white: 0.96))
                    .overlay(Image(uiImage: logo).resizable().interpolation(.high).scaledToFit().padding(size * 0.12))
            } else {
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(LinearGradient(colors: tile.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(Image(systemName: tile.symbol).font(.system(size: size * 0.42, weight: .semibold)).foregroundColor(.white))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// One desktop in the picker: mark, name, badges, what it is, and its state
/// (selected, ready to use, install, or installing with live progress).
struct DesktopChoiceCard: View {
    let option: DesktopOption
    let distro: String
    let selected: Bool
    let installed: Bool
    let progress: String?
    let enabled: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                DesktopBadge(desktopID: option.id, size: 52)
                VStack(alignment: .leading, spacing: 5) {
                    Text(option.title).font(.headline).foregroundColor(.primary).lineLimit(1).minimumScaleFactor(0.8)
                    if !option.badges(distro).isEmpty {
                        HStack(spacing: 6) {
                            ForEach(option.badges(distro), id: \.self) { badge in
                                StatusChip(text: badge, color: badge == "Recommended" ? .accentColor : badge == "Experimental" ? .orange : .green)
                                    .fixedSize()
                            }
                        }
                    }
                    Text(option.detail).font(.footnote).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                    if let progress {
                        HStack(spacing: 6) { ProgressView().scaleEffect(0.7); Text(progress).font(.caption).foregroundColor(.secondary).lineLimit(2) }
                    } else if !installed {
                        Label("Install", systemImage: "arrow.down.circle.fill").font(.caption.weight(.semibold)).foregroundColor(.accentColor)
                    }
                }
                Spacer(minLength: 4)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title2).foregroundColor(selected ? .accentColor : Color(.tertiaryLabel))
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 2))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled || selected ? 1 : 0.55)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint(installed ? "Selects this desktop" : "Installs this desktop")
    }
}

/// Status label used across screens. `color` maps onto the nearest design tone.
struct StatusChip: View {
    let text: String; let color: Color
    private var tone: DS.Tone {
        switch color {
        case .green: return .success
        case .orange, .yellow: return .warning
        case .red: return .danger
        case .accentColor: return .accent
        case .blue: return .info
        default: return .neutral
        }
    }
    var body: some View { DSBadge(text: text, tone: tone) }
}

struct InstalledDistributionCard: View {
    let name: String, distributionID: String?, version: String, size: String, desktop: String?
    let active: Bool, nextLaunch: Bool
    var body: some View {
        HStack(spacing: DS.Space.md) {
            DistroBadge(distributionID: distributionID, size: 48)
            VStack(alignment: .leading, spacing: 5) {
                Text(name).font(DS.Font.cardTitle).foregroundColor(DS.Palette.textPrimary).lineLimit(1)
                Text([version, size].filter { !$0.isEmpty }.joined(separator: " · ")).font(DS.Font.data).foregroundColor(DS.Palette.textSecondary).lineLimit(1)
                if active { DSBadge(text: "Running", tone: .success) }
                else if nextLaunch { DSBadge(text: "Next launch", tone: .accent) }
                if let desktop {
                    Label(desktop, systemImage: "macwindow").font(DS.Font.caption).foregroundColor(DS.Palette.textSecondary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundColor(DS.Palette.textTertiary)
        }
        .dsCard()
        .accessibilityElement(children: .combine)
    }
}

struct CatalogDistributionCard: View {
    let item: CatalogDistribution
    let installed: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack(alignment: .top) {
                DistroBadge(distributionID: item.id, size: 40)
                Spacer()
                if item.experimental { DSBadge(text: "Experimental", tone: .warning) }
                else if installed { DSBadge(text: "Installed", tone: .neutral) }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name).font(DS.Font.cardTitle).foregroundColor(DS.Palette.textPrimary)
                Text(item.summary).font(DS.Font.label).foregroundColor(DS.Palette.textSecondary)
                Text(item.detail).font(DS.Font.caption).foregroundColor(DS.Palette.textTertiary).lineLimit(2)
            }
            Spacer(minLength: 0)
            HStack(spacing: 5) {
                Image(systemName: installed ? "plus" : "arrow.down.circle.fill")
                Text(installed ? "Add another" : "Install")
            }
            .font(.subheadline.weight(.semibold)).foregroundColor(DS.Palette.accent)
        }
        .frame(maxWidth: .infinity, minHeight: 184, alignment: .topLeading)
        .dsCard()
        .accessibilityElement(children: .combine)
    }
}

/// Plain values for one installed distribution.
struct InstalledDistributionItem: Identifiable {
    let id: String
    let name: String
    let distributionID: String?
    let version: String
    let size: String
    let desktop: String?
    let active: Bool
    let nextLaunch: Bool
    let deletionBlocked: Bool
}

/// The Distributions tab: installed environments and the catalog.
struct DistributionsScreen: View {
    let installed: [InstalledDistributionItem]
    let busy: Bool
    var detail: (InstalledDistributionItem) -> AnyView
    var install: (String) -> Void
    var useNextLaunch: (InstalledDistributionItem) -> Void
    var delete: (InstalledDistributionItem) -> Void
    var refresh: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.xxl) {
                VStack(alignment: .leading, spacing: DS.Space.sm) {
                    DSSectionHeader("Installed") {
                        if !installed.isEmpty { Text("\(installed.count)").font(DS.Font.dataSmall.weight(.semibold)).foregroundColor(DS.Palette.textTertiary) }
                    }
                    if installed.isEmpty {
                        DSEmptyState(symbol: "square.stack.3d.up", title: "No distribution yet", message: "Choose one below. Debian is the best start for desktop apps.")
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: DS.Space.sm)], spacing: DS.Space.sm) {
                        ForEach(installed) { item in
                            NavigationLink(destination: detail(item)) {
                                InstalledDistributionCard(name: item.name, distributionID: item.distributionID, version: item.version, size: item.size,
                                                          desktop: item.desktop, active: item.active, nextLaunch: item.nextLaunch)
                            }
                            .buttonStyle(DSPressableStyle())
                            .contextMenu {
                                if !item.active { Button { useNextLaunch(item) } label: { Label("Use on Next Launch", systemImage: "arrow.uturn.right") } }
                                Button(role: .destructive) { delete(item) } label: { Label("Delete…", systemImage: "trash") }
                                    .disabled(busy || item.deletionBlocked)
                            }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: DS.Space.sm) {
                    DSSectionHeader("Add a Distribution")
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 158), spacing: DS.Space.sm)], spacing: DS.Space.sm) {
                        ForEach(CatalogDistribution.all) { item in
                            Button { install(item.id) } label: {
                                CatalogDistributionCard(item: item, installed: installed.contains { $0.distributionID == item.id })
                            }
                            .buttonStyle(DSPressableStyle()).disabled(busy).accessibilityIdentifier("Install \(item.name)")
                        }
                    }
                    if busy { HStack(spacing: DS.Space.xs) { ProgressView(); Text("Preparing environment…").font(DS.Font.caption).foregroundColor(DS.Palette.textSecondary) } }
                }
                DSNotice(text: "Each distribution keeps its own packages and files. One runs at a time; switching takes effect when LinuxRunner is reopened.", symbol: "info.circle", tone: .neutral)
            }
            .padding(.horizontal, DS.Space.screen).padding(.top, DS.Space.xs).padding(.bottom, 96)
            .dsReadableWidth()
        }
        .dsScreenBackground()
        .navigationTitle("Distributions")
        .toolbar { Button(action: refresh) { Image(systemName: "arrow.clockwise") }.accessibilityLabel("Refresh Distributions") }
    }
}

/// Settings row label. `color` is kept for existing callers; rows use the
/// neutral tile so the list reads as one system.
struct SettingsLabel: View {
    let title: String, symbol: String, color: Color
    init(_ title: String, _ symbol: String, _ color: Color) { self.title = title; self.symbol = symbol; self.color = color }
    var body: some View { DSRowLabel(title, outlineSymbol(symbol)) }
}

/// The outline variant of a ".fill" SF Symbol name; other names are unchanged.
func outlineSymbol(_ name: String) -> String {
    name.hasSuffix(".fill") ? String(name.dropLast(5)) : name
}

// MARK: - CPU & Memory (Settings › Graphics & Performance)

/// What Linux programs are told about CPU cores and memory. Programs size their
/// worker threads (make -j, Blender, browsers, Java) and heaps from these, and
/// guest threads run on separate CPU cores. Applied at the next launch.
struct SystemResourcesView: View {
    @AppStorage(LRSystemCPUCoresKey) private var cores = 0
    @AppStorage(LRSystemMemoryMBKey) private var memoryMB = 0
    private let hostCores = max(1, min(16, ProcessInfo.processInfo.activeProcessorCount))
    /// Advertised RAM tier: iOS reports a little less than the marketed amount
    /// (a 12 GB iPhone can report under 11.5 GiB), so classify instead of rounding.
    private let deviceGB: Int = {
        let gib = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        switch gib {
        case 14...: return 16
        case 10...: return 12
        case 7...: return 8
        case 5...: return 6
        case 3.5...: return 4
        default: return max(1, Int(gib.rounded()))
        }
    }()
    private let appliedCores = ProcessInfo.processInfo.environment["LINUXRUNNER_CPU_CORES"].flatMap(Int.init) ?? 0
    private let appliedMemoryMB = ProcessInfo.processInfo.environment["LINUXRUNNER_MEMORY_MB"].flatMap(Int.init) ?? 0

    /// 12 GB → 8, 16 → 8 (runtime maximum), 8 → 4, 6 → 3, 4 → 2: the rest stays for iOS and the app.
    private var maximumGB: Int {
        let limit = deviceGB >= 12 ? deviceGB - 4 : deviceGB >= 8 ? deviceGB / 2 : deviceGB >= 6 ? 3 : max(1, deviceGB / 2)
        return min(8, max(1, limit))
    }
    /// What iOS lets LinuxRunner use right now (footprint plus what is still
    /// available); nil where iOS reports no app limit (Simulator, Mac).
    private var iosAllowanceGB: Double? {
        let available = os_proc_available_memory()
        guard available > 0 else { return nil }
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let footprint = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count) }
        } == KERN_SUCCESS ? Double(info.phys_footprint) : 0
        return (footprint + Double(available)) / 1_073_741_824
    }
    private var pendingRestart: Bool { cores != appliedCores || memoryMB != appliedMemoryMB }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                card(title: "CPU Cores", symbol: "cpu.fill", colors: [.indigo, .purple],
                     value: cores == 0 ? "Automatic · 4" : "\(cores) of \(hostCores)",
                     detail: "Linux programs start this many worker threads, and each runs on its own core. More cores speed up compiling, rendering and browsers; Automatic keeps 4, which suits most apps.") {
                    chips(options: [0] + Array(1...hostCores), selection: $cores) { $0 == 0 ? "Auto" : "\($0)" }
                }
                card(title: "Linux Memory", symbol: "memorychip.fill", colors: [.teal, .blue],
                     value: memoryMB == 0 ? "Automatic" : "\(memoryMB / 1024) GB",
                     detail: "The memory Linux programs see. Java, browsers and games size their heaps from it. Up to \(maximumGB) GB on this \(deviceGB) GB device; the rest stays for iOS and LinuxRunner.") {
                    chips(options: [0] + Array(1...maximumGB).map { $0 * 1024 }, selection: $memoryMB) { $0 == 0 ? "Auto" : "\($0 / 1024) GB" }
                    if memoryMB > 0, let allowance = iosAllowanceGB, Double(memoryMB) / 1024 > allowance {
                        Label(String(format: "iOS currently allows LinuxRunner about %.1f GB. Programs that use more than that can be closed by iOS.", allowance), systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote).foregroundStyle(.orange).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if pendingRestart {
                    Label("Applies the next time LinuxRunner starts. Close it from the app switcher and open it again.", systemImage: "arrow.clockwise.circle.fill")
                        .font(.footnote.weight(.medium)).foregroundStyle(.blue)
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.blue.opacity(0.12)))
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 12).padding(.bottom, 96)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("CPU & Memory")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: [.indigo, .teal], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 54, height: 54)
                .overlay(Image(systemName: "speedometer").font(.system(size: 24, weight: .semibold)).foregroundColor(.white))
            VStack(alignment: .leading, spacing: 3) {
                Text(UIDevice.current.model).font(.headline)
                Text("\(hostCores) CPU cores · \(deviceGB) GB memory").font(.subheadline).foregroundStyle(.secondary)
                if let allowance = iosAllowanceGB {
                    Text(String(format: "iOS allows LinuxRunner about %.1f GB now", allowance)).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
    }

    private func card<Content: View>(title: String, symbol: String, colors: [Color], value: String, detail: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 34, height: 34)
                    .overlay(Image(systemName: symbol).font(.system(size: 16, weight: .semibold)).foregroundColor(.white))
                Text(title).font(.headline)
                Spacer()
                Text(value).font(.subheadline.weight(.semibold).monospacedDigit()).foregroundStyle(.secondary)
            }
            content()
            Text(detail).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
    }

    private func chips(options: [Int], selection: Binding<Int>, label: @escaping (Int) -> String) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 58), spacing: 8)], spacing: 8) {
            ForEach(options, id: \.self) { option in
                let selected = selection.wrappedValue == option
                Button { withAnimation(.easeOut(duration: 0.2)) { selection.wrappedValue = option } } label: {
                    Text(label(option))
                        .font(.subheadline.weight(selected ? .semibold : .regular).monospacedDigit())
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .foregroundColor(selected ? .white : .primary)
                        .background(Capsule().fill(selected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color(.tertiarySystemGroupedBackground))))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}

// MARK: - Shared settings design (GPU, Devices, File Sharing)
// Cards in the style of CPU & Memory: gradient icon tile, headline, short
// value, content, and long explanations folded into "More info".
struct LRIconTile: View {
    let symbol: String; let colors: [Color]; var size: CGFloat = 34
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: size, height: size)
            .overlay(Image(systemName: symbol).font(.system(size: size * 0.47, weight: .semibold)).foregroundColor(.white))
    }
}
struct LRCard<Content: View>: View {
    let title: String; let symbol: String; let colors: [Color]; var value: String? = nil
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                LRIconTile(symbol: symbol, colors: colors)
                Text(title).font(.headline)
                Spacer()
                if let value { Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary).lineLimit(1) }
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
    }
}
struct LRChoice: Identifiable { let id: String; let title: String; let subtitle: String; let symbol: String }
struct LRChoiceList: View {
    let choices: [LRChoice]; @Binding var selection: String
    var body: some View {
        VStack(spacing: 8) {
            ForEach(choices) { choice in
                let selected = selection == choice.id
                Button { withAnimation(.easeOut(duration: 0.2)) { selection = choice.id } } label: {
                    HStack(spacing: 12) {
                        Image(systemName: choice.symbol).font(.system(size: 16, weight: .semibold))
                            .foregroundColor(selected ? .white : .accentColor)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(selected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.accentColor.opacity(0.14))))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(choice.title).font(.subheadline.weight(.semibold)).foregroundColor(.primary)
                            Text(choice.subtitle).font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle").font(.title3)
                            .foregroundColor(selected ? .accentColor : Color(.tertiaryLabel))
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(.tertiarySystemGroupedBackground)))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(selected ? Color.accentColor.opacity(0.6) : .clear, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}
struct LRStatusPill: View {
    let text: String; let color: Color
    var body: some View {
        Text(text).font(.caption2.weight(.semibold)).lineLimit(1)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .foregroundColor(color).background(Capsule().fill(color.opacity(0.15)))
    }
}
struct LRMoreInfo<Content: View>: View {
    var title = "More info"
    @ViewBuilder let content: () -> Content
    @State private var open = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { withAnimation(.easeOut(duration: 0.2)) { open.toggle() } } label: {
                HStack(spacing: 4) {
                    Text(title).font(.footnote.weight(.semibold))
                    Image(systemName: "chevron.down").font(.caption2.weight(.bold)).rotationEffect(.degrees(open ? 180 : 0))
                }.foregroundColor(.accentColor)
            }.buttonStyle(.plain)
            if open { content().font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
        }
    }
}
struct LRNavRow: View {
    let title: String; let subtitle: String?; let symbol: String; let colors: [Color]
    var body: some View {
        HStack(spacing: 12) {
            LRIconTile(symbol: symbol, colors: colors, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundColor(.primary)
                if let subtitle { Text(subtitle).font(.caption).foregroundColor(.secondary).lineLimit(1) }
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundColor(Color(.tertiaryLabel))
        }
        .padding(.vertical, 4).contentShape(Rectangle())
    }
}
