# frozen_string_literal: true

class SsoController < ApplicationController
  skip_before_action :check_if_login_required
  skip_before_action :verify_authenticity_token, only: [:callback]

  before_action :require_sso_enabled, except: [:disabled]
  before_action :redirect_if_logged_in, only: [:login]

  def login
    state = RedmineSsoSuite::OidcClient.generate_state
    code_verifier = RedmineSsoSuite::OidcClient.generate_code_verifier

    session[:sso_oidc_state] = state
    session[:sso_oidc_code_verifier] = code_verifier
    # Reuse Redmine core's back_url validation (same-host, relative path only) to
    # prevent an open redirect via a crafted `back_url` param (CWE-601).
    session[:sso_back_url] = validate_back_url(params[:back_url].to_s) || my_page_path

    client = RedmineSsoSuite::OidcClient.new
    redirect_to client.authorization_url(state: state, code_verifier: code_verifier), allow_other_host: true
  rescue RedmineSsoSuite::OidcClient::ConfigurationError => e
    logger.error("[redmine_sso_suite] #{e.message}")
    flash[:error] = I18n.t(:error_sso_not_configured)
    redirect_to signin_path
  end

  def callback
    if params[:error].present?
      logger.warn("[redmine_sso_suite] IdP error=#{params[:error].to_s.truncate(64)}")
      flash[:error] = I18n.t(:error_sso_provider_failed)
      return redirect_to signin_path
    end

    unless secure_compare(session[:sso_oidc_state].to_s, params[:state].to_s)
      logger.warn("[redmine_sso_suite] State mismatch: session_present=#{session[:sso_oidc_state].present?} " \
                   "session_id=#{session.id.to_s.first(8)}")
      flash[:error] = I18n.t(:error_sso_state_mismatch)
      return redirect_to signin_path
    end

    code_verifier = session.delete(:sso_oidc_code_verifier)
    session.delete(:sso_oidc_state)
    # Re-validate at use time so a tampered session value cannot open-redirect.
    back_url = validate_back_url(session.delete(:sso_back_url).to_s) || my_page_path

    unless params[:code].present? && code_verifier.present?
      flash[:error] = I18n.t(:error_sso_missing_code)
      return redirect_to signin_path
    end

    client = RedmineSsoSuite::OidcClient.new
    token_response = client.exchange_code(code: params[:code], code_verifier: code_verifier)
    claims = client.claims_from_token_response(token_response)

    user = RedmineSsoSuite::UserProvisioner.new.find_or_create_from_claims(claims)
    unless user.active?
      flash[:error] = I18n.t(:error_sso_inactive_user)
      return redirect_to signin_path
    end

    self.logged_user = user
    call_hook(:controller_account_success_authentication_after, { user: user })
    redirect_to back_url
  rescue RedmineSsoSuite::OidcClient::Error, RedmineSsoSuite::UserProvisioner::Error => e
    logger.error("[redmine_sso_suite] #{e.class}: #{e.message}")
    flash[:error] = I18n.t(:error_sso_login_failed)
    redirect_to signin_path
  end

  private

  def require_sso_enabled
    return if RedmineSsoSuite::Settings.configured?

    flash[:error] = I18n.t(:error_sso_not_configured)
    redirect_to signin_path
  end

  def redirect_if_logged_in
    redirect_to my_page_path if User.current.logged?
  end

  def secure_compare(left, right)
    return false if left.blank? || right.blank? || left.bytesize != right.bytesize

    ActiveSupport::SecurityUtils.secure_compare(left, right)
  end
end
