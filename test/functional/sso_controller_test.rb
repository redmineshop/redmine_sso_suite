# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class SsoControllerTest < ActionController::TestCase
  tests SsoController

  setup do
    @original = Setting.plugin_redmine_sso_suite
    Setting.plugin_redmine_sso_suite = RedmineSsoSuite::Settings.defaults.merge(
      'enabled' => '1',
      'issuer_url' => 'http://demo-keycloak:8080/realms/redmineshop-dev',
      'public_issuer_url' => 'http://localhost:8190/realms/redmineshop-dev',
      'client_id' => 'redmine-oidc',
      'client_secret' => 'secret'
    )
    Rails.cache.write(
      RedmineSsoSuite::OidcClient::DISCOVERY_CACHE_KEY,
      {
        'authorization_endpoint' => 'http://demo-keycloak:8080/realms/redmineshop-dev/protocol/openid-connect/auth',
        'token_endpoint' => 'http://demo-keycloak:8080/realms/redmineshop-dev/protocol/openid-connect/token',
        'userinfo_endpoint' => 'http://demo-keycloak:8080/realms/redmineshop-dev/protocol/openid-connect/userinfo'
      },
      expires_in: 5.minutes
    )
  end

  teardown do
    Setting.plugin_redmine_sso_suite = @original
    Rails.cache.delete(RedmineSsoSuite::OidcClient::DISCOVERY_CACHE_KEY)
  end

  test 'login redirects to oidc provider' do
    get :login

    assert_response :redirect
    assert_match %r{localhost:8190/realms/redmineshop-dev/protocol/openid-connect/auth}, @response.redirect_url
    assert session[:sso_oidc_state].present?
    assert session[:sso_oidc_code_verifier].present?
  end

  test 'login requires configuration' do
    Setting.plugin_redmine_sso_suite = RedmineSsoSuite::Settings.defaults
    get :login
    assert_redirected_to '/login'
    assert flash[:error].present?
  end

  test 'callback rejects state mismatch' do
    session[:sso_oidc_state] = 'expected'
    session[:sso_oidc_code_verifier] = 'verifier'
    get :callback, params: { state: 'wrong', code: 'abc' }
    assert_redirected_to '/login'
    assert flash[:error].present?
  end

  test 'login does not store an external back_url (open redirect protection)' do
    get :login, params: { back_url: 'https://evil.example/phish' }

    refute_equal 'https://evil.example/phish', session[:sso_back_url]
    assert_equal '/my/page', session[:sso_back_url]
  end

  test 'login keeps a valid same-host relative back_url' do
    get :login, params: { back_url: '/my/page' }

    assert_equal '/my/page', session[:sso_back_url]
  end

  test 'callback establishes valid redmine session token' do
    user = User.find(1)
    state = 'callback-state-token'
    session[:sso_oidc_state] = state
    session[:sso_oidc_code_verifier] = 'callback-verifier'
    session[:sso_back_url] = '/my/page'

    exchange = lambda do |code:, code_verifier:|
      { 'access_token' => 'test-token' }
    end
    claims = lambda do |token_response|
      { 'email' => user.mail, 'preferred_username' => user.login }
    end

    client = RedmineSsoSuite::OidcClient.new
    client.singleton_class.send(:define_method, :exchange_code, exchange)
    client.singleton_class.send(:define_method, :claims_from_token_response, claims)

    RedmineSsoSuite::OidcClient.define_singleton_method(:new) { client }
    begin
      get :callback, params: { state: state, code: 'auth-code' }
    ensure
      RedmineSsoSuite::OidcClient.singleton_class.remove_method(:new)
    end

    assert_redirected_to '/my/page'
    assert_equal user.id, session[:user_id]
    assert User.verify_session_token(session[:user_id], session[:tk])
  end
end
