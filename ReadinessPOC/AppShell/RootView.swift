import SwiftUI

/// 应用根视图
struct RootView: View {
    @StateObject private var viewModel = ReadinessViewModel()

    var body: some View {
        NavigationStack {
            ReadinessOverviewView(viewModel: viewModel)
        }
    }
}
