import SwiftUI
import UIKit

// MARK: - App Colors

extension Color {
    /// Primary accent color used throughout the app
    static let appAccent = Color(red: 220/255, green: 36/255, blue: 67/255) // #DC2443

    /// Secondary accent for less prominent elements
    static let appAccentSecondary = Color.appAccent.opacity(0.7)

    /// Background variations
    static let appBackground = Color(UIColor.systemBackground)
    static let appBackgroundSecondary = Color(UIColor.secondarySystemBackground)
    static let appBackgroundTertiary = Color(UIColor.tertiarySystemBackground)
}

// MARK: - App Fonts

extension Font {
    /// Large title for main headings
    static let appLargeTitle = Font.largeTitle.weight(.bold)

    /// Title for section headers
    static let appTitle = Font.title2.weight(.semibold)

    /// Headline for card titles and important text
    static let appHeadline = Font.headline.weight(.semibold)

    /// Body text
    static let appBody = Font.body

    /// Caption for secondary information
    static let appCaption = Font.caption
}

// MARK: - App Spacing

enum AppSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - App Corner Radius

enum AppCornerRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
}

// MARK: - App Shadows

extension View {
    func appShadow(_ style: AppShadowStyle = .medium) -> some View {
        self.shadow(
            color: .black.opacity(style.opacity),
            radius: style.radius,
            x: 0,
            y: style.y
        )
    }
}

enum AppShadowStyle {
    case subtle
    case medium
    case prominent

    var opacity: Double {
        switch self {
        case .subtle: return 0.08
        case .medium: return 0.12
        case .prominent: return 0.2
        }
    }

    var radius: CGFloat {
        switch self {
        case .subtle: return 4
        case .medium: return 8
        case .prominent: return 16
        }
    }

    var y: CGFloat {
        switch self {
        case .subtle: return 2
        case .medium: return 4
        case .prominent: return 8
        }
    }
}

// MARK: - App Animation

extension Animation {
    static let appDefault = Animation.easeInOut(duration: 0.2)
    static let appSpring = Animation.spring(response: 0.3, dampingFraction: 0.7)
}
