# frozen_string_literal: true

require 'openssl'
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
    Rails.cache.delete(RedmineSsoSuite::OidcClient::JWKS_CACHE_KEY)
  end

  def teardown
    Setting.plugin_redmine_sso_suite = @original
    Rails.cache.delete(RedmineSsoSuite::OidcClient::DISCOVERY_CACHE_KEY)
    Rails.cache.delete(RedmineSsoSuite::OidcClient::JWKS_CACHE_KEY)
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

  def test_claims_from_token_response_accepts_matching_iss_and_aud
    client = RedmineSsoSuite::OidcClient.new
    jwt = build_jwt(
      'sub' => 'abc',
      'email' => 'user@example.com',
      'iss' => 'http://demo-keycloak:8080/realms/redmineshop-dev',
      'aud' => 'redmine-oidc',
      'exp' => 5.minutes.from_now.to_i
    )

    claims = client.claims_from_token_response('id_token' => jwt)
    assert_equal 'user@example.com', claims['email']
  end

  def test_claims_from_token_response_rejects_issuer_mismatch
    client = RedmineSsoSuite::OidcClient.new
    jwt = build_jwt(
      'sub' => 'abc',
      'iss' => 'http://attacker-idp.example/realms/other',
      'aud' => 'redmine-oidc',
      'exp' => 5.minutes.from_now.to_i
    )

    assert_raises RedmineSsoSuite::OidcClient::TokenError do
      client.claims_from_token_response('id_token' => jwt)
    end
  end

  def test_claims_from_token_response_accepts_public_issuer_url
    # Keycloak issues tokens with `iss` matching the browser-facing hostname
    # (public_issuer_url), which differs from the server-side issuer_url used
    # for discovery in the split-hostname Docker demo setup.
    client = RedmineSsoSuite::OidcClient.new
    jwt = build_jwt(
      'sub' => 'abc',
      'email' => 'user@example.com',
      'iss' => 'http://localhost:8190/realms/redmineshop-dev',
      'aud' => 'redmine-oidc',
      'exp' => 5.minutes.from_now.to_i
    )

    claims = client.claims_from_token_response('id_token' => jwt)
    assert_equal 'user@example.com', claims['email']
  end

  def test_claims_from_token_response_rejects_audience_mismatch
    client = RedmineSsoSuite::OidcClient.new
    jwt = build_jwt(
      'sub' => 'abc',
      'iss' => 'http://demo-keycloak:8080/realms/redmineshop-dev',
      'aud' => 'some-other-client',
      'exp' => 5.minutes.from_now.to_i
    )

    assert_raises RedmineSsoSuite::OidcClient::TokenError do
      client.claims_from_token_response('id_token' => jwt)
    end
  end

  def test_claims_from_token_response_rejects_expired_token
    client = RedmineSsoSuite::OidcClient.new
    jwt = build_jwt(
      'sub' => 'abc',
      'iss' => 'http://demo-keycloak:8080/realms/redmineshop-dev',
      'aud' => 'redmine-oidc',
      'exp' => 5.minutes.ago.to_i
    )

    assert_raises RedmineSsoSuite::OidcClient::TokenError do
      client.claims_from_token_response('id_token' => jwt)
    end
  end

  def test_claims_from_token_response_rejects_missing_iss
    client = RedmineSsoSuite::OidcClient.new
    jwt = build_jwt(
      'sub' => 'abc',
      'aud' => 'redmine-oidc',
      'exp' => 5.minutes.from_now.to_i
    )

    error = assert_raises RedmineSsoSuite::OidcClient::TokenError do
      client.claims_from_token_response('id_token' => jwt)
    end
    assert_match(/iss/, error.message)
  end

  def test_claims_from_token_response_rejects_missing_aud
    client = RedmineSsoSuite::OidcClient.new
    jwt = build_jwt(
      'sub' => 'abc',
      'iss' => 'http://demo-keycloak:8080/realms/redmineshop-dev',
      'exp' => 5.minutes.from_now.to_i
    )

    error = assert_raises RedmineSsoSuite::OidcClient::TokenError do
      client.claims_from_token_response('id_token' => jwt)
    end
    assert_match(/aud/, error.message)
  end

  def test_claims_from_token_response_rejects_missing_exp
    client = RedmineSsoSuite::OidcClient.new
    jwt = build_jwt(
      'sub' => 'abc',
      'iss' => 'http://demo-keycloak:8080/realms/redmineshop-dev',
      'aud' => 'redmine-oidc'
    )

    error = assert_raises RedmineSsoSuite::OidcClient::TokenError do
      client.claims_from_token_response('id_token' => jwt)
    end
    assert_match(/exp/, error.message)
  end

  def test_claims_from_token_response_verifies_rs256_when_jwks_present
    rsa = OpenSSL::PKey::RSA.generate(2048)
    jwk = rsa_to_jwk(rsa, 'test-key')
    client = client_with_jwks(jwk)

    jwt = sign_jwt(
      rsa,
      {
        'sub' => 'abc',
        'email' => 'user@example.com',
        'iss' => 'http://demo-keycloak:8080/realms/redmineshop-dev',
        'aud' => 'redmine-oidc',
        'exp' => 5.minutes.from_now.to_i
      },
      'test-key'
    )

    claims = client.claims_from_token_response('id_token' => jwt)
    assert_equal 'user@example.com', claims['email']
  end

  def test_claims_from_token_response_rejects_invalid_signature_when_jwks_present
    rsa = OpenSSL::PKey::RSA.generate(2048)
    other = OpenSSL::PKey::RSA.generate(2048)
    client = client_with_jwks(rsa_to_jwk(rsa, 'test-key'))

    jwt = sign_jwt(
      other,
      {
        'sub' => 'abc',
        'iss' => 'http://demo-keycloak:8080/realms/redmineshop-dev',
        'aud' => 'redmine-oidc',
        'exp' => 5.minutes.from_now.to_i
      },
      'test-key'
    )

    assert_raises RedmineSsoSuite::OidcClient::TokenError do
      client.claims_from_token_response('id_token' => jwt)
    end
  end

  def test_claims_from_token_response_rejects_alg_none_when_jwks_present
    rsa = OpenSSL::PKey::RSA.generate(2048)
    client = client_with_jwks(rsa_to_jwk(rsa, 'test-key'))
    jwt = build_jwt(
      {
        'sub' => 'abc',
        'iss' => 'http://demo-keycloak:8080/realms/redmineshop-dev',
        'aud' => 'redmine-oidc',
        'exp' => 5.minutes.from_now.to_i
      },
      'none'
    )

    error = assert_raises RedmineSsoSuite::OidcClient::TokenError do
      client.claims_from_token_response('id_token' => jwt)
    end
    assert_match(/none/i, error.message)
  end

  private

  def build_jwt(payload, alg = 'RS256')
    header = Base64.urlsafe_encode64({ 'alg' => alg }.to_json, padding: false)
    body = Base64.urlsafe_encode64(payload.to_json, padding: false)
    "#{header}.#{body}.signature"
  end

  def sign_jwt(rsa, payload, kid)
    header = Base64.urlsafe_encode64({ 'alg' => 'RS256', 'kid' => kid }.to_json, padding: false)
    body = Base64.urlsafe_encode64(payload.to_json, padding: false)
    signed = "#{header}.#{body}"
    signature = Base64.urlsafe_encode64(rsa.sign(OpenSSL::Digest::SHA256.new, signed), padding: false)
    "#{signed}.#{signature}"
  end

  def rsa_to_jwk(rsa, kid)
    {
      'kty' => 'RSA',
      'kid' => kid,
      'n' => Base64.urlsafe_encode64(rsa.n.to_s(2), padding: false),
      'e' => Base64.urlsafe_encode64(rsa.e.to_s(2), padding: false)
    }
  end

  def client_with_jwks(jwk)
    RedmineSsoSuite::OidcClient.new(
      discovery: { 'jwks_uri' => 'http://demo-keycloak:8080/jwks' },
      jwks: { 'keys' => [jwk] }
    )
  end
end
