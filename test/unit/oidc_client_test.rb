# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class RedmineSsoSuite::OidcClientTest < ActiveSupport::TestCase
  def setup
    @original = Setting.plugin_redmine_sso_suite
    Setting.plugin_redmine_sso_suite = {
      'enabled' => '1',
      'issuer_url' => 'http://demo-keycloak:8080/realms/redmineshop-dev',
      'public_issuer_url' => 'http://localhost:8190/realms/redmineshop-dev',
      'client_id' => 'redmine-oidc',
      'client_secret' => 'secret',
      'scopes' => 'openid profile email'
    }
    Rails.cache.delete(RedmineSsoSuite::OidcClient::DISCOVERY_CACHE_KEY)
  end

  def teardown
    Setting.plugin_redmine_sso_suite = @original
    Rails.cache.delete(RedmineSsoSuite::OidcClient::DISCOVERY_CACHE_KEY)
  end

  def test_code_challenge_s256
    verifier = 'test-verifier-value'
    challenge = RedmineSsoSuite::OidcClient.code_challenge(verifier)
    assert_match(/\A[A-Za-z0-9_-]+\z/, challenge)
    assert_no_match(/=/, challenge)
  end

  def test_authorization_url_includes_pkce_and_public_host
    Rails.cache.write(
      RedmineSsoSuite::OidcClient::DISCOVERY_CACHE_KEY,
      {
        'authorization_endpoint' => 'http://demo-keycloak:8080/realms/redmineshop-dev/protocol/openid-connect/auth',
        'token_endpoint' => 'http://demo-keycloak:8080/realms/redmineshop-dev/protocol/openid-connect/token',
        'userinfo_endpoint' => 'http://demo-keycloak:8080/realms/redmineshop-dev/protocol/openid-connect/userinfo'
      },
      expires_in: 5.minutes
    )

    client = RedmineSsoSuite::OidcClient.new
    url = client.authorization_url(state: 'state123', code_verifier: 'verifier123')
    assert_includes url, 'http://localhost:8190/realms/redmineshop-dev/protocol/openid-connect/auth'
    assert_includes url, 'code_challenge='
    assert_includes url, 'code_challenge_method=S256'
    assert_includes url, 'state=state123'
    assert_includes url, 'client_id=redmine-oidc'
  end

  def test_decode_jwt_payload
    payload = { 'sub' => 'abc', 'email' => 'user@example.com' }
    jwt_body = Base64.urlsafe_encode64(payload.to_json, padding: false)
    jwt = "header.#{jwt_body}.signature"

    client = RedmineSsoSuite::OidcClient.new
    decoded = client.send(:decode_jwt_payload, jwt)
    assert_equal 'user@example.com', decoded['email']
  end
end
