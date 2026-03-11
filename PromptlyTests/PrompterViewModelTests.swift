import XCTest
@testable import Promptly
import AVFoundation

/// Tests for PrompterViewModel covering start/stop/pause/speed/countdown/errors
@MainActor
final class PrompterViewModelTests: XCTestCase {
    var scriptStore: ScriptStore!
    var settingsManager: SettingsManager!
    var audioDetector: AudioLevelDetector!
    var scrollController: VoiceScrollController!
    var viewModel: PrompterViewModel!

    override func setUp() async throws {
        try await super.setUp()
        scriptStore = ScriptStore.forTesting()
        settingsManager = SettingsManager.forTesting()
        audioDetector = AudioLevelDetector()
        scrollController = VoiceScrollController()
        viewModel = PrompterViewModel(
            scriptStore: scriptStore,
            settingsManager: settingsManager,
            audioDetector: audioDetector,
            scrollController: scrollController
        )
    }

    override func tearDown() async throws {
        viewModel.stopPrompting()
        viewModel = nil
        scrollController = nil
        audioDetector = nil
        settingsManager = nil
        scriptStore = nil
        try await super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        XCTAssertFalse(viewModel.state.isActive, "Should not be active initially")
        XCTAssertFalse(viewModel.state.isPaused, "Should not be paused initially")
        XCTAssertFalse(viewModel.state.isCountingDown, "Should not be counting down initially")
        XCTAssertEqual(viewModel.state.scrollOffset, 0, "Scroll offset should be zero")
        XCTAssertEqual(viewModel.state.currentSpeed, settingsManager.scrollSpeed, "Speed should match settings")
    }

    func testCurrentScriptReturnsSelectedScript() {
        scriptStore.createScript(title: "Test Script", content: "Test content")
        XCTAssertNotNil(viewModel.currentScript)
        XCTAssertEqual(viewModel.currentScript?.title, "Test Script")
    }

    // MARK: - Start/Stop Tests

    func testStartPromptingWithNoScriptShowsError() {
        // Ensure no script selected
        scriptStore.currentScript = nil

        viewModel.startPrompting()

        XCTAssertTrue(viewModel.showErrorAlert, "Should show error alert")
        XCTAssertEqual(viewModel.currentError, .noScriptSelected)
    }

    func testStartPromptingWithEmptyScriptShowsError() {
        scriptStore.createScript(title: "Empty", content: "")

        viewModel.startPrompting()

        XCTAssertTrue(viewModel.showErrorAlert, "Should show error alert")
        XCTAssertEqual(viewModel.currentError, .emptyScript)
    }

    func testStopPromptingResetsState() {
        scriptStore.createScript(title: "Test", content: "Some content here")
        viewModel.state.isActive = true
        viewModel.state.isCountingDown = true
        viewModel.state.scrollOffset = 100

        viewModel.stopPrompting()

        XCTAssertFalse(viewModel.state.isActive, "Should not be active after stopping")
        XCTAssertFalse(viewModel.state.isCountingDown, "Should not be counting down after stopping")
    }

    // MARK: - Pause/Resume Tests

    func testPauseSetsStateCorrectly() {
        viewModel.pause()

        XCTAssertTrue(viewModel.state.isPaused, "State should be paused")
        XCTAssertTrue(scrollController.isPaused, "Scroll controller should be paused")
    }

    func testResumeSetsStateCorrectly() {
        viewModel.pause()
        viewModel.resume()

        XCTAssertFalse(viewModel.state.isPaused, "State should not be paused")
        XCTAssertFalse(scrollController.isPaused, "Scroll controller should not be paused")
    }

    func testTogglePauseFromUnpausedToPaused() {
        XCTAssertFalse(viewModel.state.isPaused)

        viewModel.togglePause()

        XCTAssertTrue(viewModel.state.isPaused)
    }

    func testTogglePauseFromPausedToUnpaused() {
        viewModel.pause()
        XCTAssertTrue(viewModel.state.isPaused)

        viewModel.togglePause()

        XCTAssertFalse(viewModel.state.isPaused)
    }

    // MARK: - Speed Control Tests

    func testSpeedUpIncreasesSpeed() {
        let initialSpeed = viewModel.state.currentSpeed

        viewModel.speedUp()

        XCTAssertGreaterThan(viewModel.state.currentSpeed, initialSpeed)
        XCTAssertEqual(scrollController.speed, viewModel.state.currentSpeed)
    }

    func testSlowDownDecreasesSpeed() {
        viewModel.state.currentSpeed = 1.5
        scrollController.speed = 1.5
        let initialSpeed = viewModel.state.currentSpeed

        viewModel.slowDown()

        XCTAssertLessThan(viewModel.state.currentSpeed, initialSpeed)
        XCTAssertEqual(scrollController.speed, viewModel.state.currentSpeed)
    }

    func testSpeedUpClampsToMaximum() {
        viewModel.state.currentSpeed = 3.0

        viewModel.speedUp()

        XCTAssertLessThanOrEqual(viewModel.state.currentSpeed, 3.0, "Speed should not exceed maximum")
    }

    func testSlowDownClampsToMinimum() {
        viewModel.state.currentSpeed = 0.25

        viewModel.slowDown()

        XCTAssertGreaterThanOrEqual(viewModel.state.currentSpeed, 0.25, "Speed should not go below minimum")
    }

    // MARK: - Scroll Control Tests

    func testResetScrollSetsOffsetToZero() {
        viewModel.state.scrollOffset = 500
        scrollController.setScrollOffset(500)

        viewModel.resetScroll()

        XCTAssertEqual(viewModel.state.scrollOffset, 0)
    }

    func testManualScrollDelegatesCorrectly() {
        scrollController.setScrollOffset(100)

        viewModel.manualScroll(delta: 50)

        XCTAssertEqual(scrollController.scrollOffset, 150)
    }

    // MARK: - Error Handling Tests

    func testShowErrorSetsProperties() {
        viewModel.showError(.noScriptSelected)

        XCTAssertTrue(viewModel.showErrorAlert)
        XCTAssertEqual(viewModel.currentError, .noScriptSelected)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testClearErrorResetsProperties() {
        viewModel.showError(.noScriptSelected)

        viewModel.clearError()

        XCTAssertFalse(viewModel.showErrorAlert)
        XCTAssertNil(viewModel.currentError)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testPrompterErrorEquality() {
        XCTAssertEqual(PrompterError.noScriptSelected, PrompterError.noScriptSelected)
        XCTAssertNotEqual(PrompterError.noScriptSelected, PrompterError.emptyScript)
        XCTAssertEqual(
            PrompterError.audioEngineFailure("test"),
            PrompterError.audioEngineFailure("test")
        )
    }

    func testPrompterErrorDescriptions() {
        XCTAssertNotNil(PrompterError.noScriptSelected.errorDescription)
        XCTAssertNotNil(PrompterError.emptyScript.errorDescription)
        XCTAssertNotNil(PrompterError.microphonePermissionDenied.errorDescription)
        XCTAssertNotNil(PrompterError.audioEngineFailure("test").errorDescription)
        XCTAssertNotNil(PrompterError.scriptSaveFailure("test").errorDescription)
    }

    func testPrompterErrorRecoverySuggestions() {
        XCTAssertNotNil(PrompterError.noScriptSelected.recoverySuggestion)
        XCTAssertNotNil(PrompterError.emptyScript.recoverySuggestion)
        XCTAssertNotNil(PrompterError.microphonePermissionDenied.recoverySuggestion)
        XCTAssertNotNil(PrompterError.audioEngineFailure("test").recoverySuggestion)
        XCTAssertNotNil(PrompterError.scriptSaveFailure("test").recoverySuggestion)
    }

    func testCanOpenSettingsOnlyForMicPermissionError() {
        XCTAssertTrue(PrompterError.microphonePermissionDenied.canOpenSettings)
        XCTAssertFalse(PrompterError.noScriptSelected.canOpenSettings)
        XCTAssertFalse(PrompterError.emptyScript.canOpenSettings)
        XCTAssertFalse(PrompterError.audioEngineFailure("test").canOpenSettings)
        XCTAssertFalse(PrompterError.scriptSaveFailure("test").canOpenSettings)
    }

    // MARK: - Mode Toggle Tests

    func testToggleModeChangesPreferredMode() {
        settingsManager.preferredMode = .notch

        viewModel.toggleMode()

        XCTAssertEqual(settingsManager.preferredMode, .floating)
    }

    func testToggleModeFromFloatingToNotch() {
        settingsManager.preferredMode = .floating

        viewModel.toggleMode()

        XCTAssertEqual(settingsManager.preferredMode, .notch)
    }

    // MARK: - Keyboard Shortcut Tests

    func testHandleStartStopShortcutTogglesPrompting() {
        scriptStore.createScript(title: "Test", content: "Content")
        XCTAssertFalse(viewModel.state.isActive)

        // Can't fully test start (needs mic permission) but can test the shortcut routes correctly
        viewModel.state.isActive = true
        viewModel.handleKeyboardShortcut(.startStop)

        XCTAssertFalse(viewModel.state.isActive, "Should stop when active")
    }

    func testHandlePauseResumeShortcut() {
        XCTAssertFalse(viewModel.state.isPaused)

        viewModel.handleKeyboardShortcut(.pauseResume)

        XCTAssertTrue(viewModel.state.isPaused)
    }

    func testHandleSpeedUpShortcut() {
        let initialSpeed = viewModel.state.currentSpeed

        viewModel.handleKeyboardShortcut(.speedUp)

        XCTAssertGreaterThan(viewModel.state.currentSpeed, initialSpeed)
    }

    func testHandleSpeedDownShortcut() {
        viewModel.state.currentSpeed = 1.5
        let initialSpeed = viewModel.state.currentSpeed

        viewModel.handleKeyboardShortcut(.speedDown)

        XCTAssertLessThan(viewModel.state.currentSpeed, initialSpeed)
    }

    func testHandleToggleModeShortcut() {
        let initialMode = settingsManager.preferredMode

        viewModel.handleKeyboardShortcut(.toggleMode)

        XCTAssertNotEqual(settingsManager.preferredMode, initialMode)
    }

    // MARK: - State Integration Tests

    func testStateProgressCalculation() {
        viewModel.state.totalContentHeight = 1000
        viewModel.state.visibleContentHeight = 200
        viewModel.state.scrollOffset = 400

        // Progress = scrollOffset / (totalContentHeight - visibleContentHeight)
        // = 400 / 800 = 0.5
        XCTAssertEqual(viewModel.state.progress, 0.5, accuracy: 0.01)
    }

    func testStateHasReachedEnd() {
        viewModel.state.totalContentHeight = 1000
        viewModel.state.visibleContentHeight = 200
        viewModel.state.scrollOffset = 800  // At the end

        XCTAssertTrue(viewModel.state.hasReachedEnd)
    }
}
