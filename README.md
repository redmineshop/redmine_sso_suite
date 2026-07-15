# Redmine SSO Suite (Community)

Free forever **OIDC / OAuth 2.0** single sign-on for self-hosted Redmine.

Part of [RedmineShop](https://redmineshop.com) Phase 2 Community edition. Pro features (SAML, multi-IdP, group sync, audit) ship after the public trust gate — Community features never move behind a paywall.

## Community features (v0.1.0-alpha)

- OpenID Connect authorization code flow with **PKCE**
- Issuer discovery (`.well-known/openid-configuration`)
- **JIT user provisioning** on first SSO login
- **Sign in with SSO** button on the Redmine login page
- **Admin break-glass** — local password login remains available (optional enforce SSO for non-admin users)
- Admin settings under **Administration → Plugins → Redmine SSO Suite**

## Requirements

- Redmine **6.x** (5.1.x compatibility planned in beta)
- Ruby 3.x (bundled with official Redmine image)
- MySQL 8 or PostgreSQL
- One OIDC identity provider (Keycloak, Okta, Azure Entra, Google, …)

## Install (development)

1. Copy or symlink this plugin to `plugins/redmine_sso_suite`
2. Restart Redmine / run `bundle install` if needed
3. **Administration → Plugins** — configure issuer, client ID, and secret
4. Register redirect URI at your IdP:

   ```
   https://your-redmine.example.com/sso/oauth/callback
   ```

### Demo stack (RedmineShop monorepo)

Commercial plugins live under `demo/plugins/`, not `backend/plugins/`.

```bash
cp demo/.env.demo.example demo/.env.demo
docker compose -f docker-compose.demo.yml --env-file demo/.env.demo up -d --build
./demo/scripts/configure-sso-dev.sh
```

- Demo Redmine: http://localhost:8090
- Keycloak: http://localhost:8190 (admin / admin)
- Test user: `sso.test` / `sso-test-password`

See [demo/docs/sso-keycloak.md](../../docs/sso-keycloak.md).

## Settings

| Setting | Description |
| --- | --- |
| Issuer URL (server-side) | OIDC issuer reachable from Redmine (demo Docker: `http://demo-keycloak:8080/realms/...`) |
| Public issuer URL | Browser-facing issuer host (local demo: `http://localhost:8190/realms/...`) |
| Client ID / secret | OAuth client credentials from your IdP |
| Enforce SSO for non-admin | Hides password form; **Administrator? Sign in with password** reveals break-glass form |
| Auto-create users | JIT provisioning (recommended ON for Community) |

## Tests

From the monorepo:

```bash
chmod +x demo/scripts/run-sso-plugin-tests.sh
./demo/scripts/run-sso-plugin-tests.sh
```

## License

GPL-3.0 — see [LICENSE](LICENSE).

Official signed release packages with checksums will be distributed via the RedmineShop email funnel at Community beta/GA. Source is public; clone/build is allowed under GPL.

## Links

- Product: https://redmineshop.com/products/redmine-sso-suite
- Community vs Pro: https://redmineshop.com/docs/sso-community-vs-pro
- Issues: https://github.com/redmineshop/redmine_sso_suite/issues
