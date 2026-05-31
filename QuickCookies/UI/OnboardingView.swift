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
                for _ in 0..<70 {
                    particles.append(ConfettiParticle(
                        x: Double.random(in: 0...Double(geo.size.width)),
                        y: Double.random(in: -150...0),
                        color: colors.randomElement()!,
                        size: Double.random(in: 8...15),
                        speed: Double.random(in: 3...7),
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

// MARK: - SwiftUI VisualEffectView Wrapper
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
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
    }
}

// MARK: - Onboarding View
struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var isAuthorized = false
    @State private var showConfetti = false
    
    @ObservedObject var settings = Settings.shared
    
    let onFinished: () -> Void
    let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Header Title
                Text("新手向导".localized())
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.appText)
                    .padding(.top, 24)
                
                // Page Area
                ZStack {
                    if currentPage == 0 {
                        welcomePage
                            .transition(.opacity)
                    } else if currentPage == 1 {
                        demoPage
                            .transition(.opacity)
                    } else if currentPage == 2 {
                        configPage
                            .transition(.opacity)
                    } else if currentPage == 3 {
                        permissionPage
                            .transition(.opacity)
                    }
                }
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 40)
                
                Divider()
                    .background(Color.appBorder)
                
                // Navigation Bottom Bar
                bottomBar
            }
            
            if showConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
            }
        }
        .frame(width: 600, height: 430)
        .onAppear {
            checkPermissionState()
        }
        .onReceive(timer) { _ in
            checkPermissionState()
        }
    }
    
    // MARK: - Pages
    
    private var welcomePage: some View {
        VStack(spacing: 20) {
            Image("MenuBarIcon")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 72, height: 72)
                .foregroundColor(.accentColor)
                .padding(.top, 16)
            
            Text("Quick Cookies")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(Color.appText)
            
            Text("秒级代码与文档预览".localized())
                .font(.system(size: 14))
                .foregroundColor(Color.appText.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)
        }
    }
    
    private var demoPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("简单三步，开启效率之旅".localized())
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.appText)
                .padding(.bottom, 4)
            
            VStack(alignment: .leading, spacing: 16) {
                StepRow(text: "1. 在 Finder 中选中任意代码或 Markdown 文件".localized())
                StepRow(text: "2. 在键盘上快速双击 Option 键（或右键选择预览）".localized())
                StepRow(text: "3. 预览窗口瞬间飞出，支持行号与即时编辑！".localized())
            }
            .padding(.leading, 8)
        }
    }
    
    private var configPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("偏好配置".localized())
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.appText)
            
            Text("在正式使用前，您可以进行一些基础的个性化定制：".localized())
                .font(.system(size: 13))
                .foregroundColor(Color.appText.opacity(0.6))
            
            VStack(spacing: 12) {
                // Theme Toggle
                HStack {
                    Text("外观主题".localized())
                        .foregroundColor(Color.appText)
                    Spacer()
                    Picker("", selection: $settings.themeMode) {
                        ForEach(ThemeMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
                
                // Language Toggle
                HStack {
                    Text("语言".localized())
                        .foregroundColor(Color.appText)
                    Spacer()
                    Picker("", selection: $settings.language) {
                        ForEach(Language.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
                
                // Hotkey Info
                HStack {
                    Text("默认触发快捷键".localized())
                        .foregroundColor(Color.appText)
                    Spacer()
                    HStack(spacing: 4) {
                        Text("⌥ Option")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.kbdBackground)
                            .cornerRadius(4)
                        Text("+")
                            .foregroundColor(.secondary)
                        Text("⌥ Option")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.kbdBackground)
                            .cornerRadius(4)
                    }
                }
                .padding(.top, 4)
            }
            .padding(16)
            .background(Color.cardBackground)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.appBorder, lineWidth: 1)
            )
        }
    }
    
    private var permissionPage: some View {
        VStack(spacing: 18) {
            Text("系统权限授权".localized())
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.appText)
            
            VStack(spacing: 12) {
                Text("请授予辅助功能权限，以便能够通过快捷键触发预览。".localized())
                    .font(.system(size: 13))
                    .foregroundColor(Color.appText.opacity(0.8))
                    .multilineTextAlignment(.center)
                
                Text("（选填）若不授予，您仍可通过 Finder 右键菜单及 Services 菜单直接预览文件。".localized())
                    .font(.system(size: 11))
                    .foregroundColor(Color.appText.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            
            if isAuthorized {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green)
                    Text("授权成功！🎉".localized())
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.green)
                }
                .padding(.top, 8)
            } else {
                Button(action: {
                    HotkeyManager.shared.requestAccessibilityPermission()
                }) {
                    HStack {
                        Image(systemName: "hand.raised.fill")
                        Text("去授予权限".localized())
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
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
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentPage -= 1
                    }
                }) {
                    Text("上一步".localized())
                        .frame(width: 60)
                }
                .buttonStyle(.bordered)
            }
            
            if currentPage < 3 {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentPage += 1
                    }
                }) {
                    Text("下一步".localized())
                        .frame(width: 60)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button(action: onFinished) {
                    Text("开启 Quick Cookies".localized())
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .accentColor(.green)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color.toolbarBackground)
    }
    
    // MARK: - Logic Helpers
    
    private func checkPermissionState() {
        let auth = AXIsProcessTrusted()
        if auth != isAuthorized {
            withAnimation(.spring()) {
                isAuthorized = auth
                if auth {
                    showConfetti = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        self.showConfetti = false
                    }
                }
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
                .frame(width: 6, height: 6)
                .padding(.top, 6)
            
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(Color.appText)
                .lineSpacing(4)
        }
    }
}
