# frozen_string_literal: true

require 'redmine'

require_relative 'lib/redmine_sso_suite/version'
require_relative 'lib/redmine_sso_suite/settings'
require_relative 'lib/redmine_sso_suite/oidc_client'
require_relative 'lib/redmine_sso_suite/user_provisioner'
require_relative 'lib/redmine_sso_suite/hooks'
require_relative 'lib/redmine_sso_suite/account_controller_patch'
require_relative 'lib/redmine_sso_suite/settings_validator'
require_relative 'lib/redmine_sso_suite/settings_controller_patch'
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

# NOTE: Redmine's own PluginLoader already wraps `init.rb` loading inside a
# `Rails.application.config.to_prepare` block (see lib/redmine/plugin_loader.rb).
# Registering another nested `to_prepare` here would only run starting on the
# *next* reload cycle — never on the very first boot in `test`/`production`
# (cache_classes = true, no reload cycle ever happens). Prepending directly
# at load time is safe: on first boot we're already inside the initial
# prepare cycle, and on each dev reload this file is reloaded and re-run.
unless AccountController.ancestors.include?(RedmineSsoSuite::AccountControllerPatch)
  AccountController.prepend(RedmineSsoSuite::AccountControllerPatch)
end

unless SettingsController.ancestors.include?(RedmineSsoSuite::SettingsControllerPatch)
  SettingsController.prepend(RedmineSsoSuite::SettingsControllerPatch)
end
