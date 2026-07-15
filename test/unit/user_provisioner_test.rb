# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class RedmineSsoSuite::UserProvisionerTest < ActiveSupport::TestCase
  fixtures :users

  setup do
    @original = Setting.plugin_redmine_sso_suite
    Setting.plugin_redmine_sso_suite = {
      'enabled' => '1',
      'auto_create_users' => '1',
      'claim_email' => 'email',
      'claim_login' => 'preferred_username',
      'claim_firstname' => 'given_name',
      'claim_lastname' => 'family_name'
    }
  end

  teardown do
    Setting.plugin_redmine_sso_suite = @original
  end

  test 'creates user from claims' do
    provisioner = RedmineSsoSuite::UserProvisioner.new
    suffix = SecureRandom.hex(4)
    claims = {
      'email' => "jit.#{suffix}@example.com",
      'preferred_username' => "jit.#{suffix}",
      'given_name' => 'JIT',
      'family_name' => 'User'
    }

    user = provisioner.find_or_create_from_claims(claims)
    assert user.persisted?
    assert_equal claims['email'], user.mail
    assert_equal claims['preferred_username'], user.login
  end

  test 'finds existing user by email' do
    existing = User.find_by(login: 'jsmith') || User.find(2)
    provisioner = RedmineSsoSuite::UserProvisioner.new
    user = provisioner.find_or_create_from_claims(
      'email' => existing.mail,
      'preferred_username' => 'someone-else'
    )
    assert_equal existing.id, user.id
  end

  test 'raises when jit disabled and user missing' do
    Setting.plugin_redmine_sso_suite = Setting.plugin_redmine_sso_suite.merge('auto_create_users' => '0')
    provisioner = RedmineSsoSuite::UserProvisioner.new

    assert_raises RedmineSsoSuite::UserProvisioner::UserNotFoundError do
      provisioner.find_or_create_from_claims(
        'email' => 'missing.user@example.com',
        'preferred_username' => 'missing.user'
      )
    end
  end
end
