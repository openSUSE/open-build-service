require File.dirname(__FILE__) + '/../test_helper'
require 'registration_mailer'

class RegistrationMailerTest < Test::Unit::TestCase
  FIXTURES_PATH = File.dirname(__FILE__) + '/../fixtures'
  CHARSET = "utf-8"
  
  fixtures :roles, :users, :groups, :roles_users, :user_registrations, :groups_users, :groups_roles

  include ActionMailer::Quoting

  def setup
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []

    @expected = TMail::Mail.new
    @expected.set_content_type "text", "plain", { "charset" => CHARSET }
  end

  def test_confirm_registration
    @expected.from    = ActiveRbac::Configuration.mailer[:from]
    @expected.to      = 'root@localhost'
    @expected.subject = ActiveRbac::Configuration.mailer[:subjects][:confirm_registration]
    @expected.body    = read_fixture('confirm_registration')
    @expected.date    = Time.now
    
    user = User.new
    user.login = 'test login'
    user.email = 'root@localhost'
    user.update_password 'test_password'
    user.save
    user.create_user_registration

    assert_equal(@expected.encoded, RegistrationMailer.create_confirm_registration(user, 'http://www.example.com').encoded)
  end

  def test_lost_password
    @expected.from    = ActiveRbac::Configuration.mailer[:from]
    @expected.subject = ActiveRbac::Configuration.mailer[:subjects][:lost_password]
    @expected.to      = 'root@localhost'
    @expected.body    = read_fixture('lost_password')
    @expected.date    = Time.now
    
    user = User.new
    user.email = 'root@localhost'
    user.login = 'USER LOGIN'
    password = 'NEW PASSWORD'
    
    assert_equal @expected.encoded, RegistrationMailer.create_lost_password(user, password).encoded
  end

  private
    def read_fixture(action)
      IO.readlines("#{FIXTURES_PATH}/registration_mailer/#{action}")
    end

    def encode(subject)
      quoted_printable(subject, CHARSET)
    end
end