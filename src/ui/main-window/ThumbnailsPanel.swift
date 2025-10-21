import Cocoa

class ThumbnailsPanel: NSPanel {
    var thumbnailsView = ThumbnailsView()
    var previewWindow: NSWindow?
    var previewView: NSImageView?
    var previewContainerView: NSView?
    override var canBecomeKey: Bool { true }

    convenience init() {
        self.init(contentRect: .zero, styleMask: .nonactivatingPanel, backing: .buffered, defer: false)
        delegate = self
        isFloatingPanel = true
        animationBehavior = .none
        hidesOnDeactivate = false
        hasShadow = Appearance.enablePanelShadow
        titleVisibility = .hidden
        backgroundColor = .clear
        contentView! = thumbnailsView
        // triggering AltTab before or during Space transition animation brings the window on the Space post-transition
        collectionBehavior = .canJoinAllSpaces
        // 2nd highest level possible; this allows the app to go on top of context menus
        // highest level is .screenSaver but makes drag and drop on top the main window impossible
        level = .popUpMenu
        // helps filter out this window from the thumbnails
        setAccessibilitySubrole(.unknown)
        // for VoiceOver
        setAccessibilityLabel(App.name)
        setupPreviewWindow()
    }

    private func setupPreviewWindow() {
        // Create a separate window for the preview
        previewWindow = NSWindow(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        previewWindow?.isOpaque = false
        previewWindow?.backgroundColor = .clear
        previewWindow?.hasShadow = true
        previewWindow?.level = .popUpMenu
        previewWindow?.collectionBehavior = [.canJoinAllSpaces, .stationary]
        previewWindow?.ignoresMouseEvents = true

        // Create container view for the preview
        previewContainerView = NSView(frame: .zero)
        previewContainerView?.wantsLayer = true

        // Configure shadow on the container layer
        previewContainerView?.layer?.shadowColor = NSColor.black.cgColor
        previewContainerView?.layer?.shadowOpacity = 0.5
        previewContainerView?.layer?.shadowOffset = NSSize(width: 0, height: -4)
        previewContainerView?.layer?.shadowRadius = 20
        previewContainerView?.layer?.masksToBounds = false

        // Create the image view for the preview
        previewView = NSImageView(frame: .zero)
        previewView?.imageScaling = .scaleProportionallyUpOrDown
        previewView?.wantsLayer = true

        // Add white border to the image view
        previewView?.layer?.borderColor = NSColor.white.cgColor
        previewView?.layer?.borderWidth = 3
        previewView?.layer?.cornerRadius = Appearance.cellCornerRadius
        previewView?.layer?.masksToBounds = true

        if let container = previewContainerView, let preview = previewView {
            container.addSubview(preview)
            previewWindow?.contentView = container
        }
    }

    func updatePreview() {
        // Only show preview when app is being used
        guard App.app.appIsBeingUsed else {
            previewWindow?.orderOut(nil)
            return
        }

        guard Preferences.appearanceStyle == .titles else {
            previewWindow?.orderOut(nil)
            return
        }

        guard Windows.focusedWindowIndex < Windows.list.count else {
            previewWindow?.orderOut(nil)
            return
        }

        let focusedWindow = Windows.list[Windows.focusedWindowIndex]

        // Get the thumbnail
        if let thumbnail = focusedWindow.thumbnail {
            let nsImage = NSImage(cgImage: thumbnail, size: NSSize(width: thumbnail.width, height: thumbnail.height))
            previewView?.image = nsImage

            // Calculate preview size maintaining aspect ratio
            let maxPreviewWidth: CGFloat = 450
            let maxPreviewHeight: CGFloat = 350

            let imageAspect = CGFloat(thumbnail.width) / CGFloat(thumbnail.height)
            var previewWidth = maxPreviewWidth
            var previewHeight = previewWidth / imageAspect

            if previewHeight > maxPreviewHeight {
                previewHeight = maxPreviewHeight
                previewWidth = previewHeight * imageAspect
            }

            // Update container and preview sizes
            previewContainerView?.frame.size = NSSize(width: previewWidth, height: previewHeight)
            previewView?.frame = previewContainerView?.bounds ?? .zero

            // Apply rounded corners
            applyRoundedCornersToPreview(cornerRadius: Appearance.cellCornerRadius)

            // Position the preview window
            positionPreview()

            // Show the preview window
            previewWindow?.orderFront(nil)
        } else {
            previewWindow?.orderOut(nil)
        }
    }

    private func applyRoundedCornersToPreview(cornerRadius: CGFloat) {
        guard let container = previewContainerView else { return }
        guard let preview = previewView else { return }

        // Apply corner radius to the image view (already has masksToBounds = true)
        preview.layer?.cornerRadius = cornerRadius

        // Update shadow path for better performance and appearance
        // The shadow should follow the rounded rectangle shape
        let shadowPath = NSBezierPath(roundedRect: container.bounds, xRadius: cornerRadius, yRadius: cornerRadius)
        container.layer?.shadowPath = shadowPath.toCGPath()
    }

    private func positionPreview() {
        guard let previewWindowInstance = previewWindow else { return }
        guard let container = previewContainerView else { return }
        guard Windows.focusedWindowIndex < ThumbnailsView.recycledViews.count else { return }

        let focusedView = ThumbnailsView.recycledViews[Windows.focusedWindowIndex]

        // Convert the focused view's frame to screen coordinates
        guard let documentView = thumbnailsView.scrollView.documentView else { return }

        // Get the focused view's frame in the visible contentView (accounts for scrolling)
        let focusedFrameInContentView = documentView.convert(focusedView.frame, to: thumbnailsView.scrollView.contentView)

        // Convert from contentView to window coordinates
        let focusedFrameInWindow = thumbnailsView.scrollView.contentView.convert(focusedFrameInContentView, to: nil)

        // Convert to screen coordinates
        guard let focusedFrameInScreen = self.convertToScreen(NSRect(origin: focusedFrameInWindow.origin, size: focusedFrameInWindow.size)) as NSRect? else { return }

        // Calculate vertical position - center with focused item
        let focusedCenterY = focusedFrameInScreen.midY
        let previewY = focusedCenterY - container.frame.height / 2

        // Position to the left of the main window with some padding
        let padding: CGFloat = 20
        let previewX = self.frame.minX - container.frame.width - padding

        previewWindowInstance.setFrame(NSRect(x: previewX, y: previewY, width: container.frame.width, height: container.frame.height), display: true)
    }

    override func orderOut(_ sender: Any?) {
        previewWindow?.orderOut(nil)
        if Preferences.fadeOutAnimation {
            NSAnimationContext.runAnimationGroup(
                { _ in animator().alphaValue = 0 },
                completionHandler: { super.orderOut(sender) }
            )
        } else {
            super.orderOut(sender)
        }
    }

    func show() {
        hasShadow = Appearance.enablePanelShadow
        alphaValue = 1
        makeKeyAndOrderFront(nil)
        MouseEvents.toggle(true)
        thumbnailsView.scrollView.flashScrollers()
    }

    static func maxThumbnailsWidth() -> CGFloat {
        return (NSScreen.preferred.frame.width * Appearance.maxWidthOnScreen - Appearance.windowPadding * 2).rounded()
    }

    static func maxThumbnailsHeight() -> CGFloat {
        return (NSScreen.preferred.frame.height * Appearance.maxHeightOnScreen - Appearance.windowPadding * 2).rounded()
    }
}

extension ThumbnailsPanel: NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        // other windows can steal key focus from alt-tab; we make sure that if it's active, if keeps key focus
        // dispatching to the main queue is necessary to introduce a delay in scheduling the makeKey; otherwise it is ignored
        DispatchQueue.main.async {
            if App.app.appIsBeingUsed {
                App.app.thumbnailsPanel.makeKeyAndOrderFront(nil)
            }
        }
    }
}

extension NSBezierPath {
    func toCGPath() -> CGPath {
        let path = CGMutablePath()
        let pointCount = self.elementCount

        for i in 0..<pointCount {
            var points = [NSPoint](repeating: .zero, count: 3)
            let elementType = self.element(at: i, associatedPoints: &points)

            switch elementType {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .curveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .closePath:
                path.closeSubpath()
            default:
                break
            }
        }

        return path
    }
}