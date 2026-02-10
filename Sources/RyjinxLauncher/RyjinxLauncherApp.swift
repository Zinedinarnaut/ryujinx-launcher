import SwiftUI
import AppKit

@main
struct RyjinxLauncherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    @StateObject private var viewModel = LauncherViewModel()
    @StateObject private var controllerViewModel = ControllerManagerViewModel()
    @State private var showSplash = true
    @State private var window: NSWindow?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if showSplash {
                SplashView()
                    .transition(.opacity.combined(with: .scale))
            } else {
                LauncherView(viewModel: viewModel, controllerViewModel: controllerViewModel)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .onAppear {
            LauncherAppController.shared.attach(viewModel: viewModel)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeInOut(duration: 0.6)) {
                    showSplash = false
                }
            }
            controllerViewModel.onNavigate = { action in
                switch action {
                case .next:
                    viewModel.selectNextGame()
                case .previous:
                    viewModel.selectPreviousGame()
                case .launch:
                    viewModel.launchSelectedGame()
                case .stop:
                    viewModel.stopLaunch()
                case .openSettings:
                    viewModel.isSettingsPresented = true
                }
            }
        }
        .onOpenURL { url in
            viewModel.handleDeepLink(url)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            viewModel.handlePendingLaunchIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification, object: window)) { _ in
            viewModel.isGamingMode = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification, object: window)) { _ in
            viewModel.isGamingMode = false
        }
        .onChange(of: viewModel.isLaunchIsolationActive) { _, newValue in
            controllerViewModel.setPollingEnabled(!newValue)
        }
        .background(WindowAccessor(window: $window))
    }
}

private struct WindowAccessor: NSViewRepresentable {
    @Binding var window: NSWindow?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            guard let view else { return }
            self.window = view.window
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { [weak nsView] in
            guard let nsView else { return }
            self.window = nsView.window
        }
    }
}
