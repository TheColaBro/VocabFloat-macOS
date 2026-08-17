import Foundation

enum Logger {
    @inlinable
    static func debug(_ message: @autoclosure () -> String) {
        #if DEBUG
        Swift.print("DEBUG: \(message())")
        #endif
    }
}
