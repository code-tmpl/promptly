import Foundation
import Combine
import QuartzCore

/// Controls scroll advancement based on voice activity and user input
@MainActor
public final class VoiceScrollController: ObservableObject, @unchecked Sendable {
    // MARK: - Published Properties

    /// Current scroll offset in points
    @Published public private(set) var scrollOffset: CGFloat = 0

    /// Whether scrolling is currently active
    @Published public private(set) var isScrolling: Bool = false

    // MARK: - Configuration

    /// Scroll speed multiplier (1.0 = normal)
    public var speed: Double = 1.0

    /// Whether scrolling is paused
    public var isPaused: Bool = false {
        didSet {
            if isPaused {
                stopScrolling()
            }
        }
    }

    /// Base scroll rate in points per second at speed 1.0
    public var baseScrollRate: CGFloat = 50.0

    // MARK: - Private Properties

    private var displayLink: CVDisplayLink?
    private var displayLinkSource: DispatchSourceUserDataAdd?
    private var isSpeaking: Bool = false
    private var lastFrameTime: CFTimeInterval = 0
    private var cancellables = Set<AnyCancellable>()

    // Fallback timer for when CVDisplayLink is unavailable
    private var fallbackTimer: Timer?
    private let targetFrameRate: TimeInterval = 1.0 / 60.0

    public init() {}

    // cleanup() must be called before deallocation to stop CVDisplayLink.
    // Swift 6 strict concurrency prevents accessing @MainActor properties in deinit.
    // The PrompterViewModel.stopPrompting() calls stop() synchronously before releasing.

    /// Call this to clean up resources before deallocation.
    /// Must be called from @MainActor context (not async fire-and-forget).
    public func cleanup() {
        stop()
    }

    // MARK: - Public API

    /// Binds the scroll controller to an audio detector
    public func bind(to audioDetector: AudioLevelDetector) {
        audioDetector.$isSpeaking
            .receive(on: RunLoop.main)
            .sink { [weak self] speaking in
                self?.handleSpeakingChange(speaking)
            }
            .store(in: &cancellables)
    }

    /// Starts the scroll controller (prepares for scrolling)
    public func start() {
        // Ready to scroll, will begin when speaking detected
    }

    /// Stops the scroll controller completely
    public func stop() {
        stopScrolling()
        cancellables.removeAll()
    }

    /// Manually scrolls by a delta amount
    public func manualScroll(delta: CGFloat) {
        scrollOffset = max(0, scrollOffset + delta)
    }

    /// Adjusts speed by a delta
    public func adjustSpeed(by delta: Double) {
        speed = max(0.25, min(3.0, speed + delta))
    }

    /// Resets scroll position to zero
    public func reset() {
        scrollOffset = 0
    }

    /// Sets scroll offset to a specific value
    public func setScrollOffset(_ offset: CGFloat) {
        scrollOffset = max(0, offset)
    }

    // MARK: - Private Implementation

    private func handleSpeakingChange(_ speaking: Bool) {
        isSpeaking = speaking

        if speaking && !isPaused {
            startScrolling()
        } else {
            stopScrolling()
        }
    }

    private func startScrolling() {
        guard !isScrolling else { return }
        isScrolling = true
        lastFrameTime = CACurrentMediaTime()

        // Try to use CVDisplayLink for smooth 60fps scrolling
        if !setupDisplayLink() {
            // Fall back to Timer if CVDisplayLink fails
            setupFallbackTimer()
        }
    }

    private func stopScrolling() {
        guard isScrolling else { return }
        isScrolling = false

        teardownDisplayLink()
        teardownFallbackTimer()
    }

    // MARK: - Display Link

    private func setupDisplayLink() -> Bool {
        var displayLinkRef: CVDisplayLink?
        let result = CVDisplayLinkCreateWithActiveCGDisplays(&displayLinkRef)

        guard result == kCVReturnSuccess, let link = displayLinkRef else {
            return false
        }

        displayLink = link

        // Create a dispatch source to handle display link callbacks on main thread
        let source = DispatchSource.makeUserDataAddSource(queue: .main)
        displayLinkSource = source

        source.setEventHandler { [weak self] in
            self?.displayLinkFired()
        }

        source.resume()

        // Set the callback — passRetained to prevent use-after-free.
        // The CVDisplayLink callback runs on a separate thread and can fire
        // even after CVDisplayLinkStop is called (per Apple docs).
        let opaqueSource = Unmanaged.passRetained(source).toOpaque()
        CVDisplayLinkSetOutputCallback(link, { _, _, _, _, _, userInfo -> CVReturn in
            guard let userInfo = userInfo else { return kCVReturnSuccess }
            // takeUnretainedValue — we manage the retain manually in teardown
            let source = Unmanaged<DispatchSourceUserDataAdd>.fromOpaque(userInfo).takeUnretainedValue()
            source.add(data: 1)
            return kCVReturnSuccess
        }, opaqueSource)

        CVDisplayLinkStart(link)
        return true
    }

    private func teardownDisplayLink() {
        if let link = displayLink {
            // Stop first — callback may still fire once more after this
            CVDisplayLinkStop(link)
            // Clear the callback to prevent any more dispatches
            CVDisplayLinkSetOutputCallback(link, nil, nil)
            displayLink = nil
        }

        // Now safe to release the source — no more callbacks can reach it
        if let source = displayLinkSource {
            // Balance the passRetained from setup
            Unmanaged.passUnretained(source).release()
            source.cancel()
            displayLinkSource = nil
        }
    }

    private func displayLinkFired() {
        guard isScrolling, !isPaused, isSpeaking else { return }

        let currentTime = CACurrentMediaTime()
        let deltaTime = currentTime - lastFrameTime
        lastFrameTime = currentTime

        // Calculate scroll amount based on speed and delta time
        let scrollAmount = baseScrollRate * CGFloat(speed) * CGFloat(deltaTime)
        scrollOffset += scrollAmount
    }

    // MARK: - Fallback Timer

    private func setupFallbackTimer() {
        let timer = Timer.scheduledTimer(
            withTimeInterval: targetFrameRate,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.timerFired()
            }
        }
        fallbackTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func teardownFallbackTimer() {
        fallbackTimer?.invalidate()
        fallbackTimer = nil
    }

    private func timerFired() {
        guard isScrolling, !isPaused, isSpeaking else { return }

        let currentTime = CACurrentMediaTime()
        let deltaTime = currentTime - lastFrameTime
        lastFrameTime = currentTime

        // Calculate scroll amount based on speed and delta time
        let scrollAmount = baseScrollRate * CGFloat(speed) * CGFloat(deltaTime)
        scrollOffset += scrollAmount
    }
}

// MARK: - Testing Support

extension VoiceScrollController {
    /// Simulates the speaking state changing for testing
    public func simulateSpeaking(_ speaking: Bool) {
        handleSpeakingChange(speaking)
    }

    /// Advances the scroll by one frame for testing
    public func advanceFrame(deltaTime: TimeInterval = 1.0 / 60.0) {
        guard !isPaused else { return }
        let scrollAmount = baseScrollRate * CGFloat(speed) * CGFloat(deltaTime)
        scrollOffset += scrollAmount
    }
}
