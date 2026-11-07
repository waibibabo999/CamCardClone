import SwiftUI

struct CardHolderView: View {
    @Environment(BusinessCardStore.self) private var store
    @State private var selectedTab = 1
    @State private var showingScanner = false

    var body: some View {
        NavigationStack {
            Group {
                switch selectedTab {
                case 1:
                    CardHolderHome(store: store, showingScanner: $showingScanner)
                default:
                    PlaceholderTab(title: tabTitle)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                CardHolderTabBar(selectedTab: $selectedTab) {
                    showingScanner = true
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                Group {
                    switch route {
                    case .scanner:
                        ScannerView()
                            .toolbar(.visible, for: .navigationBar)
                    case .search:
                        SearchView()
                            .toolbar(.hidden, for: .navigationBar)
                    case .tags:
                        TagManagementView()
                            .toolbar(.visible, for: .navigationBar)
                    case .detail(let id):
                        CardDetailView(cardID: id, store: store)
                            .toolbar(.hidden, for: .navigationBar)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingScanner) {
            NavigationStack {
                ScannerView()
            }
            .environment(store)
        }
        .alert("名片数据读取失败", isPresented: Binding(
            get: { store.loadError != nil },
            set: { if !$0 { store.clearLoadError() } }
        )) {
            Button("好", role: .cancel) { store.clearLoadError() }
        } message: {
            Text(store.loadError ?? "")
        }
    }

    private var tabTitle: String {
        switch selectedTab {
        case 0: return "首页"
        case 2: return "企业"
        default: return "我"
        }
    }
}

private struct CardHolderHome: View {
    let store: BusinessCardStore
    @Binding var showingScanner: Bool
    @State private var viewModel: CardHolderViewModel
    @State private var showAddMenu = false
    @State private var notice: String?

    @MainActor
    init(store: BusinessCardStore, showingScanner: Binding<Bool>) {
        self.store = store
        _showingScanner = showingScanner
        _viewModel = State(initialValue: CardHolderViewModel(store: store))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .topTrailing) {
                ScrollView {
                    VStack(spacing: 0) {
                        topBar
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        quickActions
                            .padding(.top, 14)
                        cardSection { letter in
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(initialAnchor(letter), anchor: .top)
                            }
                        }
                        .padding(.top, 18)
                        Spacer(minLength: 28)
                    }
                }

                if !groupedCards.isEmpty {
                    initialIndex(proxy: proxy)
                        .padding(.top, 286)
                        .padding(.trailing, 2)
                }
            }
        }
        .background(Theme.background)
        .alert("提示", isPresented: Binding(
            get: { notice != nil },
            set: { if !$0 { notice = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(notice ?? "")
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                notice = "消息功能暂未开放。"
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bubble.left")
                        .font(.title2)
                        .foregroundStyle(.primary)
                    Circle()
                        .fill(.red)
                        .frame(width: 7, height: 7)
                        .offset(x: 3, y: -2)
                }
                .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)

            NavigationLink(value: AppRoute.search) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Theme.textSecondary)
                    Text("请输入姓名/公司/职位搜索")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .frame(height: 40)
                .background(Color(.systemBackground))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("searchButton")

            Button {
                showAddMenu = true
            } label: {
                Image(systemName: "plus.circle")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("addButton")
            .popover(
                isPresented: $showAddMenu,
                attachmentAnchor: .rect(.bounds),
                arrowEdge: .top
            ) {
                AddMenuView(
                    onScan: {
                        showAddMenu = false
                        showingScanner = true
                    },
                    onAddCard: {
                        showAddMenu = false
                        showingScanner = true
                    },
                    onNotice: { message in
                        showAddMenu = false
                        notice = message
                    }
                )
                .presentationCompactAdaptation(.popover)
            }
        }
    }

    private var quickActions: some View {
        HStack(spacing: 10) {
            Button {
                showingScanner = true
            } label: {
                QuickActionLabel(
                    icon: "person.2.fill",
                    color: .blue,
                    title: "新的人脉"
                )
            }
            .buttonStyle(.plain)

            NavigationLink(value: AppRoute.tags) {
                QuickActionLabel(
                    icon: "folder.fill.badge.plus",
                    color: .orange,
                    title: "分组管理"
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("tagsButton")

            Button {
                notice = "人脉地图功能暂未开放。"
            } label: {
                QuickActionLabel(
                    icon: "map.fill",
                    color: .green,
                    title: "人脉地图"
                )
            }
            .buttonStyle(.plain)

            Button {
                notice = "人脉分析功能暂未开放。"
            } label: {
                QuickActionLabel(
                    icon: "chart.bar.fill",
                    color: .blue,
                    title: "人脉分析"
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }

    private func cardSection(onSelectInitial: @escaping (String) -> Void) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("名片")
                    .font(.title3.weight(.semibold))
                Text("(\(viewModel.cards.count)张)")
                    .font(.body)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Button("管理") {
                    notice = "批量管理暂未开放，可在名片详情中编辑或删除。"
                }
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if !viewModel.cards.isEmpty {
                Button {
                    notice = "好友名片更新记录暂未开放。"
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                        Text("好友名片更新记录")
                        Spacer()
                        Text("立即查看")
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
                .buttonStyle(.plain)
            }

            if viewModel.cards.isEmpty {
                promoRow
                    .padding(.top, 4)
            } else {
                ForEach(groupedCards) { group in
                    Text(group.letter)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 2)
                        .id(initialAnchor(group.letter))
                    ForEach(group.cards) { card in
                        NavigationLink(value: AppRoute.detail(card.id)) {
                            CardRowView(card: card)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        Divider()
                            .padding(.leading, 124)
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: 14,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: 14,
            style: .continuous
        ))
    }

    private func initialIndex(proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 1) {
            ForEach(groupedCards) { group in
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(initialAnchor(group.letter), anchor: .top)
                    }
                } label: {
                    Text(group.letter)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 24, height: 17)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("跳到\(group.letter)组")
                .accessibilityIdentifier("initialIndex_\(group.letter)")
            }
        }
        .padding(.vertical, 4)
    }

    private func initialAnchor(_ letter: String) -> String {
        "card-initial-\(letter)"
    }

    private var groupedCards: [CardInitialGroup] {
        let groups = Dictionary(grouping: viewModel.cards) {
            initialLetter(for: $0)
        }
        return groups
            .map { CardInitialGroup(letter: $0.key, cards: $0.value) }
            .sorted { $0.letter < $1.letter }
    }

    private func initialLetter(for card: BusinessCard) -> String {
        let source = card.name ?? card.company ?? "#"
        let transliterated = source.applyingTransform(.toLatin, reverse: false) ?? source
        let folded = transliterated.folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: .current
        )
        guard let first = folded.uppercased().first, first.isLetter else { return "#" }
        return String(first)
    }

    private var promoRow: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 82, height: 54)
                Image(systemName: "rectangle.stack.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text("30 秒快速认识 CC")
                    .font(.headline)
                Text("体验智能的名片识别、人脉管理")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 22)
        .accessibilityIdentifier("emptyPromo")
    }
}

private struct CardInitialGroup: Identifiable {
    let letter: String
    let cards: [BusinessCard]
    var id: String { letter }
}

private struct QuickActionLabel: View {
    let icon: String
    let color: Color
    let title: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(color)
                .frame(height: 28)
            Text(title)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 90)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct CardHolderTabBar: View {
    @Binding var selectedTab: Int
    let onScan: () -> Void

    var body: some View {
        ZStack(alignment: .center) {
            HStack(alignment: .bottom, spacing: 0) {
                tab(index: 0, title: "首页", icon: "house")
                tab(index: 1, title: "名片夹", icon: "rectangle.stack.person.crop")
                Spacer()
                    .frame(width: 72)
                tab(index: 2, title: "企业", icon: "building.2")
                tab(index: 3, title: "我", icon: "person.crop.circle")
            }
            .padding(.top, 8)
            .padding(.bottom, 4)
            .background(Color(.systemBackground))

            Button(action: onScan) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Theme.accent)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white, lineWidth: 3))
                    .shadow(color: .black.opacity(0.15), radius: 5, y: 2)
            }
            .accessibilityLabel("扫描名片")
            .accessibilityIdentifier("scanButton")
        }
        .frame(height: 64)
        .background(Color(.systemBackground).ignoresSafeArea(edges: .bottom))
    }

    private func tab(index: Int, title: String, icon: String) -> some View {
        Button {
            selectedTab = index
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .regular))
                Text(title)
                    .font(.caption2)
            }
            .foregroundStyle(selectedTab == index ? Theme.accent : Theme.textSecondary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tab_\(title)")
    }
}

private struct PlaceholderTab: View {
    let title: String

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: title == "企业" ? "building.2" : "house",
            description: Text("该页面暂未开放")
        )
        .background(Theme.background)
    }
}

private struct AddMenuView: View {
    let onScan: () -> Void
    let onAddCard: () -> Void
    let onNotice: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            menuRow(icon: "viewfinder", title: "扫一扫", action: onScan)
            Divider().padding(.leading, 48)
            menuRow(icon: "rectangle.and.pencil.and.ellipsis", title: "添加名片", action: onAddCard)
            Divider().padding(.leading, 48)
            menuRow(icon: "icloud.and.arrow.up", title: "备份手机通讯录") {
                onNotice("备份手机通讯录暂未开放。")
            }
            Divider().padding(.leading, 48)
            menuRow(icon: "person.crop.circle.badge.plus", title: "导入联系人") {
                onNotice("导入联系人暂未开放。")
            }
        }
        .frame(width: 224)
        .padding(.vertical, 5)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 12, y: 5)
    }

    private func menuRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.blue)
                    .frame(width: 26)
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(height: 51)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
