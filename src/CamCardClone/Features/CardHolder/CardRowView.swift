import SwiftUI
import UIKit

struct CardRowView: View {
    let card: BusinessCard
    @State private var image: UIImage?

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "person.crop.rectangle")
                        .resizable()
                        .scaledToFit()
                        .padding(12)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(width: 72, height: 48)
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
                Text(card.updatedAt.formatted(date: .numeric, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                if !card.tags.isEmpty {
                    Text(card.tags.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(Theme.accent)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
        .task(id: card.originalImageFileName) {
            let store = ImageStore()
            image = (try? store.loadImage(fileName: card.processedImageFileName))
                ?? (try? store.loadImage(fileName: card.originalImageFileName))
        }
    }
}
