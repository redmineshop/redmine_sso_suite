# frozen_string_literal: true

module RedmineSsoSuite
  module DemoEnvConfig
    module_function

    def apply_if_needed!
      return unless auto_configure?

      apply!
    end

    def auto_configure?
      ENV['SSO_AUTO_CONFIGURE'].to_s == '1' && ENV['SSO_ISSUER_URL'].to_s.strip.present?
    end

    def apply!
      if ENV['REDMINE_PUBLIC_HOST'].present?
        Setting.host_name = ENV['REDMINE_PUBLIC_HOST'].to_s.strip
        Setting.protocol = ENV.fetch('REDMINE_PUBLIC_PROTOCOL', 'http')
      end

      Setting.plugin_redmine_sso_suite = RedmineSsoSuite::Settings.defaults.merge(
        'enabled' => '1',
        'issuer_url' => ENV.fetch('SSO_ISSUER_URL', '').to_s.strip,
        'public_issuer_url' => ENV.fetch('SSO_PUBLIC_ISSUER_URL', '').to_s.strip,
        'client_id' => ENV.fetch('SSO_CLIENT_ID', '').to_s.strip,
        'client_secret' => ENV.fetch('SSO_CLIENT_SECRET', '').to_s,
        'scopes' => ENV.fetch('SSO_SCOPES', 'openid profile email'),
        'auto_create_users' => ENV.fetch('SSO_AUTO_CREATE_USERS', '1'),
        'enforce_sso_for_non_admin' => '0'
      )
    end
  end
end
