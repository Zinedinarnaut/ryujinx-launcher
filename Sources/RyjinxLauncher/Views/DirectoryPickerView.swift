import SwiftUI

struct DirectoryPickerView: View {
    let title: String
    @Binding var path: String
    let validation: ValidationResult
    let allowsFiles: Bool
    let onPickURL: ((URL) -> Void)?
    @State private var isPanelPresented = false
    @State private var activePanel: NSOpenPanel?
    @State private var hostingWindow: NSWindow?

    init(title: String, path: Binding<String>, validation: ValidationResult, allowsFiles: Bool = false, onPickURL: ((URL) -> Void)? = nil) {
        self.title = title
        self._path = path
        self.validation = validation
        self.allowsFiles = allowsFiles
        self.onPickURL = onPickURL
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.custom("Avenir Next", size: 11).weight(.semibold))
                .foregroundStyle(Theme.textSecondary)

            HStack(spacing: 8) {
                Text(path.isEmpty ? "Not set" : path)
                    .font(.custom("Avenir Next", size: 12).weight(.medium))
                    .foregroundStyle(path.isEmpty ? Theme.textMuted : Theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                    .background(Theme.panelAlt)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(validation.isValid ? Theme.border : Color(white: 0.35), lineWidth: 1)
                    )

                Button("Choose") {
                    openPanel()
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            Text(validation.message)
                .font(.custom("Avenir Next", size: 10).weight(.medium))
                .foregroundStyle(validation.isValid ? Theme.textMuted : Color(white: 0.6))
        }
        .padding(10)
        .background(Theme.panel)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.border.opacity(0.6), lineWidth: 1)
        )
        .background(WindowAccessor(window: $hostingWindow))
    }

    @MainActor
    private func openPanel() {
        guard !isPanelPresented else { return }

        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = allowsFiles
        panel.allowsMultipleSelection = false
        panel.title = title
        panel.prompt = "Select"
        panel.treatsFilePackagesAsDirectories = false
        if !path.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: path)
        }

        isPanelPresented = true
        activePanel = panel

        let handleResponse: (NSApplication.ModalResponse) -> Void = { response in
            defer {
                isPanelPresented = false
                activePanel = nil
            }
            guard response == .OK, let url = panel.url else { return }
            path = url.path
            onPickURL?(url)
        }

        let targetWindow = hostingWindow ?? NSApp.keyWindow ?? NSApp.mainWindow
        if let window = targetWindow, window.sheetParent == nil {
            panel.beginSheetModal(for: window, completionHandler: handleResponse)
        } else {
            let response = panel.runModal()
            handleResponse(response)
        }
    }
}

private struct WindowAccessor: NSViewRepresentable {
    @Binding var window: NSWindow?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            self.window = view?.window
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { [weak nsView] in
            self.window = nsView?.window
        }
    }
}
