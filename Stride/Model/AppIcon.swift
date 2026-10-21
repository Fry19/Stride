import UIKit

/// Each tier has its own app icon. Tier 1 is the main icon; the others are alternates.
enum AppIcon {
    static func iconName(forTier tier: Int) -> String? {
        tier <= 1 ? nil : "AppIcon\(tier)"
    }

    /// Switches the home screen icon. iOS shows a short notice when it changes.
    @MainActor
    static func apply(tier: Int) {
        let application = UIApplication.shared
        guard !ScreenshotMode.isActive, application.supportsAlternateIcons else { return }
        let target = iconName(forTier: tier)
        guard application.alternateIconName != target else { return }
        application.setAlternateIconName(target) { error in
            if let error {
                print("Couldn't change the app icon: \(error)")
            }
        }
    }
}
