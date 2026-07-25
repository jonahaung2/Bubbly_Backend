import Foundation
import Testing
@testable import BubblyBackend

@Suite
struct FirebasePushNotificationSenderTests {
    @Test(arguments: ["UNREGISTERED", "INVALID_ARGUMENT"])
    func recognizesPermanentDeviceTokenFailures(errorCode: String) throws {
        let response = try decodeFailure(status: "NOT_FOUND", errorCode: errorCode)

        #expect(response.isPermanentDeviceTokenFailure)
    }

    @Test(arguments: ["UNAVAILABLE", "INTERNAL", "QUOTA_EXCEEDED"])
    func retainsTokensForRetryableFailures(errorCode: String) throws {
        let response = try decodeFailure(status: errorCode, errorCode: errorCode)

        #expect(!response.isPermanentDeviceTokenFailure)
    }

    @Test
    func recognizesUnregisteredStatusWithoutDetails() throws {
        let data = Data(#"{"error":{"status":"UNREGISTERED"}}"#.utf8)
        let response = try JSONDecoder().decode(
            FirebasePushNotificationSender.FCMErrorResponse.self,
            from: data
        )

        #expect(response.isPermanentDeviceTokenFailure)
    }

    @Test
    func retainsTokenForUnknownFirebaseResponse() throws {
        let data = Data(#"{"error":{"status":"UNKNOWN","details":[{}]}}"#.utf8)
        let response = try JSONDecoder().decode(
            FirebasePushNotificationSender.FCMErrorResponse.self,
            from: data
        )

        #expect(!response.isPermanentDeviceTokenFailure)
    }

    @Test
    func retainsTokenForGenericInvalidArgumentResponse() throws {
        let data = Data(#"{"error":{"status":"INVALID_ARGUMENT"}}"#.utf8)
        let response = try JSONDecoder().decode(
            FirebasePushNotificationSender.FCMErrorResponse.self,
            from: data
        )

        #expect(!response.isPermanentDeviceTokenFailure)
    }

    private func decodeFailure(
        status: String,
        errorCode: String
    ) throws -> FirebasePushNotificationSender.FCMErrorResponse {
        let data = Data(
            """
            {
                "error": {
                    "status": "\(status)",
                    "details": [
                        {
                            "@type": "type.googleapis.com/google.firebase.fcm.v1.FcmError",
                            "errorCode": "\(errorCode)"
                        }
                    ]
                }
            }
            """.utf8
        )
        return try JSONDecoder().decode(
            FirebasePushNotificationSender.FCMErrorResponse.self,
            from: data
        )
    }
}
