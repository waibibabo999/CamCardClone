#if DEBUG
import UIKit

@MainActor
enum UITestSupport {
    static func seedIfNeeded() {
        guard ProcessInfo.processInfo.arguments.contains("-ui-testing-seed") else { return }

        let image = makeCardImage()
        guard let data = image.jpegData(compressionQuality: 0.9) else { return }
        let imageStore = ImageStore()
        let store = BusinessCardStore()

        do {
            try store.addTag("会议")
            try store.addTag("客户")

            let firstID = UUID()
            let firstOriginal = try imageStore.saveOriginal(data, cardID: firstID)
            let firstProcessed = try imageStore.saveProcessed(data, cardID: firstID)
            try store.add(BusinessCard(
                id: firstID,
                originalImageFileName: firstOriginal,
                processedImageFileName: firstProcessed,
                name: "张伟",
                company: "上海远景科技有限公司",
                jobTitle: "技术总监",
                mobile: "+86 138-0013-8000",
                email: "zhangwei@example.com",
                address: "上海市浦东新区世纪大道 100 号 25 层",
                notes: "UI 测试名片",
                tags: ["会议"]
            ))

            let secondID = UUID()
            let secondOriginal = try imageStore.saveOriginal(data, cardID: secondID)
            let secondProcessed = try imageStore.saveProcessed(data, cardID: secondID)
            try store.add(BusinessCard(
                id: secondID,
                originalImageFileName: secondOriginal,
                processedImageFileName: secondProcessed,
                name: "李静怡",
                company: "北京华信医疗科技有限公司",
                jobTitle: "产品经理",
                mobile: "139-0022-4567",
                tags: ["客户"]
            ))
        } catch {
            print("UI test seed failed: \(error)")
        }
    }

    private static func makeCardImage() -> UIImage {
        let size = CGSize(width: 900, height: 560)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor(red: 0.11, green: 0.3, blue: 0.85, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 28, height: size.height))

            let title = "张伟" as NSString
            title.draw(
                at: CGPoint(x: 70, y: 80),
                withAttributes: [
                    .font: UIFont.boldSystemFont(ofSize: 46),
                    .foregroundColor: UIColor.black
                ]
            )
            let company = "上海远景科技有限公司" as NSString
            company.draw(
                at: CGPoint(x: 70, y: 160),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 28),
                    .foregroundColor: UIColor.darkGray
                ]
            )
        }
    }
}
#endif
