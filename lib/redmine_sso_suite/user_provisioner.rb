# frozen_string_literal: true

require 'securerandom'

module RedmineSsoSuite
  class UserProvisioner
    class Error < StandardError; end
    class UserNotFoundError < Error; end

    def initialize(settings: RedmineSsoSuite::Settings, claim_mapping: settings.claim_mapping)
      @settings = settings
      @claim_mapping = claim_mapping
    end

    def find_or_create_from_claims(claims)
      attrs = extract_attributes(claims)
      user = find_existing_user(attrs)
      return user if user

      raise UserNotFoundError, I18n.t(:error_sso_user_not_found) unless @settings.auto_create_users?

      create_user(attrs)
    end

    private

    def extract_attributes(claims)
      data = claims.stringify_keys
      email = fetch_claim(data, @claim_mapping[:email])
      login = fetch_claim(data, @claim_mapping[:login]) || email
      firstname = fetch_claim(data, @claim_mapping[:firstname]) || login.to_s.split('@').first
      lastname = fetch_claim(data, @claim_mapping[:lastname]) || '-'

      {
        mail: email.to_s.strip.downcase,
        email_verified: email_verified?(data),
        login: sanitize_login(login),
        firstname: firstname.to_s.strip.presence || 'SSO',
        lastname: lastname.to_s.strip.presence || 'User'
      }
    end

    # Only trust the `email` claim for account matching/creation when the IdP
    # explicitly marks it verified (or omits the claim entirely, e.g. userinfo
    # endpoints that don't expose it). Without this check, an IdP that lets
    # users self-declare an unverified email could be used to take over an
    # existing Redmine account matching that email (CWE-290-style spoofing).
    def email_verified?(data)
      claim = data['email_verified']
      claim.nil? || claim == true || claim.to_s == 'true'
    end

    def fetch_claim(data, key)
      return data[key] if key.present? && data[key].present?

      data[key.to_s] if key.present?
    end

    def sanitize_login(value)
      login = value.to_s.strip.downcase
      login = login.gsub(/[^a-z0-9@._-]/, '_')
      login = "sso_#{SecureRandom.hex(4)}" if login.blank?
      login.slice(0, 60)
    end

    def find_existing_user(attrs)
      if attrs[:mail].present? && attrs[:email_verified]
        user = User
               .joins(:email_addresses)
               .merge(EmailAddress.where(address: attrs[:mail]))
               .first
        return user if user&.active?
      end

      User.active.find_by(login: attrs[:login])
    end

    def create_user(attrs)
      user = User.new
      user.login = unique_login(attrs[:login])
      user.firstname = attrs[:firstname]
      user.lastname = attrs[:lastname]
      user.mail = attrs[:mail]
      user.language = Setting.default_language
      user.must_change_passwd = false
      user.random_password
      user.save!
      user
    rescue ActiveRecord::RecordInvalid => e
      raise Error, e.record.errors.full_messages.join(', ')
    end

    def unique_login(base_login)
      login = base_login
      suffix = 1
      while User.exists?(login: login)
        login = "#{base_login}#{suffix}"
        suffix += 1
      end
      login
    end

  end
end
