import SwiftUI
import AppKit

struct ThumbnailView: View {
    let game: Game
    let service: ThumbnailService
    let targetSize: CGSize?

    @State private var image: NSImage?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.panelAlt)

                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                } else {
                    Text("No Art")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textMuted)
                }
            }
        }
        .clipped()
        .task(id: game.id) {
            await load()
        }
    }

    private func load() async {
        guard image == nil, !isLoading else { return }
        isLoading = true
        let pixelSize = targetPixelSize()
        let fetched = await service.fetchThumbnail(for: game, targetPixelSize: pixelSize)
        await MainActor.run {
            self.image = fetched
            self.isLoading = false
        }
    }

    private func targetPixelSize() -> Int? {
        guard let targetSize else { return nil }
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let maxDimension = max(targetSize.width, targetSize.height)
        return Int(maxDimension * scale)
    }
}
