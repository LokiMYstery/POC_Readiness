import SwiftUI

/// 总览页
struct ReadinessOverviewView: View {
    @ObservedObject var viewModel: ReadinessViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 顶部标题
                headerSection

                if viewModel.isLoading {
                    ProgressView("加载中...")
                        .padding(.top, 60)
                } else if let result = viewModel.result {
                    // 圆环
                    ringSection(result)

                    // 解释
                    explanationSection(result)

                    // 三张证据卡
                    cardsSection(result)

                    // 缺失提示
                    if let hint = result.text.missingHint {
                        missingHintBar(hint)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear {
            viewModel.load()
        }
        .refreshable {
            viewModel.refresh()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("就绪度")
                    .font(.largeTitle.weight(.bold))

                if let result = viewModel.result {
                    HStack(spacing: 6) {
                        Text(result.mode.displayName)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(result.mode == .day ? Color.orange : Color.indigo)
                            )

                        Text(timeString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            #if DEBUG
            NavigationLink {
                DebugPanelView(viewModel: viewModel)
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            #endif
        }
        .padding(.top, 10)
    }

    // MARK: - Ring

    private func ringSection(_ result: ReadinessResult) -> some View {
        RingChartView(
            subScores: result.subScores,
            overallScore: result.overallScore
        )
        .padding(.vertical, 10)
    }

    // MARK: - Explanation

    private func explanationSection(_ result: ReadinessResult) -> some View {
        Text(result.text.overviewSentence)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
    }

    // MARK: - Cards

    private func cardsSection(_ result: ReadinessResult) -> some View {
        VStack(spacing: 12) {
            // 图例
            HStack(spacing: 16) {
                ForEach(result.subScores) { sub in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(legendColor(sub.id))
                            .frame(width: 8, height: 8)
                        Text("\(sub.id.displayName) \(Int(sub.contributionPercent))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.bottom, 4)

            // 卡片
            let explanations = [
                FactorKind.circadian: result.text.circadianExplanation,
                FactorKind.activity:  result.text.activityExplanation,
                FactorKind.recovery:  result.text.recoveryExplanation,
            ]

            ForEach(FactorKind.allCases) { kind in
                let sub = result.subScores.first { $0.id == kind }
                let isAvailable = sub?.availability.isAvailable ?? false
                let expl = explanations[kind] ?? ""

                NavigationLink {
                    detailView(for: kind, result: result)
                } label: {
                    FactorCardView(
                        factorKind: kind,
                        subScore: sub,
                        explanation: expl,
                        isAvailable: isAvailable
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Missing Hint

    private func missingHintBar(_ hint: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundColor(.orange)
            Text(hint)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.08))
        )
    }

    // MARK: - Detail Navigation

    @ViewBuilder
    private func detailView(for kind: FactorKind, result: ReadinessResult) -> some View {
        let sub = result.subScores.first { $0.id == kind }
        switch kind {
        case .circadian:
            CircadianDetailView(
                subScore: sub,
                inputs: viewModel.effectiveInputs?.circadian,
                global: viewModel.effectiveInputs?.global,
                explanation: result.text.circadianExplanation
            )
        case .activity:
            ActivityDetailView(
                subScore: sub,
                inputs: viewModel.effectiveInputs?.activity,
                mode: result.mode,
                explanation: result.text.activityExplanation
            )
        case .recovery:
            RecoveryDetailView(
                subScore: sub,
                inputs: viewModel.effectiveInputs?.recovery,
                mode: result.mode,
                explanation: result.text.recoveryExplanation
            )
        }
    }

    // MARK: - Helpers

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm 更新"
        return formatter.string(from: viewModel.result?.timestamp ?? .now)
    }

    private func legendColor(_ kind: FactorKind) -> Color {
        switch kind {
        case .circadian: return .orange
        case .activity:  return .green
        case .recovery:  return .blue
        }
    }
}
