# frozen_string_literal: true

module RedmineSsoSuite
  module SettingsValidator
    URL_PATTERN = /\Ahttps?:\/\/[^\s]+\z/i

    module_function

    def validate(settings)
      settings = (settings || {}).stringify_keys
      errors = []

      if settings['enabled'].to_s == '1'
        errors << I18n.t(:error_sso_issuer_url_required) if settings['issuer_url'].to_s.strip.blank?
        errors << I18n.t(:error_sso_client_id_required) if settings['client_id'].to_s.strip.blank?

        issuer = settings['issuer_url'].to_s.strip
        errors << I18n.t(:error_sso_issuer_url_invalid) if issuer.present? && !valid_url?(issuer)

        public_issuer = settings['public_issuer_url'].to_s.strip
        if public_issuer.present? && !valid_url?(public_issuer)
          errors << I18n.t(:error_sso_public_issuer_url_invalid)
        end

        scopes = settings['scopes'].to_s.strip
        errors << I18n.t(:error_sso_scopes_invalid) if scopes.present? && !scopes.match?(/\A[\w\s.-]+\z/)

        %w[claim_email claim_login claim_firstname claim_lastname].each do |key|
          value = settings[key].to_s.strip
          next if value.blank?

          unless value.match?(/\A[\w.-]+\z/)
            errors << I18n.t(:error_sso_claim_invalid, claim: key.sub('claim_', '').humanize)
          end
        end
      end

      errors
    end

    def valid_url?(value)
      value.to_s.strip.match?(URL_PATTERN)
    end
  end
end
