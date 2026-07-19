import Foundation
import ServiceManagement
import OSLog

/// Start-at-login, via `SMAppService` (macOS 13+). No third-party dependency.
enum LoginItem {
    private static let log = Logger(subsystem: "com.nicojan.Quip", category: "LoginItem")

    /// On when registered — including `.requiresApproval`, where the user has
    /// enabled it but still needs to approve Quip in System Settings. Treating
    /// that as on keeps the toggle from silently flipping back off.
    static var isEnabled: Bool {
        switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval: return true
        default: return false
        }
    }

    /// Registered but waiting on the user's approval in System Settings.
    static var needsApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    /// Registers or unregisters the login item. Throws so the caller can tell the
    /// user and re-sync the toggle with reality, instead of leaving it lying.
    static func setEnabled(_ enabled: Bool) throws {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            log.error("Failed to \(enabled ? "register" : "unregister") login item: \(error.localizedDescription)")
            throw error
        }
    }
}
