import SwiftUI
import AppKit

// MARK: - Confetti Particle Model

struct ConfettiParticle: Identifiable {
    let id = UUID()
    var x: Double
    var y: Double
    var color: Color
    var size: Double
    var speed: Double
    var angle: Double
}

// MARK: - Confetti View

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    let timer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { p in
                    Rectangle()
                        .fill(p.color)
                        .frame(width: p.size, height: p.size / 2)
                        .rotationEffect(.degrees(p.angle))
                        .position(x: p.x, y: p.y)
                }
            }
            .onAppear {
                let colors: [Color] = [.red, .blue, .green, .yellow, .pink, .purple, .orange, .cyan]
                for _ in 0..<85 {
                    particles.append(ConfettiParticle(
                        x: Double.random(in: 0...Double(geo.size.width)),
                        y: Double.random(in: -80...Double(geo.size.height) * 0.4),
                        color: colors.randomElement()!,
                        size: Double.random(in: 7...14),
                        speed: Double.random(in: 4...8),
                        angle: Double.random(in: 0...360)
                    ))
                }
            }
            .onReceive(timer) { _ in
                for i in 0..<particles.count {
                    particles[i].y += particles[i].speed
                    particles[i].angle += particles[i].speed * 2
                    if particles[i].y > Double(geo.size.height) {
                        particles[i].y = -20
                        particles[i].x = Double.random(in: 0...Double(geo.size.width))
                    }
                }
            }
        }
    }
}

// MARK: - Visual Effect View (System Vibrancy)

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    var themeMode: ThemeMode? = nil
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        
        if let mode = themeMode {
            DispatchQueue.main.async {
                guard let window = nsView.window else { return }
                switch mode {
                case .light:
                    if window.appearance?.name != .aqua {
                        window.appearance = NSAppearance(named: .aqua)
                    }
                case .dark:
                    if window.appearance?.name != .darkAqua {
                        window.appearance = NSAppearance(named: .darkAqua)
                    }
                case .system:
                    window.appearance = nil
                }
            }
        }
    }
}

// MARK: - Onboarding Window Policy

struct OnboardingWindowPolicy {
    static let contentSize = CGSize(width: 540, height: 410)
    static let cornerRadius: CGFloat = 28
    static let totalPages = 4
}

// MARK: - Onboarding Exit Coordinator

struct OnboardingExitCoordinator {
    private(set) var hasExited: Bool = false
    
    mutating func requestExit(action: () -> Void) -> Bool {
        guard !hasExited else { return false }
        hasExited = true
        action()
        return true
    }
}

// MARK: - Superpower Showcase Tabs

enum ShowcaseTab: Int, CaseIterable, Identifiable {
    case code = 0
    case markdown = 1
    case archive = 2
    case relay = 3
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .code: return "Code & Config".localized()
        case .markdown: return "Markdown Docs".localized()
        case .archive: return "Archive & Folders".localized()
        case .relay: return "App Relay".localized()
        }
    }
    
    var icon: String {
        switch self {
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .markdown: return "text.badge.checkmark"
        case .archive: return "archivebox.fill"
        case .relay: return "arrow.up.forward.app.fill"
        }
    }
    
    var description: String {
        switch self {
        case .code:
            return "Syntax highlighting for 60+ languages with line numbers & streaming highlight.".localized()
        case .markdown:
            return "GitHub-style typography with rounded tables, transparent background & local images.".localized()
        case .archive:
            return "0-extract structure inspection, format size bar & collapsible directory tree.".localized()
        case .relay:
            return "One-click handoff to VS Code, Cursor, Xcode or your favorite editors.".localized()
        }
    }
}

// MARK: - Singline Theme Constants

private let brandIndigo = Color(red: 0.38, green: 0.36, blue: 0.88)

// MARK: - Tactile Keycap Component

struct PlaygroundKbdKeyView: View {
    let symbol: String
    let isHighlighted: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Text(symbol)
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundColor(isHighlighted ? .white : Color.appText)
            .frame(width: 38, height: 34)
            .background(
                ZStack {
                    if isHighlighted {
                        LinearGradient(
                            colors: [brandIndigo, brandIndigo.opacity(0.85)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    } else {
                        LinearGradient(
                            gradient: Gradient(colors: colorScheme == .dark ? [
                                Color(red: 0.25, green: 0.25, blue: 0.29),
                                Color(red: 0.17, green: 0.17, blue: 0.20)
                            ] : [
                                Color.white,
                                Color(red: 0.93, green: 0.93, blue: 0.95)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                }
            )
            .cornerRadius(7)
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(
                        isHighlighted ? Color.white.opacity(0.6) : Color.appBorder.opacity(colorScheme == .dark ? 0.35 : 0.8),
                        lineWidth: 0.8
                    )
            )
            .shadow(
                color: isHighlighted ? brandIndigo.opacity(0.65) : Color.black.opacity(colorScheme == .dark ? 0.35 : 0.10),
                radius: isHighlighted ? 4 : 1.5,
                x: 0,
                y: isHighlighted ? 1 : 1.5
            )
    }
}

// MARK: - Hotkey Option Card Component (Singline Style)

struct HotkeyOptionCard: View {
    let title: String
    let subtitle: String
    let keys: [String]
    let isSelected: Bool
    let isPulsing: Bool
    let action: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Keycaps Icon Area
                HStack(spacing: 4) {
                    ForEach(keys, id: \.self) { k in
                        PlaygroundKbdKeyView(symbol: k, isHighlighted: isPulsing || isSelected)
                    }
                }
                .frame(height: 42)
                .scaleEffect(isPulsing ? 1.08 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.5), value: isPulsing)
                
                // Title
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                    .foregroundColor(Color.appText)
                
                // Subtitle Badge
                Text(subtitle)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(isSelected ? (colorScheme == .dark ? Color(red: 0.78, green: 0.76, blue: 1.0) : brandIndigo) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(colorScheme == .dark ? brandIndigo.opacity(0.18) : Color(red: 0.94, green: 0.95, blue: 1.0))
                    } else {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(colorScheme == .dark ? Color(white: 0.16).opacity(0.6) : Color.white.opacity(0.7))
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected ? brandIndigo : Color.white.opacity(colorScheme == .dark ? 0.12 : 0.6),
                        lineWidth: isSelected ? 2 : 0.8
                    )
            )
            .shadow(
                color: isSelected ? brandIndigo.opacity(0.2) : Color.black.opacity(colorScheme == .dark ? 0.2 : 0.04),
                radius: isSelected ? 6 : 3,
                x: 0,
                y: isSelected ? 2 : 1.5
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Modern Onboarding Main View

struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var isFullDiskAccessAuthorized = {
        let path = NSHomeDirectory() + "/Library/Safari/Bookmarks.plist"
        return FileManager.default.isReadableFile(atPath: path)
    }()
    @State private var isCheckingFDA = false
    @State private var isFinderExtensionAttempted = false
    @State private var showConfetti = false
    @State private var isStartingApp = false
    
    // Window fade-out animation properties
    @State private var windowOpacity: Double = 1.0
    @State private var windowScale: CGFloat = 1.0
    
    // Step 2 Hotkey Playground state
    @State private var didTriggerPulse = false
    @State private var lastModifierPressTime: Date? = nil
    @State private var lastModifierState: Bool = false
    @State private var playgroundMonitor: Any? = nil
    
    // Step 3 Showcase selected tab
    @State private var selectedShowcaseTab: ShowcaseTab = .code
    
    // Timer to poll permissions while window is visible
    let authTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    @ObservedObject private var settings = Settings.shared
    @Environment(\.colorScheme) private var colorScheme
    
    var onFinished: () -> Void = {}
    
    @State private var isClosing = false
    
    init(initialPage: Int = 0, onFinished: @escaping () -> Void = {}) {
        self._currentPage = State(initialValue: initialPage)
        self.onFinished = onFinished
    }
    
    var body: some View {
        ZStack {
            // Base Layer: Native System Vibrancy Frosted Glass
            VisualEffectView(material: .popover, blendingMode: .behindWindow, themeMode: settings.themeMode)
                .edgesIgnoringSafeArea(.all)
            
            // Middle Layer: Soft Pastel Aurora Gradient Tint (Singline Style)
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.94, green: 0.84, blue: 0.98).opacity(colorScheme == .dark ? 0.16 : 0.45),
                    Color(red: 0.82, green: 0.90, blue: 0.98).opacity(colorScheme == .dark ? 0.14 : 0.35),
                    Color.clear
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)
            
            // Soft Light Wash
            Color.white.opacity(colorScheme == .dark ? 0.03 : 0.25)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Top Mini Bar (Skip Guide Button if not on page 0)
                HStack {
                    Spacer()
                    if currentPage > 0 {
                        Button(action: {
                            handleFinishAction(withConfetti: false)
                        }) {
                            Text("Skip Guide".localized())
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(colorScheme == .dark ? 0.2 : 0.05))
                                .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 16)
                    }
                }
                .frame(height: 28)
                .padding(.top, 4)
                
                // Page Carousel
                ZStack {
                    switch currentPage {
                    case 0:
                        welcomeStepView
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity.combined(with: .move(edge: .leading))
                            ))
                    case 1:
                        hotkeySelectorStepView
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity.combined(with: .move(edge: .leading))
                            ))
                    case 2:
                        showcaseStepView
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity.combined(with: .move(edge: .leading))
                            ))
                    case 3:
                        readyStepView
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity.combined(with: .move(edge: .leading))
                            ))
                    default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 28)
                
                // Bottom Universal Navigation Bar (Visible on pages 1, 2, 3)
                if currentPage > 0 {
                    bottomNavigationBar
                }
            }
            
            if showConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
            }
        }
        .frame(width: OnboardingWindowPolicy.contentSize.width, height: OnboardingWindowPolicy.contentSize.height)
        .cornerRadius(OnboardingWindowPolicy.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: OnboardingWindowPolicy.cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.16 : 0.6), lineWidth: 0.8)
        )
        .opacity(windowOpacity)
        .scaleEffect(windowScale)
        .id(settings.language)
        .onAppear {
            isFinderExtensionAttempted = UserDefaults.standard.bool(forKey: "isFinderExtensionAttempted")
            checkPermissionState()
            setupPlaygroundKeyMonitor()
        }
        .onDisappear {
            teardownPlaygroundKeyMonitor()
        }
        .onReceive(authTimer) { _ in
            guard !isClosing else { return }
            checkPermissionState()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            guard !isClosing else { return }
            checkPermissionState()
            isCheckingFDA = false
        }
    }
    
    // MARK: - Step 0: Welcome (Singline Image 1 Style)
    
    private var welcomeStepView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            // App Icon on soft rounded card with shadow
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(colorScheme == .dark ? Color(white: 0.22) : Color.white)
                    .frame(width: 76, height: 76)
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.12), radius: 10, x: 0, y: 5)
                
                if let icon = NSImage(named: "AppIcon") {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 64, height: 64)
                        .cornerRadius(14)
                } else {
                    Text("🍪")
                        .font(.system(size: 44))
                }
            }
            .padding(.bottom, 4)
            
            Text("Welcome to QuickCookies".localized())
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(Color.appText)
            
            Text("Instant card preview for your Finder files".localized())
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Spacer()
            
            // Centered Pill Button "Get Started"
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    currentPage = 1
                }
            }) {
                Text("Get Started".localized())
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .black : Color(white: 0.1))
                    .frame(width: 190, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.12), radius: 6, x: 0, y: 2)
                    )
            }
            .buttonStyle(.plain)
            
            Text("Takes about a minute".localized())
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary.opacity(0.85))
                .padding(.top, 2)
            
            Spacer().frame(height: 24)
        }
    }
    
    // MARK: - Step 1: Hotkey Selection (Singline Image 2 Style)
    
    private var hotkeySelectorStepView: some View {
        let isDoubleCmd = settings.hotkeyKeyCode == 0 && settings.hotkeyModifiers.contains(NSEvent.ModifierFlags.command)
        let isDoubleOpt = settings.hotkeyKeyCode == 0 && settings.hotkeyModifiers.contains(NSEvent.ModifierFlags.option)
        
        return VStack(spacing: 12) {
            Spacer().frame(height: 4)
            
            Text("How would you like to open previews?".localized())
                .font(.system(size: 23, weight: .bold, design: .rounded))
                .foregroundColor(Color.appText)
            
            Text("Choose the shortcut to press in Finder.".localized())
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.secondary)
            
            Spacer().frame(height: 6)
            
            // Horizontal Option Cards (Image 2 style)
            HStack(spacing: 12) {
                // Card 1: Double Command
                HotkeyOptionCard(
                    title: "Double Command".localized(),
                    subtitle: "Recommended".localized(),
                    keys: ["⌘", "⌘"],
                    isSelected: isDoubleCmd,
                    isPulsing: didTriggerPulse && isDoubleCmd
                ) {
                    settings.saveHotkey(modifiers: .command, keyCode: 0)
                }
                
                // Card 2: Double Option
                HotkeyOptionCard(
                    title: "Double Option".localized(),
                    subtitle: "Classic".localized(),
                    keys: ["⌥", "⌥"],
                    isSelected: isDoubleOpt,
                    isPulsing: didTriggerPulse && isDoubleOpt
                ) {
                    settings.saveHotkey(modifiers: .option, keyCode: 0)
                }
                
                // Card 3: Instant Search
                HotkeyOptionCard(
                    title: "Instant Search".localized(),
                    subtitle: "Find in file (⌥F)".localized(),
                    keys: ["⌥", "F"],
                    isSelected: false,
                    isPulsing: false
                ) {
                    // Informative preset card
                }
            }
            
            // Footnote description (Image 2 style)
            Text(isDoubleCmd 
                ? "Double Command is recommended for natural macOS interaction.".localized() 
                : "Press twice anywhere in Finder to trigger instant card preview.".localized()
            )
            .font(.system(size: 11, weight: .regular))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .frame(height: 28)
            
            // Interactive keypress feedback
            if didTriggerPulse {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Shortcut detected! Works perfectly.".localized())
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.12))
                .cornerRadius(8)
                .transition(.scale.combined(with: .opacity))
            } else {
                Text("Try pressing twice on your keyboard now:".localized())
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.75))
            }
            
            Spacer()
        }
    }
    
    // MARK: - Step 2: Showcase (Compact Feature Cards)
    
    private var showcaseStepView: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 4)
            
            Text("What QuickCookies previews".localized())
                .font(.system(size: 23, weight: .bold, design: .rounded))
                .foregroundColor(Color.appText)
            
            Text("Instant preview without opening heavy apps.".localized())
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.secondary)
            
            Spacer().frame(height: 6)
            
            // 3 Feature Showcase Cards in HStack
            HStack(spacing: 10) {
                // Card 1: Code & Config
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.blue)
                        Text("Code & Config".localized())
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.appText)
                        Spacer()
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("1  import SwiftUI")
                            .foregroundColor(.purple)
                        Text("2  struct App: View {")
                            .foregroundColor(Color.appText.opacity(0.85))
                        Text("3    var body: some View")
                            .foregroundColor(.blue)
                        Text("4      Text(\"Instant!\")")
                            .foregroundColor(.orange)
                        Text("5    }")
                            .foregroundColor(Color.appText.opacity(0.85))
                    }
                    .font(.system(size: 9.5, design: .monospaced))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(colorScheme == .dark ? 0.35 : 0.05))
                    .cornerRadius(8)
                    
                    Spacer()
                    
                    Text("60+ Languages".localized())
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(.blue)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .frame(height: 168)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(colorScheme == .dark ? Color(white: 0.16).opacity(0.7) : Color.white.opacity(0.8))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.1 : 0.6), lineWidth: 0.8)
                )
                
                // Card 2: Markdown
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "text.badge.checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.green)
                        Text("Markdown Docs".localized())
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.appText)
                        Spacer()
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("# README.md")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color.appText)
                        Text("GitHub-style typography with rounded tables & images.".localized())
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                        HStack(spacing: 4) {
                            Text("Feature".localized()).bold()
                            Spacer()
                            Text("Status".localized()).bold()
                        }
                        .font(.system(size: 8))
                        .padding(4)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(4)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(colorScheme == .dark ? 0.35 : 0.05))
                    .cornerRadius(8)
                    
                    Spacer()
                    
                    Text("GitHub Typography".localized())
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(.green)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .frame(height: 168)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(colorScheme == .dark ? Color(white: 0.16).opacity(0.7) : Color.white.opacity(0.8))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.1 : 0.6), lineWidth: 0.8)
                )
                
                // Card 3: Archives & Folders
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "archivebox.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.orange)
                        Text("Archive & Folders".localized())
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.appText)
                        Spacer()
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Capsule().fill(Color.blue).frame(width: 40, height: 4)
                            Capsule().fill(Color.orange).frame(width: 25, height: 4)
                            Capsule().fill(Color.green).frame(width: 15, height: 4)
                        }
                        Text("📁 src/")
                            .font(.system(size: 9, weight: .semibold))
                        Text("  📄 main.swift (24KB)")
                            .font(.system(size: 8.5))
                            .foregroundColor(.secondary)
                        Text("  📄 package.json")
                            .font(.system(size: 8.5))
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(colorScheme == .dark ? 0.35 : 0.05))
                    .cornerRadius(8)
                    
                    Spacer()
                    
                    Text("Instant Inspection".localized())
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(.orange)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .frame(height: 168)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(colorScheme == .dark ? Color(white: 0.16).opacity(0.7) : Color.white.opacity(0.8))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.1 : 0.6), lineWidth: 0.8)
                )
            }
            
            Text("One-click handoff to VS Code, Cursor, Xcode or your favorite editors.".localized())
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
    }
    
    // MARK: - Step 3: Ready & Personalize (Singline Image 3 Style)
    
    private var readyStepView: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 4)
            
            Text("You're all set".localized())
                .font(.system(size: 23, weight: .bold, design: .rounded))
                .foregroundColor(Color.appText)
            
            Text("QuickCookies is standing by in Finder.".localized())
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.secondary)
            
            Spacer().frame(height: 6)
            
            // Asymmetric Split Cards (Image 3 Style)
            HStack(spacing: 14) {
                // Left Card: Pure Architecture / Zero-Privilege Badge
                VStack(alignment: .leading, spacing: 6) {
                    Text("Privacy & Security".localized())
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Text("Zero".localized())
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundColor(Color.appText)
                    
                    Text("Zero Accessibility privileges required. Safe, private, and lightweight.".localized())
                        .font(.system(size: 10.5, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                        Text("No Special Permissions Required".localized())
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(.green)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 156)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(colorScheme == .dark ? Color(white: 0.16).opacity(0.7) : Color.white.opacity(0.85))
                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.05), radius: 6, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.1 : 0.6), lineWidth: 0.8)
                )
                
                // Right Card: Inset Grouped Settings List
                VStack(spacing: 0) {
                    // Row 1: Start at Login
                    HStack(spacing: 12) {
                        Image(systemName: "power")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.blue)
                            .frame(width: 22)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Open at Login".localized())
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color.appText)
                            Text("Ready when you open your Mac.".localized())
                                .font(.system(size: 10, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $settings.launchAtLogin)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    
                    Divider()
                        .padding(.horizontal, 14)
                    
                    // Row 2: View Settings
                    Button(action: {
                        SettingsWindowController.shared.show()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.purple)
                                .frame(width: 22)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("More Settings...".localized())
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color.appText)
                                Text("Fonts, theme and shortcuts.".localized())
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 156)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(colorScheme == .dark ? Color(white: 0.16).opacity(0.7) : Color.white.opacity(0.85))
                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.05), radius: 6, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.1 : 0.6), lineWidth: 0.8)
                )
            }
            
            Spacer()
        }
    }
    
    // MARK: - Universal Bottom Navigation Bar (Singline Style)
    
    private var bottomNavigationBar: some View {
        HStack {
            // Left: Back Button
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    currentPage = max(0, currentPage - 1)
                }
            }) {
                Text("Back".localized())
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.appText.opacity(0.85))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(colorScheme == .dark ? Color(white: 0.22) : Color.white.opacity(0.9))
                            .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 1)
                    )
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Center: 4-Dot Page Indicator (Singline Image 2 & 3 Style)
            HStack(spacing: 7) {
                ForEach(0..<4) { index in
                    if index == currentPage {
                        Capsule()
                            .fill(brandIndigo)
                            .frame(width: 14, height: 6)
                    } else {
                        Circle()
                            .fill(Color.secondary.opacity(0.35))
                            .frame(width: 6, height: 6)
                    }
                }
            }
            
            Spacer()
            
            // Right: Primary Action Button
            if currentPage == 3 {
                // "Start Using QuickCookies"
                Button(action: {
                    handleFinishAction(withConfetti: true)
                }) {
                    Text(isStartingApp ? "Starting...".localized() : "Start Using QuickCookies".localized())
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(brandIndigo)
                                .shadow(color: brandIndigo.opacity(0.4), radius: 6, x: 0, y: 2)
                        )
                }
                .buttonStyle(.plain)
                .disabled(isStartingApp)
            } else {
                // "Continue" (Image 2 style)
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        currentPage = min(3, currentPage + 1)
                    }
                }) {
                    Text("Continue".localized())
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .white : Color(white: 0.1))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(colorScheme == .dark ? Color(white: 0.25) : Color.white)
                                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 5, x: 0, y: 2)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }
    
    // MARK: - Hotkey Playground Physical Keypress Monitor
    
    private func setupPlaygroundKeyMonitor() {
        guard playgroundMonitor == nil else { return }
        playgroundMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { event in
            guard self.currentPage == 1 else { return event }
            
            let isOpt = self.settings.hotkeyModifiers.contains(NSEvent.ModifierFlags.option)
            let targetFlag: NSEvent.ModifierFlags = isOpt ? .option : .command
            let isPressed = event.modifierFlags.contains(targetFlag)
            
            if isPressed && !self.lastModifierState {
                let now = Date()
                if let lastPress = self.lastModifierPressTime, now.timeIntervalSince(lastPress) < 0.45 {
                    self.triggerPlaygroundPulse()
                    self.lastModifierPressTime = nil
                } else {
                    self.lastModifierPressTime = now
                }
            }
            self.lastModifierState = isPressed
            return event
        }
    }
    
    private func teardownPlaygroundKeyMonitor() {
        if let monitor = playgroundMonitor {
            NSEvent.removeMonitor(monitor)
            playgroundMonitor = nil
        }
    }
    
    private func triggerPlaygroundPulse() {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.45)) {
            didTriggerPulse = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.3)) {
                self.didTriggerPulse = false
            }
        }
    }
    
    // MARK: - Permission & LifeCycle Helpers
    
    private func checkPermissionState() {
        let path = NSHomeDirectory() + "/Library/Safari/Bookmarks.plist"
        let fda = FileManager.default.isReadableFile(atPath: path)
        if fda != isFullDiskAccessAuthorized {
            isFullDiskAccessAuthorized = fda
        }
    }
    
    private func handleFinishAction(withConfetti: Bool = true) {
        guard !isStartingApp else { return }
        isStartingApp = true
        
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        
        if withConfetti {
            showConfetti = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                self.performWindowExit()
            }
        } else {
            performWindowExit()
        }
    }
    
    private func performWindowExit() {
        withAnimation(.easeInOut(duration: 0.18)) {
            windowOpacity = 0.0
            windowScale = 0.96
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            self.showConfetti = false
            self.isClosing = true
            self.teardownPlaygroundKeyMonitor()
            self.onFinished()
        }
    }
}
