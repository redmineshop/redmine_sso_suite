# frozen_string_literal: true

RedmineApp::Application.routes.draw do
  get 'sso/login', to: 'sso#login', as: 'sso_login'
  get 'sso/oauth/callback', to: 'sso#callback', as: 'sso_callback'
end
