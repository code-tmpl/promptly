import XCTest
import AppKit
@testable import Promptly

/// Tests for PrompterPanel — the core window that must be invisible to screen share.
@MainActor
final class PrompterPanelTests: XCTestCase {

    // MARK: - Screen Share Invisibility (Core Feature)

    func testSharingTypeIsNoneInNotchMode() {
        let panel = PrompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 100),
            isNotchMode: true
        )

        XCTAssertEqual(panel.sharingType, .none,
                       "Panel must be invisible to screen share — sharingType must be .none")
    }

    func testSharingTypeIsNoneInFloatingMode() {
        let panel = PrompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            isNotchMode: false
        )

        XCTAssertEqual(panel.sharingType, .none,
                       "Panel must be invisible to screen share in floating mode too")
    }

    // MARK: - Panel Configuration

    func testPanelIsTransparent() {
        let panel = PrompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 100),
            isNotchMode: true
        )

        XCTAssertFalse(panel.isOpaque, "Panel should not be opaque")
        XCTAssertEqual(panel.backgroundColor, .clear, "Background should be clear")
    }

    func testPanelLevelIsAboveNormal() {
        let panel = PrompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 100),
            isNotchMode: true
        )

        XCTAssertGreaterThan(panel.level.rawValue, NSWindow.Level.normal.rawValue,
                             "Panel should float above normal windows")
    }

    func testNotchModeIsNotResizable() {
        let panel = PrompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 100),
            isNotchMode: true
        )

        XCTAssertFalse(panel.styleMask.contains(.resizable),
                       "Notch mode should not be resizable")
    }

    func testFloatingModeIsResizable() {
        let panel = PrompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            isNotchMode: false
        )

        XCTAssertTrue(panel.styleMask.contains(.resizable),
                      "Floating mode should be resizable")
    }

    func testFloatingModeHasShadow() {
        let panel = PrompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            isNotchMode: false
        )

        XCTAssertTrue(panel.hasShadow, "Floating mode should have shadow")
    }

    func testNotchModeHasNoShadow() {
        let panel = PrompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 100),
            isNotchMode: true
        )

        XCTAssertFalse(panel.hasShadow, "Notch mode should not have shadow")
    }
}
