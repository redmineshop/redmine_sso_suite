# frozen_string_literal: true

namespace :redmine do
  namespace :sso_suite do
    desc 'Configure OIDC settings from SSO_* / REDMINE_PUBLIC_* environment variables'
    task configure_dev: :environment do
      unless ENV['SSO_ISSUER_URL'].to_s.strip.present?
        abort 'SSO_ISSUER_URL is not set'
      end

      RedmineSsoSuite::DemoEnvConfig.apply!
      puts 'redmine_sso_suite settings applied from environment.'
      puts "Callback URL: #{RedmineSsoSuite::Settings.callback_url}"
    end
  end
end
