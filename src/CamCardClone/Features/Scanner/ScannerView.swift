import SwiftUI

/// 扫描入口页。本批次只做页面骨架，拍摄与相册导入在批次 B 接入。
struct ScannerView: View {
    var body: some View {
        VStack(spacing: Theme.spacing) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 48))
                .foregroundStyle(Theme.textSecondary)
            Text("扫描名片")
                .font(.title2.bold())
            Text("本页面将在下一批次接入相机与相册导入")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)

            Button {
                // 批次 B：进入相机拍摄
            } label: {
                Label("拍摄名片", systemImage: "camera")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                // 批次 B：PhotosPicker 相册导入
            } label: {
                Label("从相册导入", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .navigationTitle("扫描名片")
    }
}
