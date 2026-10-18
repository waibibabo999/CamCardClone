import SwiftUI
import UIKit

struct VerificationView: View {
    let onSaved: () -> Void
    let onRetake: () -> Void
    let onCancel: () -> Void

    @State private var viewModel: VerificationViewModel

    @MainActor
    init(
        originalImage: UIImage,
        processedImage: UIImage,
        store: BusinessCardStore,
        onSaved: @escaping () -> Void,
        onRetake: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onSaved = onSaved
        self.onRetake = onRetake
        self.onCancel = onCancel
        _viewModel = State(initialValue: VerificationViewModel(
            originalImage: originalImage,
            processedImage: processedImage,
            store: store
        ))
    }

    private struct FieldRow: Identifiable {
        let key: FieldKey
        let label: String
        var id: FieldKey { key }
    }

    private let rows: [FieldRow] = [
        FieldRow(key: .name, label: "姓名"),
        FieldRow(key: .company, label: "公司"),
        FieldRow(key: .jobTitle, label: "职位"),
        FieldRow(key: .department, label: "部门"),
        FieldRow(key: .mobile, label: "手机"),
        FieldRow(key: .phone, label: "电话"),
        FieldRow(key: .fax, label: "传真"),
        FieldRow(key: .email, label: "邮箱"),
        FieldRow(key: .website, label: "网址"),
        FieldRow(key: .address, label: "地址"),
        FieldRow(key: .postalCode, label: "邮编"),
        FieldRow(key: .notes, label: "备注")
    ]

    var body: some View {
        Group {
            switch viewModel.phase {
            case .processing:
                ProgressView("正在识别名片文字…")
            case .noResult:
                noResultView
            case .failed(let message):
                failedView(message)
            case .editing, .saved:
                editForm
            }
        }
        .navigationTitle("确认名片信息")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { onCancel() }
            }
        }
        .task { await viewModel.run() }
    }

    private var editForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(rows) { row in
                    fieldRow(key: row.key, label: row.label)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("其他电话（每行一个）")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: Binding(
                        get: { viewModel.additionalPhonesText },
                        set: { viewModel.setAdditionalPhones($0) }
                    ))
                    .frame(minHeight: 54)
                    .font(.footnote)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("其他邮箱（每行一个）")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: Binding(
                        get: { viewModel.additionalEmailsText },
                        set: { viewModel.setAdditionalEmails($0) }
                    ))
                    .frame(minHeight: 54)
                    .font(.footnote)
                }

                DisclosureGroup("OCR 原始文本") {
                    Text(viewModel.rawText.isEmpty ? "（无）" : viewModel.rawText)
                        .font(.footnote)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 12) {
                    Button("取消") { onCancel() }
                        .buttonStyle(.bordered)
                    Button("重拍") { onRetake() }
                        .buttonStyle(.bordered)
                    Button("恢复识别结果") { viewModel.resetToOCR() }
                        .buttonStyle(.bordered)
                }
                Button("保存") { viewModel.save() }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
            .padding()
        }
        .alert(
            "保存失败",
            isPresented: Binding(
                get: { viewModel.saveError != nil },
                set: { if !$0 { viewModel.saveError = nil } }
            )
        ) {
            Button("好", role: .cancel) {}
        } message: {
            Text(viewModel.saveError ?? "")
        }
        .onChange(of: viewModel.phase) { _, phase in
            if phase == .saved { onSaved() }
        }
    }

    private func fieldRow(key: FieldKey, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(label, text: textBinding(key))
                .textFieldStyle(.roundedBorder)
                .keyboardType(keyboardType(for: key))
                .textInputAutocapitalization(key == .name || key == .company ? .words : .never)
        }
    }

    private func textBinding(_ key: FieldKey) -> Binding<String> {
        Binding(
            get: { viewModel.value(for: key) ?? "" },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                viewModel.updateField(key: key, value: trimmed.isEmpty ? nil : trimmed)
            }
        )
    }

    private func keyboardType(for key: FieldKey) -> UIKeyboardType {
        switch key {
        case .email: return .emailAddress
        case .website: return .URL
        case .mobile, .phone, .fax, .postalCode: return .phonePad
        default: return .default
        }
    }

    private func failedView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 40))
            Text("识别失败")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack {
                Button("重拍") { onRetake() }
                    .buttonStyle(.bordered)
                Button("重试") { Task { await viewModel.retry() } }
                    .buttonStyle(.borderedProminent)
                Button("手动录入") { viewModel.beginManualEntry() }
                    .buttonStyle(.bordered)
            }
        }
        .padding()
    }

    private var noResultView: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 40))
            Text("没有识别到文字")
                .font(.headline)
            Text("可以重试、重拍，或者手动录入名片信息。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack {
                Button("重拍") { onRetake() }
                    .buttonStyle(.bordered)
                Button("重试") { Task { await viewModel.retry() } }
                    .buttonStyle(.bordered)
                Button("手动录入") { viewModel.beginManualEntry() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}
