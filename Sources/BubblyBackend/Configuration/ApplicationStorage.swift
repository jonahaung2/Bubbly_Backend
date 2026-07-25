import Vapor

extension Application {
    private struct ConfigurationKey: StorageKey {
        typealias Value = AppConfiguration
    }

    private struct TokenVerifierKey: StorageKey {
        typealias Value = FirebaseTokenVerifier
    }

    private struct PushNotificationSenderKey: StorageKey {
        typealias Value = FirebasePushNotificationSender
    }

    var bubblyConfiguration: AppConfiguration {
        get {
            guard let value = storage[ConfigurationKey.self] else {
                preconditionFailure("AppConfiguration has not been registered")
            }
            return value
        }
        set {
            storage[ConfigurationKey.self] = newValue
        }
    }

    var firebaseTokenVerifier: FirebaseTokenVerifier {
        get {
            guard let value = storage[TokenVerifierKey.self] else {
                preconditionFailure("FirebaseTokenVerifier has not been registered")
            }
            return value
        }
        set {
            storage[TokenVerifierKey.self] = newValue
        }
    }

    var pushNotificationSender: FirebasePushNotificationSender {
        get {
            guard let value = storage[PushNotificationSenderKey.self] else {
                preconditionFailure("FirebasePushNotificationSender has not been registered")
            }
            return value
        }
        set {
            storage[PushNotificationSenderKey.self] = newValue
        }
    }
}
