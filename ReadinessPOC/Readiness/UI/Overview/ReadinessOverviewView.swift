import SwiftUI

struct ReadinessOverviewView: View {
    @ObservedObject var viewModel: ReadinessViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                headerSection

                if viewModel.isLoading {
                    ProgressView("加载中...")
                        .padding(.top, 60)
                } else if let result = viewModel.result {
                    ReadinessHeroCardView(result: result)

                    Text(result.text.summaryLine)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 18)

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

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm 更新"
        return formatter.string(from: viewModel.result?.timestamp ?? .now)
    }
}
