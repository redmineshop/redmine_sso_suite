# frozen_string_literal: true

module RedmineSsoSuite
  module Settings
    module_function

    def defaults
      {
        'enabled' => '0',
        'issuer_url' => '',
        'public_issuer_url' => '',
        'client_id' => '',
        'client_secret' => '',
        'scopes' => 'openid profile email',
        'login_button_label' => '',
        'enforce_sso_for_non_admin' => '0',
        'auto_create_users' => '1',
        'claim_email' => 'email',
        'claim_login' => 'preferred_username',
        'claim_firstname' => 'given_name',
        'claim_lastname' => 'family_name'
      }
    end

    def current
      Setting.plugin_redmine_sso_suite || {}
    end

    def enabled?
      current['enabled'].to_s == '1'
    end

    def configured?
      enabled? &&
        current['issuer_url'].present? &&
        current['client_id'].present?
    end

    def enforce_sso_for_non_admin?
      current['enforce_sso_for_non_admin'].to_s == '1'
    end

    def auto_create_users?
      current['auto_create_users'].to_s != '0'
    end

    def login_button_label
      label = current['login_button_label'].to_s.strip
      label.presence || I18n.t(:label_sso_login_button)
    end

    def callback_url
      "#{RedmineSsoSuite::Settings.redmine_base_url}/sso/oauth/callback"
    end

    def redmine_base_url
      if ENV['REDMINE_PUBLIC_HOST'].present?
        protocol = ENV.fetch('REDMINE_PUBLIC_PROTOCOL', 'http')
        return "#{protocol}://#{ENV['REDMINE_PUBLIC_HOST']}"
      end

      host = Setting.host_name.to_s
      protocol = Setting.protocol || 'http'
      "#{protocol}://#{host}"
    end

    def issuer_for_server
      current['issuer_url'].to_s.strip
    end

    def issuer_for_browser
      public = current['public_issuer_url'].to_s.strip
      public.presence || issuer_for_server
    end

    def scopes
      current['scopes'].presence || 'openid profile email'
    end

    def client_id
      current['client_id'].to_s.strip
    end

    def client_secret
      current['client_secret'].to_s
    end

    def claim_mapping
      {
        email: current['claim_email'].presence || 'email',
        login: current['claim_login'].presence || 'preferred_username',
        firstname: current['claim_firstname'].presence || 'given_name',
        lastname: current['claim_lastname'].presence || 'family_name'
      }
    end
  end
end
