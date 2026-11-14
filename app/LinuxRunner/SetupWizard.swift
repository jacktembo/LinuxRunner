import SwiftUI
import UniformTypeIdentifiers

// Guided setup: Welcome → Distribution → Install Linux → (restart into it) →
// Account → Desktop → Finish → Open Desktop. Uses the verified installers, the
// native account setup (password hashed in the app; tools installed if absent)
// and the same desktop-profile repair as Open Desktop. It opens by itself only
// when no Linux environment exists; existing environments, homes and accounts
// are never modified, and an existing account can be used as it is.
enum SetupStep: String { case welcome, distribution, install, relaunch, account, desktop, done }

struct SetupWizardView: View {
    @ObservedObject var manager: EnvironmentManager
    var openDesktop: () -> Void
    @Environment(\.dismiss) private var dismiss
    @AppStorage("LinuxRunnerSetup.step") private var stepRaw = SetupStep.welcome.rawValue
    @AppStorage("LinuxRunnerSetup.distribution") private var distribution = "debian"
    @AppStorage("LinuxRunnerSetup.root") private var setupRoot = ""
    @StateObject private var debian = DebianInstaller()
    @StateObject private var arch = ArchInstaller()
    @StateObject private var fedora = FedoraInstaller()
    @StateObject private var kali = KaliInstaller()
    @StateObject private var steamos = SteamOSInstaller()
    @State private var steamOSImporter = false
    @State private var username = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var administrator = true
    @State private var working: String?
    @State private var problem: String?
    @State private var desktopReady = false
    @State private var extraDesktops: Set<String> = []
    @State private var chosenDesktop = "linuxrunner"
    private var step: SetupStep { SetupStep(rawValue: stepRaw) ?? .welcome }

    private var anyInstallerRunning: Bool { debian.running || arch.running || fedora.running || kali.running || steamos.running }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.xl) {
                    if let index = stepIndex { DSStepIndicator(current: index, total: 5) }
                    content
                    if let working {
                        HStack(spacing: DS.Space.sm) {
                            ProgressView()
                            Text(working).font(DS.Font.detail).foregroundColor(DS.Palette.textSecondary).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .dsCard()
                    }
                    if let problem { DSNotice(text: problem, symbol: "exclamationmark.triangle.fill", tone: .danger) }
                }
                .padding(.horizontal, DS.Space.screen).padding(.top, DS.Space.md).padding(.bottom, 140)
                .frame(maxWidth: 640).frame(maxWidth: .infinity)
            }
            .dsScreenBackground()
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(step == .done ? "Close" : "Later") { dismiss() }.disabled(working != nil || anyInstallerRunning || manager.busy) } }
        }
        .navigationViewStyle(.stack)
        .tint(DS.Palette.accent)
        .overlay(alignment: .bottom) { InstallProgressCard() }
        .interactiveDismissDisabled(working != nil || anyInstallerRunning || manager.busy)
        .onAppear(perform: resume)
        .fileImporter(isPresented: $steamOSImporter, allowedContentTypes: [.data], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls): if let source = urls.first { installSteamOS(from: source) }
            case .failure(let error): problem = error.localizedDescription
            }
        }
    }

    private var title: String {
        switch step {
        case .welcome: return "Welcome"; case .distribution: return "Choose Linux"; case .install: return "Install Linux"
        case .relaunch: return "Restart LinuxRunner"; case .account: return "Your Account"; case .desktop: return "Desktop"; case .done: return "Ready"
        }
    }

    private var stepIndex: Int? {
        switch step {
        case .welcome, .done: return nil
        case .distribution: return 1; case .install: return 2; case .relaunch: return 3; case .account: return 4; case .desktop: return 5
        }
    }

    private var selectedDistributionName: String { CatalogDistribution.all.first { $0.id == distribution }?.name ?? "Linux" }

    /// What the chosen distribution offers and what it cannot do on iOS.
    private var distributionNote: (String, DS.Tone)? {
        switch distribution {
        case "debian": return ("Recommended: stable, with the widest app and desktop support.", .info)
        case "arch": return ("A rolling release with pacman and experimental X11 and Wayland desktops.", .info)
        case "fedora": return ("Experimental DNF userspace with a lightweight X11 desktop.", .info)
        case "kali": return ("The official Kali userspace with its Xfce desktop and optional standard tools. Kernel-level features such as monitor-mode Wi-Fi, raw packet capture and kernel modules are not available on iOS.", .warning)
        case "alpine": return ("Small, and mainly for the terminal.", .info)
        case "steamos": return ("Experimental: installed from Valve's SteamFrame recovery image. This is not official SteamOS support, and Steam games are not supported.", .warning)
        default: return nil
        }
    }

    @ViewBuilder private var content: some View {
        switch step {
        case .welcome:
            VStack(alignment: .leading, spacing: DS.Space.lg) {
                DSBrandMark(size: 64)
                DSScreenHeading(title: "Linux on your iPhone", message: "LinuxRunner runs real ARM64 Linux programs with its own interpreter. There is no virtual machine.")
            }
            VStack(alignment: .leading, spacing: DS.Space.md) {
                featureRow("square.stack.3d.up", "Install a distribution", "Debian, Arch, Fedora, Kali, Alpine or SteamOS.")
                featureRow("person.crop.circle", "Create your account", "Your own Linux user, with sudo if you want it.")
                featureRow("macwindow", "Choose a desktop", "A graphical desktop on this screen or an external display.")
            }
            .dsCard()
            if !manager.environments.isEmpty {
                DSNotice(text: "Configure an existing environment or install another distribution. Your files and accounts are preserved.", symbol: "info.circle.fill", tone: .info)
            }
            VStack(spacing: DS.Space.sm) {
                Button("Continue") { stepRaw = SetupStep.distribution.rawValue }.buttonStyle(DSButtonStyle(.primary, size: .large, fullWidth: true))
                Text("Everything can be changed later in Settings.").font(DS.Font.caption).foregroundColor(DS.Palette.textTertiary).frame(maxWidth: .infinity)
            }
        case .distribution:
            DSScreenHeading(title: "Choose a distribution", message: "Each distribution keeps its own packages and files. You can add more later.")
            VStack(spacing: DS.Space.sm) {
                ForEach(CatalogDistribution.all) { item in
                    Button { distribution = item.id } label: {
                        HStack(spacing: DS.Space.md) {
                            DistroBadge(distributionID: item.id, size: 44)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.id == "kali" ? "Kali Linux \(KaliImage.version)" : item.name).font(DS.Font.cardTitle).foregroundColor(DS.Palette.textPrimary)
                                HStack(spacing: DS.Space.xs) {
                                    Text(item.summary).font(DS.Font.caption).foregroundColor(DS.Palette.textSecondary)
                                    if item.experimental { DSBadge(text: "Experimental", tone: .warning) }
                                }
                            }
                            Spacer(minLength: 28)
                        }
                        .dsSelectable(distribution == item.id)
                    }
                    .buttonStyle(DSPressableStyle())
                    .accessibilityLabel(item.name)
                }
            }
            if let note = distributionNote { DSNotice(text: note.0, symbol: note.1 == .warning ? "exclamationmark.triangle.fill" : "info.circle.fill", tone: note.1) }
            let installed = manager.environments.filter { ($0.distributionID ?? "alpine") == distribution }
            if !installed.isEmpty {
                VStack(alignment: .leading, spacing: DS.Space.sm) {
                    Text("Already installed").font(DS.Font.cardTitle).foregroundColor(DS.Palette.textPrimary)
                    ForEach(installed) { environment in
                        Button("Configure " + environment.name) { configureExisting(environment) }.buttonStyle(DSButtonStyle(.secondary, fullWidth: true))
                    }
                    Text("Uses the existing environment, accounts and files. Switching environments takes effect after relaunch.").font(DS.Font.caption).foregroundColor(DS.Palette.textSecondary)
                }
            }
            Button(installed.isEmpty ? "Continue" : "Install Another Environment") { stepRaw = SetupStep.install.rawValue }
                .buttonStyle(DSButtonStyle(.primary, size: .large, fullWidth: true))
        case .install: install
        case .relaunch:
            DSScreenHeading(title: "Restart LinuxRunner", message: "Linux is installed and selected. One restart starts it.")
            VStack(alignment: .leading, spacing: DS.Space.md) {
                numberedRow(1, "Swipe LinuxRunner away in the app switcher.")
                numberedRow(2, "Open LinuxRunner again.")
                numberedRow(3, "Setup continues with your account.")
            }
            .dsCard()
            DSNotice(text: "iOS allows one Linux runtime per app launch, so this restart is needed once.", symbol: "info.circle.fill", tone: .info)
        case .account: account
        case .desktop: desktop
        case .done:
            VStack(spacing: DS.Space.md) {
                DSIconTile(symbol: "checkmark", tone: .success, size: 64)
                Text("Linux is ready").font(.title2.weight(.bold)).foregroundColor(DS.Palette.textPrimary)
                Text("Add applications any time from the App Store on Home.").font(DS.Font.detail).foregroundColor(DS.Palette.textSecondary).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(.vertical, DS.Space.xl)
            Button { stepRaw = SetupStep.welcome.rawValue; setupRoot = ""; dismiss(); openDesktop() } label: { Label("Open Desktop", systemImage: "desktopcomputer") }
                .buttonStyle(DSButtonStyle(.primary, size: .large, fullWidth: true))
                .disabled(!LRRuntimeBridge.isRunning())
        }
    }

    private func featureRow(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: DS.Space.sm) {
            DSIconTile(symbol: symbol, tone: .accent, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(DS.Font.label).foregroundColor(DS.Palette.textPrimary)
                Text(detail).font(DS.Font.caption).foregroundColor(DS.Palette.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private func numberedRow(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Space.sm) {
            Text("\(number)").font(DS.Font.mono.weight(.semibold)).foregroundColor(DS.Palette.accent).frame(width: 22, height: 22).background(Circle().fill(DS.Palette.accent.opacity(0.14)))
            Text(text).font(DS.Font.detail).foregroundColor(DS.Palette.textPrimary).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    /// One installer's controls: progress and Cancel while running, otherwise Install; failures with Try Again.
    @ViewBuilder private func installerControls(running: Bool, message: String, fraction: Double, cancel: @escaping () -> Void, installTitle: String, disabled: Bool, failure: String?, footer: String) -> some View {
        if running {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                Text(message).font(DS.Font.detail).foregroundColor(DS.Palette.textPrimary).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: DS.Space.sm) {
                    ProgressView(value: fraction).tint(DS.Palette.accent)
                    Text("\(Int(fraction * 100))%").font(DS.Font.mono).foregroundColor(DS.Palette.textSecondary).frame(minWidth: 36, alignment: .trailing)
                }
                Text("Keep LinuxRunner open until this finishes.").font(DS.Font.caption).foregroundColor(DS.Palette.textTertiary)
            }
            .dsCard()
            Button("Cancel", role: .destructive, action: cancel).buttonStyle(DSButtonStyle(.destructive, fullWidth: true))
        } else {
            Button(installTitle) { startInstall() }.buttonStyle(DSButtonStyle(.primary, size: .large, fullWidth: true)).disabled(disabled)
        }
        if let failure {
            DSNotice(text: failure, symbol: "exclamationmark.triangle.fill", tone: .danger)
            Button("Try Again") { startInstall() }.buttonStyle(DSButtonStyle(.secondary, fullWidth: true))
        }
        Text(footer).font(DS.Font.caption).foregroundColor(DS.Palette.textSecondary).fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var install: some View {
        let free = (try? LRRuntimeBridge.managedStorageURL().resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage) ?? 0
        let manifest = try? DebianManifest.load()
        let steamManifest = try? SteamOSManifest.load()
        let alpineBytes = Int64((try? Bundle.main.url(forResource: "root", withExtension: "tar.gz")?.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        let download = distribution == "debian" ? (manifest?.downloadBytes ?? 0) : distribution == "fedora" ? FedoraImage.bytes : distribution == "kali" ? KaliImage.bytes : 0
        let installed = distribution == "debian" ? (manifest?.installedBytes ?? 0) : alpineBytes * 3
        HStack(spacing: DS.Space.md) {
            DistroBadge(distributionID: distribution, size: 48)
            DSScreenHeading(title: "Install \(selectedDistributionName)", message: "Check the space it needs, then install.")
        }
        VStack(spacing: DS.Space.sm) {
            DSKeyValueRow(key: "Download", value: distribution == "steamos" ? (steamManifest.flatMap { SteamOSInstaller.downloadedImage($0) } != nil ? "Already downloaded" : ByteCountFormatter.string(fromByteCount: steamManifest?.source?.bytes ?? 0, countStyle: .file) + " from Valve") : distribution == "arch" ? "Calculated from the signed package selection" : ["debian", "fedora", "kali"].contains(distribution) ? ByteCountFormatter.string(fromByteCount: download, countStyle: .file) : "None (included in the app)")
            Divider().overlay(DS.Palette.border)
            DSKeyValueRow(key: distribution == "debian" || distribution == "steamos" ? "Installed size" : "Installed size (estimate)", value: distribution == "steamos" ? ByteCountFormatter.string(fromByteCount: steamManifest?.installedBytes ?? 0, countStyle: .file) : distribution == "arch" ? "At least 1.5 GB free for base installation" : distribution == "fedora" ? "At least 2 GB free for base installation" : distribution == "kali" ? "About 0.9 GB base; desktop about 2 GB more; standard tools about 6 GB more" : ByteCountFormatter.string(fromByteCount: installed, countStyle: .file))
            Divider().overlay(DS.Palette.border)
            DSKeyValueRow(key: "Available", value: ByteCountFormatter.string(fromByteCount: free, countStyle: .file))
        }
        .dsCard()
        if distribution == "debian" {
            installerControls(running: debian.running, message: debian.message, fraction: debian.fraction, cancel: { debian.cancel() }, installTitle: "Install Debian",
                              disabled: free < max(Int64(1 << 30), download + installed), failure: debian.failure,
                              footer: "Official Debian packages, checked against Debian's signed index. The desktop, sound and account tools are added in the next steps.")
        } else if distribution == "arch" {
            installerControls(running: arch.running, message: arch.message, fraction: arch.fraction, cancel: { arch.cancel() }, installTitle: "Install Arch Linux ARM",
                              disabled: free < Int64(1_500_000_000), failure: arch.failure,
                              footer: "Official signed Arch Linux ARM packages. Verified downloads are kept for retry. First-start configuration finishes before desktop packages are installed.")
        } else if distribution == "fedora" {
            installerControls(running: fedora.running, message: fedora.message, fraction: fedora.fraction, cancel: { fedora.cancel() }, installTitle: "Install Fedora Linux",
                              disabled: free < Int64(2_000_000_000), failure: fedora.failure,
                              footer: "Authenticates Fedora's official AArch64 WSL userspace image; runs it with LinuxRunner, without WSL, a Linux kernel or systemd. The lightweight GTK/X11 desktop and experimental KDE Plasma are available. Fedora sound is not yet qualified.")
        } else if distribution == "kali" {
            installerControls(running: kali.running, message: kali.message, fraction: kali.fraction, cancel: { kali.cancel() }, installTitle: "Install Kali Linux",
                              disabled: free < Int64(2_000_000_000), failure: kali.failure,
                              footer: "Kali's official ARM64 root filesystem (\(KaliImage.version)), checked against its published SHA-256; packages come from Kali's signed archive. The image's preset root and kali passwords are locked at first start; you create your own account next. Runs with LinuxRunner, without a Linux kernel or systemd.")
        } else if distribution == "steamos" {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                Text(steamos.message).font(DS.Font.detail).foregroundColor(DS.Palette.textPrimary).fixedSize(horizontal: false, vertical: true)
                if steamos.running { ProgressView(value: steamos.fraction).tint(DS.Palette.accent) }
            }
            .dsCard()
            if steamos.running {
                Button("Cancel Installation", role: .destructive) { steamos.cancel() }.buttonStyle(DSButtonStyle(.destructive, fullWidth: true))
            } else {
                let required = steamManifest?.directRequiredFreeBytes(imagePresent: steamManifest.flatMap { SteamOSInstaller.downloadedImage($0) } != nil) ?? .max
                Button(steamos.failure == nil ? "Install SteamOS" : "Try Again") { installSteamOSFromValve() }
                    .buttonStyle(DSButtonStyle(.primary, size: .large, fullWidth: true))
                    .disabled(steamManifest?.supportsDirectInstall != true || free < required)
                if free < required, required != .max {
                    DSNotice(text: "Needs " + ByteCountFormatter.string(fromByteCount: required, countStyle: .file) + " free while installing; about " + ByteCountFormatter.string(fromByteCount: steamManifest?.streamInstalledBytes ?? 0, countStyle: .file) + " stays in use afterwards.", symbol: "internaldrive", tone: .warning)
                }
                if FileManager.default.fileExists(atPath: SteamOSInstaller.preparedArchiveURL.path) {
                    Button("Install Prepared SteamOS Archive") { installSteamOS(from: SteamOSInstaller.preparedArchiveURL) }
                        .buttonStyle(DSButtonStyle(.secondary, fullWidth: true))
                        .disabled(steamManifest == nil || free < (steamManifest?.requiredFreeBytes ?? Int64.max))
                }
            }
            if let failure = steamos.failure { DSNotice(text: failure, symbol: "exclamationmark.triangle.fill", tone: .danger) }
            if steamManifest == nil { DSNotice(text: "This build has no supported SteamOS manifest.", symbol: "info.circle.fill", tone: .neutral) }
            Text("Downloads Valve's SteamFrame recovery image from Valve's server, checks its published SHA-256, and installs its ARM64 system with a terminal and the Plasma X11 desktop. Two display packages (x11vnc, libvncserver) come from Arch Linux ARM with pinned checksums. The download is removed after installation. Keep LinuxRunner open while it installs.")
                .font(DS.Font.caption).foregroundColor(DS.Palette.textSecondary).fixedSize(horizontal: false, vertical: true)
        } else if distribution == "alpine" {
            if manager.busy {
                HStack(spacing: DS.Space.sm) { ProgressView(); Text("Unpacking Alpine Linux…").font(DS.Font.detail).foregroundColor(DS.Palette.textSecondary); Spacer(minLength: 0) }.dsCard()
            } else {
                Button("Install Alpine") { startInstall() }.buttonStyle(DSButtonStyle(.primary, size: .large, fullWidth: true))
            }
            if let error = manager.error { DSNotice(text: error, symbol: "exclamationmark.triangle.fill", tone: .danger) }
        }
    }

    @ViewBuilder private var account: some View {
        if !LRRuntimeBridge.isRunning() || (!setupRoot.isEmpty && LRRuntimeBridge.activeRootName() != setupRoot) {
            DSScreenHeading(title: "Your account")
            DSNotice(text: "Close LinuxRunner completely and open it again to continue.", symbol: "arrow.clockwise", tone: .info)
        } else {
            let existing = LRRuntimeBridge.linuxAccounts().filter { $0["name"] != "root" && ($0["uid"].flatMap(Int.init) ?? 0) >= 1000 }
            DSScreenHeading(title: "Your account", message: "The Linux user you work as in the terminal and on the desktop.")
            if !existing.isEmpty {
                VStack(alignment: .leading, spacing: DS.Space.sm) {
                    Text("Use an existing account").font(DS.Font.cardTitle).foregroundColor(DS.Palette.textPrimary)
                    ForEach(existing, id: \.self) { account in
                        Button { useAccount(account["name"] ?? "") } label: {
                            HStack(spacing: DS.Space.sm) {
                                DSIconTile(symbol: "person", size: 32)
                                Text(account["name"] ?? "").font(DS.Font.mono).foregroundColor(DS.Palette.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundColor(DS.Palette.textTertiary)
                            }
                            .dsCard(padding: DS.Space.sm)
                        }
                        .buttonStyle(DSPressableStyle()).disabled(working != nil)
                        .accessibilityLabel(account["name"] ?? "")
                    }
                }
            }
            VStack(alignment: .leading, spacing: DS.Space.md) {
                if !existing.isEmpty { Text("Or create a new account").font(DS.Font.cardTitle).foregroundColor(DS.Palette.textPrimary) }
                DSTextField(title: "Username", text: $username, prompt: "e.g. alex", contentType: .username)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                DSTextField(title: "Password", text: $password, prompt: "Choose a password", secure: true, contentType: .newPassword)
                DSTextField(title: "Confirm password", text: $confirmation, prompt: "Type it again", secure: true, contentType: .newPassword)
                if !confirmation.isEmpty && password != confirmation {
                    Label("The passwords do not match.", systemImage: "exclamationmark.circle.fill").font(DS.Font.caption).foregroundColor(DS.Palette.warning)
                }
                Toggle(isOn: $administrator) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Administrator").font(DS.Font.label).foregroundColor(DS.Palette.textPrimary)
                        Text("Can use sudo to install packages").font(DS.Font.caption).foregroundColor(DS.Palette.textSecondary)
                    }
                }
                .accessibilityLabel("Administrator (can use sudo)")
            }
            .dsCard()
            Button("Create Account") { createAccount() }
                .buttonStyle(DSButtonStyle(.primary, size: .large, fullWidth: true))
                .disabled(working != nil || username.isEmpty || password.isEmpty || password != confirmation)
            Text("Lowercase letters, digits, - and _. LinuxRunner stores only Linux's own password hash, never the password.")
                .font(DS.Font.caption).foregroundColor(DS.Palette.textSecondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var desktop: some View {
        if LRRuntimeBridge.activeEnvironmentIsSteamOS() {
            DSScreenHeading(title: "SteamOS Plasma X11", message: "SteamOS includes the Plasma desktop; LinuxRunner adds its display bridge. This experiment uses software rendering.")
            if desktopReady {
                Label("Desktop components checked", systemImage: "checkmark.circle.fill").font(DS.Font.label).foregroundColor(DS.Palette.success)
                Button("Continue") { stepRaw = SetupStep.done.rawValue }.buttonStyle(DSButtonStyle(.primary, size: .large, fullWidth: true))
            } else {
                Button("Check SteamOS Desktop") { prepareDesktop() }.buttonStyle(DSButtonStyle(.primary, size: .large, fullWidth: true)).disabled(working != nil)
            }
        } else {
            let distro = DesktopCatalog.activeDistribution()
            DSScreenHeading(title: "Choose a desktop", message: "Installed from \(DesktopCatalog.distributionName(distro))'s own packages (network needed). You can add or switch desktops later in Settings.")
            VStack(spacing: DS.Space.sm) {
                ForEach(DesktopCatalog.options) { option in desktopChoiceRow(option, distro: distro) }
            }
            .onAppear { if distro == "kali" && chosenDesktop == "linuxrunner" { chosenDesktop = "xfce" } }
            let chosen = DesktopCatalog.option(chosenDesktop)
            if working == nil {
                if desktopReady && DesktopCatalog.isInstalled(chosen.id) {
                    Label("\(chosen.title) is installed and selected", systemImage: "checkmark.circle.fill").font(DS.Font.label).foregroundColor(DS.Palette.success)
                    Button("Continue") { stepRaw = SetupStep.done.rawValue }.buttonStyle(DSButtonStyle(.primary, size: .large, fullWidth: true))
                } else {
                    Button(DesktopCatalog.isInstalled(chosen.id) && desktopReady ? "Use \(chosen.title)" : "Install \(chosen.title)") { installChosenDesktop() }
                        .buttonStyle(DSButtonStyle(.primary, size: .large, fullWidth: true))
                        .disabled(DesktopCatalog.unavailableReason(chosen.id, distro) != nil)
                    if problem != nil {
                        Button("Retry") { installChosenDesktop() }.buttonStyle(DSButtonStyle(.secondary, fullWidth: true))
                        Text("The package log is kept; Settings › Repair Center can check and repair the package database without deleting your files.").font(DS.Font.caption).foregroundColor(DS.Palette.textSecondary)
                    }
                }
            }
            if distro == "kali" && desktopReady {
                VStack(alignment: .leading, spacing: DS.Space.sm) {
                    HStack(spacing: DS.Space.sm) {
                        DSIconTile(symbol: "shield.lefthalf.filled", tone: .accent, size: 32)
                        Text("Kali tools (optional)").font(DS.Font.cardTitle).foregroundColor(DS.Palette.textPrimary)
                    }
                    Text("Kali's standard tool selection (kali-linux-default) from Kali's signed archive: about 1.5 GB to download and 6 GB installed. Tools that need kernel access, such as monitor-mode Wi-Fi, raw packet capture or kernel modules, install but cannot use those features on iOS.")
                        .font(DS.Font.caption).foregroundColor(DS.Palette.textSecondary).fixedSize(horizontal: false, vertical: true)
                    if LRRuntimeBridge.kaliToolsInstalled() || extraDesktops.contains("kali-tools") {
                        Label("Kali standard tools installed", systemImage: "checkmark.circle.fill").font(DS.Font.label).foregroundColor(DS.Palette.success)
                    } else {
                        Button("Install Kali Standard Tools") {
                            problem = nil; working = "Kali tools: starting"
                            LRRuntimeBridge.installKaliTools({ working = "Kali tools: \($0)" }) { error in
                                working = nil
                                if let error { problem = error.localizedDescription } else { extraDesktops.insert("kali-tools") }
                            }
                        }
                        .buttonStyle(DSButtonStyle(.secondary, fullWidth: true)).disabled(working != nil)
                    }
                }
                .dsCard()
            }
        }
    }

    @ViewBuilder private func desktopChoiceRow(_ option: DesktopOption, distro: String) -> some View {
        let reason = DesktopCatalog.unavailableReason(option.id, distro)
        let selected = chosenDesktop == option.id && reason == nil
        Button { if reason == nil { chosenDesktop = option.id; problem = nil } } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: DS.Space.xs) {
                    Text(option.title).font(DS.Font.cardTitle).foregroundColor(reason == nil ? DS.Palette.textPrimary : DS.Palette.textSecondary)
                    if DesktopCatalog.isInstalled(option.id) && desktopReady { DSBadge(text: "Installed", tone: .success) }
                }
                if !option.badges(distro).isEmpty {
                    HStack(spacing: 6) {
                        ForEach(option.badges(distro), id: \.self) { badge in
                            DSBadge(text: badge, tone: badge == "Recommended" ? .accent : badge == "Experimental" ? .warning : .neutral)
                        }
                    }
                }
                Text(option.detail).font(DS.Font.caption).foregroundColor(DS.Palette.textSecondary).fixedSize(horizontal: false, vertical: true)
                if let reason { Label(reason, systemImage: "info.circle").font(DS.Font.caption).foregroundColor(DS.Palette.warning).fixedSize(horizontal: false, vertical: true) }
            }
            .padding(.trailing, 28)
            .dsSelectable(selected, enabled: reason == nil)
        }
        .buttonStyle(DSPressableStyle())
        .disabled(working != nil || reason != nil)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint(reason ?? "Selects this desktop")
    }

    private func resume() {
        if step == .relaunch, LRRuntimeBridge.isRunning(), LRRuntimeBridge.activeRootName() == setupRoot { stepRaw = SetupStep.account.rawValue }
    }

    private func configureExisting(_ environment: LinuxEnvironment) {
        problem = nil; desktopReady = false
        setupRoot = environment.rootfsName
        distribution = environment.distributionID ?? "alpine"
        LRRuntimeBridge.setNextRootName(environment.rootfsName)
        stepRaw = manager.active(environment) ? SetupStep.account.rawValue : SetupStep.relaunch.rawValue
    }

    private func startInstall() {
        guard !debian.running, !arch.running, !fedora.running, !kali.running, !steamos.running, !manager.busy else { return }
        problem = nil
        let known = Set(manager.environments.map(\.rootfsName))
        let finish: (String) -> Void = { root in
            setupRoot = root; LRRuntimeBridge.setNextRootName(root)
            stepRaw = (LRRuntimeBridge.isRunning() && LRRuntimeBridge.activeRootName() == root) ? SetupStep.account.rawValue : SetupStep.relaunch.rawValue
        }
        if distribution == "debian" {
            debian.install { environment in manager.acceptInstalled(environment); finish(environment.rootfsName) }
        } else if distribution == "arch" {
            arch.install { environment in manager.acceptInstalled(environment); finish(environment.rootfsName) }
        } else if distribution == "fedora" {
            fedora.install { environment in manager.acceptInstalled(environment); finish(environment.rootfsName) }
        } else if distribution == "kali" {
            kali.install { environment in manager.acceptInstalled(environment); finish(environment.rootfsName) }
        } else if distribution == "alpine" {
            manager.error = nil; manager.create(name: "Alpine Linux")
            Task { @MainActor in
                while manager.busy { try? await Task.sleep(nanoseconds: 300_000_000) }
                if let created = manager.environments.first(where: { !known.contains($0.rootfsName) }) { finish(created.rootfsName) }
            }
        } else { problem = "Choose a supported Linux distribution before installing." }
    }

    private func installSteamOSFromValve() {
        guard !debian.running, !arch.running, !fedora.running, !kali.running, !steamos.running, !manager.busy else { return }
        problem = nil
        steamos.installFromValve { environment in
            manager.acceptInstalled(environment)
            setupRoot = environment.rootfsName
            LRRuntimeBridge.setNextRootName(environment.rootfsName)
            stepRaw = SetupStep.relaunch.rawValue
        }
    }

    private func installSteamOS(from source: URL) {
        guard !debian.running, !arch.running, !fedora.running, !kali.running, !steamos.running, !manager.busy else { return }
        problem = nil
        steamos.install(source: source) { environment in
            manager.acceptInstalled(environment)
            setupRoot = environment.rootfsName
            LRRuntimeBridge.setNextRootName(environment.rootfsName)
            stepRaw = SetupStep.relaunch.rawValue
        }
    }

    private func createAccount() {
        problem = nil; working = "Preparing"
        LRRuntimeBridge.createLinuxUser(username, password: password, administrator: administrator, progress: { working = $0 }) { error in
            working = nil
            if let error { problem = error.localizedDescription; return }
            password = ""; confirmation = ""
            useAccount(username)
        }
    }

    private func useAccount(_ name: String) {
        do { try LRRuntimeBridge.setDefaultLinuxUser(name); problem = nil; stepRaw = SetupStep.desktop.rawValue }
        catch { problem = error.localizedDescription }
    }

    // Base components first (every desktop session uses them), then the chosen
    // desktop. Stages are numbered so progress is meaningful; failures keep the
    // log and leave the previous desktop selected.
    private func installChosenDesktop() {
        let option = DesktopCatalog.option(chosenDesktop)
        guard DesktopCatalog.unavailableReason(option.id, DesktopCatalog.activeDistribution()) == nil else { return }
        let needsExtra = option.id != "linuxrunner" && !DesktopCatalog.isInstalled(option.id)
        let total = needsExtra ? 2 : 1
        problem = nil; working = "Step 1 of \(total) · Desktop components: starting"
        LRRuntimeBridge.prepareDesktopProfile({ working = "Step 1 of \(total) · Desktop components: \($0)" }) { error in
            if let error { working = nil; problem = error.localizedDescription; return }
            desktopReady = true
            guard needsExtra, let install = DesktopCatalog.installer(option.id) else { selectDesktop(option.id); return }
            working = "Step 2 of 2 · \(option.title): starting"
            install({ working = "Step 2 of 2 · \(option.title): \($0)" }) { error in
                if let error { working = nil; problem = error.localizedDescription; return }
                selectDesktop(option.id)
            }
        }
    }

    // SteamOS: the image already contains Plasma; this only runs its
    // offline profile check (steamos-profile.sh) and selects Plasma.
    private func prepareDesktop() {
        problem = nil; working = "Checking the SteamOS desktop"
        LRRuntimeBridge.prepareDesktopProfile({ working = $0 }) { error in
            working = nil
            if let error { problem = error.localizedDescription } else { desktopReady = true; selectDesktop("plasma") }
        }
    }

    private func selectDesktop(_ id: String) {
        working = nil
        // Same per-environment choice as Settings › Desktop Environment.
        UserDefaults.standard.set(id, forKey: "LinuxRunnerDesktop.environment." + LRRuntimeBridge.activeRootName())
        extraDesktops.insert(id)
    }
}

struct DesktopOption: Identifiable {
    let id: String
    let title: String
    let detail: String
    let experimental: Bool
    let lightweight: Bool
    func badges(_ distro: String) -> [String] {
        var b: [String] = []
        if id == "linuxrunner" { b.append("Recommended") }
        if lightweight { b.append("Lightweight") }
        if experimental { b.append("Experimental") }
        return b
    }
}

// What each distribution can actually install and start, matching
// desktop-profile.sh. Unavailable options say why instead of disappearing.
enum DesktopCatalog {
    static let options: [DesktopOption] = [
        DesktopOption(id: "linuxrunner", title: "LinuxRunner Desktop", detail: "Openbox with a panel and file manager. Fastest start and lowest memory use; best for first-time Linux users.", experimental: false, lightweight: true),
        DesktopOption(id: "xfce", title: "Xfce", detail: "On Kali: Kali's own desktop (kali-desktop-xfce) with the Kali menu, themes and wallpaper.", experimental: false, lightweight: false),
        DesktopOption(id: "lxqt", title: "LXQt", detail: "A light, traditional Qt desktop with a start menu, panel and file manager.", experimental: false, lightweight: true),
        DesktopOption(id: "wayfire", title: "Wayfire", detail: "A Wayland compositor with a panel and dock, running in the X display.", experimental: false, lightweight: false),
        DesktopOption(id: "enlightenment", title: "Enlightenment", detail: "A distinctive desktop with its own compositor; large download.", experimental: false, lightweight: false),
        DesktopOption(id: "plasma", title: "KDE Plasma", detail: "The full KDE desktop. Heaviest option: slowest start and highest memory use.", experimental: true, lightweight: false),
        DesktopOption(id: "hyprland", title: "Hyprland", detail: "A tiling Wayland compositor with Waybar, for keyboard-driven use.", experimental: true, lightweight: false),
    ]
    static func option(_ id: String) -> DesktopOption { options.first { $0.id == id } ?? options[0] }
    static func activeDistribution() -> String {
        if LRRuntimeBridge.activeEnvironmentIsKali() { return "kali" }
        if LRRuntimeBridge.activeEnvironmentIsDebian() { return "debian" }
        if LRRuntimeBridge.activeEnvironmentIsArch() { return "arch" }
        if LRRuntimeBridge.activeEnvironmentIsFedora() { return "fedora" }
        return "alpine"
    }
    static func distributionName(_ d: String) -> String {
        switch d { case "debian": return "Debian"; case "arch": return "Arch Linux ARM"; case "fedora": return "Fedora"; case "kali": return "Kali Linux"; default: return "Alpine Linux" }
    }
    static func unavailableReason(_ id: String, _ d: String) -> String? {
        switch (id, d) {
        case ("linuxrunner", _): return nil
        case ("xfce", "kali"): return nil
        case ("xfce", _): return "Offered on Kali Linux, where it is Kali's own desktop; not yet tested on this distribution."
        case (_, "kali") where id != "linuxrunner": return "Kali's desktop is Xfce; other desktops are not yet tested on Kali."
        case ("lxqt", "fedora"): return "Not yet tested with Fedora in LinuxRunner, so it is not offered yet."
        case ("lxqt", _): return nil
        case ("enlightenment", "debian"): return "Debian's Enlightenment session stops at its splash screen in LinuxRunner."
        case ("enlightenment", "fedora"): return "Not yet tested with Fedora in LinuxRunner, so it is not offered yet."
        case ("enlightenment", _): return nil
        case ("wayfire", "alpine"): return "Alpine's packages lack what LinuxRunner's Wayfire session needs."
        case ("wayfire", _): return nil
        case ("plasma", "alpine"): return "LinuxRunner's Plasma session supports Debian, Arch Linux ARM and Fedora only."
        case ("plasma", _): return nil
        case ("hyprland", "arch"): return nil
        case ("hyprland", "debian"): return "Debian 13 does not package Hyprland; it needs Arch Linux ARM."
        case ("hyprland", _): return "Needs Arch Linux ARM, which packages Hyprland for this setup."
        default: return "Not available."
        }
    }
    static func isInstalled(_ id: String) -> Bool {
        switch id {
        case "xfce": return LRRuntimeBridge.xfceInstalled()
        case "lxqt": return LRRuntimeBridge.lxqtInstalled()
        case "enlightenment": return LRRuntimeBridge.enlightenmentInstalled()
        case "wayfire": return LRRuntimeBridge.wayfireInstalled()
        case "plasma": return LRRuntimeBridge.plasmaInstalled()
        case "hyprland": return LRRuntimeBridge.hyprlandInstalled()
        default: return true // part of the desktop components
        }
    }
    static func installer(_ id: String) -> ((@escaping (String) -> Void, @escaping (Error?) -> Void) -> Void)? {
        switch id {
        case "xfce": return { LRRuntimeBridge.installXfce($0, completion: $1) }
        case "lxqt": return { LRRuntimeBridge.installLXQt($0, completion: $1) }
        case "enlightenment": return { LRRuntimeBridge.installEnlightenment($0, completion: $1) }
        case "wayfire": return { LRRuntimeBridge.installWayfire($0, completion: $1) }
        case "plasma": return { LRRuntimeBridge.installPlasma($0, completion: $1) }
        case "hyprland": return { LRRuntimeBridge.installHyprland($0, completion: $1) }
        default: return nil
        }
    }
}
