# frozen_string_literal: true

module RedmineSsoSuite
  module Hooks
    class ViewListener < Redmine::Hook::ViewListener
      render_on :view_account_login_bottom, partial: 'sso/login_button'
    end
  end
end
