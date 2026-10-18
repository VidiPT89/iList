import SwiftUI

struct SplashView: View {
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.18, green: 0.54, blue: 0.34), Color(red: 0.08, green: 0.32, blue: 0.20)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image(systemName: "cart.fill")
                    .font(.system(size: 90))
                    .foregroundStyle(.white)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    .padding(.bottom, 24)

                VStack(spacing: 8) {
                    Text("iList")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("splash.subtitle")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                }
                .opacity(textOpacity)

                Spacer()

                VStack(spacing: 6) {
                    Text("David Arsénio Martins")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.white.opacity(0.65))
                    Link("ividi.dev", destination: URL(string: "https://ividi.dev/")!)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.45))
                }
                .opacity(textOpacity)
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            withAnimation(.easeIn(duration: 0.5).delay(0.35)) {
                textOpacity = 1.0
            }
        }
    }
}
