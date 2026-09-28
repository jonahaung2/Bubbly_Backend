import Fluent
import FluentPostgresDriver
import Foundation
import Shared
import Vapor

enum ContactRepository {
    static func find(userID: String, on database: any Database) async throws -> ContactModel? {
        try await ContactModel.query(on: database)
            .filter(\.$firebaseUID == userID)
            .first()
    }

    static func upsertProfile(
        uid: String,
        profile: ContactDTO.ResponseModel,
        on database: any Database
    ) async throws -> ContactModel {
        let sql = try sqlDatabase(database)
        try await sql.raw(
            """
            INSERT INTO \(unsafeRaw: API.Path.contacts.rawValue)
                (id, firebase_uid, name, mobile, push_token, public_key, created_at, updated_at)
            VALUES
                (\(bind: UUID()), \(bind: uid), \(bind: profile.name), \(bind: profile.mobile),
                 \(bind: profile.pushToken), \(bind: profile.publicKeyString), NOW(), NOW())
            ON CONFLICT (firebase_uid) DO UPDATE SET
                name = EXCLUDED.name,
                mobile = EXCLUDED.mobile,
                push_token = EXCLUDED.push_token,
                public_key = EXCLUDED.public_key,
                updated_at = NOW()
            """
        ).run()
        return try await require(userID: uid, on: database)
    }

    static func clearPushToken(
        uid: String,
        matching pushToken: String,
        on database: any Database
    ) async throws {
        let sql = try sqlDatabase(database)
        try await sql.raw(
            """
            UPDATE contacts SET
                push_token = '',
                updated_at = NOW()
            WHERE firebase_uid = \(bind: uid)
                AND push_token = \(bind: pushToken)
            """
        ).run()
    }

    static func upsertPhoto(
        uid: String,
        data: Data,
        photoContentType: String,
        version: UUID,
        on database: any Database
    ) async throws -> ContactModel {
        let sql = try sqlDatabase(database)
        try await sql.raw(
            """
            INSERT INTO contacts
                (id, firebase_uid, name, mobile, push_token, public_key,
                 photo_data, photo_content_type, photo_version, created_at, updated_at)
            VALUES
                (\(bind: UUID()), \(bind: uid), '', '', '', '',
                 \(bind: data), \(bind: photoContentType), \(bind: version), NOW(), NOW())
            ON CONFLICT (firebase_uid) DO UPDATE SET
                photo_data = EXCLUDED.photo_data,
                photo_content_type = EXCLUDED.photo_content_type,
                photo_version = EXCLUDED.photo_version,
                updated_at = NOW()
            """
        ).run()
        return try await require(userID: uid, on: database)
    }

    static func deletePhoto(userID: String, on database: any Database) async throws {
        let sql = try sqlDatabase(database)
        try await sql.raw(
            """
            UPDATE contacts SET
                photo_data = NULL,
                photo_content_type = NULL,
                photo_version = NULL,
                updated_at = NOW()
            WHERE firebase_uid = \(bind: userID)
            """
        ).run()
    }

    private static func require(userID: String, on database: any Database) async throws -> ContactModel {
        guard let model = try await find(userID: userID, on: database) else {
            throw Abort(.internalServerError)
        }
        return model
    }

    private static func sqlDatabase(_ database: any Database) throws -> any SQLDatabase {
        guard let sql = database as? any SQLDatabase else {
            throw Abort(.internalServerError)
        }
        return sql
    }
}
