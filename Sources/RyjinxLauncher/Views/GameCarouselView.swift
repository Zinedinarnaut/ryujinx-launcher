import SwiftUI
import Foundation

struct GameCarouselView: View {
    let games: [Game]
    @Binding var selectedGame: Game?
    let thumbnailService: ThumbnailService
    @Binding var scrollOffset: CGFloat
    let isGamingMode: Bool
    let isScanning: Bool
    let isLaunching: Bool
    let statusMessage: String?

    private let rowHeight: CGFloat = GameCardView.cardSize.height + GameCardView.titleHeight + GameCardView.verticalSpacing + 16
    private let cardSpacing: CGFloat = 14

    @State private var isUserDragging = false
    @State private var cardCenters: [String: CGFloat] = [:]
    @State private var carouselCenterX: CGFloat = 0
    @State private var snapWorkItem: DispatchWorkItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Game Library")
                    .font(.custom("Avenir Next", size: 15).weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)

                Text("\(games.count)")
                    .font(.custom("Avenir Next", size: 11).weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.panel.opacity(0.6))
                    .cornerRadius(10)
            }
            .opacity(isGamingMode ? 0.5 : 1.0)

            if isScanning {
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(.circular)
                    Text(statusMessage ?? "Scanning library…")
                        .font(.custom("Avenir Next", size: 11).weight(.semibold))
                        .foregroundStyle(Theme.textMuted)
                }
            }

            if games.isEmpty {
                VStack(spacing: 10) {
                    if isScanning {
                        ProgressView()
                            .progressViewStyle(.circular)
                    }
                    Text(statusMessage ?? "No games found in the selected directory")
                        .font(.custom("Avenir Next", size: 12).weight(.medium))
                        .foregroundStyle(Theme.textMuted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 160, alignment: .center)
            } else {
                ScrollViewReader { proxy in
                    GeometryReader { geometry in
                        let contentWidth = CGFloat(games.count) * GameCardView.cardSize.width
                            + CGFloat(max(games.count - 1, 0)) * cardSpacing
                        let horizontalInset = max(10, (geometry.size.width - contentWidth) * 0.5)

                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: cardSpacing) {
                                ForEach(games) { game in
                                    let isSelected = game.id == selectedGame?.id
                                    GameCardView(game: game, isSelected: isSelected, thumbnailService: thumbnailService, isGamingMode: isGamingMode) {
                                        selectedGame = game
                                    }
                                    .background(
                                        GeometryReader { proxy in
                                            let cardFrame = proxy.frame(in: .named("carousel"))
                                            Color.clear
                                                .preference(
                                                    key: CardCenterPreferenceKey.self,
                                                    value: [game.id: cardFrame.midX]
                                                )
                                        }
                                    )
                                    .id(game.id)
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, horizontalInset)
                            .background(
                                GeometryReader { geo in
                                    let frame = geo.frame(in: .named("carousel"))
                                    Color.clear
                                        .preference(key: ScrollOffsetPreferenceKey.self, value: -frame.minX)
                                        .preference(key: CarouselCenterPreferenceKey.self, value: frame.midX)
                                }
                            )
                        }
                        .frame(height: rowHeight)
                        .coordinateSpace(name: "carousel")
                        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                            scrollOffset = value
                        }
                        .onPreferenceChange(CardCenterPreferenceKey.self) { value in
                            cardCenters = value
                        }
                        .onPreferenceChange(CarouselCenterPreferenceKey.self) { value in
                            carouselCenterX = value
                        }
                        .onChange(of: selectedGame?.id) { _, newValue in
                            guard let newValue else { return }
                            guard !isUserDragging else { return }
                            let animation = isGamingMode
                                ? Animation.interpolatingSpring(stiffness: 280, damping: 32)
                                : Animation.interpolatingSpring(stiffness: 220, damping: 26)
                            withAnimation(animation) {
                                proxy.scrollTo(newValue, anchor: .center)
                            }
                        }
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 4)
                                .onChanged { _ in
                                    isUserDragging = true
                                }
                                .onEnded { _ in
                                    isUserDragging = false
                                    scheduleSnap(using: proxy)
                                }
                        )
                    }
                    .frame(height: rowHeight)
                }
            }

            if isLaunching {
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(.circular)
                    Text("Launching game…")
                        .font(.custom("Avenir Next", size: 11).weight(.semibold))
                        .foregroundStyle(Theme.textMuted)
                }
                .padding(.top, 4)
            }
        }
    }

    private func snapToNearest(using proxy: ScrollViewProxy) {
        guard !games.isEmpty, !cardCenters.isEmpty else { return }
        let nearest = cardCenters.min { lhs, rhs in
            abs(lhs.value - carouselCenterX) < abs(rhs.value - carouselCenterX)
        }
        guard let id = nearest?.key,
              let game = games.first(where: { $0.id == id }) else { return }
        if selectedGame?.id != id {
            selectedGame = game
        }
        let animation = isGamingMode
            ? Animation.interpolatingSpring(stiffness: 260, damping: 30)
            : Animation.interpolatingSpring(stiffness: 210, damping: 24)
        withAnimation(animation) {
            proxy.scrollTo(id, anchor: .center)
        }
    }

    private func scheduleSnap(using proxy: ScrollViewProxy) {
        snapWorkItem?.cancel()
        let work = DispatchWorkItem {
            snapToNearest(using: proxy)
        }
        snapWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }
}

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct CardCenterPreferenceKey: PreferenceKey {
    static let defaultValue: [String: CGFloat] = [:]

    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct CarouselCenterPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct SelectedCardFramePreferenceKey: PreferenceKey {
    static let defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero {
            value = next
        }
    }
}
