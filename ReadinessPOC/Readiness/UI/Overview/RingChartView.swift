import SwiftUI

struct ReadinessHeroCardView: View {
    let result: ReadinessResult

    private let dotSizes: [CGFloat] = [10, 16, 24, 34, 46, 34, 24, 16, 10]

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("当前状态表现")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.white.opacity(0.72))

                Spacer()

                Text("\(Int(result.overallScore))")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundColor(.white.opacity(0.86))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                    )
            }
            .overlay(alignment: .center) {
                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 1)
                    .padding(.horizontal, 64)
            }

            HStack(spacing: 10) {
                ForEach(Array(dotSizes.enumerated()), id: \.offset) { index, size in
                    Circle()
                        .fill(dotColor(at: index))
                        .frame(width: size, height: size)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(index == currentDotIndex ? 0.22 : 0), lineWidth: 2)
                        )
                        .animation(.easeInOut(duration: 0.45).delay(Double(index) * 0.03), value: result.band.rawValue)
                }
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 10) {
                Text(result.text.heroTitle)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text(result.text.heroSubtitle)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white.opacity(0.84))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var currentDotIndex: Int {
        max(result.band.rawValue - 1, 0)
    }

    private func dotColor(at index: Int) -> Color {
        guard index <= currentDotIndex else {
            return Color.white.opacity(index == currentDotIndex + 1 ? 0.22 : 0.14)
        }

        let opacity = 0.42 + (Double(index + 1) / Double(max(currentDotIndex + 1, 1))) * 0.48
        return paletteBaseColor.opacity(opacity)
    }

    private var paletteBaseColor: Color {
        switch (result.mode, result.band) {
        case (.day, .veryLow): return Color(red: 0.88, green: 0.47, blue: 0.47)
        case (.day, .low): return Color(red: 0.91, green: 0.58, blue: 0.35)
        case (.day, .medium): return Color(red: 0.84, green: 0.72, blue: 0.30)
        case (.day, .good): return Color(red: 0.43, green: 0.77, blue: 0.39)
        case (.day, .high): return Color(red: 0.37, green: 0.50, blue: 0.93)
        case (.night, .veryLow): return Color(red: 0.39, green: 0.50, blue: 0.90)
        case (.night, .low): return Color(red: 0.44, green: 0.76, blue: 0.58)
        case (.night, .medium): return Color(red: 0.84, green: 0.72, blue: 0.30)
        case (.night, .good): return Color(red: 0.90, green: 0.56, blue: 0.33)
        case (.night, .high): return Color(red: 0.88, green: 0.43, blue: 0.43)
        }
    }

    private var cardBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.47, green: 0.47, blue: 0.49),
                    Color(red: 0.40, green: 0.40, blue: 0.42)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
    }
}
