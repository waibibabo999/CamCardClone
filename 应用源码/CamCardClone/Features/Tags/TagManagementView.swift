import SwiftUI
import UIKit

struct TagManagementView: View {
    @Environment(BusinessCardStore.self) private var store
    @State private var searchText = ""
    @State private var newTag = ""
    @State private var showAddTag = false
    @State private var isEditing = false
    @State private var sortAscending = true
    @State private var renameTarget: Tag?
    @State private var renameText = ""

    var body: some View {
        Group {
            if isEditing {
                editingView
            } else {
                regularView
            }
        }
        .navigationTitle(isEditing ? "编辑分组" : "分组")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isEditing ? "完成" : "编辑") {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isEditing.toggle()
                    }
                }
                .fontWeight(.medium)
                .accessibilityIdentifier(isEditing ? "finishEditingGroupsButton" : "editGroupsButton")
            }
        }
        .alert("新建分组", isPresented: $showAddTag) {
            TextField("分组名称", text: $newTag)
            Button("创建") {
                let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    try? store.addTag(trimmed)
                }
                newTag = ""
            }
            Button("取消", role: .cancel) { newTag = "" }
        } message: {
            Text("例如：合作伙伴、客户、会议")
        }
        .alert("重命名分组", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
            TextField("分组名称", text: $renameText)
            Button("保存") {
                guard let target = renameTarget else { return }
                let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty, trimmed != target.name {
                    try? store.renameTag(target.name, to: trimmed)
                }
                renameTarget = nil
            }
            Button("取消", role: .cancel) { renameTarget = nil }
        }
    }

    private var regularView: some View {
        ScrollView {
            VStack(spacing: 0) {
                searchField
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                Divider()

                Button {
                    showAddTag = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .regular))
                        Text("新建分组")
                            .font(.body)
                        Spacer()
                    }
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 18)
                    .frame(height: 52)
                    .background(Color(.systemBackground))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("addTagButton")

                sectionHeader(
                    title: "我的分组",
                    trailing: {
                        Button {
                            sortAscending.toggle()
                        } label: {
                            HStack(spacing: 4) {
                                Text("排序")
                                Image(systemName: "arrow.up.arrow.down")
                            }
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                )

                if visibleTags.isEmpty, !searchText.isEmpty {
                    Text("没有匹配的分组")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                        .frame(height: 56)
                        .background(Color(.systemBackground))
                } else if !visibleTags.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(visibleTags.enumerated()), id: \.element.id) { index, tag in
                            NavigationLink {
                                TagResultsView(tag: tag.name)
                            } label: {
                                HStack(spacing: 8) {
                                    Text(tag.name)
                                        .font(.body)
                                        .foregroundStyle(Theme.textPrimary)
                                    Text("(\(store.filter(tag: tag.name).count))")
                                        .font(.body)
                                        .foregroundStyle(Theme.textSecondary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color(.tertiaryLabel))
                                }
                                .padding(.horizontal, 18)
                                .frame(height: 52)
                                .background(Color(.systemBackground))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("group_\(tag.name)")

                            if index < visibleTags.count - 1 {
                                Divider().padding(.leading, 18)
                            }
                        }
                    }
                }
            }
        }
        .background(Theme.background)
    }

    private var editingView: some View {
        List {
            Section {
                ForEach(store.tags) { tag in
                    HStack(spacing: 8) {
                        Text(tag.name)
                            .font(.body)
                        Text("(\(store.filter(tag: tag.name).count))")
                            .font(.body)
                            .foregroundStyle(Theme.textSecondary)

                        Button {
                            renameTarget = tag
                            renameText = tag.name
                        } label: {
                            Image(systemName: "pencil")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("重命名\(tag.name)")

                        Spacer()
                    }
                    .frame(height: 44)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                }
                .onDelete { offsets in
                    let names = offsets.compactMap { index in
                        store.tags.indices.contains(index) ? store.tags[index].name : nil
                    }
                    for name in names {
                        try? store.deleteTag(name)
                    }
                }
                .onMove { source, destination in
                    try? store.moveTag(fromOffsets: source, toOffset: destination)
                }
            } header: {
                Text("我的分组")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .textCase(nil)
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(.active))
        .background(Theme.background)
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(Theme.textSecondary)
            TextField("请输入分组名称", text: $searchText)
                .font(.subheadline)
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(Color(.systemBackground))
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(Color(.separator).opacity(0.7), lineWidth: 1)
        }
    }

    private func sectionHeader<Trailing: View>(
        title: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 18)
        .frame(height: 42)
        .background(Color(.secondarySystemBackground))
    }

    private var visibleTags: [Tag] {
        let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = needle.isEmpty
            ? store.tags
            : store.tags.filter { $0.name.localizedCaseInsensitiveContains(needle) }
        return filtered.sorted {
            sortAscending
                ? $0.name.localizedStandardCompare($1.name) == .orderedAscending
                : $0.name.localizedStandardCompare($1.name) == .orderedDescending
        }
    }
}

struct TagResultsView: View {
    @Environment(BusinessCardStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let tag: String

    @State private var searchText = ""
    @State private var activeMenu: GroupMenu?
    @State private var showScanner = false
    @State private var showCardPicker = false
    @State private var isSelecting = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var membershipCard: BusinessCard?
    @State private var editCard: BusinessCard?
    @State private var shareData: Data?
    @State private var showShareSheet = false
    @State private var toastMessage: String?

    private struct InitialGroup: Identifiable {
        let letter: String
        let cards: [BusinessCard]
        var id: String { letter }
    }

    private enum GroupMenu: Identifiable {
        case add
        case card(BusinessCard)
        case bulk

        var id: String {
            switch self {
            case .add:
                return "add"
            case .card(let card):
                return "card-\(card.id.uuidString)"
            case .bulk:
                return "bulk"
            }
        }
    }

    private var allCards: [BusinessCard] {
        store.filter(tag: tag).sorted {
            $0.name?.localizedStandardCompare($1.name ?? "") == .orderedAscending
        }
    }

    private var visibleCards: [BusinessCard] {
        let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return allCards }
        return allCards.filter { card in
            [card.name, card.company, card.jobTitle]
                .compactMap { $0 }
                .contains { $0.localizedCaseInsensitiveContains(needle) }
        }
    }

    private var groupedCards: [InitialGroup] {
        Dictionary(grouping: visibleCards, by: initialLetter)
            .map { InitialGroup(letter: $0.key, cards: $0.value) }
            .sorted { $0.letter < $1.letter }
    }

    private var selectedCards: [BusinessCard] {
        allCards.filter { selectedIDs.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            if isSelecting {
                VStack(spacing: 0) {
                    selectionHeader
                    groupTitleField
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                }
            } else {
                regularHeader
            }

            Divider()

            if visibleCards.isEmpty {
                emptyState
            } else {
                cardList
            }
        }
        .background(Theme.background)
        .overlay(alignment: .center) {
            if let toastMessage {
                Text(toastMessage)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(Color.black.opacity(0.88))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(.horizontal, 32)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isSelecting {
                bulkActionBar
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .sheet(item: $activeMenu) { menu in
            groupActionMenu(menu)
                .presentationDetents([.height(menuHeight(for: menu))])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(20)
                .presentationBackground(Color(.systemBackground))
        }
        .sheet(isPresented: $showCardPicker) {
            NavigationStack {
                CardPickerView(tag: tag)
                    .environment(store)
            }
        }
        .sheet(item: $membershipCard) { card in
            NavigationStack {
                CardGroupMembershipView(card: card)
                    .environment(store)
            }
        }
        .sheet(item: $editCard) { card in
            NavigationStack {
                EditCardView(card: card, store: store)
                    .environment(store)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let shareData {
                ShareSheet(items: [shareData])
            }
        }
        .fullScreenCover(isPresented: $showScanner) {
            NavigationStack {
                ScannerView(initialTags: [tag])
                    .environment(store)
            }
        }
    }

    private var regularHeader: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 19, weight: .regular))
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("返回")

            groupTitleField

            Button {
                activeMenu = .add
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("添加名片")
            .accessibilityIdentifier("groupAddMenuButton")
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .background(Color(.systemBackground))
    }

    private var selectionHeader: some View {
        HStack {
            Button(allVisibleSelected ? "取消全选" : "全选") {
                toggleSelectAll()
            }
            .font(.body)
            .foregroundStyle(Theme.textPrimary)

            Spacer()

            Text("已选\(selectedIDs.count)张")
                .font(.headline)

            Spacer()

            Button("关闭") {
                isSelecting = false
                selectedIDs.removeAll()
            }
            .font(.body)
            .foregroundStyle(Theme.textPrimary)
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(Color(.systemBackground))
    }

    private var groupTitleField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.textSecondary)
            TextField(
                "\(tag) (\(allCards.count))",
                text: $searchText
            )
            .font(.subheadline)
            .foregroundStyle(Theme.textPrimary)
            .textFieldStyle(.plain)
        }
        .padding(.horizontal, 14)
        .frame(height: 38)
        .background(Color(.secondarySystemBackground))
        .clipShape(Capsule())
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "person.2.fill")
                .font(.system(size: 78, weight: .regular))
                .foregroundStyle(Color(.systemGray5))
            Text("点击右上角按钮添加名片")
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private var cardList: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(groupedCards) { group in
                    Section {
                        ForEach(group.cards) { card in
                            cardRow(card)
                            Divider().padding(.leading, selectionInset(for: card))
                        }
                    } header: {
                        Text(group.letter)
                            .font(.body)
                            .foregroundStyle(Theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .frame(height: 30)
                            .background(Color(.secondarySystemBackground))
                    }
                }
            }
        }
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    private func cardRow(_ card: BusinessCard) -> some View {
        if isSelecting {
            Button {
                toggleSelection(card.id)
            } label: {
                HStack(spacing: 8) {
                    selectionCheck(selectedIDs.contains(card.id))
                    CardRowView(card: card, showsEllipsis: false)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 8)
                }
                .padding(.horizontal, 12)
            }
            .buttonStyle(.plain)
        } else {
            HStack(spacing: 0) {
                NavigationLink(value: AppRoute.detail(card.id)) {
                    CardRowView(card: card, showsEllipsis: false)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)

                Button {
                    activeMenu = .card(card)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 46, height: 52)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("更多操作")
            }
        }
    }

    private func selectionCheck(_ selected: Bool) -> some View {
        ZStack {
            Circle()
                .fill(selected ? Theme.accent : Color.clear)
            Circle()
                .stroke(selected ? Theme.accent : Color(.separator), lineWidth: 1)
            if selected {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 24, height: 24)
    }

    private var bulkActionBar: some View {
        HStack {
            bulkButton("设置分组", icon: "person.2") {
                showToast("当前名片已在该分组")
            }
            bulkButton("分享名片", icon: "square.and.arrow.up") {
                share(cards: selectedCards)
            }
            bulkButton("保存到通讯录", icon: "person.crop.circle.badge.plus") {
                saveSelectedToContacts()
            }
            bulkButton("更多", icon: "ellipsis") {
                guard !selectedIDs.isEmpty else { return }
                activeMenu = .bulk
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(Color(.systemBackground))
        .overlay(alignment: .top) { Divider() }
    }

    @ViewBuilder
    private func groupActionMenu(_ menu: GroupMenu) -> some View {
        VStack(spacing: 0) {
            switch menu {
            case .add:
                menuButton("多选") {
                    dismissMenuThen { beginSelection() }
                }
                separator
                menuButton("拍名片") {
                    dismissMenuThen { showScanner = true }
                }
                separator
                menuButton("从名片夹中添加") {
                    dismissMenuThen { showCardPicker = true }
                }
            case .card(let card):
                if let phone = card.mobile ?? card.phone {
                    menuButton("打电话", icon: "phone") {
                        dismissMenuThen { openPhone(phone) }
                    }
                    separator
                }
                menuButton("管理分组", icon: "list.bullet.indent") {
                    dismissMenuThen { membershipCard = card }
                }
                separator
                menuButton("添加备注/拜访日志", icon: "note.text") {
                    dismissMenuThen { editCard = card }
                }
                separator
                menuButton("分享 TA 的名片", icon: "square.and.arrow.up") {
                    dismissMenuThen { share(cards: [card]) }
                }
            case .bulk:
                menuButton("删除选中名片", destructive: true) {
                    dismissMenuThen { deleteSelectedCards() }
                }
            }

            separator
            menuButton("取消") {
                activeMenu = nil
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 8)
        .background(Color(.systemBackground))
    }

    private var separator: some View {
        Divider().padding(.leading, 18)
    }

    private func menuButton(
        _ title: String,
        icon: String? = nil,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .regular))
                        .frame(width: 26)
                }
                Text(title)
                    .font(.body)
                Spacer()
            }
            .foregroundStyle(destructive ? Color.red : Theme.textPrimary)
            .padding(.horizontal, 18)
            .frame(height: 54)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func menuHeight(for menu: GroupMenu) -> CGFloat {
        switch menu {
        case .add:
            return 226
        case .card(let card):
            return card.mobile == nil && card.phone == nil ? 284 : 338
        case .bulk:
            return 170
        }
    }

    private func dismissMenuThen(_ action: @escaping () -> Void) {
        activeMenu = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            action()
        }
    }

    private func bulkButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 21))
                Text(title)
                    .font(.caption)
            }
            .foregroundStyle(selectedIDs.isEmpty ? Color(.tertiaryLabel) : Theme.textSecondary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(selectedIDs.isEmpty)
    }

    private var allVisibleSelected: Bool {
        !visibleCards.isEmpty && visibleCards.allSatisfy { selectedIDs.contains($0.id) }
    }

    private func beginSelection() {
        guard !store.cards.isEmpty else {
            showToast("名片夹还没有名片，无法批量操作")
            return
        }
        guard !allCards.isEmpty else {
            showToast("当前分组还没有名片")
            return
        }
        isSelecting = true
    }

    private func toggleSelection(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    private func toggleSelectAll() {
        let visibleIDs = Set(visibleCards.map(\.id))
        if allVisibleSelected {
            selectedIDs.subtract(visibleIDs)
        } else {
            selectedIDs.formUnion(visibleIDs)
        }
    }

    private func selectionInset(for card: BusinessCard) -> CGFloat {
        isSelecting ? 58 : 124
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

    private func showToast(_ message: String) {
        toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if toastMessage == message {
                toastMessage = nil
            }
        }
    }

    private func openPhone(_ value: String) {
        let digits = value.filter { $0.isNumber || $0 == "+" }
        guard let url = URL(string: "tel://\(digits)") else { return }
        UIApplication.shared.open(url)
    }

    private func share(cards: [BusinessCard]) {
        let exporter = SystemExportService()
        var combined = Data()
        for card in cards {
            if let data = try? exporter.makeVCard(for: card) {
                combined.append(data)
            }
        }
        guard !combined.isEmpty else {
            showToast("没有可分享的名片")
            return
        }
        shareData = combined
        showShareSheet = true
    }

    private func saveSelectedToContacts() {
        let cards = selectedCards
        guard !cards.isEmpty else { return }
        Task {
            let exporter = SystemExportService()
            for card in cards {
                try? await exporter.saveToSystemContacts(card)
            }
        }
    }

    private func deleteSelectedCards() {
        let cards = selectedCards
        let imageStore = ImageStore()
        for card in cards {
            try? store.delete(id: card.id)
            if let file = card.originalImageFileName {
                try? imageStore.deleteImage(fileName: file)
            }
            if let file = card.processedImageFileName, file != card.originalImageFileName {
                try? imageStore.deleteImage(fileName: file)
            }
            if let file = card.backImageFileName {
                try? imageStore.deleteImage(fileName: file)
            }
        }
        selectedIDs.removeAll()
        isSelecting = false
    }
}

private struct CardPickerView: View {
    @Environment(BusinessCardStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let tag: String
    @State private var selectedIDs: Set<UUID> = []

    private var candidates: [BusinessCard] {
        store.cards
            .filter { !$0.tags.contains(tag) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        Group {
            if candidates.isEmpty {
                ContentUnavailableView(
                    "没有可添加的名片",
                    systemImage: "person.crop.rectangle.stack",
                    description: Text("名片夹中的名片都已在此分组")
                )
            } else {
                List(candidates) { card in
                    Button {
                        if selectedIDs.contains(card.id) {
                            selectedIDs.remove(card.id)
                        } else {
                            selectedIDs.insert(card.id)
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: selectedIDs.contains(card.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedIDs.contains(card.id) ? Theme.accent : Color(.separator))
                            CardRowView(card: card, showsEllipsis: false)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("从名片夹中添加")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("添加") {
                    addSelected()
                }
                .disabled(selectedIDs.isEmpty)
            }
        }
    }

    private func addSelected() {
        for card in candidates where selectedIDs.contains(card.id) {
            var updated = card
            updated.tags.append(tag)
            try? store.update(updated)
        }
        dismiss()
    }
}

private struct CardGroupMembershipView: View {
    @Environment(BusinessCardStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let card: BusinessCard
    @State private var selectedTags: Set<String>
    @State private var isUngrouped: Bool
    @State private var searchText = ""
    @State private var showNewGroup = false
    @State private var newGroupName = ""
    @State private var pendingNewTag: String?

    private let suggestions = ["VIP", "客户", "供应商", "同行"]

    init(card: BusinessCard) {
        self.card = card
        _selectedTags = State(initialValue: Set(card.tags))
        _isUngrouped = State(initialValue: card.tags.isEmpty)
    }

    private var visibleGroups: [Tag] {
        let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let groups = needle.isEmpty
            ? store.tags
            : store.tags.filter { $0.name.localizedCaseInsensitiveContains(needle) }
        return groups.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            Button {
                showNewGroup = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus")
                        .font(.system(size: 18))
                    Text("新建分组")
                        .font(.body)
                    Spacer()
                }
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 18)
                .frame(height: 50)
                .background(Color(.systemBackground))
            }
            .buttonStyle(.plain)

            ScrollView {
                VStack(spacing: 0) {
                    groupChoice(title: "未分组", selected: isUngrouped) {
                        isUngrouped = true
                        selectedTags.removeAll()
                    }
                    Divider().padding(.leading, 18)

                    ForEach(visibleGroups) { group in
                        groupChoice(
                            title: group.name,
                            selected: !isUngrouped && selectedTags.contains(group.name)
                        ) {
                            toggle(group.name)
                        }
                        Divider().padding(.leading, 18)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("你可能会用到的分组")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                        FlowLayout(spacing: 8) {
                            ForEach(suggestions.filter { suggestion in
                                !store.tags.contains(where: { $0.name == suggestion })
                            }, id: \.self) { suggestion in
                                Button(suggestion) {
                                    addSuggestion(suggestion)
                                }
                                .font(.subheadline)
                                .foregroundStyle(Theme.textPrimary)
                                .padding(.horizontal, 18)
                                .frame(height: 34)
                                .background(Color(.systemBackground))
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                }
            }
            .background(Theme.background)
        }
        .navigationTitle("添加到分组")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("确认") { save() }
            }
        }
        .alert("新建分组", isPresented: $showNewGroup) {
            TextField("分组名称", text: $newGroupName)
            Button("创建") {
                let name = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                try? store.addTag(name)
                pendingNewTag = name
                newGroupName = ""
            }
            Button("取消", role: .cancel) { newGroupName = "" }
        }
        .onChange(of: store.tags) { _, _ in
            if let pendingNewTag {
                toggle(pendingNewTag)
                self.pendingNewTag = nil
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.textSecondary)
            TextField("请输入分组名称", text: $searchText)
                .font(.subheadline)
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
        .background(Color(.secondarySystemBackground))
        .clipShape(Capsule())
    }

    private func groupChoice(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.body)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Theme.accent : Color(.separator))
            }
            .padding(.horizontal, 18)
            .frame(height: 48)
            .background(Color(.systemBackground))
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ tagName: String) {
        isUngrouped = false
        if selectedTags.contains(tagName) {
            selectedTags.remove(tagName)
        } else {
            selectedTags.insert(tagName)
        }
    }

    private func addSuggestion(_ name: String) {
        try? store.addTag(name)
        toggle(name)
    }

    private func save() {
        var updated = card
        updated.tags = isUngrouped ? [] : Array(selectedTags)
        try? store.update(updated)
        dismiss()
    }
}
