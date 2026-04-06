import SwiftUI

struct BannerMessageCard: View {
    let banner: BannerMessage
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbolName(for: banner.kind))
                .foregroundStyle(symbolColor(for: banner.kind))

            Text(banner.text)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()

            Button("Dismiss", action: onDismiss)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(backgroundColor(for: banner.kind))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func backgroundColor(for kind: BannerKind) -> Color {
        switch kind {
        case .info:
            return .blue.opacity(0.12)
        case .success:
            return .green.opacity(0.12)
        case .warning:
            return .orange.opacity(0.12)
        case .error:
            return .red.opacity(0.12)
        }
    }

    private func symbolColor(for kind: BannerKind) -> Color {
        switch kind {
        case .info:
            return .blue
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
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
