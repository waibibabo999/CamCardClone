import Foundation

/// 字段解析结果。多邮箱 / 多电话无法用单个 `CardField` 表达，单独放在附加数组里。
struct ParsedFields {
    var fields: [CardField]
    var additionalEmails: [String] = []
    var additionalPhones: [String] = []
}

protocol FieldParserService {
    func parse(ocrResult: OCRResult) -> ParsedFields
}

/// 基于规则（标签 + 正则）的确定性解析器。
///
/// 原则：只把能确认的行映射到字段，无法确认就留 nil，**不允许根据语义补全名片上不存在的信息**。
struct RuleBasedFieldParser: FieldParserService {
    private let emailRegex = try! NSRegularExpression(pattern: #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#)
    private let websiteRegex = try! NSRegularExpression(pattern: #"(?:https?://)?(?:www\.)?[A-Za-z0-9-]+(?:\.[A-Za-z]{2,})+(?:/[^\s，,]*)*"#)
    private let phoneRegex = try! NSRegularExpression(pattern: #"\+?\d[\d\s\-()（）]{6,}\d"#)

    private let companyHints = ["公司", "集团", "大学", "学院", "研究院", "事务所", "银行",
                                "co.,", "ltd.", "inc.", "corp.", "llc", "llp", "group",
                                "university", "institute", "hospital", "bank", "partners",
                                "consulting", "studio", "media", "analytics", "systems"]
    private let titleHints = ["职位", "职务", "职称", "title", "job", "professor",
                              "director", "manager", "engineer", "consultant", "architect",
                              "设计师", "工程师", "经理", "总监", "教授", "主任", "主管", "专员", "顾问"]

    func parse(ocrResult: OCRResult) -> ParsedFields {
        var values: [FieldKey: String] = [:]
        var additionalEmails: [String] = []
        var additionalPhones: [String] = []
        var unclassified: [String] = []

        let lines = ocrResult.rawText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for line in lines {
            let lowered = line.lowercased()

            if let emails = emails(in: line), !emails.isEmpty {
                for email in emails {
                    if values[.email] == nil {
                        values[.email] = email
                    } else if !additionalEmails.contains(email) {
                        additionalEmails.append(email)
                    }
                }
                continue
            }

            if let website = website(in: line), values[.website] == nil {
                values[.website] = website
                continue
            }

            if let fax = value(in: line, lowered: lowered, labels: ["fax", "传真"]) {
                values[.fax] = fax
                continue
            }

            if let mobile = value(in: line, lowered: lowered, labels: ["mobile", "手机"]) {
                values[.mobile] = mobile
                continue
            }

            if let phone = value(in: line, lowered: lowered, labels: ["tel", "phone", "office", "电话"]) {
                let cleaned = phoneDigits(phone)
                if let number = cleaned {
                    if values[.phone] == nil {
                        values[.phone] = number
                    } else if !additionalPhones.contains(number) {
                        additionalPhones.append(number)
                    }
                }
                continue
            }

            if let postal = value(in: line, lowered: lowered, labels: ["postal", "zip", "邮编"]) {
                values[.postalCode] = postal
                continue
            }

            if let department = value(in: line, lowered: lowered, labels: ["department", "dept", "部门"]) {
                values[.department] = department
                continue
            }

            if let address = value(in: line, lowered: lowered, labels: ["address", "地址"]) {
                values[.address] = address
                continue
            }

            if let name = value(in: line, lowered: lowered, labels: ["name", "姓名"]) {
                values[.name] = name
                continue
            }

            if let title = value(in: line, lowered: lowered, labels: ["job", "title", "职位", "职务", "职称"]) {
                values[.jobTitle] = title
                continue
            }

            if let company = value(in: line, lowered: lowered, labels: companyHints) {
                values[.company] = company
                continue
            }

            if let title = matchedHint(line, lowered: lowered, hints: titleHints) {
                values[.jobTitle] = title
                continue
            }

            // 无标签但整行看起来像电话号码
            if let number = phoneDigits(line), values[.phone] == nil {
                values[.phone] = number
                continue
            }

            unclassified.append(line)
        }

        // 姓名兜底：取第一行“像人名的短行”（无数字、无 @、无 http、长度适中）。
        if values[.name] == nil {
            values[.name] = unclassified.first { candidate in
                let c = candidate.trimmingCharacters(in: .whitespaces)
                let looksNumeric = c.rangeOfCharacter(from: .decimalDigits) != nil
                let looksContact = c.contains("@") || c.lowercased().contains("http") || c.lowercased().contains("www")
                return !looksNumeric && !looksContact && c.count <= 24 && c.count >= 1
            }
        }

        let allKeys = FieldKey.allCases
        let fields = allKeys.map { key -> CardField in
            if let value = values[key] {
                return CardField(key: key, value: value, source: .ocr)
            }
            return CardField(key: key, value: nil, source: .empty)
        }

        return ParsedFields(fields: fields, additionalEmails: additionalEmails, additionalPhones: additionalPhones)
    }

    // MARK: - 私有工具

    private func emails(in line: String) -> [String]? {
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        let matches = emailRegex.matches(in: line, range: range)
        let results = matches.compactMap { Range($0.range, in: line).map { String(line[$0]) } }
        return results.isEmpty ? nil : results
    }

    private func website(in line: String) -> String? {
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = websiteRegex.firstMatch(in: line, range: range),
              let result = Range(match.range, in: line).map({ String(line[$0]) }) else {
            return nil
        }
        return result
    }

    /// 找到标签后返回去掉“标签 + 冒号”的剩余部分。
    private func value(in line: String, lowered: String, labels: [String]) -> String? {
        guard labels.contains(where: { lowered.contains($0.lowercased()) }) else { return nil }
        let separators = ["：", ":", " ", "  "]
        for separator in separators {
            if let range = line.range(of: separator) {
                let remainder = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !remainder.isEmpty { return remainder }
            }
        }
        return line.trimmingCharacters(in: .whitespaces)
    }

    /// 只按后缀/关键词命中，返回整行（去掉冒号前缀）。
    private func matchedHint(_ line: String, lowered: String, hints: [String]) -> String? {
        guard hints.contains(where: { lowered.contains($0.lowercased()) }) else { return nil }
        for separator in ["：", ":"] {
            if let range = line.range(of: separator) {
                return String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
        }
        return line.trimmingCharacters(in: .whitespaces)
    }

    /// 从一行里提取电话号码主体（去掉标签文字），无号码则返回 nil。
    private func phoneDigits(_ line: String) -> String? {
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = phoneRegex.firstMatch(in: line, range: range),
              let result = Range(match.range, in: line).map({ String(line[$0]) }) else {
            return nil
        }
        return result.trimmingCharacters(in: .whitespaces)
    }
}
