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
                        y: Double.random(in: -100...Double(geo.size.height) * 0.5),
                        color: colors.randomElement()!,
                        size: Double.random(in: 8...15),
                        speed: Double.random(in: 4...9),
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

// MARK: - Visual Effect View
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
        
        // 动态应用外观给所属窗口，实现 OnboardingWindow 的主题热切换与自适应
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

// MARK: - Onboarding View
struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var isAccessibilityAuthorized = false
    @State private var isFullDiskAccessAuthorized = false
    @State private var isFinderExtensionAttempted = false
    @State private var isCheckingAccessibility = false
    @State private var isCheckingFDA = false
    @State private var isStartingApp = false
    @State private var showConfetti = false
    @State private var isWelcomeAnimating = false
    @State private var demoAnimStep = 0
    @State private var optionPulse = false
    @State private var windowOpacity: Double = 1.0
    @State private var windowScale: CGFloat = 1.0
    // NOTE: 关闭序列启动后设为 true，所有 Timer 回调检查此标志并立即返回，
    //       防止 orderOut 后 RunLoop 中残留的 Timer 事件继续触发 SwiftUI 状态更新，
    //       与 window.close()/setActivationPolicy 产生主线程 CATransaction 竞争导致死锁
    @State private var isClosing = false
    
    @ObservedObject var settings = Settings.shared
    
    let onFinished: () -> Void
    let authTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    let animationTimer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow, themeMode: settings.themeMode)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Header Title
                Text("Onboarding".localized())
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.appText)
                    .opacity(0.8)
                    .padding(.top, 20)
                
                // Page Area
                ZStack {
                    if currentPage == 0 {
                        welcomePage
                            .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity.combined(with: .move(edge: .leading))))
                    } else if currentPage == 1 {
                        demoPage
                            .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity.combined(with: .move(edge: .leading))))
                    } else if currentPage == 2 {
                        configPage
                            .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity.combined(with: .move(edge: .leading))))
                    } else if currentPage == 3 {
                        permissionPage
                            .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity.combined(with: .move(edge: .leading))))
                    }
                }
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 32)
                
                Rectangle()
                    .fill(Color.appText.opacity(0.08))
                    .frame(height: 1)
                
                // Navigation Bottom Bar
                bottomBar
            }
            
            if showConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
            }
        }
        .opacity(windowOpacity)
        .scaleEffect(windowScale)
        .frame(width: 620, height: 450)
        .onAppear {
            isFinderExtensionAttempted = UserDefaults.standard.bool(forKey: "isFinderExtensionAttempted")
            checkPermissionState()
            withAnimation(.easeOut(duration: 0.8)) {
                isWelcomeAnimating = true
            }
        }
        .onReceive(authTimer) { _ in
            // 关闭序列启动后不再轮询权限，避免与 close/activationPolicy 产生 RunLoop 竞争
            guard !isClosing else { return }
            checkPermissionState()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            guard !isClosing else { return }
            checkPermissionState()
            isCheckingAccessibility = false
            isCheckingFDA = false
        }
        .onReceive(animationTimer) { _ in
            // 关闭序列启动后停止动画更新
            guard !isClosing, currentPage == 1 else { return }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                demoAnimStep = (demoAnimStep + 1) % 4
            }
            withAnimation(.easeInOut(duration: 0.3)) {
                optionPulse = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                optionPulse = false
            }
        }
    }
    
    // MARK: - Page 0: Welcome Page
    private var welcomePage: some View {
        VStack(spacing: 16) {
            Spacer()
            
            // Transparent PNG Brand Logo
            Image("AppIcon_transparent")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 90, height: 90)
                .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
                .scaleEffect(isWelcomeAnimating ? 1.02 : 0.98)
                .offset(y: isWelcomeAnimating ? -6 : 6)
                .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: isWelcomeAnimating)
                .padding(.top, 10)
            
            Text("Quick Cookies")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(Color.appText)
            
            Text("Instant Code & Document Preview".localized())
                .font(.system(size: 14))
                .foregroundColor(Color.appText.opacity(0.6))
                .kerning(1.2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)
            
            Spacer()
        }
    }
    
    // MARK: - Page 1: Demo Page
    private var demoPage: some View {
        HStack(spacing: 24) {
            // Left Content: Text Steps & Key Cap
            VStack(alignment: .leading, spacing: 14) {
                Text("Instant Preview".localized())
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.appText)
                
                VStack(alignment: .leading, spacing: 12) {
                    StepRow(text: "1. Select any code or Markdown file in Finder".localized())
                    
                    HStack(spacing: 6) {
                        StepRow(text: "2. Quickly double-press".localized())
                        
                        // Interactive keycap with pulse animation
                        Text("⌥ Option")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(optionPulse ? .black : Color.appText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(optionPulse ? Color.accentColor : Color.kbdBackground)
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.appBorder, lineWidth: 1)
                            )
                            .scaleEffect(optionPulse ? 1.1 : 1.0)
                    }
                    
                    StepRow(text: "3. The preview window flies out instantly, supporting live edit & save".localized())
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Right Content: Visualized Line-frame Animation
            ZStack {
                // Simulator Background Container (macOS Desktop representation)
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.appBorder, lineWidth: 1)
                    )
                    .frame(width: 240, height: 180)
                
                // Simulated Finder Window
                VStack(spacing: 0) {
                    // Traffic lights & header
                    HStack(spacing: 4) {
                        Circle().fill(Color.red.opacity(0.7)).frame(width: 5, height: 5)
                        Circle().fill(Color.yellow.opacity(0.7)).frame(width: 5, height: 5)
                        Circle().fill(Color.green.opacity(0.7)).frame(width: 5, height: 5)
                        Spacer()
                        RoundedRectangle(cornerRadius: 2).fill(Color.secondary.opacity(0.2)).frame(width: 40, height: 4)
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.toolbarBackground.opacity(0.5))
                    
                    HStack(spacing: 0) {
                        // Sidebar simulator
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(0..<4) { _ in
                                RoundedRectangle(cornerRadius: 1).fill(Color.secondary.opacity(0.2)).frame(width: 25, height: 3)
                            }
                            Spacer()
                        }
                        .padding(8)
                        .frame(width: 45)
                        .background(Color.toolbarBackground.opacity(0.2))
                        
                        Divider().background(Color.appBorder)
                        
                        // Files Area Simulator
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(0..<4) { index in
                                HStack {
                                    Image(systemName: index == 2 ? "doc.text.fill" : "doc.text")
                                        .font(.system(size: 7))
                                        .foregroundColor(index == 2 ? .accentColor : .secondary)
                                    RoundedRectangle(cornerRadius: 1)
                                        .fill(index == 2 ? Color.accentColor.opacity(0.8) : Color.secondary.opacity(0.3))
                                        .frame(width: index == 2 ? 65 : 80, height: 3)
                                }
                                .padding(.vertical, 2)
                                .padding(.horizontal, 4)
                                .background(index == 2 ? Color.accentColor.opacity(0.15) : Color.clear)
                                .cornerRadius(2)
                            }
                            Spacer()
                        }
                        .padding(8)
                    }
                }
                .frame(width: 200, height: 140)
                .background(Color.cardBackground.opacity(0.6))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.appBorder, lineWidth: 0.8)
                )
                
                // Fly-out Preview Window Simulator
                if demoAnimStep == 1 || demoAnimStep == 2 {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 3) {
                            Circle().fill(Color.red.opacity(0.7)).frame(width: 3, height: 3)
                            Spacer()
                            RoundedRectangle(cornerRadius: 1).fill(Color.secondary.opacity(0.3)).frame(width: 24, height: 3)
                            Spacer()
                        }
                        .padding(4)
                        
                        Divider().background(Color.appBorder)
                        
                        // Fake code lines
                        VStack(alignment: .leading, spacing: 3) {
                            RoundedRectangle(cornerRadius: 0.5).fill(Color.accentColor.opacity(0.7)).frame(width: 45, height: 2)
                            RoundedRectangle(cornerRadius: 0.5).fill(Color.secondary.opacity(0.4)).frame(width: 60, height: 2)
                            RoundedRectangle(cornerRadius: 0.5).fill(Color.secondary.opacity(0.4)).frame(width: 35, height: 2)
                            RoundedRectangle(cornerRadius: 0.5).fill(Color.accentColor.opacity(0.6)).frame(width: 50, height: 2)
                        }
                        .padding(6)
                    }
                    .frame(width: 85, height: 110)
                    .background(Color.cardBackground)
                    .cornerRadius(4)
                    .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
                    )
                    // Fly-out animation transition parameters
                    .offset(x: demoAnimStep == 1 ? 0 : 0, y: demoAnimStep == 1 ? -10 : -10)
                    .scaleEffect(demoAnimStep == 1 ? 1.0 : 0.2)
                    .opacity(demoAnimStep == 1 ? 1.0 : 0.0)
                    .transition(.identity) // Managed manually via demoAnimStep state
                }
            }
            .frame(width: 240, height: 180)
        }
    }
    
    // MARK: - Page 2: Config Page
    private var configPage: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Personalized Settings".localized())
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color.appText)
            
            Text("Before getting started, you can customize some core preferences:".localized())
                .font(.system(size: 13))
                .foregroundColor(Color.appText.opacity(0.6))
                .padding(.bottom, 6)
            
            SettingsCard {
                // Exterior Theme Settings Row
                SettingsRow(title: "Theme Mode".localized(), subtitle: "Adapt to your system appearance".localized()) {
                    Picker("", selection: $settings.themeMode) {
                        ForEach(ThemeMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                    .labelsHidden()
                }
                
                Divider()
                    .background(Color.appBorder)
                    .padding(.horizontal, 16)
                
                // Language Settings Row
                SettingsRow(title: "Interface Language".localized(), subtitle: "Support dynamic toggle between English & Chinese".localized()) {
                    Picker("", selection: $settings.language) {
                        ForEach(Language.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                    .labelsHidden()
                }
                
                Divider()
                    .background(Color.appBorder)
                    .padding(.horizontal, 16)
                
                // Startup Launch Settings Row
                SettingsRow(title: "Launch at Login".localized(), subtitle: "Silently start in the background when you log in".localized()) {
                    Toggle("", isOn: $settings.launchAtLogin)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
            }
        }
    }
    
    // MARK: - Page 3: Permission Center (Progressive & Dual track)
    private var permissionPage: some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text("Running Mode & Permissions".localized())
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color.appText)
                
                Text("QuickCookies supports running without high-level permissions. Choose as you need:".localized())
                    .font(.system(size: 11))
                    .foregroundColor(Color.appText.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 2)
            
            HStack(spacing: 12) {
                // 1. Finder 扩展卡片
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: isFinderExtensionAttempted ? "checkmark.circle.fill" : "arrow.up.forward.app")
                            .foregroundColor(isFinderExtensionAttempted ? .green : .secondary)
                            .font(.system(size: 14))
                        Text("Finder Extension".localized())
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.appText)
                    }
                    
                    Text("Integrate right-click menu and seamless preview. Zero privacy risk.".localized())
                        .font(.system(size: 10.5))
                        .foregroundColor(Color.appText.opacity(0.6))
                        .lineSpacing(2.5)
                        .frame(height: 52, alignment: .topLeading)
                    
                    Spacer()
                    
                    if isFinderExtensionAttempted {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Attempted".localized())
                                .foregroundColor(.green)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    } else {
                        Button(action: {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences") {
                                NSWorkspace.shared.open(url)
                                UserDefaults.standard.set(true, forKey: "isFinderExtensionAttempted")
                                isFinderExtensionAttempted = true
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.forward.app")
                                Text("Enable Finder Extension".localized())
                                    .font(.system(size: 11))
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }
                }
                .padding(12)
                .background(Color.cardBackground)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isFinderExtensionAttempted ? Color.green.opacity(0.3) : Color.appBorder, lineWidth: 1)
                )
                
                // 2. 辅助功能卡片
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: isAccessibilityAuthorized ? "star.fill" : "star")
                            .foregroundColor(isAccessibilityAuthorized ? .orange : .secondary)
                            .font(.system(size: 14))
                        Text("Advanced Animation Mode".localized())
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.appText)
                    }
                    
                    Text("Allow flying from file position with smooth spring physics animations.".localized())
                        .font(.system(size: 10.5))
                        .foregroundColor(Color.appText.opacity(0.6))
                        .lineSpacing(2.5)
                        .frame(height: 52, alignment: .topLeading)
                    
                    Spacer()
                    
                    if isAccessibilityAuthorized {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Permission Granted".localized())
                                .foregroundColor(.green)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    } else {
                        Button(action: {
                            isCheckingAccessibility = true
                            HotkeyManager.shared.requestAccessibilityPermission()
                        }) {
                            HStack(spacing: 4) {
                                if isCheckingAccessibility {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Checking...".localized())
                                        .font(.system(size: 11))
                                } else {
                                    Image(systemName: "hand.raised.fill")
                                    Text("Grant Accessibility".localized())
                                        .font(.system(size: 11))
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .disabled(isCheckingAccessibility)
                    }
                }
                .padding(12)
                .background(Color.cardBackground)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isAccessibilityAuthorized ? Color.orange.opacity(0.4) : Color.appBorder, lineWidth: 1)
                )
                
                // 3. 所有文件夹访问 (FDA) 卡片
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: isFullDiskAccessAuthorized ? "folder.fill" : "folder")
                            .foregroundColor(isFullDiskAccessAuthorized ? .green : .secondary)
                            .font(.system(size: 14))
                        Text("Full Disk Access".localized())
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.appText)
                    }
                    
                    Text("Grant Full Disk Access to avoid folder permission prompts.".localized())
                        .font(.system(size: 10.5))
                        .foregroundColor(Color.appText.opacity(0.6))
                        .lineSpacing(2.5)
                        .frame(height: 52, alignment: .topLeading)
                    
                    Spacer()
                    
                    if isFullDiskAccessAuthorized {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Permission Granted".localized())
                                .foregroundColor(.green)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    } else {
                        Button(action: {
                            isCheckingFDA = true
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            HStack(spacing: 4) {
                                if isCheckingFDA {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Checking...".localized())
                                        .font(.system(size: 11))
                                } else {
                                    Image(systemName: "lock.fill")
                                    Text("Grant Access".localized())
                                        .font(.system(size: 11))
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .disabled(isCheckingFDA)
                    }
                }
                .padding(12)
                .background(Color.cardBackground)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isFullDiskAccessAuthorized ? Color.green.opacity(0.4) : Color.appBorder, lineWidth: 1)
                )
            }
            .frame(height: 170)
        }
    }
    
    // MARK: - Navigation Bar
    private var bottomBar: some View {
        HStack(spacing: 16) {
            // Page Dot Indicator
            HStack(spacing: 6) {
                ForEach(0..<4) { index in
                    Circle()
                        .fill(currentPage == index ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
            
            Spacer()
            
            if currentPage > 0 {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        currentPage -= 1
                    }
                }) {
                    Text("Back".localized())
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.appText)
                        .frame(width: 72, height: 28)
                        .background(Color.appText.opacity(0.06))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.appText.opacity(0.12), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            
            if currentPage < 3 {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        currentPage += 1
                    }
                }) {
                    Text("Next".localized())
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 72, height: 28)
                        .background(Color.accentColor)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            } else {
                Button(action: handleFinishAction) {
                    HStack(spacing: 6) {
                        if isStartingApp {
                            ProgressView()
                                .controlSize(.small)
                            Text("Starting...".localized())
                        } else {
                            Text("Start Using Quick Cookies".localized())
                        }
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 140, height: 28)
                    .background(isStartingApp ? Color.green.opacity(0.6) : Color.green)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(isStartingApp)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color.clear)
    }
    
    // MARK: - Logic & Actions
    private func checkPermissionState() {
        let auth = AXIsProcessTrusted()
        let fda = checkFullDiskAccess()
        
        var shouldShowConfetti = false
        
        DispatchQueue.main.async {
            if auth != self.isAccessibilityAuthorized {
                withAnimation(.spring()) {
                    self.isAccessibilityAuthorized = auth
                    if auth {
                        shouldShowConfetti = true
                    }
                }
            }
            
            if fda != self.isFullDiskAccessAuthorized {
                withAnimation(.spring()) {
                    self.isFullDiskAccessAuthorized = fda
                    if fda {
                        shouldShowConfetti = true
                    }
                }
            }
            
            if shouldShowConfetti {
                self.showConfetti = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    if !self.isClosing {
                        self.showConfetti = false
                    }
                }
            }
        }
    }
    
    private func checkFullDiskAccess() -> Bool {
        let path = NSHomeDirectory() + "/Library/Safari/Bookmarks.plist"
        return FileManager.default.isReadableFile(atPath: path)
    }
    
    private func handleFinishAction() {
        guard !isStartingApp else { return }
        isStartingApp = true
        
        // Step 1: 触发彩屑庆祝动画
        showConfetti = true
        
        // Step 2: 1.8s 庆祝后，启动窗口淡出
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeInOut(duration: 0.18)) {
                windowOpacity = 0.0
                windowScale = 0.96
            }
            
            // Step 3: 淡出动画结束（0.18s）后，先停止所有 Timer 副作用再回调
            // NOTE: isClosing = true 必须在 onFinished() 之前设置，
            //       确保 AppDelegate 执行 orderOut 之前 RunLoop 中不再有新的
            //       Timer 事件可以触发 SwiftUI 状态更新（防死锁关键步骤）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                showConfetti = false   // 移除 ConfettiView，取消其 33ms 高频 Timer 订阅
                isClosing = true       // 屏蔽 authTimer / animationTimer 回调
                onFinished()           // 通知 AppDelegate 执行四阶段关闭序列
            }
        }
    }
}


// MARK: - Step Row Helper
struct StepRow: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.accentColor.opacity(0.8))
                .frame(width: 5, height: 5)
                .padding(.top, 6)
            
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(Color.appText)
                .lineSpacing(3)
        }
    }
}
