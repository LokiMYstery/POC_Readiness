import SwiftUI

@main
struct ReadinessPOCApp: App {
    init() {
        do {
            try ReadinessTextResolver.shared.bootstrap()
        } catch {
            #if DEBUG
            fatalError("Failed to bootstrap readiness copy: \(error.localizedDescription)")
            #else
            NSLog("Failed to bootstrap readiness copy: %@", error.localizedDescription)
            #endif
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
