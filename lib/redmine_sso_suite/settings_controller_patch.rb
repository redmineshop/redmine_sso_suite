# frozen_string_literal: true

module RedmineSsoSuite
  # Validates plugin settings before Redmine persists them.
  module SettingsControllerPatch
    def plugin_settings
      if params[:id] == 'redmine_sso_suite'
        errors = RedmineSsoSuite::SettingsValidator.validate(params[:settings])
        if errors.any?
          flash[:error] = errors.join(' ')
          redirect_to plugin_settings_path(params[:id])
          return
        end
      end

      super
    end
  end
end
