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

/// 基于标签、行首特征和正则的确定性解析器。
///
/// 设计原则：
/// - 有明确标签时，只去掉标签本身，保留整行剩余内容；
/// - 没有标签时按整行判断，绝不按第一个空格截断；
/// - 无法确认的字段返回 nil；
/// - 不根据语义补全名片上不存在的信息。
struct RuleBasedFieldParser: FieldParserService {
    private let emailRegex = try! NSRegularExpression(
        pattern: #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#
    )
    private let websiteRegex = try! NSRegularExpression(
        pattern: #"(?i)(?:https?://[^\s]+|www\.[^\s]+|(?:[a-z0-9-]+\.)+(?:com|cn|net|org|edu|io|co|uk|ai|dev)(?:/[^\s]*)?)"#
    )
    private let phoneRegex = try! NSRegularExpression(
        pattern: #"\+?\d[\d\s\-()（）]{6,}\d"#
    )

    private let companyHints = [
        "公司", "集团", "大学", "学院", "研究院", "研究所", "事务所", "银行",
        "co.,", "co.", "ltd", "inc", "corp", "llc", "llp", "group",
        "university", "institute", "college", "hospital", "bank",
        "partners", "consulting", "studio", "media", "analytics",
        "systems", "technologies", "services", "logistics", "publishing",
        "financial", "trading", "design", "center", "energy",
        "科技", "新能源", "装饰", "设计"
    ]
    private let titleHints = [
        "职位", "职务", "职称", "title", "job", "professor", "director",
        "manager", "engineer", "consultant", "architect", "designer",
        "editor", "producer", "lead", "partner", "scientist", "officer",
        "specialist", "coordinator", "president", "founder",
        "设计师", "工程师", "经理", "总监", "教授", "主任", "主管",
        "专员", "顾问", "首席", "副总", "总裁", "创始人", "研发", "编辑"
    ]
    private let addressHints = [
        "street", "st.", "avenue", "ave.", "road", "rd.", "drive", "dr.",
        "suite", "floor", "building", "lane", "boulevard", "highway",
        "路", "街", "道", "号", "室", "楼", "区", "市", "省", "县", "巷"
    ]
    private let departmentHints = [
        "department", "dept", "school", "college", "faculty",
        "部门", "学院", "系"
    ]

    private let labelMap: [(FieldKey, [String])] = [
        (.name, ["姓名", "name"]),
        (.company, ["公司名称", "company name", "公司", "company"]),
        (.jobTitle, ["职位", "职务", "职称", "job title", "title"]),
        (.department, ["部门", "dept", "department"]),
        (.mobile, ["手机", "mobile", "cell"]),
        (.phone, ["电话", "tel", "phone", "office"]),
        (.fax, ["传真", "fax"]),
        (.email, ["邮箱", "email", "e-mail"]),
        (.website, ["网址", "网站", "web", "website", "url"]),
        (.address, ["地址", "address"]),
        (.postalCode, ["邮编", "zip", "postal"]),
        (.notes, ["备注", "note"])
    ]

    func parse(ocrResult: OCRResult) -> ParsedFields {
        var values: [FieldKey: String] = [:]
        var additionalEmails: [String] = []
        var additionalPhones: [String] = []
        var unlabeled: [String] = []

        let lines = ocrResult.rawText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for line in lines {
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

            if isWebsiteLine(line), let website = website(in: line) {
                if values[.website] == nil {
                    values[.website] = website
                }
                continue
            }

            if let (key, value) = labeledValue(in: line) {
                assign(key: key, value: value, values: &values, additionalPhones: &additionalPhones)
                continue
            }

            if looksLikePhoneOnly(line), let number = phoneDigits(line) {
                assignPhone(number, values: &values, additionalPhones: &additionalPhones)
                continue
            }

            unlabeled.append(line)
        }

        classifyUnlabeled(
            unlabeled,
            values: &values,
            additionalPhones: &additionalPhones
        )

        let fields = FieldKey.allCases.map { key -> CardField in
            if let value = values[key], !value.isEmpty {
                return CardField(key: key, value: value, source: .ocr)
            }
            return CardField(key: key, value: nil, source: .empty)
        }

        return ParsedFields(
            fields: fields,
            additionalEmails: additionalEmails,
            additionalPhones: additionalPhones
        )
    }

    // MARK: - 标签与字段赋值

    private func labeledValue(in line: String) -> (FieldKey, String)? {
        let lower = line.lowercased()
        for (key, labels) in labelMap {
            for label in labels where lower.hasPrefix(label.lowercased()) {
                var remainder = line.dropFirst(label.count)
                remainder = remainder.drop(while: {
                    $0.isWhitespace || $0 == ":" || $0 == "：" || $0 == "-"
                })
                let value = String(remainder).trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty {
                    return (key, value)
                }
            }
        }
        return nil
    }

    private func assign(
        key: FieldKey,
        value: String,
        values: inout [FieldKey: String],
        additionalPhones: inout [String]
    ) {
        switch key {
        case .mobile, .phone, .fax:
            if values[key] == nil {
                values[key] = value
            } else if !additionalPhones.contains(value) {
                additionalPhones.append(value)
            }
        default:
            if values[key] == nil {
                values[key] = value
            }
        }
    }

    private func assignPhone(
        _ number: String,
        values: inout [FieldKey: String],
        additionalPhones: inout [String]
    ) {
        if isMobileNumber(number), values[.mobile] == nil {
            values[.mobile] = number
        } else if values[.phone] == nil {
            values[.phone] = number
        } else if values[.mobile] == nil, number != values[.phone] {
            values[.mobile] = number
        } else if !additionalPhones.contains(number) {
            additionalPhones.append(number)
        }
    }

    private func isMobileNumber(_ number: String) -> Bool {
        let digits = number.filter(\.isNumber)
        if digits.count == 11, digits.hasPrefix("1") {
            return true
        }
        if digits.count == 13, digits.hasPrefix("86"), digits.dropFirst(2).first == "1" {
            return true
        }
        return false
    }

    // MARK: - 无标签行分类

    private func classifyUnlabeled(
        _ lines: [String],
        values: inout [FieldKey: String],
        additionalPhones: inout [String]
    ) {
        var remaining = lines

        if values[.name] == nil,
           let index = remaining.firstIndex(where: isLikelyName) {
            values[.name] = remaining.remove(at: index)
        }

        if values[.jobTitle] == nil,
           let best = remaining.max(by: { titleScore($0) < titleScore($1) }),
           titleScore(best) > 0 {
            values[.jobTitle] = best
            remaining.removeAll { $0 == best }
        }

        if values[.company] == nil,
           let best = remaining.max(by: { companyScore($0) < companyScore($1) }),
           companyScore(best) > 0 {
            values[.company] = best
            remaining.removeAll { $0 == best }
        }

        if values[.department] == nil,
           let index = remaining.firstIndex(where: isDepartment) {
            values[.department] = remaining.remove(at: index)
        }

        if values[.address] == nil,
           let index = remaining.firstIndex(where: isAddress) {
            values[.address] = remaining.remove(at: index)
        }

        // Some cards put the name below the title/company. Use the first
        // remaining short line only after the stronger classifications.
        if values[.name] == nil,
           let index = remaining.firstIndex(where: { isShortLine($0) && !isAddress($0) }) {
            values[.name] = remaining.remove(at: index)
        }

        for line in remaining {
            if let number = phoneDigits(line), looksLikePhoneOnly(line) {
                assignPhone(number, values: &values, additionalPhones: &additionalPhones)
            }
        }
    }

    private func isLikelyName(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isAddress(trimmed), titleScore(trimmed) == 0, companyScore(trimmed) == 0 else {
            return false
        }
        if trimmed.rangeOfCharacter(from: .decimalDigits) != nil { return false }
        if trimmed.contains("@") || trimmed.lowercased().contains("http") { return false }

        let cjkCount = trimmed.unicodeScalars.filter { (0x4E00...0x9FFF).contains($0.value) }.count
        if cjkCount >= 2 { return true }

        let words = trimmed
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
        guard (2...4).contains(words.count) else { return false }
        return words.allSatisfy { word in
            guard let first = word.first else { return false }
            return first.isUppercase || ["Dr.", "Mr.", "Ms.", "Mrs."].contains(word)
        }
    }

    private func titleScore(_ line: String) -> Int {
        let lower = line.lowercased()
        return titleHints.reduce(0) { score, hint in
            score + (lower.contains(hint.lowercased()) ? 1 : 0)
        }
    }

    private func companyScore(_ line: String) -> Int {
        let lower = line.lowercased()
        let base = companyHints.reduce(0) { score, hint in
            score + (lower.contains(hint.lowercased()) ? 1 : 0)
        }
        let hasStrongCompanyCue = lower.contains("partners")
            || lower.contains("llp")
            || lower.contains("llc")
            || lower.contains("ltd")
            || lower.contains("inc")
            || lower.contains("group")
        // A job-title word should win when both sides match, e.g.
        // "Systems Architect" is a title, not a company.
        return max(0, base - (titleScore(line) > 0 && !hasStrongCompanyCue ? 1 : 0))
    }

    private func isAddress(_ line: String) -> Bool {
        let lower = line.lowercased()
        return addressHints.contains { lower.contains($0.lowercased()) }
    }

    private func isDepartment(_ line: String) -> Bool {
        let lower = line.lowercased()
        return departmentHints.contains { lower.contains($0.lowercased()) }
    }

    private func isShortLine(_ line: String) -> Bool {
        line.count <= 40 && !line.contains("@")
    }

    // MARK: - 正则工具

    private func emails(in line: String) -> [String]? {
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        let matches = emailRegex.matches(in: line, range: range)
        let results = matches.compactMap { Range($0.range, in: line).map { String(line[$0]) } }
        return results.isEmpty ? nil : results
    }

    private func isWebsiteLine(_ line: String) -> Bool {
        let lower = line.lowercased()
        return lower.contains("www.")
            || lower.contains("http")
            || lower.contains("网址")
            || lower.contains("网站")
            || lower.hasPrefix("web")
            || lower.hasPrefix("website")
    }

    private func website(in line: String) -> String? {
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = websiteRegex.firstMatch(in: line, range: range),
              let result = Range(match.range, in: line).map({ String(line[$0]) }) else {
            return nil
        }
        return result.trimmingCharacters(in: CharacterSet(charactersIn: "，,。.;；"))
    }

    private func looksLikePhoneOnly(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.rangeOfCharacter(from: .letters) == nil,
              trimmed.rangeOfCharacter(from: .decimalDigits) != nil else {
            return false
        }
        return phoneDigits(trimmed) != nil
    }

    private func phoneDigits(_ line: String) -> String? {
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = phoneRegex.firstMatch(in: line, range: range),
              let result = Range(match.range, in: line).map({ String(line[$0]) }) else {
            return nil
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
