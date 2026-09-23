# Changelog

All notable changes to **redmine_sso_suite** (Community OIDC plugin).

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Security

- ID token `iss` / `aud` / `exp` now fail closed when missing (previously skipped).
- RS256 signatures are verified when OIDC discovery exposes `jwks_uri`.
- Callback flash messages no longer echo IdP `error_description` or token-endpoint bodies.
- `back_url` is re-validated at callback time so a tampered session value cannot open-redirect.
- JIT provisioning sets `admin = false` explicitly.

### Fixed

- The “Administrator? Sign in with password” link reveals the local login form on the first click. The form is hidden with a stylesheet rule, so the toggle uses the computed display.

### Changed

- Install docs use `git clone https://github.com/redmineshop/redmine_sso_suite.git` (no email form).
- README lists Last maintained, screenshots, and what is verified vs untested.
- Private harness Playwright spec completes Keycloak login through callback, session, and JIT user `sso.test`. Callback URL follows `Setting.host_name` (harness seed + compose default `127.0.0.1:8090`) so the redirect URI and Playwright cookie host match.

### Added

- Plugin quality harness on the RedmineShop demo stack: Playwright E2E for the Configure page, SSO login button, Keycloak authorization, callback, and JIT login, plus README screenshots.
- MiniTest coverage for missing ID-token claims, JWKS signature accept/reject, `alg=none`, tampered `back_url`, reflected IdP errors, and unknown-login SSO enforcement.

### Notes

- Do not treat the harness as a Redmine 5.1 / 6.x matrix. JWKS verification runs when discovery includes `jwks_uri`; MiniTest cases without it still stub token exchange.

## [1.0.0] — 2026-07-18

Community GA (OIDC).

### Added

- GA release packaging via RedmineShop email funnel (signed URL + SHA256)
- Compatibility notes for the 1.0.0 release

### Changed

- Version bump 0.9.0-beta → 1.0.0
- README and storefront product copy updated for GA (OIDC Community; SAML remains Pro planned)

### Compatibility

- Tested: Redmine 6.x | MySQL 8 (demo stack) — see QA matrix for additional cells
- Targets: Redmine 5.1.x | PostgreSQL 16

[1.0.0]: https://github.com/redmineshop/redmine_sso_suite/releases/tag/v1.0.0

## [0.9.0-beta] — 2026-07-16

Beta release with validated settings UI.

### Added

- Settings validation on save — issuer URL format, required fields when enabled, scope and claim name checks
- Improved admin settings labels and validation error messages (en locale)

### Changed

- Version bump to beta; README and install docs updated for storefront funnel

### Notes

- QA: Redmine 6.x + MySQL 8 PASS; PostgreSQL 16 and Redmine 5.1.x cells were still untested at this tag
- Official package distributed via RedmineShop email funnel with signed URL (72h) and SHA256 checksum

[0.9.0-beta]: https://github.com/redmineshop/redmine_sso_suite/releases/tag/v0.9.0-beta

## [0.1.0-alpha] — 2026-07-15

OIDC login with a local Keycloak stack.

### Fixed

- SSO callback now uses Redmine `logged_user=` so `session[:tk]` is a valid session token (fixes "Your session has expired" after OIDC redirect)
- **Security**: `back_url` param is now validated with Redmine's own `validate_back_url` before use, closing an open redirect (CWE-601) that let a crafted `/sso/login?back_url=...` link send an authenticated user off-site after login
- **Security**: "Enforce SSO for non-admin users" is now enforced server-side (`AccountController` patch) — previously it only hid the password form via CSS/JS and could be bypassed with a direct POST to `/login`
- **Security**: the `email` claim is only trusted to match an existing account when the IdP marks it `email_verified` (or omits the claim), preventing account takeover via an unverified/spoofed email claim
- **Security**: ID token `iss`/`aud`/`exp` claims are now validated (accepts either the server-side or public/browser-facing issuer, since Keycloak issues tokens against whichever hostname the browser used)

### Added

- OIDC authorization code flow with PKCE (S256)
- OpenID Provider discovery via issuer URL
- OAuth callback route `/sso/oauth/callback`
- JIT user provisioning from configurable OIDC claims
- Login page hook — **Sign in with SSO** button
- Admin plugin settings (issuer, client credentials, scopes, claim mapping)
- **Enforce SSO for non-admin** with administrator break-glass password login toggle
- Rake task `redmine:sso_suite:configure_dev` for local Keycloak
- Unit and functional tests
- Keycloak dev realm import (`demo/keycloak/realm-redmineshop-dev.json`)

### Notes

- SAML, multi-IdP, group sync, and audit log are **Pro** (planned)
- Settings UI is functional but minimal — full admin UX ships in v0.9.0-beta

[0.1.0-alpha]: https://github.com/redmineshop/redmine_sso_suite/releases/tag/v0.1.0-alpha
