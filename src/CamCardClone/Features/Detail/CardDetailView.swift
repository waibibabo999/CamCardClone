import SwiftUI
import UIKit

struct CardDetailView: View {
    @Environment(BusinessCardStore.self) private var observedStore
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CardDetailViewModel
    @State private var editing = false
    @State private var showDeleteConfirmation = false
    @State private var shareURL: URL?
    @State private var showShareSheet = false

    @MainActor
    init(cardID: UUID, store: BusinessCardStore) {
        _viewModel = State(initialValue: CardDetailViewModel(cardID: cardID, store: store))
    }

    var body: some View {
        Group {
            if let card = observedStore.cards.first(where: { $0.id == viewModel.cardID }) {
                detail(card)
            } else {
                ContentUnavailableView("名片不存在", systemImage: "person.crop.rectangle")
            }
        }
        .navigationTitle(observedStore.cards.first(where: { $0.id == viewModel.cardID })?.name ?? "名片详情")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("编辑") { editing = true }
                    .accessibilityIdentifier("editCardButton")
                Menu {
                    Button("导出 VCF") { exportVCard() }
                    Button("存入系统联系人") { Task { await viewModel.saveToContacts() } }
                    Divider()
                    Button("删除名片", role: .destructive) { showDeleteConfirmation = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityIdentifier("detailMenuButton")
            }
        }
        .task { viewModel.loadImages() }
        .sheet(isPresented: $editing) {
            if let card = observedStore.cards.first(where: { $0.id == viewModel.cardID }) {
                NavigationStack {
                    EditCardView(card: card, store: viewModel.storeForEditing) {
                        viewModel.loadImages()
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let shareURL {
                ShareSheet(items: [shareURL])
            }
        }
        .confirmationDialog(
            "删除这张名片？",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                do {
                    try viewModel.deleteCard()
                    dismiss()
                } catch {
                    viewModel.exportMessage = error.localizedDescription
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("原图和识别信息都会从本机删除。")
        }
        .alert("提示", isPresented: Binding(
            get: { viewModel.exportMessage != nil },
            set: { if !$0 { viewModel.exportMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(viewModel.exportMessage ?? "")
        }
    }

    private func detail(_ card: BusinessCard) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                imageSection
                fieldSection(card)
                tagSection(card)
                if let notes = card.notes, !notes.isEmpty {
                    sectionTitle("备注")
                    Text(notes)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
                }
                Text("创建于 \(card.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding()
        }
        .background(Theme.background)
    }

    private var imageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("名片图片")
            TabView {
                if let processed = viewModel.processedImage {
                    Image(uiImage: processed)
                        .resizable()
                        .scaledToFit()
                        .tag(0)
                }
                if let original = viewModel.originalImage {
                    Image(uiImage: original)
                        .resizable()
                        .scaledToFit()
                        .tag(1)
                }
            }
            .frame(height: 220)
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .background(Color.black.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
        }
    }

    private func fieldSection(_ card: BusinessCard) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("联系信息")
            VStack(spacing: 0) {
                detailRow("姓名", card.name, icon: "person")
                detailRow("公司", card.company, icon: "building.2")
                detailRow("职位", card.jobTitle, icon: "briefcase")
                detailRow("部门", card.department, icon: "person.3")
                detailRow("手机", card.mobile, icon: "iphone", action: openPhone)
                detailRow("电话", card.phone, icon: "phone", action: openPhone)
                detailRow("传真", card.fax, icon: "printer")
                detailRow("邮箱", card.email, icon: "envelope", action: openEmail)
                detailRow("网址", card.website, icon: "globe", action: openWebsite)
                detailRow("地址", card.address, icon: "mappin.and.ellipse")
                detailRow("邮编", card.postalCode, icon: "number")
                ForEach(card.additionalPhones, id: \.self) { phone in
                    detailRow("其他电话", phone, icon: "phone", action: openPhone)
                }
                ForEach(card.additionalEmails, id: \.self) { email in
                    detailRow("其他邮箱", email, icon: "envelope", action: openEmail)
                }
            }
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
        }
    }

    private func tagSection(_ card: BusinessCard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("标签")
            if card.tags.isEmpty {
                Text("暂无标签，可在编辑页添加")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(card.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Theme.accent.opacity(0.12))
                            .foregroundStyle(Theme.accent)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .padding(.bottom, 8)
    }

    @ViewBuilder
    private func detailRow(
        _ label: String,
        _ value: String?,
        icon: String,
        action: ((String) -> Void)? = nil
    ) -> some View {
        if let value, !value.isEmpty {
            if let action {
                Button {
                    action(value)
                } label: {
                    rowContent(label, value, icon: icon, isAction: true)
                }
                .buttonStyle(.plain)
            } else {
                rowContent(label, value, icon: icon, isAction: false)
            }
            Divider().padding(.leading, 48)
        }
    }

    private func rowContent(_ label: String, _ value: String, icon: String, isAction: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 22)
                .foregroundStyle(Theme.accent)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(isAction ? Theme.accent : Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func exportVCard() {
        do {
            shareURL = try viewModel.makeVCardURL()
            showShareSheet = true
        } catch {
            viewModel.exportMessage = error.localizedDescription
        }
    }

    private func openPhone(_ value: String) {
        let digits = value.filter { $0.isNumber || $0 == "+" }
        guard let url = URL(string: "tel://\(digits)") else { return }
        UIApplication.shared.open(url)
    }

    private func openEmail(_ value: String) {
        guard let url = URL(string: "mailto:\(value)") else { return }
        UIApplication.shared.open(url)
    }

    private func openWebsite(_ value: String) {
        let text = value.hasPrefix("http") ? value : "https://\(value)"
        guard let url = URL(string: text) else { return }
        UIApplication.shared.open(url)
    }
}

/// Small wrapping layout for tags without adding a third-party dependency.
private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth.isFinite ? maxWidth : x, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
