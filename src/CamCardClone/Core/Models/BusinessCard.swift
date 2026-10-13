import Foundation

/// 一张名片的结构化记录。
///
/// 规则：
/// - 所有可选字段为 Optional，名片上不存在的信息必须为 nil，不允许用空字符串代替。
/// - 只存图片文件名，不存绝对路径；图片文件存 Documents/Images/。
/// - `additionalEmails` / `additionalPhones` 用于多邮箱 / 多电话场景。
struct BusinessCard: Identifiable, Codable, Hashable {
    let id: UUID
    var originalImageFileName: String
    var processedImageFileName: String
    var name: String?
    var company: String?
    var jobTitle: String?
    var mobile: String?
    var phone: String?
    var fax: String?
    var email: String?
    var website: String?
    var address: String?
    var department: String?
    var postalCode: String?
    var notes: String?
    var tags: [String]
    var additionalEmails: [String]
    var additionalPhones: [String]
    var createdAt: Date
    var updatedAt: Date
    var ocrRawText: String?

    init(
        id: UUID = UUID(),
        originalImageFileName: String,
        processedImageFileName: String,
        name: String? = nil,
        company: String? = nil,
        jobTitle: String? = nil,
        mobile: String? = nil,
        phone: String? = nil,
        fax: String? = nil,
        email: String? = nil,
        website: String? = nil,
        address: String? = nil,
        department: String? = nil,
        postalCode: String? = nil,
        notes: String? = nil,
        tags: [String] = [],
        additionalEmails: [String] = [],
        additionalPhones: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        ocrRawText: String? = nil
    ) {
        self.id = id
        self.originalImageFileName = originalImageFileName
        self.processedImageFileName = processedImageFileName
        self.name = name
        self.company = company
        self.jobTitle = jobTitle
        self.mobile = mobile
        self.phone = phone
        self.fax = fax
        self.email = email
        self.website = website
        self.address = address
        self.department = department
        self.postalCode = postalCode
        self.notes = notes
        self.tags = tags
        self.additionalEmails = additionalEmails
        self.additionalPhones = additionalPhones
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.ocrRawText = ocrRawText
    }
}
