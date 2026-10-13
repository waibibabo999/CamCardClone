import Foundation

/// 测试名片对应的 Ground Truth，用于计算字段级准确率。
/// 字段不存在时为 nil；`additionalEmails` / `additionalPhones` 仅多邮箱 / 多电话场景出现。
struct GroundTruth: Identifiable, Codable, Hashable {
    var id: String
    var name: String?
    var company: String?
    var jobTitle: String?
    var department: String?
    var mobile: String?
    var phone: String?
    var fax: String?
    var email: String?
    var website: String?
    var address: String?
    var postalCode: String?
    var notes: String?
    var additionalEmails: [String]?
    var additionalPhones: [String]?

    init(
        id: String,
        name: String? = nil,
        company: String? = nil,
        jobTitle: String? = nil,
        department: String? = nil,
        mobile: String? = nil,
        phone: String? = nil,
        fax: String? = nil,
        email: String? = nil,
        website: String? = nil,
        address: String? = nil,
        postalCode: String? = nil,
        notes: String? = nil,
        additionalEmails: [String]? = nil,
        additionalPhones: [String]? = nil
    ) {
        self.id = id
        self.name = name
        self.company = company
        self.jobTitle = jobTitle
        self.department = department
        self.mobile = mobile
        self.phone = phone
        self.fax = fax
        self.email = email
        self.website = website
        self.address = address
        self.postalCode = postalCode
        self.notes = notes
        self.additionalEmails = additionalEmails
        self.additionalPhones = additionalPhones
    }
}
