import SwiftUI

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

enum HomeDestination { case appStore, files, gpu, devices, diagnostics }

/// The Home tab: environment header, desktop hero, quick actions and tools.
struct HomeScreen<Tasks: View>: View {
    let model: HomeModel
    var primary: () -> Void
    var stop: (() -> Void)?
    var openTerminal: () -> Void
    /// Shown instead of Start Linux when nothing is installed yet.
    var addDistribution: () -> Void
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
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DS.Space.sm), count: sizeClass == .regular ? 4 : 2), spacing: DS.Space.sm) {
                        toolLink(.files, "Files", "folder", detail: "Shared files", enabled: model.hasEnvironment)
                        toolLink(.gpu, "Graphics", "cpu", detail: model.gpuInUse ? "Metal active" : "Renderer", tone: model.gpuInUse ? .success : .neutral)
                        toolLink(.devices, "Devices", "cable.connector", detail: "Hardware")
                        toolLink(.diagnostics, "Diagnostics", "stethoscope", detail: "Crash reports")
                    }
                }
                tasks()
                if let status = model.runtimeStatus {
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
                Text(model.environmentDetail ?? "Choose a distribution").font(DS.Font.mono).foregroundColor(DS.Palette.textSecondary).lineLimit(1)
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

    private var hero: some View {
        VStack(spacing: 0) {
            DesktopPreviewCard(phase: model.phase, stateText: model.stateText, open: primary)
            HStack(spacing: DS.Space.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Desktop").font(DS.Font.cardTitle).foregroundColor(DS.Palette.textPrimary)
                    Text(heroSubtitle).font(DS.Font.caption).foregroundColor(DS.Palette.textSecondary).lineLimit(1)
                }
                Spacer(minLength: DS.Space.xs)
                if !model.hasEnvironment {
                    Button(action: addDistribution) {
                        HStack(spacing: DS.Space.xs) { Image(systemName: "plus").font(.subheadline.weight(.bold)); Text("Add Distribution").lineLimit(1) }.fixedSize()
                    }
                    .buttonStyle(DSButtonStyle(.primary))
                    .accessibilityIdentifier("Add Distribution")
                } else {
                Button(action: primary) {
                    HStack(spacing: DS.Space.xs) {
                        if model.starting { ProgressView().tint(DS.Palette.onAccent) }
                        else { Image(systemName: model.running ? "play.fill" : "power").font(.subheadline.weight(.bold)) }
                        Text(primaryTitle).lineLimit(1)
                    }
                    .fixedSize()
                }
                .buttonStyle(DSButtonStyle(.primary))
                .disabled(model.running ? false : (model.starting || !model.canStart))
                .accessibilityLabel(model.running ? (model.desktopAlive ? "Resume Desktop" : "Open Desktop") : "Start Linux")
                .accessibilityIdentifier(model.running ? "Open Desktop" : "Start Linux Runtime")
                }
            }
            .padding(DS.Space.md)
        }
        .background(RoundedRectangle.ds(DS.Radius.xl).fill(DS.Palette.surface))
        .clipShape(RoundedRectangle.ds(DS.Radius.xl))
        .overlay(RoundedRectangle.ds(DS.Radius.xl).stroke(DS.Palette.border, lineWidth: 1))
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
                Text(detail).font(DS.Font.monoSmall).foregroundColor(tone == .neutral ? DS.Palette.textSecondary : tone.color).lineLimit(1).minimumScaleFactor(0.85)
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
                        Text(elapsed(now: context.date)).font(DS.Font.monoSmall).foregroundColor(DS.Palette.textTertiary)
                    }
                    Text(item.detail).font(DS.Font.caption).foregroundColor(DS.Palette.textSecondary).lineLimit(2)
                    if let fraction = item.fraction, item.ended == nil {
                        ProgressView(value: fraction).tint(tone.color).padding(.top, 2)
                    }
                    Text(item.stateText).font(DS.Font.overline).foregroundColor(tone.color)
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
            Image(systemName: phase == .off ? "power" : "play.fill").font(.title3.weight(.semibold)).foregroundColor(.white.opacity(0.9))
                .frame(width: 48, height: 48).background(Circle().fill(.black.opacity(0.55))).overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))
            Text(phase == .off ? "Linux is not running" : phase == .starting ? "Starting desktop…" : "Desktop stopped").font(DS.Font.label).foregroundColor(.white)
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
        case "kali": return "kali"
        case "steamos": return "steamos"
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
                Text([version, size].filter { !$0.isEmpty }.joined(separator: " · ")).font(DS.Font.mono).foregroundColor(DS.Palette.textSecondary).lineLimit(1)
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
                Text(item.detail).font(DS.Font.caption).foregroundColor(DS.Palette.textTertiary).lineLimit(3).fixedSize(horizontal: false, vertical: true)
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
                        if !installed.isEmpty { Text("\(installed.count)").font(DS.Font.mono).foregroundColor(DS.Palette.textTertiary) }
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
