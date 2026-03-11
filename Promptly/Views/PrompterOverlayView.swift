import SwiftUI

/// SwiftUI view for the scrolling prompter text overlay
public struct PrompterOverlayView: View {
    let script: Script
    let state: PrompterState
    let settings: AppSettings
    let onContentHeightChanged: ((CGFloat) -> Void)?

    @State private var contentHeight: CGFloat = 0
    @State private var isMirrored: Bool = false
    @State private var showSpeedChangeIndicator: Bool = false
    @State private var lastSpeed: Double = 1.0

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
                        .transition(.opacity.combined(with: .scale))
                } else {
                    scrollingTextView(in: geometry)
                        .scaleEffect(x: isMirrored ? -1 : 1, y: 1)
                }

                // Edge gradients for smooth fade in/out
                if !state.isCountingDown {
                    VStack(spacing: 0) {
                        // Top gradient fade
                        LinearGradient(
                            colors: [
                                settings.backgroundSwiftUIColor.opacity(settings.backgroundOpacity),
                                settings.backgroundSwiftUIColor.opacity(settings.backgroundOpacity * 0.7),
                                settings.backgroundSwiftUIColor.opacity(0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: geometry.size.height * 0.2)

                        Spacer()

                        // Bottom gradient fade
                        LinearGradient(
                            colors: [
                                settings.backgroundSwiftUIColor.opacity(0),
                                settings.backgroundSwiftUIColor.opacity(settings.backgroundOpacity * 0.7),
                                settings.backgroundSwiftUIColor.opacity(settings.backgroundOpacity)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: geometry.size.height * 0.25)
                    }
                    .allowsHitTesting(false)
                }

                // Overlay indicators
                VStack {
                    Spacer()
                    overlayIndicators
                }

                // Speed change indicator (haptic-style visual feedback)
                if showSpeedChangeIndicator {
                    speedChangePopup
                        .transition(.scale.combined(with: .opacity))
                }

                // Pause indicator
                if state.isPaused && !state.isCountingDown {
                    pauseIndicator
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }

                // Mirror mode toggle button
                if !state.isCountingDown {
                    VStack {
                        HStack {
                            Spacer()
                            mirrorToggleButton
                        }
                        .padding(.top, 8)
                        .padding(.trailing, 8)
                        Spacer()
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: state.isPaused)
            .animation(.easeInOut(duration: 0.3), value: state.isCountingDown)
            .onAppear {
                state.visibleContentHeight = geometry.size.height
                lastSpeed = state.currentSpeed
            }
            .onChange(of: geometry.size.height) { _, newHeight in
                state.visibleContentHeight = newHeight
            }
            .onChange(of: state.currentSpeed) { oldSpeed, newSpeed in
                if oldSpeed != newSpeed {
                    showSpeedFeedback()
                }
            }
        }
    }

    private func showSpeedFeedback() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            showSpeedChangeIndicator = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.2)) {
                showSpeedChangeIndicator = false
            }
        }
    }

    // MARK: - Mirror Toggle Button

    private var mirrorToggleButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                isMirrored.toggle()
            }
        }) {
            Image(systemName: isMirrored ? "arrow.left.and.right.righttriangle.left.righttriangle.right.fill" : "arrow.left.and.right.righttriangle.left.righttriangle.right")
                .font(.system(size: 14))
                .foregroundStyle(settings.textSwiftUIColor.opacity(0.7))
                .padding(8)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                )
        }
        .buttonStyle(.plain)
        .help("Mirror text for physical teleprompter")
    }

    // MARK: - Speed Change Popup

    private var speedChangePopup: some View {
        VStack(spacing: 4) {
            Image(systemName: state.currentSpeed > lastSpeed ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .font(.system(size: 32))
            Text(String(format: "%.1fx", state.currentSpeed))
                .font(.system(size: 24, weight: .bold, design: .rounded))
        }
        .foregroundStyle(settings.textSwiftUIColor)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        )
        .onAppear {
            lastSpeed = state.currentSpeed
        }
    }

    // MARK: - Countdown View

    private var countdownView: some View {
        VStack(spacing: 16) {
            Text("\(state.countdownValue)")
                .font(.system(size: 120, weight: .bold, design: .rounded))
                .foregroundStyle(settings.textSwiftUIColor)
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                .contentTransition(.numericText(countsDown: true))
                .scaleEffect(countdownScale)
                .opacity(countdownOpacity)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: state.countdownValue)

            Text("Get ready...")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundStyle(settings.textSwiftUIColor.opacity(0.7))
                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)

            // Countdown progress ring
            ZStack {
                Circle()
                    .stroke(settings.textSwiftUIColor.opacity(0.2), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: countdownProgress)
                    .stroke(settings.textSwiftUIColor.opacity(0.8), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: state.countdownValue)
            }
            .frame(width: 60, height: 60)
        }
    }

    private var countdownScale: CGFloat {
        // Pulse effect on each countdown tick
        1.0 + (0.1 * sin(Double(state.countdownValue) * .pi))
    }

    private var countdownOpacity: Double {
        // Slight fade as countdown progresses
        0.8 + (0.2 * Double(state.countdownValue) / 10.0)
    }

    private var countdownProgress: Double {
        // Progress based on initial countdown value (assume max 10)
        let maxCountdown = 10.0
        return Double(state.countdownValue) / maxCountdown
    }

    // MARK: - Scrolling Text

    private func scrollingTextView(in geometry: GeometryProxy) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .center, spacing: 0) {
                    // Top padding for initial positioning
                    Color.clear
                        .frame(height: geometry.size.height * 0.4)
                        .id("top")

                    // Script content with line-by-line rendering for highlighting
                    scriptContentView(in: geometry)
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

    private func scriptContentView(in geometry: GeometryProxy) -> some View {
        let lines = script.content.components(separatedBy: .newlines)
        let lineHeight = settings.fontSize * 1.5

        return VStack(alignment: .center, spacing: settings.fontSize * 0.3) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                Text(line.isEmpty ? " " : line)
                    .font(.system(size: settings.fontSize, weight: .medium))
                    .foregroundStyle(lineColor(for: index, lineHeight: lineHeight, viewportHeight: geometry.size.height))
                    .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .id("line_\(index)")
            }
        }
    }

    private func lineColor(for lineIndex: Int, lineHeight: CGFloat, viewportHeight: CGFloat) -> Color {
        // Calculate the position of this line relative to the viewport center
        let lineY = CGFloat(lineIndex) * lineHeight * 1.3  // Account for line spacing
        let scrolledLineY = lineY - state.scrollOffset
        let viewportCenter = viewportHeight * 0.4  // Where the "reading line" is

        // Distance from center (normalized)
        let distanceFromCenter = abs(scrolledLineY - viewportCenter)
        let maxDistance = viewportHeight * 0.5

        // Lines near center are brighter
        let brightness = 1.0 - min(distanceFromCenter / maxDistance, 0.6)

        return settings.textSwiftUIColor.opacity(0.4 + brightness * 0.6)
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
                .shadow(color: state.isSpeaking ? .green.opacity(0.5) : .clear, radius: 4)
                .animation(.easeInOut(duration: 0.15), value: state.isSpeaking)

            // Audio level bars
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(audioLevelColor(for: index))
                    .frame(width: 3, height: audioLevelHeight(for: index))
                    .animation(.easeOut(duration: 0.1), value: state.audioLevel)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
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
            .font(.system(.caption, design: .rounded))
            .fontWeight(.semibold)
            .monospacedDigit()
            .foregroundStyle(settings.textSwiftUIColor.opacity(0.8))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: state.currentSpeed)
    }

    private var progressIndicator: some View {
        HStack(spacing: 6) {
            Text(String(format: "%.0f%%", state.progress * 100))
                .font(.system(.caption, design: .rounded))
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(settings.textSwiftUIColor.opacity(0.8))

            ZStack {
                Circle()
                    .stroke(settings.textSwiftUIColor.opacity(0.2), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: state.progress)
                    .stroke(
                        settings.textSwiftUIColor.opacity(0.8),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.3), value: state.progress)
            }
            .frame(width: 14, height: 14)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        )
    }

    // MARK: - Pause Indicator

    private var pauseIndicator: some View {
        VStack(spacing: 12) {
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(settings.textSwiftUIColor.opacity(0.9))
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

            Text("Paused")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(settings.textSwiftUIColor.opacity(0.9))
                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)

            Text("Move mouse away to resume")
                .font(.subheadline)
                .foregroundStyle(settings.textSwiftUIColor.opacity(0.6))
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        )
    }
}
