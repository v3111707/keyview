import Foundation
import ServiceManagement

/// What `LoginItem` needs from macOS. `SMAppService` has it; tests use a stand-in.
protocol LoginItemService {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

extension SMAppService: LoginItemService {}

/// Start at login through macOS Login Items. macOS keeps the state and the user can change it
/// in System Settings, so the app reads it again instead of saving it.
@MainActor
final class LoginItem: ObservableObject {
    @Published private(set) var isEnabled = false
    /// The user turned KeyView off in System Settings → General → Login Items.
    @Published private(set) var needsApproval = false
    /// Error of the last change.
    @Published private(set) var message: String?

    private let service: LoginItemService

    init(service: LoginItemService = SMAppService.mainApp) {
        self.service = service
        refresh()
    }

    /// Reads the state from macOS.
    func refresh() {
        let status = service.status
        isEnabled = status == .enabled
        needsApproval = status == .requiresApproval
    }

    func setEnabled(_ on: Bool) {
        do {
            if on {
                try service.register()
            } else {
                try service.unregister()
            }
            message = nil
        } catch {
            message = error.localizedDescription
        }
        refresh()
    }
}
