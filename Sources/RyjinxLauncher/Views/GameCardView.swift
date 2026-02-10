import SwiftUI

struct GameCardView: View {
    static let cardSize = CGSize(width: 170, height: 238)
    static let titleHeight: CGFloat = 44
    static let verticalSpacing: CGFloat = 8

    let game: Game
    let isSelected: Bool
    let thumbnailService: ThumbnailService
    let isGamingMode: Bool
    let onSelect: () -> Void

    @State private var isHovering = false

    var body: some View {
        let scale: CGFloat = isSelected ? 1.0 : (isHovering ? 0.97 : 0.95)

        VStack(alignment: .leading, spacing: Self.verticalSpacing) {
            ThumbnailView(game: game, service: thumbnailService, targetSize: Self.cardSize)
                .frame(width: Self.cardSize.width, height: Self.cardSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: SelectedCardFramePreferenceKey.self,
                            value: isSelected ? proxy.frame(in: .named("launcherRoot")) : .zero
                        )
                    }
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(game.title)
                    .font(.custom("Avenir Next", size: 12).weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(game.formattedHoursPlayed)
                    .font(.custom("Avenir Next", size: 10).weight(.medium))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            .frame(width: Self.cardSize.width, height: Self.titleHeight, alignment: .topLeading)
        }
        .saturation(isSelected ? 1.0 : 0.78)
        .brightness(isSelected ? 0.02 : -0.05)
        .scaleEffect(scale)
        .zIndex(isSelected ? 2 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .animation(.interpolatingSpring(stiffness: 240, damping: 28), value: isSelected)
        .animation(.easeOut(duration: 0.18), value: isHovering)
        .onHover { hovering in
            isHovering = hovering && !isGamingMode
        }
        .onTapGesture {
            SoundPlayer.shared.play(.select)
            onSelect()
        }
    }
}
