# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class RedmineSsoSuite::SettingsTest < ActiveSupport::TestCase
  def setup
    @original_host = Setting.host_name
    @original_protocol = Setting.protocol
    @original_public_host = ENV['REDMINE_PUBLIC_HOST']
    @original_public_protocol = ENV['REDMINE_PUBLIC_PROTOCOL']
  end

  def teardown
    Setting.host_name = @original_host
    Setting.protocol = @original_protocol
    restore_env('REDMINE_PUBLIC_HOST', @original_public_host)
    restore_env('REDMINE_PUBLIC_PROTOCOL', @original_public_protocol)
  end

  test 'callback_url uses Setting.host_name even when REDMINE_PUBLIC_HOST is set' do
    ENV['REDMINE_PUBLIC_HOST'] = 'localhost:8090'
    ENV['REDMINE_PUBLIC_PROTOCOL'] = 'http'
    Setting.host_name = '127.0.0.1:8090'
    Setting.protocol = 'http'

    assert_equal 'http://127.0.0.1:8090/sso/oauth/callback', RedmineSsoSuite::Settings.callback_url
  end

  test 'callback_url falls back to REDMINE_PUBLIC_HOST when host_name is blank' do
    Setting.host_name = ''
    ENV['REDMINE_PUBLIC_HOST'] = 'demo.example:8090'
    ENV['REDMINE_PUBLIC_PROTOCOL'] = 'https'

    assert_equal 'https://demo.example:8090/sso/oauth/callback', RedmineSsoSuite::Settings.callback_url
  end

  private

  def restore_env(key, value)
    if value.nil?
      ENV.delete(key)
    else
      ENV[key] = value
    end
  end
end
