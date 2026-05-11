import AppKit
import SwiftUI

@MainActor
enum AppIconManager {
    static func applyGlassIcon() {
        let iconView = HighContrastTimeTrackerIcon()
            .frame(width: 256, height: 256)

        let renderer = ImageRenderer(content: iconView)
        renderer.proposedSize = .init(width: 256, height: 256)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0

        if let nsImage = renderer.nsImage {
            NSApp.applicationIconImage = nsImage
        }
    }
}
