# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

# Verifies "Enforce SSO for non-admin users" is a real server-side control,
# not just a UI hint — see lib/redmine_sso_suite/account_controller_patch.rb.
class RedmineSsoSuite::AccountControllerPatchTest < ActionController::TestCase
  tests AccountController
  fixtures :users, :email_addresses

  setup do
    @original = Setting.plugin_redmine_sso_suite
    Setting.plugin_redmine_sso_suite = RedmineSsoSuite::Settings.defaults.merge(
      'enabled' => '1',
      'issuer_url' => 'http://demo-keycloak:8080/realms/redmineshop-dev',
      'client_id' => 'redmine-oidc',
      'client_secret' => 'secret',
      'enforce_sso_for_non_admin' => '1'
    )
  end

  teardown do
    Setting.plugin_redmine_sso_suite = @original
  end

  test 'blocks password login for non-admin user when enforced' do
    post :login, params: { username: 'jsmith', password: 'jsmith' }

    assert_response :success
    assert_nil session[:user_id]
    assert_select 'div.flash.error'
  end

  test 'still allows password login for admin user when enforced (break-glass)' do
    post :login, params: { username: 'admin', password: 'admin' }

    assert_equal 1, session[:user_id]
  end

  test 'allows non-admin password login when enforcement is disabled' do
    Setting.plugin_redmine_sso_suite = Setting.plugin_redmine_sso_suite.merge('enforce_sso_for_non_admin' => '0')

    post :login, params: { username: 'jsmith', password: 'jsmith' }

    assert_equal 2, session[:user_id]
  end

  test 'blocks password login for an unknown login when enforced' do
    post :login, params: { username: 'does-not-exist', password: 'whatever' }

    assert_response :success
    assert_nil session[:user_id]
    assert_select 'div.flash.error'
  end
end
