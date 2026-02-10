import Foundation
import CoreSpotlight
import UniformTypeIdentifiers

final class SpotlightIndexService {
    private let index = CSSearchableIndex.default()

    func indexGames(_ games: [Game]) {
        let items: [CSSearchableItem] = games.map { game in
            let attributes = CSSearchableItemAttributeSet(contentType: .data)
            attributes.title = game.title
            attributes.contentDescription = "Title ID: \(game.titleId ?? "Unknown") • Playtime \(game.formattedHoursPlayed)"
            attributes.keywords = [game.title, game.titleId].compactMap { $0 }

            let key = SharedThumbnailStore.key(titleId: game.titleId, title: game.title)
            if let data = ImageCache.shared.imageData(forKey: key) {
                attributes.thumbnailData = data
            }

            return CSSearchableItem(uniqueIdentifier: game.id, domainIdentifier: "ryjinx.games", attributeSet: attributes)
        }

        index.indexSearchableItems(items) { _ in }
    }
}
