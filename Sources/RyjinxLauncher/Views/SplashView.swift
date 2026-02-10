import SwiftUI

struct SplashView: View {
    @State private var animate = false
    @State private var metalIntensity: CGFloat = 0.0

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                MetalBackgroundView(
                    viewSize: size,
                    focusIntensity: metalIntensity,
                    scrollOffset: 0,
                    focusPoint: CGPoint(x: 0.5, y: 0.55),
                    backgroundImage: nil,
                    backgroundVersion: 0,
                    isGamingMode: false,
                    isLaunchActive: false
                )
                .ignoresSafeArea()
                Theme.background.opacity(0.7).ignoresSafeArea()

                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(Theme.border, lineWidth: 2)
                            .frame(width: 120, height: 120)
                            .opacity(0.6)

                        Circle()
                            .fill(Theme.panel)
                            .frame(width: 90, height: 90)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Theme.border.opacity(0.5), lineWidth: 1)
                            )

                        Capsule()
                            .fill(Theme.textSecondary)
                            .frame(width: 36, height: 6)
                            .offset(y: -24)
                    }

                    Text("Ryjinx Launcher")
                        .font(.custom("Avenir Next", size: 22).weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)

                    Text("Preparing your library")
                        .font(.custom("Avenir Next", size: 12).weight(.medium))
                        .foregroundStyle(Theme.textMuted)
                }
                .scaleEffect(animate ? 1.0 : 0.92)
                .opacity(animate ? 1.0 : 0.0)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animate = true
                metalIntensity = 0.18
            }
        }
    }
}
