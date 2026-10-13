import SwiftUI
import UIKit

struct VerificationView: View {
    let onSaved: () -> Void
    let onRetake: () -> Void

    @State private var viewModel: VerificationViewModel

    @MainActor
    init(
        originalImage: UIImage,
        processedImage: UIImage,
        store: BusinessCardStore,
        onSaved: @escaping () -> Void,
        onRetake: @escaping () -> Void
    ) {
        self.onSaved = onSaved
        self.onRetake = onRetake
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
            case .failed(let message):
                failedView(message)
            case .editing, .saved:
                editForm
            }
        }
        .navigationTitle("确认名片信息")
        .navigationBarBackButtonHidden(true)
        .task { await viewModel.run() }
    }

    private var editForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(rows) { row in
                    fieldRow(key: row.key, label: row.label)
                }

                if !viewModel.additionalEmails.isEmpty {
                    Text("识别到的其他邮箱：\(viewModel.additionalEmails.joined(separator: "、"))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if !viewModel.additionalPhones.isEmpty {
                    Text("识别到的其他电话：\(viewModel.additionalPhones.joined(separator: "、"))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                DisclosureGroup("OCR 原始文本") {
                    Text(viewModel.rawText.isEmpty ? "（无）" : viewModel.rawText)
                        .font(.footnote)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 16) {
                    Button("重拍") { onRetake() }
                        .buttonStyle(.bordered)
                    Button("保存") { viewModel.save() }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                }
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
            }
        }
        .padding()
    }
}
