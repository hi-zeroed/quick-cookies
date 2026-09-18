import SwiftUI
import Observation

public struct GoToLineBarView: View {
    @Bindable public var state: GoToLineState
    @FocusState private var isFocused: Bool

    public init(state: GoToLineState) {
        self.state = state
    }

    public var body: some View {
        if state.isPresented {
            HStack(spacing: 8) {
                Image(systemName: "arrow.right.to.line")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.appText.opacity(0.55))

                TextField("Line number...".localized(), text: $state.inputLine)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .focused($isFocused)
                    .frame(minWidth: 80, maxWidth: 110)
                    .contentShape(Rectangle())
                    .onSubmit {
                        state.submit()
                    }

                if let err = state.errorMessage {
                    Text(err)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color.red.opacity(0.85))
                } else {
                    Text("1-\(state.totalLines)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.appText.opacity(0.45))
                }

                Button(action: { state.submit() }) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.accentColor)
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Jump to Line (Enter)".localized())

                Button(action: { state.dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color.appText.opacity(0.5))
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Close (Esc)".localized())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .liquidGlassPill(cornerRadius: 8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.appBorder.opacity(0.35), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
            .padding([.top, .trailing], 12)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.async {
                    isFocused = true
                }
            }
            .onChange(of: state.isPresented) { _, presented in
                if presented {
                    DispatchQueue.main.async {
                        isFocused = true
                    }
                }
            }
            .onExitCommand {
                state.dismiss()
            }
        }
    }
}
