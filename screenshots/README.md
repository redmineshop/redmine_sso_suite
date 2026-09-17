# Screenshots — Redmine SSO Suite

Captured by the plugin quality harness (Playwright) against demo Redmine + Keycloak.

Refresh (RedmineShop monorepo, not this public plugin repo):

```bash
./demo/scripts/run-plugin-e2e.sh
```

Output:

- `admin-plugins.png` — Administration → Plugins row with Configure
- `plugin-settings.png` — OIDC settings (issuer, client, JIT, enforce SSO)
- `login-sso-button.png` — “Sign in with SSO” on the Redmine login page
- `keycloak-login.png` — Keycloak authorization form after clicking SSO

This harness does **not** complete the OIDC callback or JIT-provision a user. That path is covered by in-tree MiniTest with a stubbed token exchange.
