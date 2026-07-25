import Foundation
import Vapor

struct ContactResponse: Content, Sendable {
    let uid: String
    let name: String
    let mobile: String
    let photoURL: String
    let pushToken: String
    let publicKeyString: String

    init(model: ContactModel, publicBaseURL: URL) {
        uid = model.firebaseUID
        name = model.name
        mobile = model.mobile
        pushToken = model.pushToken
        publicKeyString = model.publicKey
        if let version = model.photoVersion {
            photoURL = ["v1", "profile-photos", model.firebaseUID]
                .reduce(publicBaseURL) { $0.appending(path: $1) }
                .appending(queryItems: [.init(name: "v", value: version.uuidString.lowercased())])
                .absoluteString
        } else {
            photoURL = ""
        }
    }
}

struct ContactLookupRequest: Content, Sendable {
    let mobileNumbers: [String]

    func validatedNumbers() throws -> [String] {
        guard !mobileNumbers.isEmpty, mobileNumbers.count <= 500 else {
            throw Abort(.badRequest, reason: "mobileNumbers must contain between 1 and 500 values")
        }
        let numbers = Array(Set(mobileNumbers))
        guard numbers.allSatisfy(Validation.isE164) else {
            throw Abort(.badRequest, reason: "mobileNumbers contains an invalid E.164 phone number")
        }
        return numbers
    }
}

struct ProfileUpdateRequest: Content, Sendable {
    let name: String
    let mobile: String
    let pushToken: String
    let publicKeyString: String

    func validated() throws -> ProfileUpdateRequest {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let mobile = mobile.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.count <= 100,
              mobile.isEmpty || Validation.isE164(mobile),
              pushToken.count <= 4_096,
              publicKeyString.count <= 8_192 else {
            throw Abort(.badRequest, reason: "Profile contains invalid values")
        }
        return ProfileUpdateRequest(
            name: name,
            mobile: mobile,
            pushToken: pushToken,
            publicKeyString: publicKeyString
        )
    }
}

struct PushTokenUpdateRequest: Content, Sendable {
    let pushToken: String

    func validated() throws -> String {
        guard !pushToken.isEmpty, pushToken.count <= 4_096 else {
            throw Abort(.badRequest, reason: "pushToken is invalid")
        }
        return pushToken
    }
}

enum Validation {
    static func isE164(_ value: String) -> Bool {
        guard value.count >= 9, value.count <= 16, value.first == "+" else {
            return false
        }
        let digits = value.dropFirst()
        return digits.first != "0"
            && digits.unicodeScalars.allSatisfy { (48 ... 57).contains($0.value) }
    }
}
