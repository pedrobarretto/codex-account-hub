import SwiftUI

struct BannerMessageCard: View {
    let banner: BannerMessage
    let onDismiss: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbolName(for: banner.kind))
                .foregroundStyle(colors.symbol)

            Text(banner.text)
                .font(.subheadline)
                .foregroundStyle(theme.textPrimary)

            Spacer()

            Button("Dismiss", action: onDismiss)
                .buttonStyle(.plain)
                .foregroundStyle(theme.textSecondary)
        }
        .padding(14)
        .background(colors.background)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(theme.elevatedInsetBorder, lineWidth: 1)
        }
    }

    private var theme: AppTheme.Palette {
        AppTheme.palette(for: colorScheme)
    }

    private var colors: AppTheme.BannerColors {
        AppTheme.bannerColors(for: banner.kind, in: theme)
    }

    private func symbolName(for kind: BannerKind) -> String {
        switch kind {
        case .info:
            return "info.circle.fill"
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.octagon.fill"
        }
    }
}
