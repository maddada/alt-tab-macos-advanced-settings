import Cocoa

class WindowHighlightOverlay {
    private var overlayWindow: NSWindow?
    private var borderView: BorderView?
    private var animationTimer: Timer?

    static let shared = WindowHighlightOverlay()

    private init() {}

    func showBlinkingBorder(for window: Window) {
        // Cancel any existing animation
        cleanup()

        // Get window position and size
        guard let position = window.position,
              let size = window.size else {
            return
        }

        // Create the overlay window
        let overlayFrame = NSRect(origin: position, size: size)
        createOverlayWindow(frame: overlayFrame)

        // Start the blinking animation (1 blink = 2 transitions)
        startBlinkingAnimation(blinkCount: 1)
    }

    private func createOverlayWindow(frame: NSRect) {
        // Create a borderless window
        overlayWindow = NSWindow(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        guard let window = overlayWindow else { return }

        // Configure window properties
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]

        // Set window level to be above the target window but not too high
        // Use a level between normal and floating to ensure it's visible above the app
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)) + 1)

        // Convert from Quartz coordinates (0,0 bottom-left) to Cocoa coordinates (0,0 top-left)
        var cocoaFrame = frame
        if let primaryScreen = NSScreen.screens.first {
            cocoaFrame.origin.y = primaryScreen.frame.maxY - frame.maxY
        }
        window.setFrame(cocoaFrame, display: false)

        // Create and configure the border view
        borderView = BorderView(frame: NSRect(origin: .zero, size: frame.size))
        if let borderView = borderView {
            window.contentView = borderView
        }

        // Initially hide the window (will be shown by animation)
        window.alphaValue = 0
        window.orderFront(nil)
    }

    private func startBlinkingAnimation(blinkCount: Int) {
        var currentBlink = 0
        var isVisible = false
        let blinkDuration = 0.15 // Duration of each fade in/out in seconds

        // Create a timer that fires twice per blink (once for fade in, once for fade out)
        animationTimer = Timer.scheduledTimer(withTimeInterval: blinkDuration, repeats: true) { [weak self] timer in
            guard let self = self, let window = self.overlayWindow else {
                timer.invalidate()
                return
            }

            // Animate the alpha value
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = blinkDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

                if isVisible {
                    // Fade out
                    window.animator().alphaValue = 0
                } else {
                    // Fade in
                    window.animator().alphaValue = 1
                }
            }, completionHandler: {
                // After fade out, increment blink count
                if isVisible {
                    currentBlink += 1

                    // Check if we've completed all blinks
                    if currentBlink >= blinkCount {
                        timer.invalidate()
                        // Delay cleanup to ensure last fade out completes
                        DispatchQueue.main.asyncAfter(deadline: .now() + blinkDuration) {
                            self.cleanup()
                        }
                    }
                }
            })

            isVisible.toggle()
        }
    }

    private func cleanup() {
        animationTimer?.invalidate()
        animationTimer = nil

        overlayWindow?.orderOut(nil)
        overlayWindow = nil
        borderView = nil
    }

    // Custom view that draws a colored border
    private class BorderView: NSView {
        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true

            // Configure the border
            layer?.borderColor = NSColor.systemBlue.cgColor
            layer?.borderWidth = 6
            layer?.cornerRadius = 8
            layer?.backgroundColor = NSColor.clear.cgColor
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}
