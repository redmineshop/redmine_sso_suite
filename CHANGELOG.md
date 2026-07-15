# Changelog

All notable changes to **redmine_sso_suite** (Community OIDC plugin).

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0-alpha] — 2026-07-15

Sprint 2.2 walking skeleton — OIDC login with Keycloak local dev stack.

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

- SAML, multi-IdP, group sync, and audit log are **Pro** scope (post trust gate)
- Settings UI is functional but minimal — full admin UX ships in v0.9.0-beta

[0.1.0-alpha]: https://github.com/redmineshop/redmine_sso_suite/releases/tag/v0.1.0-alpha
