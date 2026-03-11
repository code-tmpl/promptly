import SwiftUI

/// SwiftUI view for the scrolling prompter text overlay
public struct PrompterOverlayView: View {
    let script: Script
    let state: PrompterState
    let settings: AppSettings
    let onContentHeightChanged: ((CGFloat) -> Void)?

    @State private var contentHeight: CGFloat = 0

    public init(
        script: Script,
        state: PrompterState,
        settings: AppSettings,
        onContentHeightChanged: ((CGFloat) -> Void)? = nil
    ) {
        self.script = script
        self.state = state
        self.settings = settings
        self.onContentHeightChanged = onContentHeightChanged
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                settings.backgroundSwiftUIColor
                    .opacity(settings.backgroundOpacity)

                // Content
                if state.isCountingDown {
                    countdownView
                } else {
                    scrollingTextView(in: geometry)
                }

                // Overlay indicators
                VStack {
                    Spacer()
                    overlayIndicators
                }

                // Pause indicator
                if state.isPaused && !state.isCountingDown {
                    pauseIndicator
                }
            }
            .onAppear {
                state.visibleContentHeight = geometry.size.height
            }
            .onChange(of: geometry.size.height) { _, newHeight in
                state.visibleContentHeight = newHeight
            }
        }
    }

    // MARK: - Countdown View

    private var countdownView: some View {
        VStack(spacing: 8) {
            Text("\(state.countdownValue)")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundStyle(settings.textSwiftUIColor)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: state.countdownValue)

            Text("Get ready...")
                .font(.title3)
                .foregroundStyle(settings.textSwiftUIColor.opacity(0.7))
        }
    }

    // MARK: - Scrolling Text

    private func scrollingTextView(in geometry: GeometryProxy) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Top padding for initial positioning
                    Color.clear
                        .frame(height: geometry.size.height * 0.4)
                        .id("top")

                    // Script content
                    Text(script.content)
                        .font(.system(size: settings.fontSize, weight: .medium))
                        .foregroundStyle(settings.textSwiftUIColor)
                        .lineSpacing(settings.fontSize * 0.3)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 24)
                        .background(
                            GeometryReader { textGeometry in
                                Color.clear
                                    .onAppear {
                                        contentHeight = textGeometry.size.height
                                        onContentHeightChanged?(contentHeight + geometry.size.height)
                                    }
                                    .onChange(of: textGeometry.size.height) { _, newHeight in
                                        contentHeight = newHeight
                                        onContentHeightChanged?(newHeight + geometry.size.height)
                                    }
                            }
                        )

                    // Bottom padding
                    Color.clear
                        .frame(height: geometry.size.height * 0.6)
                        .id("bottom")
                }
            }
            .scrollDisabled(true)
            .offset(y: -state.scrollOffset)
        }
    }

    // MARK: - Overlay Indicators

    private var overlayIndicators: some View {
        HStack(spacing: 16) {
            // Voice indicator
            voiceIndicator

            Spacer()

            // Speed indicator
            if settings.showSpeedIndicator {
                speedIndicator
            }

            // Progress indicator
            if settings.showProgressIndicator {
                progressIndicator
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var voiceIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(state.isSpeaking ? Color.green : Color.gray.opacity(0.5))
                .frame(width: 8, height: 8)

            // Audio level bars
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(audioLevelColor(for: index))
                    .frame(width: 3, height: audioLevelHeight(for: index))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
        )
    }

    private func audioLevelColor(for index: Int) -> Color {
        let normalizedLevel = normalizedAudioLevel
        let threshold = Double(index) / 5.0
        return normalizedLevel > threshold ? .green : .gray.opacity(0.3)
    }

    private func audioLevelHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 6
        let maxHeight: CGFloat = 16
        let normalizedLevel = normalizedAudioLevel
        let threshold = Double(index) / 5.0

        if normalizedLevel > threshold {
            return baseHeight + (maxHeight - baseHeight) * CGFloat(min(1, (normalizedLevel - threshold) * 2))
        }
        return baseHeight
    }

    private var normalizedAudioLevel: Double {
        // Convert dB to 0-1 range (assuming -60 to 0 dB range)
        let minDB: Float = -60
        let maxDB: Float = 0
        let clampedLevel = max(minDB, min(maxDB, state.audioLevel))
        return Double((clampedLevel - minDB) / (maxDB - minDB))
    }

    private var speedIndicator: some View {
        Text(String(format: "%.1fx", state.currentSpeed))
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(settings.textSwiftUIColor.opacity(0.8))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
            )
    }

    private var progressIndicator: some View {
        HStack(spacing: 4) {
            Text(String(format: "%.0f%%", state.progress * 100))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(settings.textSwiftUIColor.opacity(0.8))

            Circle()
                .trim(from: 0, to: state.progress)
                .stroke(settings.textSwiftUIColor.opacity(0.8), lineWidth: 2)
                .rotationEffect(.degrees(-90))
                .frame(width: 12, height: 12)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Pause Indicator

    private var pauseIndicator: some View {
        VStack(spacing: 8) {
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(settings.textSwiftUIColor.opacity(0.9))

            Text("Paused")
                .font(.headline)
                .foregroundStyle(settings.textSwiftUIColor.opacity(0.8))

            Text("Move mouse away to resume")
                .font(.caption)
                .foregroundStyle(settings.textSwiftUIColor.opacity(0.6))
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
}

