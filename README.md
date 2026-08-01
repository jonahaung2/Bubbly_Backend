# Bubbly Backend

// PUBLIC_BASE_URL=http://192.168.80.127:8080 swift run BubblyBackend serve --env development --hostname 192.168.80.127 --port 8080

The service stores contact profiles and profile images in PostgreSQL. Firebase Authentication remains the identity provider; every private endpoint verifies a Firebase ID token.

## Local development

Copy `.env.example` to `.env`, replace the database password, then run:

```sh
docker compose --env-file .env up --build
```
The health endpoint is available at `GET /health`.

## Production

Set `FIREBASE_PROJECT_ID`, `PUBLIC_BASE_URL`, and either `DATABASE_URL` or the individual `DATABASE_*` variables. Provide the Firebase service account through `FIREBASE_SERVICE_ACCOUNT_JSON_BASE64`, or mount it as a secret and set `FIREBASE_SERVICE_ACCOUNT_FILE` to its absolute path. `PUBLIC_BASE_URL` must use HTTPS when the Vapor environment is production. Run database migrations as a release step with:

```sh
./BubblyBackend migrate --yes --env production
```

Keep `AUTO_MIGRATE` disabled in multi-instance deployments. Terminate TLS at the load balancer or ingress, enforce request rate limits there, use a TLS-enabled PostgreSQL connection, rotate database credentials through the deployment secret manager, and back up PostgreSQL with point-in-time recovery.

The iOS Debug build defaults to `http://127.0.0.1:8080`. Set `BUBBLY_API_BASE_URL` in the app scheme environment for a device or set the `BubblyAPIBaseURL` Info.plist value through build configuration for deployed builds.

## Admin panel

The repository includes a native macOS SwiftUI admin application for contacts, groups, memberships, profile photos, and media assets. Configure a randomly generated token containing at least 32 bytes in the backend environment:

```sh
openssl rand -base64 48
```

Set the generated value as `ADMIN_API_TOKEN` in the backend secret manager. Admin routes are not registered when the variable is absent. Never commit the generated token. Production admin traffic must use HTTPS and should additionally be restricted by a private network, VPN, or trusted ingress policy.

Run the backend, then launch the panel from SwiftPM:

```sh
swift run BubblyAdmin
```

Open Settings, enter the backend base URL and the same admin token, then connect. The URL is saved in preferences and the token is stored in the macOS Keychain.

## API

- `GET /v1/contacts/:userID`
- `POST /v1/contacts/lookup`
- `GET /v1/profile`
- `PUT /v1/profile`
- `PATCH /v1/profile/push-token`
- `PUT /v1/profile/photo`
- `DELETE /v1/profile/photo`
- `GET /v1/profile-photos/:userID`
- `GET /v1/groups?limit=100&after=:cursor`
- `GET /v1/groups/:groupID`
- `PUT /v1/groups/:groupID`
- `DELETE /v1/groups/:groupID`
- `POST /v1/push-notifications`

Admin endpoints use `Authorization: Bearer <ADMIN_API_TOKEN>`:

- `GET /v1/admin/contacts`
- `PUT|DELETE /v1/admin/contacts/:id`
- `PUT|DELETE /v1/admin/contacts/:id/photo`
- `GET /v1/admin/groups`
- `PUT|DELETE /v1/admin/groups/:id`
- `GET /v1/admin/media`
- `PUT|DELETE /v1/admin/media/:id`

## Backend architecture

The service uses explicit boundaries that allow features to grow independently:

- Controllers own HTTP routing, authentication context, request decoding, and status codes.
- DTOs define versioned external contracts and validation.
- Repositories own persistence, transactions, pagination, and query optimization.
- Models represent the PostgreSQL schema and never cross the HTTP boundary directly.
- Configuration and authentication are initialized once in the application composition root.

Collection APIs use bounded keyset pagination instead of offsets. Admin media listings select metadata and `OCTET_LENGTH(data)` without loading binary payloads. Group listings fetch memberships in one batched query, and membership replacement uses a batched create inside a transaction.

For deployments where media volume outgrows PostgreSQL, move binary payloads to S3-compatible object storage while retaining asset metadata, ownership, versions, and lookup indexes in PostgreSQL. Keep the existing HTTP contracts stable so clients and the admin panel do not require a coordinated migration.
