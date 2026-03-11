import Foundation
import SwiftUI

/// Runtime state of the active prompter session
@MainActor
@Observable
public final class PrompterState: Sendable {
    /// Whether the prompter is currently active (visible and operational)
    public var isActive: Bool

    /// Whether scrolling is paused (via hover or manual pause)
    public var isPaused: Bool

    /// Current vertical scroll offset in points
    public var scrollOffset: CGFloat

    /// Current scroll speed multiplier
    public var currentSpeed: Double

    /// Whether the countdown is currently running
    public var isCountingDown: Bool

    /// Current countdown value (seconds remaining)
    public var countdownValue: Int

    /// Whether user is currently speaking (audio detected above threshold)
    public var isSpeaking: Bool

    /// Current audio level in decibels
    public var audioLevel: Float

    /// Total content height for progress calculation
    public var totalContentHeight: CGFloat

    /// Visible content height for progress calculation
    public var visibleContentHeight: CGFloat

    /// Progress through the script (0.0 to 1.0)
    public var progress: Double {
        guard totalContentHeight > visibleContentHeight else { return 0 }
        let scrollableHeight = totalContentHeight - visibleContentHeight
        guard scrollableHeight > 0 else { return 0 }
        return min(1.0, max(0.0, Double(scrollOffset / scrollableHeight)))
    }

    /// Whether the script has reached the end
    public var hasReachedEnd: Bool {
        progress >= 0.99
    }

    public init(
        isActive: Bool = false,
        isPaused: Bool = false,
        scrollOffset: CGFloat = 0,
        currentSpeed: Double = 1.0,
        isCountingDown: Bool = false,
        countdownValue: Int = 3,
        isSpeaking: Bool = false,
        audioLevel: Float = -60.0,
        totalContentHeight: CGFloat = 0,
        visibleContentHeight: CGFloat = 0
    ) {
        self.isActive = isActive
        self.isPaused = isPaused
        self.scrollOffset = scrollOffset
        self.currentSpeed = currentSpeed
        self.isCountingDown = isCountingDown
        self.countdownValue = countdownValue
        self.isSpeaking = isSpeaking
        self.audioLevel = audioLevel
        self.totalContentHeight = totalContentHeight
        self.visibleContentHeight = visibleContentHeight
    }

    /// Resets the state to initial values for a new session
    public func reset(countdownSeconds: Int) {
        isActive = false
        isPaused = false
        scrollOffset = 0
        isCountingDown = false
        countdownValue = countdownSeconds
        isSpeaking = false
        audioLevel = -60.0
        totalContentHeight = 0
        visibleContentHeight = 0
    }

    /// Increases speed by a step
    public func speedUp() {
        currentSpeed = min(3.0, currentSpeed + 0.25)
    }

    /// Decreases speed by a step
    public func slowDown() {
        currentSpeed = max(0.25, currentSpeed - 0.25)
    }

    /// Toggles the paused state
    public func togglePause() {
        isPaused.toggle()
    }
}

// MARK: - PrompterState Snapshot for Thread Safety

/// An immutable snapshot of the prompter state for thread-safe access
public struct PrompterStateSnapshot: Sendable {
    public let isActive: Bool
    public let isPaused: Bool
    public let scrollOffset: CGFloat
    public let currentSpeed: Double
    public let isCountingDown: Bool
    public let countdownValue: Int
    public let isSpeaking: Bool
    public let audioLevel: Float
    public let progress: Double
    public let hasReachedEnd: Bool

    @MainActor
    public init(from state: PrompterState) {
        self.isActive = state.isActive
        self.isPaused = state.isPaused
        self.scrollOffset = state.scrollOffset
        self.currentSpeed = state.currentSpeed
        self.isCountingDown = state.isCountingDown
        self.countdownValue = state.countdownValue
        self.isSpeaking = state.isSpeaking
        self.audioLevel = state.audioLevel
        self.progress = state.progress
        self.hasReachedEnd = state.hasReachedEnd
    }
}
