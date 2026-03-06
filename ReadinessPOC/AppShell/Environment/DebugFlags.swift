import Foundation

/// Debug 开关
enum DebugFlags {
    #if DEBUG
    static let isDebugBuild = true
    #else
    static let isDebugBuild = false
    #endif
}
