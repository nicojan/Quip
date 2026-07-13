import Foundation
import ServiceManagement
import OSLog

/// Start-at-login, via `SMAppService` (macOS 13+). No third-party dependency.
enum LoginItem {
    private static let log = Logger(subsystem: "com.nicojan.Quip", category: "LoginItem")

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            log.error("Failed to \(enabled ? "register" : "unregister") login item: \(error.localizedDescription)")
        }
    }
}
