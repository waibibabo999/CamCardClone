import Contacts
import Foundation

enum ContactExportError: LocalizedError {
    case permissionDenied
    case noContactData

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "没有联系人权限，请在系统设置中允许访问联系人。"
        case .noContactData:
            return "名片没有可导出的字段。"
        }
    }
}

protocol ExportService {
    func makeVCard(for card: BusinessCard) throws -> Data
    func saveToSystemContacts(_ card: BusinessCard) async throws
}

struct SystemExportService: ExportService {
    func makeVCard(for card: BusinessCard) throws -> Data {
        let contact = makeContact(from: card)
        guard !contact.givenName.isEmpty
                || !contact.organizationName.isEmpty
                || !contact.phoneNumbers.isEmpty
                || !contact.emailAddresses.isEmpty
                || !contact.urlAddresses.isEmpty
                || !contact.postalAddresses.isEmpty else {
            throw ContactExportError.noContactData
        }
        return try CNContactVCardSerialization.data(with: [contact])
    }

    func saveToSystemContacts(_ card: BusinessCard) async throws {
        let store = CNContactStore()
        let granted = await withCheckedContinuation { continuation in
            store.requestAccess(for: .contacts) { allowed, _ in
                continuation.resume(returning: allowed)
            }
        }
        guard granted else { throw ContactExportError.permissionDenied }

        let request = CNSaveRequest()
        request.add(makeContact(from: card), toContainerWithIdentifier: nil)
        try store.execute(request)
    }

    private func makeContact(from card: BusinessCard) -> CNMutableContact {
        let contact = CNMutableContact()
        contact.givenName = card.name ?? ""
        contact.organizationName = card.company ?? ""
        contact.jobTitle = card.jobTitle ?? ""
        contact.departmentName = card.department ?? ""

        var phones: [CNLabeledValue<CNPhoneNumber>] = []
        if let mobile = card.mobile {
            phones.append(CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: mobile)))
        }
        if let phone = card.phone {
            phones.append(CNLabeledValue(label: CNLabelPhoneNumberMain, value: CNPhoneNumber(stringValue: phone)))
        }
        if let fax = card.fax {
            phones.append(CNLabeledValue(label: CNLabelPhoneNumberWorkFax, value: CNPhoneNumber(stringValue: fax)))
        }
        for phone in card.additionalPhones {
            phones.append(CNLabeledValue(label: CNLabelOther, value: CNPhoneNumber(stringValue: phone)))
        }
        contact.phoneNumbers = phones

        var emails: [CNLabeledValue<NSString>] = []
        if let email = card.email {
            emails.append(CNLabeledValue(label: CNLabelWork, value: email as NSString))
        }
        for email in card.additionalEmails {
            emails.append(CNLabeledValue(label: CNLabelOther, value: email as NSString))
        }
        contact.emailAddresses = emails

        if let website = card.website {
            contact.urlAddresses = [CNLabeledValue(label: CNLabelURLAddressHomePage, value: website as NSString)]
        }
        if let address = card.address {
            let postal = CNMutablePostalAddress()
            postal.street = address
            contact.postalAddresses = [CNLabeledValue(label: CNLabelWork, value: postal)]
        }
        contact.note = card.notes ?? ""
        return contact
    }
}
