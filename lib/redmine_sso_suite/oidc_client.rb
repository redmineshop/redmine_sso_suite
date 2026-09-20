# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require 'securerandom'
require 'digest'
require 'base64'
require 'openssl'

module RedmineSsoSuite
  class OidcClient
    class Error < StandardError; end
    class ConfigurationError < Error; end
    class TokenError < Error; end

    DISCOVERY_CACHE_KEY = 'redmine_sso_suite_oidc_discovery'
    JWKS_CACHE_KEY = 'redmine_sso_suite_oidc_jwks'
    # OIDC Core treats a small clock skew as acceptable for exp checks.
    CLOCK_SKEW_SECONDS = 60

    def initialize(settings: RedmineSsoSuite::Settings, discovery: nil, jwks: nil)
      @settings = settings
      @discovery = discovery
      @jwks = jwks
    end

    def authorization_url(state:, code_verifier:)
      discovery = fetch_discovery
      endpoint = rewrite_for_browser(discovery['authorization_endpoint'])
      challenge = code_challenge(code_verifier)

      query = {
        response_type: 'code',
        client_id: @settings.client_id,
        redirect_uri: @settings.callback_url,
        scope: @settings.scopes,
        state: state,
        code_challenge: challenge,
        code_challenge_method: 'S256'
      }

      "#{endpoint}?#{URI.encode_www_form(query)}"
    end

    def exchange_code(code:, code_verifier:)
      discovery = fetch_discovery
      endpoint = discovery['token_endpoint']
      raise ConfigurationError, 'Token endpoint missing from OIDC discovery' if endpoint.blank?

      body = {
        grant_type: 'authorization_code',
        code: code,
        redirect_uri: @settings.callback_url,
        client_id: @settings.client_id,
        code_verifier: code_verifier
      }

      secret = @settings.client_secret
      body[:client_secret] = secret if secret.present?

      response = post_form(endpoint, body)
      parse_json(response.body)
    rescue TokenError
      raise
    rescue StandardError => e
      raise TokenError, "Token exchange failed: #{e.message}"
    end

    def fetch_userinfo(access_token:)
      discovery = fetch_discovery
      endpoint = discovery['userinfo_endpoint']
      raise ConfigurationError, 'Userinfo endpoint missing from OIDC discovery' if endpoint.blank?

      response = get_json(endpoint, access_token)
      parse_json(response.body)
    end

    def claims_from_token_response(token_response)
      if token_response['id_token'].present?
        payload = decode_jwt_payload(token_response['id_token'])
        if payload.is_a?(Hash) && payload['sub'].present?
          validate_id_token_claims!(payload)
          verify_id_token_signature_if_jwks_available!(token_response['id_token'])
          return payload
        end
      end

      access_token = token_response['access_token']
      raise TokenError, 'No access token in OIDC response' if access_token.blank?

      fetch_userinfo(access_token: access_token)
    end

    def self.generate_state
      SecureRandom.urlsafe_base64(32)
    end

    def self.generate_code_verifier
      SecureRandom.urlsafe_base64(48)
    end

    def self.code_challenge(code_verifier)
      digest = Digest::SHA256.digest(code_verifier)
      Base64.urlsafe_encode64(digest).delete('=')
    end

    private

    def code_challenge(code_verifier)
      self.class.code_challenge(code_verifier)
    end

    def fetch_discovery
      return @discovery if @discovery.is_a?(Hash) && @discovery['authorization_endpoint'].present?

      cache = Rails.cache.read(DISCOVERY_CACHE_KEY)
      if cache.is_a?(Hash) && cache['authorization_endpoint'].present?
        @discovery = cache
        return cache
      end

      issuer = @settings.issuer_for_server
      raise ConfigurationError, 'Issuer URL is not configured' if issuer.blank?

      url = issuer.chomp('/') + '/.well-known/openid-configuration'
      response = get(url)
      unless response.is_a?(Net::HTTPSuccess)
        raise ConfigurationError, "OIDC discovery failed (#{response.code}) for #{url}"
      end

      doc = parse_json(response.body)
      @discovery = doc
      Rails.cache.write(DISCOVERY_CACHE_KEY, doc, expires_in: 10.minutes)
      doc
    end

    def rewrite_for_browser(url)
      server_issuer = @settings.issuer_for_server
      browser_issuer = @settings.issuer_for_browser
      return url if browser_issuer.blank? || server_issuer.blank? || browser_issuer == server_issuer

      url.to_s.sub(server_issuer, browser_issuer)
    end

    # Claim checks fail closed: a missing iss/aud/exp is rejected, not skipped.
    # Transport trust (token endpoint over TLS) is not enough — a crafted
    # unsigned JWT with blank registered claims used to pass. When discovery
    # exposes jwks_uri, RS256 signatures are verified as well.
    def validate_id_token_claims!(payload)
      actual_iss = payload['iss'].to_s.chomp('/')
      raise TokenError, 'ID token is missing iss' if actual_iss.blank?

      unless accepted_issuers.include?(actual_iss)
        raise TokenError, "ID token issuer mismatch (expected one of #{accepted_issuers.join(', ')}, got #{actual_iss})"
      end

      audience = Array(payload['aud']).map(&:to_s)
      raise TokenError, 'ID token is missing aud' if audience.empty?
      raise TokenError, 'client_id is not configured' if @settings.client_id.blank?

      unless audience.include?(@settings.client_id)
        raise TokenError, 'ID token audience does not match configured client_id'
      end

      exp = payload['exp']
      raise TokenError, 'ID token is missing exp' if exp.blank?

      if Time.now.to_i > exp.to_i + CLOCK_SKEW_SECONDS
        raise TokenError, 'ID token has expired'
      end
    end

    def verify_id_token_signature_if_jwks_available!(jwt)
      discovery = @discovery.is_a?(Hash) ? @discovery : Rails.cache.read(DISCOVERY_CACHE_KEY)
      return unless discovery.is_a?(Hash) && discovery['jwks_uri'].to_s.present?

      header = decode_jwt_header(jwt)
      alg = header['alg'].to_s
      raise TokenError, 'ID token algorithm none is not allowed' if alg.blank? || alg.casecmp('none').zero?
      raise TokenError, "Unsupported ID token algorithm #{alg}" unless alg == 'RS256'

      jwks = fetch_jwks(discovery['jwks_uri'])
      keys = Array(jwks['keys'])
      kid = header['kid'].to_s
      jwk = if kid.present?
              keys.find { |key| key['kid'].to_s == kid }
            else
              keys.find { |key| key['kty'].to_s == 'RSA' }
            end
      raise TokenError, 'No matching JWKS key for ID token' if jwk.blank?

      verify_rs256!(jwt, jwk)
    end

    def fetch_jwks(jwks_uri)
      return @jwks if @jwks.is_a?(Hash) && @jwks['keys'].is_a?(Array)

      cached = Rails.cache.read(JWKS_CACHE_KEY)
      return cached if cached.is_a?(Hash) && cached['keys'].is_a?(Array)

      response = get(jwks_uri)
      unless response.is_a?(Net::HTTPSuccess)
        raise TokenError, "JWKS fetch failed (#{response.code})"
      end

      doc = parse_json(response.body)
      unless doc.is_a?(Hash) && doc['keys'].is_a?(Array)
        raise TokenError, 'JWKS document is invalid'
      end

      Rails.cache.write(JWKS_CACHE_KEY, doc, expires_in: 10.minutes)
      doc
    end

    def verify_rs256!(jwt, jwk)
      parts = jwt.to_s.split('.')
      raise TokenError, 'ID token is malformed' unless parts.length == 3

      signed_data = "#{parts[0]}.#{parts[1]}"
      signature = base64url_decode(parts[2])
      key = rsa_public_key_from_jwk(jwk)
      unless key.verify(OpenSSL::Digest::SHA256.new, signature, signed_data)
        raise TokenError, 'ID token signature is invalid'
      end
    end

    def rsa_public_key_from_jwk(jwk)
      n = OpenSSL::BN.new(base64url_decode(jwk['n']), 2)
      e = OpenSSL::BN.new(base64url_decode(jwk['e']), 2)
      # OpenSSL 3 keys are immutable — build a SubjectPublicKeyInfo DER.
      sequence = OpenSSL::ASN1::Sequence([
        OpenSSL::ASN1::Integer(n),
        OpenSSL::ASN1::Integer(e)
      ])
      OpenSSL::PKey::RSA.new(sequence.to_der)
    end

    def decode_jwt_header(jwt)
      parts = jwt.to_s.split('.')
      return {} unless parts.length >= 2

      JSON.parse(base64url_decode(parts[0]))
    rescue JSON::ParserError, ArgumentError
      {}
    end

    def base64url_decode(value)
      payload = value.to_s
      padded = payload + ('=' * ((4 - payload.length % 4) % 4))
      Base64.urlsafe_decode64(padded)
    end

    # The IdP issues tokens with `iss` matching whichever hostname the
    # *browser* used to reach it (e.g. Keycloak's request-based hostname
    # resolution), which can legitimately differ from the server-side
    # discovery hostname when `public_issuer_url` rewrites the browser-facing
    # host (as in the local Docker demo stack: `demo-keycloak:8080` for the
    # server vs `localhost:8190` for the browser). Accept either.
    def accepted_issuers
      [@settings.issuer_for_server, @settings.issuer_for_browser]
        .map { |url| url.to_s.chomp('/') }
        .reject(&:blank?)
        .uniq
    end

    def decode_jwt_payload(jwt)
      parts = jwt.to_s.split('.')
      return {} unless parts.length >= 2

      JSON.parse(base64url_decode(parts[1]))
    rescue JSON::ParserError, ArgumentError
      {}
    end

    def get(url)
      uri = URI.parse(url)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 10, read_timeout: 15) do |http|
        request = Net::HTTP::Get.new(uri.request_uri)
        http.request(request)
      end
    end

    def get_json(url, bearer_token)
      uri = URI.parse(url)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 10, read_timeout: 15) do |http|
        request = Net::HTTP::Get.new(uri.request_uri)
        request['Authorization'] = "Bearer #{bearer_token}"
        request['Accept'] = 'application/json'
        http.request(request)
      end
    end

    def post_form(url, body)
      uri = URI.parse(url)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 10, read_timeout: 15) do |http|
        request = Net::HTTP::Post.new(uri.request_uri)
        request['Content-Type'] = 'application/x-www-form-urlencoded'
        request['Accept'] = 'application/json'
        request.body = URI.encode_www_form(body)
        http.request(request)
      end

      unless response.is_a?(Net::HTTPSuccess)
        Rails.logger.error("[redmine_sso_suite] Token endpoint returned #{response.code}")
        raise TokenError, "Token endpoint returned #{response.code}"
      end

      response
    end

    def parse_json(body)
      JSON.parse(body.to_s)
    rescue JSON::ParserError => e
      raise Error, "Invalid JSON from OIDC provider: #{e.message}"
    end
  end
end
