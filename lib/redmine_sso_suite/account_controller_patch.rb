# frozen_string_literal: true

module RedmineSsoSuite
  # Enforces the "Enforce SSO for non-admin users" setting server-side.
  # Without this patch the setting only hides the password form via CSS/JS,
  # which does not stop a direct POST to /login — this patch makes the
  # restriction real while always allowing admin password login (break-glass).
  module AccountControllerPatch
    def password_authentication
      if sso_password_login_blocked?
        invalid_credentials_for_sso_enforcement
        return
      end

      super
    end

    private

    def sso_password_login_blocked?
      return false unless RedmineSsoSuite::Settings.enforce_sso_for_non_admin?
      return false unless RedmineSsoSuite::Settings.configured?

      login = params[:username].to_s
      return false if login.blank?

      user = User.find_by(login: login)
      # Unknown logins and known non-admin users are blocked; only a
      # verified admin account may fall back to local password login.
      !(user && user.admin?)
    end

    def invalid_credentials_for_sso_enforcement
      logger.warn "[redmine_sso_suite] Blocked password login for '#{params[:username]}' " \
                   "from #{request.remote_ip} (SSO enforced for non-admin users)"
      flash.now[:error] = l(:error_sso_password_login_disabled)
    end
  end
end
