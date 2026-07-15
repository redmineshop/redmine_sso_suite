# Redmine SSO Suite — Free OpenID Connect (OIDC) Single Sign-On Plugin for Redmine

**Redmine SSO Suite** adds OpenID Connect / OAuth 2.0 single sign-on to self-hosted Redmine, so your team logs in with Keycloak, Okta, Azure Entra ID, Google Workspace, or any standards-compliant identity provider instead of a separate Redmine password.

Community edition is **free forever** — built and maintained by [RedmineShop](https://redmineshop.com). Pro adds SAML 2.0, multi-IdP, group/role sync, and audit logging after the public trust gate.

[![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-blue.svg)](LICENSE)

## Why teams choose this Redmine OIDC plugin

Stock Redmine authentication is username/password only. IT teams that must enforce corporate identity standards (SSO mandate, password rotation policy, offboarding via the IdP) are left bolting on plugins that vary widely in security quality and maintenance. Redmine SSO Suite is a focused, actively maintained OIDC implementation with authorization-code + PKCE, JIT provisioning, and — unlike many community SSO plugins — a real server-side enforcement mode and a documented security review (see [Security](#security) below).

## Features (Community — free forever)

- **OpenID Connect Authorization Code flow with PKCE (S256)** — the flow recommended by the OAuth 2.0 Security Best Current Practice for a confidential/public web client like Redmine
- **Automatic issuer discovery** via `.well-known/openid-configuration` — point it at your IdP realm URL, no manual endpoint entry
- **Just-in-time (JIT) user provisioning** — Redmine accounts are created automatically on first successful SSO login, mapped from configurable claims (email, login, first/last name)
- **"Sign in with SSO" button** injected on the standard Redmine login page via a view hook — no core file changes
- **Enforce SSO for non-admin users** — hide *and* server-side block password login for everyone except administrators
- **Admin break-glass** — administrators can always fall back to local password login, so a misconfigured IdP never locks you out of your own Redmine
- Configurable claim mapping (`email`, `preferred_username`, `given_name`, `family_name`) to match non-standard IdP claim names
- Split server/browser issuer URLs — supports Docker setups where Redmine reaches the IdP over an internal network while browsers use a public hostname

## Security

Single sign-on is the kind of feature where a subtle bug becomes a full account-takeover, so this plugin ships with explicit protections most Redmine OIDC plugins skip:

| Protection | What it prevents |
| --- | --- |
| `back_url` validated with Redmine's own `validate_back_url` | Open redirect (CWE-601) via a crafted `/sso/login?back_url=...` link |
| "Enforce SSO for non-admin" blocks `AccountController#password_authentication` server-side | Bypassing the SSO requirement with a direct `POST /login` once the UI toggle is hidden |
| `email` claim only trusted when the IdP marks it `email_verified` | Account takeover by claiming another user's email on IdPs that allow self-declared/unverified emails |
| ID token `iss` / `aud` / `exp` validated on every login | Tokens issued for a different issuer, a different OAuth client, or already expired |
| OAuth `state` compared with `ActiveSupport::SecurityUtils.secure_compare` | CSRF on the OIDC callback and timing side-channels on the comparison |

Full history in [CHANGELOG.md](CHANGELOG.md). Found a security issue? Please report it privately — see [Support](#support--links) — instead of opening a public GitHub issue.

## Requirements

- Redmine **6.x** (5.1.x compatibility planned for beta)
- Ruby 3.x (bundled with the official Redmine Docker image)
- MySQL 8 or PostgreSQL
- One OpenID Connect identity provider — Keycloak, Okta, Auth0, Azure Entra ID, Google Workspace, or any OIDC-compliant IdP

## Installation

1. Copy or symlink this plugin into `plugins/redmine_sso_suite` in your Redmine install
2. Restart Redmine (run `bundle install` first if your Gemfile.lock changed — this plugin has no extra gem dependencies)
3. Go to **Administration → Plugins → Redmine SSO Suite** and configure the issuer URL, client ID, and client secret
4. Register the redirect URI with your identity provider:

   ```
   https://your-redmine.example.com/sso/oauth/callback
   ```

### Local development (RedmineShop monorepo demo stack)

Commercial/community plugins under active development live in `demo/plugins/`, not `backend/plugins/` (which is reserved for the redmineshop.com storefront CMS API):

```bash
cp demo/.env.demo.example demo/.env.demo
docker compose -f docker-compose.demo.yml --env-file demo/.env.demo up -d --build
./demo/scripts/configure-sso-dev.sh
```

- Demo Redmine: http://localhost:8090
- Keycloak (dev IdP): http://localhost:8190 (admin / admin)
- Test user: `sso.test` / `sso-test-password`

See [demo/docs/sso-keycloak.md](../../docs/sso-keycloak.md) for the full local Keycloak walkthrough.

## Settings reference

| Setting | Description |
| --- | --- |
| Issuer URL (server-side) | OIDC issuer reachable from the Redmine server (Docker demo: `http://demo-keycloak:8080/realms/...`) |
| Public issuer URL | Browser-facing issuer host, only needed when it differs from the server-side URL (Docker demo: `http://localhost:8190/realms/...`) |
| Client ID / Client secret | OAuth 2.0 client credentials issued by your IdP |
| Scopes | Space-separated OIDC scopes (default `openid profile email`) |
| Login button label | Custom text for the "Sign in with SSO" button |
| Auto-create users (JIT) | Automatically create a Redmine account on first successful SSO login |
| Enforce SSO for non-admin | Hides the password form and blocks password login for non-admin accounts server-side; administrators always keep local password login (break-glass) |
| Email / login / first name / last name claims | Map your IdP's claim names if they differ from the OIDC defaults |

## Tests

From the monorepo root, against the demo Docker stack:

```bash
chmod +x demo/scripts/run-sso-plugin-tests.sh
./demo/scripts/run-sso-plugin-tests.sh
```

Unit and functional tests cover the OIDC client (PKCE, discovery, token/claim validation), JIT user provisioning (including the `email_verified` guard), the OAuth callback (state validation, session establishment), and the server-side SSO enforcement patch.

## Roadmap

Community features never move behind a paywall. Planned **Pro** tier (post trust-gate):

- SAML 2.0 support and multiple simultaneous identity providers
- Group / role mapping from IdP claims
- Login audit log with CSV export
- Advanced admin diagnostics and per-IdP setup guides

## License

GPL-3.0 — see [LICENSE](LICENSE). Source is public; clone and self-build are always allowed under GPL. Signed official release packages with checksums ship via the RedmineShop email funnel at Community beta/GA.

## Support & Links

- Product page: https://redmineshop.com/products/redmine-sso-suite
- Community vs Pro comparison: https://redmineshop.com/docs/sso-community-vs-pro
- Issues (non-security bugs and feature requests): https://github.com/redmineshop/redmine_sso_suite/issues
- Security reports: support@redmineshop.com
