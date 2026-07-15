# Changelog

All notable changes to **redmine_sso_suite** (Community OIDC plugin).

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0-alpha] — 2026-07-15

Sprint 2.2 walking skeleton — OIDC login with Keycloak local dev stack.

### Fixed

- SSO callback now uses Redmine `logged_user=` so `session[:tk]` is a valid session token (fixes "Your session has expired" after OIDC redirect)

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
