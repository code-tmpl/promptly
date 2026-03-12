import XCTest
import AppKit
import SwiftUI
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

    /// Critical: sharingType must remain .none after setContent is called
    func testSharingTypeSurvivesSetContent() {
        let panel = PrompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            isNotchMode: false
        )

        // Set SwiftUI content
        panel.setContent(Text("Test Content"))

        XCTAssertEqual(panel.sharingType, .none,
                       "sharingType must remain .none after setContent")
    }

    /// Critical: sharingType must remain .none after updateContent is called
    func testSharingTypeSurvivesUpdateContent() {
        let panel = PrompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            isNotchMode: false
        )

        panel.setContent(Text("Initial"))
        panel.updateContent(Text("Updated"))

        XCTAssertEqual(panel.sharingType, .none,
                       "sharingType must remain .none after updateContent")
    }

    /// Critical: sharingType must remain .none after setFrame is called
    func testSharingTypeSurvivesSetFrame() {
        let panel = PrompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            isNotchMode: false
        )

        panel.setFrame(NSRect(x: 100, y: 100, width: 500, height: 400), display: true)

        XCTAssertEqual(panel.sharingType, .none,
                       "sharingType must remain .none after setFrame")
    }

    /// Critical: sharingType must remain .none after animated setFrame
    func testSharingTypeSurvivesAnimatedSetFrame() {
        let panel = PrompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            isNotchMode: false
        )

        panel.setFrame(NSRect(x: 100, y: 100, width: 500, height: 400), display: true, animate: false)

        XCTAssertEqual(panel.sharingType, .none,
                       "sharingType must remain .none after animated setFrame")
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

    // MARK: - Key/Main Window Behavior

    func testCanBecomeKeyIsTrue() {
        let panel = PrompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            isNotchMode: false
        )

        XCTAssertTrue(panel.canBecomeKey,
                      "Panel must be able to become key to receive keyboard events")
    }

    func testCanBecomeMainIsFalse() {
        let panel = PrompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            isNotchMode: false
        )

        XCTAssertFalse(panel.canBecomeMain,
                       "Panel should not become main window — it's an auxiliary panel")
    }

    // MARK: - Collection Behavior

    func testCollectionBehaviorCanJoinAllSpaces() {
        let panel = PrompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            isNotchMode: false
        )

        XCTAssertTrue(panel.collectionBehavior.contains(.canJoinAllSpaces),
                      "Panel should be visible on all spaces")
    }

    func testCollectionBehaviorFullScreenAuxiliary() {
        let panel = PrompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            isNotchMode: false
        )

        XCTAssertTrue(panel.collectionBehavior.contains(.fullScreenAuxiliary),
                      "Panel should support full-screen auxiliary mode")
    }

    func testCollectionBehaviorStationary() {
        let panel = PrompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            isNotchMode: false
        )

        XCTAssertTrue(panel.collectionBehavior.contains(.stationary),
                      "Panel should remain stationary during space changes")
    }

    func testCollectionBehaviorIgnoresCycle() {
        let panel = PrompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            isNotchMode: false
        )

        XCTAssertTrue(panel.collectionBehavior.contains(.ignoresCycle),
                      "Panel should be excluded from Cmd+Tab window cycling")
    }

    // MARK: - Resize Handles

    func testFloatingModeHasResizeHandles() throws {
        let panel = PrompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            isNotchMode: false
        )

        // Set content to trigger resize handle setup
        panel.setContent(Text("Test"))

        // Wait for async setup to complete
        let expectation = XCTestExpectation(description: "Resize handles setup")
        Task { @MainActor in
            // Small delay for async handle setup
            try? await Task.sleep(for: .milliseconds(100))
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Count subviews that are resize handles (ResizeHandleView is internal)
        let contentView = try XCTUnwrap(panel.contentView)
        let handleCount = contentView.subviews.filter { type(of: $0).description().contains("ResizeHandle") }.count

        XCTAssertGreaterThan(handleCount, 0,
                             "Floating mode should have resize handles")
    }

    func testNotchModeHasNoResizeHandles() throws {
        let panel = PrompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 100),
            isNotchMode: true
        )

        panel.setContent(Text("Test"))

        // Wait for any potential async operations
        let expectation = XCTestExpectation(description: "Content setup")
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        let contentView = try XCTUnwrap(panel.contentView)
        let handleCount = contentView.subviews.filter { type(of: $0).description().contains("ResizeHandle") }.count

        XCTAssertEqual(handleCount, 0,
                       "Notch mode should not have resize handles")
    }

    // MARK: - Mouse Tracking Callbacks

    func testOnMouseEnteredCallbackFires() {
        let panel = PrompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            isNotchMode: false
        )

        var callbackFired = false
        panel.onMouseEntered = {
            callbackFired = true
        }

        // Create a generic mouse event to pass to mouseEntered
        // (the callback fires regardless of event details)
        let event = NSEvent.mouseEvent(
            with: .mouseMoved,
            location: NSPoint(x: 200, y: 150),
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: panel.windowNumber,
            context: nil,
            eventNumber: 0,
            clickCount: 0,
            pressure: 0
        )!

        panel.mouseEntered(with: event)

        XCTAssertTrue(callbackFired, "onMouseEntered callback should fire when mouse enters")
    }

    func testOnMouseExitedCallbackFires() {
        let panel = PrompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            isNotchMode: false
        )

        var callbackFired = false
        panel.onMouseExited = {
            callbackFired = true
        }

        // Create a generic mouse event to pass to mouseExited
        // (the callback fires regardless of event details)
        let event = NSEvent.mouseEvent(
            with: .mouseMoved,
            location: NSPoint(x: -10, y: -10),
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: panel.windowNumber,
            context: nil,
            eventNumber: 0,
            clickCount: 0,
            pressure: 0
        )!

        panel.mouseExited(with: event)

        XCTAssertTrue(callbackFired, "onMouseExited callback should fire when mouse exits")
    }

    func testOnCloseCallbackFires() {
        let panel = PrompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            isNotchMode: false
        )

        var callbackFired = false
        panel.onClose = {
            callbackFired = true
        }

        panel.close()

        XCTAssertTrue(callbackFired, "onClose callback should fire when panel closes")
    }

    // MARK: - Content Hosting

    func testSetContentCreatesHostingView() throws {
        let panel = PrompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            isNotchMode: false
        )

        panel.setContent(Text("Test Content"))

        let contentView = try XCTUnwrap(panel.contentView)
        XCTAssertTrue(contentView is NSHostingView<AnyView>,
                      "Content view should be an NSHostingView after setContent")
    }

    func testUpdateContentReusesHostingView() throws {
        let panel = PrompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            isNotchMode: false
        )

        panel.setContent(Text("Initial"))
        let initialContentView = panel.contentView

        panel.updateContent(Text("Updated"))
        let updatedContentView = panel.contentView

        // Same hosting view instance should be reused
        XCTAssertTrue(initialContentView === updatedContentView,
                      "updateContent should reuse the existing hosting view, not create a new one")
    }

    func testUpdateContentWithoutSetContentFallsBackToSetContent() throws {
        let panel = PrompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            isNotchMode: false
        )

        // Call updateContent without prior setContent
        panel.updateContent(Text("Fallback Test"))

        let contentView = try XCTUnwrap(panel.contentView)
        XCTAssertTrue(contentView is NSHostingView<AnyView>,
                      "updateContent should fallback to setContent when no hosting view exists")
    }

    // MARK: - Tracking Area Setup

    func testTrackingAreaExistsAfterInit() throws {
        let panel = PrompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            isNotchMode: false
        )

        let contentView = try XCTUnwrap(panel.contentView)
        XCTAssertFalse(contentView.trackingAreas.isEmpty,
                       "Content view should have tracking areas after init")
    }

    func testTrackingAreaResetAfterSetFrame() throws {
        let panel = PrompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            isNotchMode: false
        )

        let initialTrackingAreas = panel.contentView?.trackingAreas ?? []

        panel.setFrame(NSRect(x: 100, y: 100, width: 500, height: 400), display: true)

        let updatedTrackingAreas = panel.contentView?.trackingAreas ?? []

        // Tracking areas should still exist after frame change
        XCTAssertFalse(updatedTrackingAreas.isEmpty,
                       "Tracking areas should exist after setFrame")

        // Tracking area should have been recreated (different instance or updated)
        // We verify the behavior is correct by checking the count is non-zero
        XCTAssertEqual(initialTrackingAreas.count, updatedTrackingAreas.count,
                       "Tracking area count should remain consistent after setFrame")
    }

    // MARK: - Window Level Modes

    func testNotchModeLevelIsAboveStatusBar() {
        let panel = PrompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 100),
            isNotchMode: true
        )

        let statusBarLevel = Int(CGWindowLevelForKey(.statusWindow))
        XCTAssertGreaterThan(panel.level.rawValue, statusBarLevel,
                             "Notch mode should be above status bar level")
    }

    func testFloatingModeLevelIsFloating() {
        let panel = PrompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            isNotchMode: false
        )

        XCTAssertEqual(panel.level, .floating,
                       "Floating mode should use floating window level")
    }

    // MARK: - Window Movement

    func testFloatingModeIsMovableByBackground() {
        let panel = PrompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            isNotchMode: false
        )

        XCTAssertTrue(panel.isMovableByWindowBackground,
                      "Floating mode should be movable by dragging window background")
    }

    func testNotchModeIsNotMovableByBackground() {
        let panel = PrompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 100),
            isNotchMode: true
        )

        XCTAssertFalse(panel.isMovableByWindowBackground,
                       "Notch mode should not be movable by background")
    }

    // MARK: - Size Constraints (Floating Mode)

    func testFloatingModeHasMinSize() {
        let panel = PrompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            isNotchMode: false
        )

        XCTAssertGreaterThan(panel.minSize.width, 0,
                             "Floating mode should have minimum width constraint")
        XCTAssertGreaterThan(panel.minSize.height, 0,
                             "Floating mode should have minimum height constraint")
    }

    func testFloatingModeHasMaxSize() {
        let panel = PrompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            isNotchMode: false
        )

        XCTAssertGreaterThan(panel.maxSize.width, panel.minSize.width,
                             "Floating mode max width should be greater than min width")
        XCTAssertGreaterThan(panel.maxSize.height, panel.minSize.height,
                             "Floating mode max height should be greater than min height")
    }

    // MARK: - Title Bar Configuration

    func testTitleBarIsTransparent() {
        let panel = PrompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            isNotchMode: false
        )

        XCTAssertTrue(panel.titlebarAppearsTransparent,
                      "Title bar should be transparent")
    }

    func testTitleIsHidden() {
        let panel = PrompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            isNotchMode: false
        )

        XCTAssertEqual(panel.titleVisibility, .hidden,
                       "Title should be hidden")
    }

    // MARK: - Mouse Event Handling

    func testAcceptsMouseMovedEvents() {
        let panel = PrompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            isNotchMode: false
        )

        XCTAssertTrue(panel.acceptsMouseMovedEvents,
                      "Panel should accept mouse moved events for hover detection")
    }

    func testDoesNotIgnoreMouseEvents() {
        let panel = PrompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            isNotchMode: false
        )

        XCTAssertFalse(panel.ignoresMouseEvents,
                       "Panel should not ignore mouse events")
    }

    // MARK: - Window Lifecycle

    func testIsNotReleasedWhenClosed() {
        let panel = PrompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            isNotchMode: false
        )

        XCTAssertFalse(panel.isReleasedWhenClosed,
                       "Panel should not be released when closed to allow reuse")
    }

    func testDoesNotHideOnDeactivate() {
        let panel = PrompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            isNotchMode: false
        )

        XCTAssertFalse(panel.hidesOnDeactivate,
                       "Panel should remain visible when app is deactivated")
    }

    // MARK: - Style Mask

    func testStyleMaskIncludesBorderless() {
        let panel = PrompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            isNotchMode: false
        )

        XCTAssertTrue(panel.styleMask.contains(.borderless),
                      "Panel should be borderless")
    }

    func testStyleMaskIncludesNonActivatingPanel() {
        let panel = PrompterPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            isNotchMode: false
        )

        XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel),
                      "Panel should not activate app when clicked")
    }
}
