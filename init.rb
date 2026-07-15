# frozen_string_literal: true

require 'redmine'

require_relative 'lib/redmine_sso_suite/version'
require_relative 'lib/redmine_sso_suite/settings'
require_relative 'lib/redmine_sso_suite/oidc_client'
require_relative 'lib/redmine_sso_suite/user_provisioner'
require_relative 'lib/redmine_sso_suite/hooks'
require_relative 'lib/redmine_sso_suite/demo_env_config'

Redmine::Plugin.register :redmine_sso_suite do
  name 'Redmine SSO Suite (Community)'
  author 'RedmineShop'
  description 'Free forever OIDC single sign-on for self-hosted Redmine — authorization code + PKCE, JIT provisioning, admin break-glass.'
  version RedmineSsoSuite::VERSION
  url 'https://github.com/redmineshop/redmine_sso_suite'
  author_url 'https://redmineshop.com'

  settings default: RedmineSsoSuite::Settings.defaults,
           partial: 'settings/sso_settings'
end

Rails.application.config.after_initialize do
  RedmineSsoSuite::DemoEnvConfig.apply_if_needed!
rescue StandardError => e
  Rails.logger.warn("[redmine_sso_suite] Demo env configure skipped: #{e.message}")
end
