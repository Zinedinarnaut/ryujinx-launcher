import SwiftUI

struct LauncherSettingsView: View {
    @ObservedObject var viewModel: LauncherViewModel
    @ObservedObject var controllerViewModel: ControllerManagerViewModel
    @ObservedObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss

    init(viewModel: LauncherViewModel, controllerViewModel: ControllerManagerViewModel) {
        self.viewModel = viewModel
        self.controllerViewModel = controllerViewModel
        self.settings = viewModel.settings
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    header

                    directorySection

                    librarySection

                    systemSection

                    ConsoleView(lines: viewModel.consoleLines) {
                        viewModel.clearConsole()
                    }

                    ControllerManagerView(viewModel: controllerViewModel)
                }
                .padding(24)
                .frame(maxWidth: 1100)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(minWidth: 900, minHeight: 700)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Settings")
                    .font(.custom("Avenir Next", size: 24).weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Launcher configuration and tools")
                    .font(.custom("Avenir Next", size: 12).weight(.semibold))
                    .foregroundStyle(Theme.textMuted)
            }

            Spacer()

            Button("Done") {
                dismiss()
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    private var directorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Directories")

            HStack(spacing: 12) {
                DirectoryPickerView(
                    title: "Ryujinx Executable",
                    path: $settings.ryujinxDirectory,
                    validation: viewModel.ryujinxValidation,
                    allowsFiles: true,
                    onPickURL: { settings.storeBookmark(for: .ryujinx, url: $0) }
                )
                DirectoryPickerView(
                    title: "Games Directory",
                    path: $settings.gamesDirectory,
                    validation: viewModel.gamesValidation,
                    onPickURL: { settings.storeBookmark(for: .games, url: $0) }
                )
            }
        }
        .padding(14)
        .background(Theme.panelAlt)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.border.opacity(0.6), lineWidth: 1)
        )
    }

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Library")

            HStack(spacing: 12) {
                Button(viewModel.isScanning ? "Scanning..." : "Rescan Library") {
                    viewModel.rescan()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(viewModel.isScanning)

                Button("Clear Image Cache") {
                    viewModel.clearImageCache()
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(viewModel.isScanning)

                Button("Rebuild Backgrounds") {
                    viewModel.rebuildBackgrounds()
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(viewModel.isScanning)

                if viewModel.isScanning {
                    ProgressView()
                        .progressViewStyle(.circular)
                }

                Spacer()

                if let status = viewModel.statusMessage {
                    Text(status)
                        .font(.custom("Avenir Next", size: 11).weight(.semibold))
                        .foregroundStyle(Theme.textMuted)
                }
            }
        }
        .padding(14)
        .background(Theme.panelAlt)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.border.opacity(0.6), lineWidth: 1)
        )
    }

    private var systemSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("System")

            Toggle(isOn: Binding(get: {
                settings.launchAtLogin
            }, set: { newValue in
                settings.setLaunchAtLogin(newValue)
            })) {
                Text("Launch at Login")
                    .font(.custom("Avenir Next", size: 12).weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
            .toggleStyle(.switch)
        }
        .padding(14)
        .background(Theme.panelAlt)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.border.opacity(0.6), lineWidth: 1)
        )
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.custom("Avenir Next", size: 13).weight(.semibold))
            .foregroundStyle(Theme.textPrimary)
    }
}
