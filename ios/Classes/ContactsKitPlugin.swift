import Flutter
import UIKit
import Contacts

public class ContactsKitPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "contacts_kit", binaryMessenger: registrar.messenger())
        let instance = ContactsKitPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
        case "requestPermission":
            requestPermission(result: result)
        case "hasPermission":
            hasPermission(result: result)
        case "getAllContacts":
            getAllContacts(result: result)
        case "getContactsCount":
            getContactsCount(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func requestPermission(result: @escaping FlutterResult) {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { granted, error in
            DispatchQueue.main.async {
                result(granted)
            }
        }
    }

    private func hasPermission(result: @escaping FlutterResult) {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        result(status == .authorized)
    }

    private func getAllContacts(result: @escaping FlutterResult) {
        let status = CNContactStore.authorizationStatus(for: .contacts)

        guard status == .authorized else {
            result(FlutterError(code: "PERMISSION_DENIED",
                              message: "Contacts permission not granted",
                              details: nil))
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let contacts = try self.fetchContacts()
                DispatchQueue.main.async {
                    result(contacts)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "FETCH_ERROR",
                                      message: error.localizedDescription,
                                      details: nil))
                }
            }
        }
    }

    private func getContactsCount(result: @escaping FlutterResult) {
        let status = CNContactStore.authorizationStatus(for: .contacts)

        guard status == .authorized else {
            result(FlutterError(code: "PERMISSION_DENIED",
                              message: "Contacts permission not granted",
                              details: nil))
            return
        }

        let store = CNContactStore()
        let keysToFetch: [CNKeyDescriptor] = [CNContactIdentifierKey as CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keysToFetch)

        var count = 0
        do {
            try store.enumerateContacts(with: request) { _, _ in
                count += 1
            }
            result(count)
        } catch {
            result(0)
        }
    }

    private func fetchContacts() throws -> [[String: Any]] {
        let store = CNContactStore()
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor
        ]

        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        request.sortOrder = .givenName

        var contacts: [[String: Any]] = []

        try store.enumerateContacts(with: request) { contact, _ in
            let displayName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)

            let phones = contact.phoneNumbers.map { $0.value.stringValue }
            let emails = contact.emailAddresses.map { $0.value as String }

            let contactDict: [String: Any] = [
                "id": contact.identifier,
                "displayName": displayName.isEmpty ? "No Name" : displayName,
                "givenName": contact.givenName,
                "familyName": contact.familyName,
                "phones": phones,
                "emails": emails
            ]

            contacts.append(contactDict)
        }

        return contacts
    }
}