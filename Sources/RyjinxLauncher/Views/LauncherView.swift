import SwiftUI
import AppKit

struct LauncherView: View {
    @ObservedObject var viewModel: LauncherViewModel
    @ObservedObject var controllerViewModel: ControllerManagerViewModel
    @State private var scrollOffset: CGFloat = 0
    @State private var selectedIndex: Int = 0
    @State private var rootSize: CGSize = .zero
    @State private var selectedCardFrame: CGRect = .zero
    @State private var focusPoint: CGPoint = CGPoint(x: 0.5, y: 0.6)
    @State private var backgroundImage: NSImage?
    @State private var previousBackgroundImage: NSImage?
    @State private var backgroundKey: String = ""
    @State private var backgroundFade: Double = 1.0
    @State private var canPlayFocusSound = false

    init(viewModel: LauncherViewModel, controllerViewModel: ControllerManagerViewModel) {
        self.viewModel = viewModel
        self.controllerViewModel = controllerViewModel
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                backgroundLayer(size: size)
                    .zIndex(0)

                let effectiveGamingMode = viewModel.isGamingMode || viewModel.isLaunchIsolationActive
                MetalBackgroundView(
                    viewSize: size,
                    focusIntensity: focusIntensity,
                    scrollOffset: scrollOffset,
                    focusPoint: focusPoint,
                    backgroundImage: nil,
                    backgroundVersion: 0,
                    isGamingMode: effectiveGamingMode,
                    isLaunchActive: viewModel.isLaunchIsolationActive
                )
                .blendMode(.screen)
                .opacity(0.75)
                .zIndex(1)
                .ignoresSafeArea()
                .allowsHitTesting(false)

                VStack {
                    Spacer(minLength: 0)

                    GameCarouselView(
                        games: viewModel.games,
                        selectedGame: $viewModel.selectedGame,
                        thumbnailService: viewModel.thumbnailService,
                        scrollOffset: $scrollOffset,
                        isGamingMode: effectiveGamingMode,
                        isScanning: viewModel.isScanning,
                        isLaunching: viewModel.isLaunching,
                        statusMessage: viewModel.statusMessage
                    )

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 40)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .zIndex(2)
            }
            .onAppear {
                rootSize = size
                updateFocusPoint()
            }
            .onChange(of: size) { _, newSize in
                rootSize = newSize
                updateFocusPoint()
            }
        }
        .coordinateSpace(name: "launcherRoot")
        .onChange(of: viewModel.selectedGame?.id) { _, _ in
            updateSelectedIndex()
            if canPlayFocusSound, !viewModel.isScanning {
                SoundPlayer.shared.play(.focus)
            }
        }
        .onChange(of: viewModel.games.count) { _, _ in
            updateSelectedIndex()
        }
        .onChange(of: selectedIndex) { _, _ in
            Task { await updateBackground() }
        }
        .onAppear {
            updateSelectedIndex()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                canPlayFocusSound = true
            }
        }
        .onPreferenceChange(SelectedCardFramePreferenceKey.self) { frame in
            if frame != .zero {
                selectedCardFrame = frame
                updateFocusPoint()
            }
        }
        .task(id: viewModel.selectedGame?.id) {
            await updateBackground()
        }
        .sheet(isPresented: $viewModel.isSettingsPresented) {
            LauncherSettingsView(viewModel: viewModel, controllerViewModel: controllerViewModel)
        }
        .overlay(alignment: .topTrailing) {
            floatingControls
        }
        .userActivity("com.ryjinx.launcher.game", isActive: viewModel.selectedGame != nil) { activity in
            let selected = viewModel.selectedGame
            activity.title = selected?.title ?? "Ryjinx Launcher"
            activity.userInfo = [
                "gameId": selected?.id ?? "",
                "title": selected?.title ?? ""
            ]
            activity.isEligibleForHandoff = true
            activity.isEligibleForSearch = true
            #if os(iOS)
            activity.isEligibleForPrediction = true
            #endif
        }
    }

    private var floatingControls: some View {
        let hasFocus = viewModel.selectedGame != nil
        let chromeOpacity: CGFloat = (viewModel.isGamingMode || viewModel.isLaunchIsolationActive)
            ? 0.55
            : (hasFocus ? 0.8 : 0.65)

        return VStack(alignment: .trailing, spacing: 10) {
            Button("Settings") {
                viewModel.isSettingsPresented = true
            }
            .buttonStyle(SecondaryButtonStyle())

            Button(viewModel.isLaunching ? "Launching..." : "Launch Game") {
                viewModel.launchSelectedGame()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!viewModel.canLaunch)

            Button("Stop") {
                viewModel.stopLaunch()
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(!viewModel.isLaunching)
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .background(Theme.panelAlt.opacity(0.35))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.border.opacity(0.6), lineWidth: 1)
        )
        .padding(.top, 18)
        .padding(.trailing, 20)
        .opacity(chromeOpacity)
    }

    private var focusIntensity: CGFloat {
        guard !viewModel.games.isEmpty else { return 0.05 }
        let base: CGFloat = viewModel.selectedGame == nil ? 0.08 : 0.14
        let indexBoost = CGFloat(selectedIndex % 5) * 0.015
        let gamingScale: CGFloat = (viewModel.isGamingMode || viewModel.isLaunchIsolationActive) ? 0.75 : 1.0
        return min(0.3, (base + indexBoost) * gamingScale)
    }

    private func updateSelectedIndex() {
        if let selected = viewModel.selectedGame,
           let index = viewModel.games.firstIndex(where: { $0.id == selected.id }) {
            selectedIndex = index
        } else {
            selectedIndex = 0
        }
    }

    private func updateFocusPoint() {
        guard rootSize.width > 0, rootSize.height > 0 else { return }
        guard selectedCardFrame != .zero else {
            focusPoint = CGPoint(x: 0.5, y: 0.65)
            return
        }
        let x = selectedCardFrame.midX / rootSize.width
        let y = selectedCardFrame.midY / rootSize.height
        focusPoint = CGPoint(x: min(max(x, 0.05), 0.95), y: min(max(y, 0.05), 0.95))
    }

    private func updateBackground() async {
        let targetGame: Game? = {
            if let selected = viewModel.selectedGame { return selected }
            if viewModel.games.indices.contains(selectedIndex) { return viewModel.games[selectedIndex] }
            return viewModel.games.first
        }()
        guard let game = targetGame else {
            await MainActor.run {
                previousBackgroundImage = nil
                backgroundImage = nil
                backgroundFade = 1.0
                backgroundKey = ""
            }
            return
        }

        let key = game.titleId ?? game.title
        await MainActor.run {
            backgroundKey = key
        }

        let image = await viewModel.thumbnailService.fetchBackground(for: game)
        await MainActor.run {
            guard backgroundKey == key else { return }
            previousBackgroundImage = backgroundImage
            backgroundImage = image
            backgroundFade = 0.0
            withAnimation(.easeInOut(duration: 0.65)) {
                backgroundFade = 1.0
            }
        }
    }

    private func backgroundLayer(size: CGSize) -> some View {
        ZStack {
            if let previousBackgroundImage {
                backgroundImageView(previousBackgroundImage, size: size)
                    .opacity(1.0 - backgroundFade)
            }
            if let backgroundImage {
                backgroundImageView(backgroundImage, size: size)
                    .opacity(backgroundFade)
            }
            if backgroundImage == nil && previousBackgroundImage == nil {
                Theme.background
            }
        }
        .frame(width: size.width, height: size.height)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func backgroundImageView(_ image: NSImage, size: CGSize) -> some View {
        let parallax = min(max(scrollOffset / 1400, -12), 12)
        return Image(nsImage: image)
            .resizable()
            .interpolation(.high)
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .clipped()
            .blur(radius: 22)
            .saturation(0.8)
            .contrast(0.95)
            .scaleEffect(1.04)
            .overlay(Color.black.opacity(0.55))
            .offset(x: parallax)
    }
}
