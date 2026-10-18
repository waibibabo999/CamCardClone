import SwiftUI
import UIKit

struct EditCardView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: BusinessCard
    @State private var additionalPhonesText: String
    @State private var additionalEmailsText: String
    @State private var newTag = ""
    @State private var errorMessage: String?

    private let store: BusinessCardStore
    private let onSaved: () -> Void

    @MainActor
    init(card: BusinessCard, store: BusinessCardStore, onSaved: @escaping () -> Void = {}) {
        _draft = State(initialValue: card)
        _additionalPhonesText = State(initialValue: card.additionalPhones.joined(separator: "\n"))
        _additionalEmailsText = State(initialValue: card.additionalEmails.joined(separator: "\n"))
        self.store = store
        self.onSaved = onSaved
    }

    var body: some View {
        Form {
            Section("基本信息") {
                field("姓名", keyPath: \.name)
                field("公司", keyPath: \.company)
                field("职位", keyPath: \.jobTitle)
                field("部门", keyPath: \.department)
            }

            Section("联系方式") {
                field("手机", keyPath: \.mobile, keyboard: .phonePad)
                field("电话", keyPath: \.phone, keyboard: .phonePad)
                field("传真", keyPath: \.fax, keyboard: .phonePad)
                field("邮箱", keyPath: \.email, keyboard: .emailAddress)
                field("网址", keyPath: \.website, keyboard: .URL)
                field("地址", keyPath: \.address)
                field("邮编", keyPath: \.postalCode, keyboard: .phonePad)
            }

            Section("其他电话") {
                TextEditor(text: $additionalPhonesText)
                    .frame(minHeight: 68)
                    .font(.body)
                Text("每行一个号码；没有就留空。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("其他邮箱") {
                TextEditor(text: $additionalEmailsText)
                    .frame(minHeight: 68)
                    .font(.body)
                Text("每行一个邮箱；没有就留空。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("备注") {
                TextEditor(text: binding(\.notes))
                    .frame(minHeight: 90)
            }

            Section("标签") {
                ForEach(store.tags) { tag in
                    Button {
                        toggleTag(tag.name)
                    } label: {
                        HStack {
                            Text(tag.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if draft.tags.contains(tag.name) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                    }
                }

                HStack {
                    TextField("新标签", text: $newTag)
                    Button("添加") {
                        addTag()
                    }
                    .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .navigationTitle("编辑名片")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { save() }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("saveCardButton")
            }
        }
        .alert("保存失败", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func field(
        _ title: String,
        keyPath: WritableKeyPath<BusinessCard, String?>,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        HStack {
            Text(title)
                .frame(width: 64, alignment: .leading)
            TextField(title, text: binding(keyPath))
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
                .accessibilityIdentifier("field_\(title)")
        }
    }

    private func binding(_ keyPath: WritableKeyPath<BusinessCard, String?>) -> Binding<String> {
        Binding(
            get: { draft[keyPath: keyPath] ?? "" },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                draft[keyPath: keyPath] = trimmed.isEmpty ? nil : trimmed
            }
        )
    }

    private func toggleTag(_ tag: String) {
        if let index = draft.tags.firstIndex(of: tag) {
            draft.tags.remove(at: index)
        } else {
            draft.tags.append(tag)
        }
    }

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try store.addTag(trimmed)
            if !draft.tags.contains(trimmed) {
                draft.tags.append(trimmed)
            }
            newTag = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() {
        draft.additionalPhones = lines(from: additionalPhonesText)
        draft.additionalEmails = lines(from: additionalEmailsText)
        do {
            try store.update(draft)
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func lines(from text: String) -> [String] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
