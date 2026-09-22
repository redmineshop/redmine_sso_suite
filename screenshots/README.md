# Screenshots — Redmine SSO Suite

Captured by Playwright against demo Redmine + Keycloak (viewport 1440×900, deviceScaleFactor 1, full page).

Refresh is **private-monorepo only** (`redmineshop/redmineshop` harness). A public clone of this plugin cannot run that job.

Output:

- `login-sso.png` — Redmine login page with “Sign in with SSO” (`login-sso-button.png` is the same image)
- `admin-oidc.png` — OIDC settings; client secret masked (`plugin-settings.png` is the same image)
- `break-glass.png` — login page with “Administrator? Sign in with password” and an empty password form
- `keycloak-login.png` — Keycloak authorization form after clicking SSO (captured before credentials are typed)
- `admin-plugins.png` — Administration → Plugins

The harness also completes the OIDC callback and JIT-provisions `sso.test`. That step is not a README image.
