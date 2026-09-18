import SwiftUI

public struct FindBarView: View {
    @ObservedObject public var state: FindBarState
    @FocusState private var isFocused: Bool

    public init(state: FindBarState) {
        self.state = state
    }

    public var body: some View {
        if state.isPresented {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.appText.opacity(0.5))

                TextField("Find in file...".localized(), text: $state.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .focused($isFocused)
                    .frame(minWidth: 120, maxWidth: 180)
                    .contentShape(Rectangle())
                    .onSubmit {
                        state.next()
                    }

                if !state.query.isEmpty {
                    Text(state.matchCountText)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(state.totalMatches > 0 ? Color.appText.opacity(0.7) : Color.red.opacity(0.8))
                        .padding(.horizontal, 2)

                    HStack(spacing: 3) {
                        Button(action: { state.previous() }) {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 10, weight: .semibold))
                                .frame(width: 18, height: 18)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Previous Match (Shift+Enter)".localized())

                        Button(action: { state.next() }) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                                .frame(width: 18, height: 18)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Next Match (Enter)".localized())
                    }
                }

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
