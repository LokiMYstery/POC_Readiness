import SwiftUI

/// 三段分色圆环图
struct RingChartView: View {
    let subScores: [SubScore]
    let overallScore: Double

    private let ringWidth: CGFloat = 18
    private let ringSize: CGFloat = 200

    var body: some View {
        ZStack {
            // 底部灰色背景环
            Circle()
                .stroke(Color(.systemGray5), lineWidth: ringWidth)
                .frame(width: ringSize, height: ringSize)

            // 分段彩色环
            ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                Circle()
                    .trim(from: segment.start, to: segment.end)
                    .stroke(
                        segment.color,
                        style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                    )
                    .frame(width: ringSize, height: ringSize)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.8).delay(Double(index) * 0.15), value: subScores.count)
            }

            // 中心内容
            VStack(spacing: 4) {
                Text("\(Int(overallScore))")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(scoreGradient)

                Text("就绪度")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - 分段计算

    private struct Segment {
        let start: CGFloat
        let end: CGFloat
        let color: Color
    }

    private var segments: [Segment] {
        guard !subScores.isEmpty else { return [] }

        let totalContrib = subScores.reduce(0.0) { $0 + $1.contributionPercent }
        guard totalContrib > 0 else { return [] }

        let gap: CGFloat = 0.015  // 段间间隙
        var result: [Segment] = []
        var currentStart: CGFloat = 0

        for sub in subScores.sorted(by: { $0.contributionPercent > $1.contributionPercent }) {
            let proportion = CGFloat(sub.contributionPercent / totalContrib)
            let segmentLength = max(proportion - gap, 0.01)
            let end = currentStart + segmentLength

            result.append(Segment(
                start: currentStart,
                end: min(end, 1.0),
                color: color(for: sub.id)
            ))

            currentStart = end + gap
        }

        return result
    }

    private func color(for kind: FactorKind) -> Color {
        switch kind {
        case .circadian: return .orange
        case .activity:  return .green
        case .recovery:  return .blue
        }
    }

    private var scoreGradient: LinearGradient {
        let scoreColor: Color = overallScore >= 70 ? .green :
                                overallScore >= 50 ? .orange : .red
        return LinearGradient(
            colors: [scoreColor, scoreColor.opacity(0.7)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
