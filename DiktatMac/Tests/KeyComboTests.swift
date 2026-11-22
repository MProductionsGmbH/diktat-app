import AppKit
import Carbon.HIToolbox
import XCTest

final class KeyComboTests: XCTestCase {
    private func combo(_ key: Int, _ modifiers: NSEvent.ModifierFlags) -> KeyCombo {
        KeyCombo(keyCode: UInt32(key), modifierFlags: modifiers.rawValue, keyLabel: "")
    }

    /// Command-V as Diktat's global shortcut would stop pasting everywhere.
    func testShortcutsEveryAppUsesAreReserved() {
        XCTAssertTrue(combo(kVK_ANSI_V, .command).isReserved)
        XCTAssertTrue(combo(kVK_ANSI_C, .command).isReserved)
        XCTAssertTrue(combo(kVK_ANSI_Q, .command).isReserved)
        XCTAssertTrue(combo(kVK_ANSI_Z, [.command, .shift]).isReserved)
        XCTAssertTrue(combo(kVK_Space, .command).isReserved)
        XCTAssertTrue(combo(kVK_Tab, .command).isReserved)
    }

    func testOtherShortcutsStayFree() {
        XCTAssertFalse(combo(kVK_ANSI_V, [.command, .option]).isReserved)
        XCTAssertFalse(combo(kVK_ANSI_V, [.control, .option]).isReserved)
        XCTAssertFalse(combo(kVK_ANSI_D, .command).isReserved)
        XCTAssertFalse(combo(kVK_F5, []).isReserved)
        XCTAssertFalse(combo(kVK_Space, [.control, .option]).isReserved)
    }
}
