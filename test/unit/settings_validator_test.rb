require File.expand_path('../test_helper', __dir__)

class RedmineSsoSuite::SettingsValidatorTest < ActiveSupport::TestCase
  test 'allows disabled settings without issuer' do
    errors = RedmineSsoSuite::SettingsValidator.validate('enabled' => '0')
    assert_empty errors
  end

  test 'requires issuer and client id when enabled' do
    errors = RedmineSsoSuite::SettingsValidator.validate(
      'enabled' => '1',
      'issuer_url' => '',
      'client_id' => ''
    )

    assert_includes errors.join(' '), 'Issuer URL'
    assert_includes errors.join(' '), 'Client ID'
  end

  test 'rejects invalid issuer url' do
    errors = RedmineSsoSuite::SettingsValidator.validate(
      'enabled' => '1',
      'issuer_url' => 'not-a-url',
      'client_id' => 'redmine-oidc'
    )

    assert errors.any?
  end

  test 'accepts valid enabled settings' do
    errors = RedmineSsoSuite::SettingsValidator.validate(
      'enabled' => '1',
      'issuer_url' => 'http://localhost:8190/realms/demo',
      'client_id' => 'redmine-oidc',
      'scopes' => 'openid profile email'
    )

    assert_empty errors
  end
end
