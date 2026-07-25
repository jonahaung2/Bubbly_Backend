# Bubbly Backend

// swift run BubblyBackend serve --env development --hostname 192.168.80.114 --port 8080

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
