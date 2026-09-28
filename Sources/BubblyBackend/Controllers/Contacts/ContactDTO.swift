//
//  ContactDTO.swift
//  BubblyBackend
//
//  Created by Aung Ko Min on 28/9/26.
//

import Foundation
import Shared
import Vapor

enum ContactDTO {
    struct RequestLookUp: Content, Sendable {
        let mobileNumbers: [String]
    }
}

extension ContactDTO {
    struct ResponseModel: Content, ContactRepresentableSendable {
        var uid: String
        var name: String
        let mobile: String
        var photoURL: String
        var pushToken: String
        var publicKeyString: String

        init(
            uid: String,
            name: String,
            mobile: String,
            photoURL: String,
            pushToken: String,
            publicKeyString: String
        ) {
            self.uid = uid
            self.name = name
            self.mobile = mobile
            self.photoURL = photoURL
            self.pushToken = pushToken
            self.publicKeyString = publicKeyString
        }

        init(model: ContactModel, publicBaseURL: URL) {
            let photoURL: String = {
                if let version = model.photoVersion {
                    return ["v1", "contacts", "profile_photo", model.firebaseUID]
                        .reduce(publicBaseURL) { $0.appending(path: $1) }
                        .appending(queryItems: [.init(name: "v", value: version.uuidString.lowercased())])
                        .absoluteString
                } else {
                    return ""
                }
            }()
            self.init(
                uid: model.firebaseUID,
                name: model.name,
                mobile: model.mobile,
                photoURL: photoURL,
                pushToken: model.pushToken,
                publicKeyString: model.publicKey
            )
        }
    }
}
