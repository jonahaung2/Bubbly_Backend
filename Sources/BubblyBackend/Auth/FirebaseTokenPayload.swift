import JWTKit

struct FirebaseTokenPayload: JWTPayload, Sendable {
    let issuer: IssuerClaim
    let subject: SubjectClaim
    let audience: AudienceClaim
    let expiration: ExpirationClaim
    let issuedAt: IssuedAtClaim
    let authTime: Int

    enum CodingKeys: String, CodingKey {
        case issuer = "iss"
        case subject = "sub"
        case audience = "aud"
        case expiration = "exp"
        case issuedAt = "iat"
        case authTime = "auth_time"
    }

    func verify(using _: some JWTAlgorithm) throws {
        try expiration.verifyNotExpired()
        guard !subject.value.isEmpty, subject.value.count <= 128 else {
            throw JWTError.claimVerificationFailure(
                failedClaim: subject,
                reason: "invalid subject"
            )
        }
    }
}
