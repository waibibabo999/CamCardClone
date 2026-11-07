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
    @State private var captureSide: CardImageSide?
    @State private var showingImageEditor = false
    @State private var selectedImagePage = 0
    @State private var scrollOffset: CGFloat = 0

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
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .task { viewModel.loadImages() }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let card = observedStore.cards.first(where: { $0.id == viewModel.cardID }) {
                detailActions(card)
            }
        }
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
        .fullScreenCover(item: $captureSide) { side in
            BackSideCaptureFlow(
                side: side,
                onSave: { image in
                    switch side {
                    case .front:
                        try viewModel.replaceFrontImage(image)
                    case .back:
                        try viewModel.saveBackImage(image)
                    }
                }
            )
        }
        .fullScreenCover(isPresented: $showingImageEditor) {
            CardImageEditor(
                frontImage: viewModel.processedImage,
                backImage: viewModel.backImage,
                initialPage: selectedImagePage,
                onSaveFront: { image in try viewModel.replaceFrontImage(image) },
                onSaveBack: { image in try viewModel.saveBackImage(image) },
                onDeleteFront: { try viewModel.deleteFrontImage() },
                onDeleteBack: { try viewModel.deleteBackImage() }
            )
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
        ZStack(alignment: .top) {
            Theme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: DetailScrollOffsetKey.self,
                            value: proxy.frame(in: .named("detailScroll")).minY
                        )
                    }
                    .frame(height: 0)

                    Color.clear
                        .frame(height: 58)

                    heroImageSection
                        .scaleEffect(
                            y: 1 - heroProgress * 0.76,
                            anchor: .top
                        )
                        .offset(y: heroProgress * 56)
                        .opacity(1 - heroProgress * 0.9)

                    VStack(alignment: .leading, spacing: 16) {
                        summaryCard(card)
                        quickActionRow(card)
                        fieldSection(card)
                        tagSection(card)
                        if let notes = card.notes, !notes.isEmpty {
                            sectionTitle("备注")
                            Text(notes)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
                        }
                        Text("创建于 \(card.createdAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 16)
                    .background(Theme.background)
                }
            }
            .coordinateSpace(name: "detailScroll")
            .onPreferenceChange(DetailScrollOffsetKey.self) { value in
                scrollOffset = value
            }

            detailNavigationBar
        }
    }

    private var heroProgress: CGFloat {
        min(max(-scrollOffset / 235, 0), 1)
    }

    private var detailNavigationBar: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.16, blue: 0.34).opacity(0.96),
                    Color(red: 0.02, green: 0.08, blue: 0.20).opacity(0.96)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)

            Text("名片详情")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("返回")
                .accessibilityIdentifier("detailBackButton")

                Spacer(minLength: 0)

                Button {
                    // 保留收藏入口的外观，当前仅提供提示反馈。
                } label: {
                    Image(systemName: "star")
                        .font(.system(size: 18, weight: .regular))
                        .frame(width: 32, height: 36)
                }
                .buttonStyle(.plain)

                Menu {
                    Button("导出 VCF") { exportVCard() }
                    Button("存入系统联系人") { Task { await viewModel.saveToContacts() } }
                    Divider()
                    Button("删除名片", role: .destructive) { showDeleteConfirmation = true }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20, weight: .regular))
                        .frame(width: 32, height: 36)
                }
                .accessibilityIdentifier("detailMenuButton")
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.top, 8)
        }
        .frame(height: 58)
    }

    private var heroImageSection: some View {
        TabView(selection: $selectedImagePage) {
            if let processed = viewModel.processedImage {
                Button {
                    selectedImagePage = 0
                    showingImageEditor = true
                } label: {
                    Image(uiImage: processed)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(headerBlue)
                }
                .buttonStyle(.plain)
                .tag(0)
            } else {
                Button {
                    captureSide = .front
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "rectangle.portrait.badge.plus")
                            .font(.system(size: 37, weight: .light))
                        Text("添加正面")
                            .font(.headline)
                        Text("拍一张名片正面")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("addFrontCardButton")
                .tag(0)
            }
            if let back = viewModel.backImage {
                Button {
                    selectedImagePage = 1
                    showingImageEditor = true
                } label: {
                    Image(uiImage: back)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(headerBlue)
                }
                .buttonStyle(.plain)
                .tag(1)
            } else {
                Button {
                    captureSide = .back
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "rectangle.portrait.badge.plus")
                            .font(.system(size: 37, weight: .light))
                        Text("添加背面")
                            .font(.headline)
                        Text("拍一张名片背面")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("addCardBackButton")
                .tag(1)
            }
        }
        .frame(height: 232)
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .background(headerBlue)
        .clipped()
        .accessibilityIdentifier("detailCardImage")
    }

    private var headerBlue: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.04, green: 0.16, blue: 0.34),
                Color(red: 0.02, green: 0.08, blue: 0.20)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func summaryCard(_ card: BusinessCard) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(.systemGroupedBackground))
                    Text(initial(of: card))
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(width: 62, height: 62)

                VStack(alignment: .leading, spacing: 3) {
                    Text(card.name ?? "未命名名片")
                        .font(.title3.weight(.semibold))
                    if let title = card.jobTitle, !title.isEmpty {
                        Text(title)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    if let company = card.company, !company.isEmpty {
                        Text(company)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
            }

            if let phone = card.mobile ?? card.phone, !phone.isEmpty {
                Label(phone, systemImage: "phone.fill")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            if let address = card.address, !address.isEmpty {
                Label(address, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 5, y: 2)
        .padding(.top, 8)
    }

    private func quickActionRow(_ card: BusinessCard) -> some View {
        HStack(spacing: 0) {
            actionCircle(title: "电话", icon: "phone.fill", color: .blue) {
                if let phone = card.mobile ?? card.phone { openPhone(phone) }
            }
            actionCircle(title: "地址", icon: "mappin", color: .gray) {
                if let address = card.address, !address.isEmpty {
                    let query = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? address
                    if let url = URL(string: "http://maps.apple.com/?q=\(query)") {
                        UIApplication.shared.open(url)
                    }
                }
            }
            actionCircle(title: "备注", icon: "note.text", color: .green) {
                // 备注内容在下方区域展示。
            }
            actionCircle(title: "编辑", icon: "pencil", color: .teal) {
                editing = true
            }
        }
        .padding(.vertical, 4)
    }

    private func actionCircle(
        title: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(color)
                    .clipShape(Circle())
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(title == "编辑" ? "editCardButton" : "detailAction_\(title)")
    }

    private func initial(of card: BusinessCard) -> String {
        let name = card.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return String(name.first ?? "?")
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

    private func detailActions(_ card: BusinessCard) -> some View {
        HStack(spacing: 10) {
            Button {
                Task { await viewModel.saveToContacts() }
            } label: {
                Label("存入通讯录", systemImage: "person.crop.circle.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isExporting)
            .accessibilityIdentifier("saveToContactsButton")

            Button {
                viewModel.exportMessage = "分享名片功能暂未开放。"
            } label: {
                Label("分享名片", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("shareVCardButton")
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.regularMaterial)
        .overlay(alignment: .top) { Divider() }
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

private struct DetailScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private enum CardImageSide: Int, Identifiable, Hashable {
    case front
    case back

    var id: Int { rawValue }
    var title: String { self == .front ? "正面" : "背面" }
    var frameInstruction: String { "请将名片\(title)放入框内" }
}

private struct CardImageEditor: View {
    let onSaveFront: (UIImage) throws -> Void
    let onSaveBack: (UIImage) throws -> Void
    let onDeleteFront: () throws -> Void
    let onDeleteBack: () throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var frontImage: UIImage?
    @State private var backImage: UIImage?
    @State private var selectedPage: Int
    @State private var retakeSide: CardImageSide?
    @State private var cropSide: CardImageSide?
    @State private var showDeleteConfirmation = false
    @State private var errorMessage: String?

    init(
        frontImage: UIImage?,
        backImage: UIImage?,
        initialPage: Int,
        onSaveFront: @escaping (UIImage) throws -> Void,
        onSaveBack: @escaping (UIImage) throws -> Void,
        onDeleteFront: @escaping () throws -> Void,
        onDeleteBack: @escaping () throws -> Void
    ) {
        self.onSaveFront = onSaveFront
        self.onSaveBack = onSaveBack
        self.onDeleteFront = onDeleteFront
        self.onDeleteBack = onDeleteBack
        _frontImage = State(initialValue: frontImage)
        _backImage = State(initialValue: backImage)
        _selectedPage = State(initialValue: backImage != nil && initialPage == 1 ? 1 : 0)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                editorHeader

                TabView(selection: $selectedPage) {
                    editorPage(frontImage, side: .front)
                        .tag(0)
                    editorPage(backImage, side: .back)
                        .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                editorActions
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(item: $retakeSide) { side in
            BackSideCaptureFlow(
                side: side,
                onSave: { image in
                    try save(image, for: side)
                }
            )
        }
        .fullScreenCover(item: $cropSide) { side in
            NavigationStack {
                if let image = image(for: side) {
                    CorrectionView(
                        image: image,
                        corners: CardGeometry.fullFrameCorners,
                        onComplete: { processed in
                            do {
                                try save(processed, for: side)
                                cropSide = nil
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        },
                        onCancel: { cropSide = nil }
                    )
                }
            }
        }
        .alert("提示", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .confirmationDialog(
            "删除\(currentSide.title)照片？",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                do {
                    switch currentSide {
                    case .front:
                        try onDeleteFront()
                        frontImage = nil
                        selectedPage = 0
                    case .back:
                        try onDeleteBack()
                        backImage = nil
                        selectedPage = 1
                    }
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("只删除这张照片，不影响联系人信息。")
        }
    }

    private var currentSide: CardImageSide {
        selectedPage == 1 ? .back : .front
    }

    private var currentImage: UIImage? {
        image(for: currentSide)
    }

    private var editorHeader: some View {
        ZStack {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("返回")

                Spacer()
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(selectedPage == 0 ? Color.blue : Color.white.opacity(0.35))
                    .frame(width: 8, height: 8)
                Circle()
                    .fill(selectedPage == 1 ? Color.blue : Color.white.opacity(0.35))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 4)
        .frame(height: 56)
    }

    private func editorPage(_ image: UIImage?, side: CardImageSide) -> some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: side == .front ? "photo" : "rectangle.portrait")
                        .font(.system(size: 38, weight: .light))
                    Text(side == .front ? "暂无正面照片" : "暂无背面照片")
                        .font(.headline)
                    Text("点击下方“重拍”添加")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 10)
    }

    private var editorActions: some View {
        HStack(spacing: 0) {
            editorAction("重拍", icon: "camera.fill") {
                retakeSide = currentSide
            }
            editorAction("旋转", icon: "arrow.counterclockwise") {
                rotateCurrentImage()
            }
            editorAction("删除", icon: "trash.fill") {
                deleteCurrentImage()
            }
            editorAction("手动切边", icon: "crop") {
                guard currentImage != nil else { return }
                cropSide = currentSide
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 16)
        .padding(.bottom, 26)
        .background(Color.black)
    }

    private func editorAction(
        _ title: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                Text(title)
                    .font(.subheadline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func image(for side: CardImageSide) -> UIImage? {
        side == .front ? frontImage : backImage
    }

    private func rotateCurrentImage() {
        guard let currentImage else { return }
        do {
            try save(currentImage.rotatedClockwise, for: currentSide)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteCurrentImage() {
        guard currentImage != nil else { return }
        showDeleteConfirmation = true
    }

    private func save(_ image: UIImage, for side: CardImageSide) throws {
        switch side {
        case .front:
            try onSaveFront(image)
            frontImage = image
            selectedPage = 0
        case .back:
            try onSaveBack(image)
            backImage = image
            selectedPage = 1
        }
    }
}

private struct BackSideCaptureFlow: View {
    let side: CardImageSide
    let onSave: (UIImage) throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var step: Step = .capture
    @State private var workingImage: UIImage?
    @State private var errorMessage: String?

    private enum Step: Equatable {
        case capture
        case processing
        case failed
    }

    var body: some View {
        Group {
            switch step {
            case .capture:
                CaptureView(
                    backOnly: true,
                    frameInstruction: side.frameInstruction,
                    onPhoto: processCapturedPhoto,
                    onCancel: { dismiss() }
                )
            case .processing:
                processingView
            case .failed:
                failureView
            }
        }
        .preferredColorScheme(step == .capture ? .dark : .light)
    }

    private var processingView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let workingImage {
                Image(uiImage: workingImage)
                    .resizable()
                    .scaledToFit()
                    .padding(12)
                    .opacity(0.55)
            }

            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                Text("正在处理\(side.title)照片…")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
            .background(Color.black.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 22, weight: .light))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                    }
                    Spacer()
                }
                Spacer()
            }
            .padding(.horizontal, 16)
        }
    }

    private var failureView: some View {
        VStack(spacing: 16) {
            HStack {
                Button("关闭") { dismiss() }
                Spacer()
            }
            .padding()

            Spacer()
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(Theme.textSecondary)
            Text("\(side.title)照片处理失败")
                .font(.headline)
            Text(errorMessage ?? "请重新拍摄")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Button("重新拍摄") {
                step = .capture
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding()
        .background(Theme.background)
    }

    private func processCapturedPhoto(_ image: UIImage, guideCrop: CGRect?) {
        let cropped = guideCrop.flatMap {
            image.cropped(toNormalizedRect: $0)
        } ?? image
        workingImage = cropped
        step = .processing

        Task {
            let result = try? await VisionCardDetectionService().detectCard(in: cropped)
            let corners = result?.corners ?? CardGeometry.fullFrameCorners
            let shouldRotate = result.map { !$0.usedFallback } ?? false
            let processed = await Task.detached(priority: .userInitiated) {
                autoreleasepool {
                    let upright = CorrectionViewModel.correctedImage(
                        from: cropped,
                        corners: corners,
                        rotationSteps: 0
                    ) ?? cropped
                    if shouldRotate, upright.size.height > upright.size.width {
                        return CorrectionViewModel.correctedImage(
                            from: cropped,
                            corners: corners,
                            rotationSteps: 3
                        ) ?? upright
                    }
                    return upright
                }
            }.value

            await MainActor.run {
                do {
                    try onSave(processed)
                    dismiss()
                } catch {
                    errorMessage = error.localizedDescription
                    step = .failed
                }
            }
        }
    }
}

/// Small wrapping layout for tags without adding a third-party dependency.
struct FlowLayout: Layout {
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
