import SwiftUI
import UIKit

struct CardRowView: View {
    let card: BusinessCard
    let showsEllipsis: Bool
    @State private var image: UIImage?

    init(card: BusinessCard, showsEllipsis: Bool = true) {
        self.card = card
        self.showsEllipsis = showsEllipsis
    }

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Circle()
                            .fill(Theme.cardBackground)
                            .frame(width: 42, height: 42)
                        Text(cardInitial)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .frame(width: 96, height: 60)
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(card.name ?? "未命名名片")
                    .font(.headline)
                    .lineLimit(1)
                if let title = card.jobTitle, !title.isEmpty {
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                if let company = card.company, !company.isEmpty {
                    Text(company)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                if !card.tags.isEmpty {
                    Text(card.tags.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(Theme.accent)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if showsEllipsis {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 34, height: 44)
            }
        }
        .padding(.vertical, 4)
        .task(id: "\(card.processedImageFileName ?? "")|\(card.originalImageFileName ?? "")|\(card.updatedAt.timeIntervalSince1970)") {
            let store = ImageStore()
            image = card.processedImageFileName.flatMap {
                try? store.loadImage(fileName: $0)
            } ?? card.originalImageFileName.flatMap {
                try? store.loadImage(fileName: $0)
            }
        }
    }

    private var cardInitial: String {
        let source = card.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return String(source.first ?? "?")
    }
}
