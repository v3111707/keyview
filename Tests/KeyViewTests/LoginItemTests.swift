import Foundation
import ServiceManagement
import Testing
@testable import KeyView

/// Stands in for macOS Login Items, so tests do not touch the real ones.
private final class FakeLoginItems: LoginItemService {
    var status: SMAppService.Status = .notRegistered
    var calls: [String] = []
    var failure: Error?

    func register() throws {
        calls.append("register")
        if let failure { throw failure }
        status = .enabled
    }

    func unregister() throws {
        calls.append("unregister")
        if let failure { throw failure }
        status = .notRegistered
    }
}

private struct NotAllowed: LocalizedError {
    var errorDescription: String? { "Not allowed" }
}

@MainActor
struct LoginItemTests {
    @Test func readsStateFromMacOS() {
        let service = FakeLoginItems()
        let item = LoginItem(service: service)
        #expect(item.isEnabled == false)
        #expect(item.needsApproval == false)

        service.status = .enabled // turned on elsewhere
        item.refresh()
        #expect(item.isEnabled)

        service.status = .requiresApproval // turned off in System Settings
        item.refresh()
        #expect(item.isEnabled == false)
        #expect(item.needsApproval)
    }

    @Test func checkboxRegistersAndUnregisters() {
        let service = FakeLoginItems()
        let item = LoginItem(service: service)

        item.setEnabled(true)
        #expect(item.isEnabled)
        item.setEnabled(false)
        #expect(item.isEnabled == false)
        #expect(service.calls == ["register", "unregister"])
        #expect(item.message == nil)
    }

    @Test func failureLeavesItOffAndShowsMessage() {
        let service = FakeLoginItems()
        service.failure = NotAllowed()
        let item = LoginItem(service: service)

        item.setEnabled(true)
        #expect(item.isEnabled == false)
        #expect(item.message == "Not allowed")

        service.failure = nil
        item.setEnabled(true)
        #expect(item.isEnabled)
        #expect(item.message == nil)
    }
}
