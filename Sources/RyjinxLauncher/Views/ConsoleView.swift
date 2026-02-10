import SwiftUI

struct ConsoleView: View {
    let lines: [ConsoleLine]
    let onClear: () -> Void

    @State private var autoScroll = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Launcher Console")
                    .font(.custom("Avenir Next", size: 14).weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                if !autoScroll {
                    Button("Resume Auto-Scroll") {
                        autoScroll = true
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }

                Button("Clear") {
                    onClear()
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(lines) { line in
                            Text(line.text)
                                .font(.custom("Menlo", size: 11))
                                .foregroundStyle(color(for: line.stream))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding(.vertical, 8)
                }
                .background(Theme.panelAlt)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.border.opacity(0.6), lineWidth: 1)
                )
                .gesture(
                    DragGesture(minimumDistance: 4)
                        .onChanged { _ in
                            autoScroll = false
                        }
                )
                .onChange(of: lines.count) { _, _ in
                    guard autoScroll else { return }
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
        .padding(12)
        .background(Theme.panelAlt)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.border.opacity(0.6), lineWidth: 1)
        )
    }

    private func color(for stream: ConsoleStream) -> Color {
        switch stream {
        case .stdout:
            return Theme.textSecondary
        case .stderr:
            return Color(white: 0.75)
        case .system:
            return Theme.textMuted
        }
    }
}
