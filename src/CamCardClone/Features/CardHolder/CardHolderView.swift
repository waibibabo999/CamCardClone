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
                    case .search:
                        SearchView()
                    case .tags:
                        TagManagementView()
                    case .detail(let id):
                        CardDetailView(cardID: id, store: store)
                    }
                }
                .toolbar(.visible, for: .navigationBar)
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
    @State private var notice: String?

    @MainActor
    init(store: BusinessCardStore, showingScanner: Binding<Bool>) {
        self.store = store
        _showingScanner = showingScanner
        _viewModel = State(initialValue: CardHolderViewModel(store: store))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                quickActions
                    .padding(.top, 14)
                cardSection
                    .padding(.top, 18)
                Spacer(minLength: 28)
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
                notice = "消息功能不在本次作业切片内。"
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
                showingScanner = true
            } label: {
                Image(systemName: "plus.circle")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("addButton")
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
                notice = "人脉地图功能不在本次作业切片内。"
            } label: {
                QuickActionLabel(
                    icon: "map.fill",
                    color: .green,
                    title: "人脉地图"
                )
            }
            .buttonStyle(.plain)

            Button {
                notice = "人脉分析功能不在本次作业切片内。"
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

    private var cardSection: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("名片")
                    .font(.title3.weight(.semibold))
                Text("(\(viewModel.cards.count)张)")
                    .font(.body)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Button("管理") {
                    notice = "批量管理不在本次作业切片内，可在名片详情中编辑或删除。"
                }
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if viewModel.cards.isEmpty {
                promoRow
            } else {
                ForEach(groupedCards) { group in
                    Text(group.date.formatted(date: .numeric, time: .omitted))
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 2)
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

    private var groupedCards: [CardDayGroup] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: viewModel.cards) {
            calendar.startOfDay(for: $0.updatedAt)
        }
        return groups
            .map { CardDayGroup(date: $0.key, cards: $0.value) }
            .sorted { $0.date > $1.date }
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
        .padding(.bottom, 22)
        .accessibilityIdentifier("emptyPromo")
    }
}

private struct CardDayGroup: Identifiable {
    let date: Date
    let cards: [BusinessCard]
    var id: Date { date }
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
        ZStack(alignment: .top) {
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
            .overlay(alignment: .top) {
                Divider()
            }

            Button(action: onScan) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(Theme.accent)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white, lineWidth: 3))
                    .shadow(color: .black.opacity(0.15), radius: 5, y: 2)
            }
            .offset(y: -22)
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
            description: Text("该页面不在本次作业功能切片内")
        )
        .background(Theme.background)
    }
}
