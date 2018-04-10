# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'
require 'ichain_notifier'

class IchainNotifierTest < ActiveSupport::TestCase
  CHARSET = 'utf-8'.freeze

  fixtures :users

  # include ActionMailer::Quoting

  def setup
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []

    @user = User.find_by_login 'tom'
    assert @user.valid?

    @expected = TMail::Mail.new
    @expected.set_content_type 'text', 'plain', 'charset' => CHARSET
    @expected.from    = 'admin@opensuse.org'
    @expected.to      = @user.email
    @expected['Precedence'] = 'bulk'
    @expected.mime_version = '1.0'
  end

  # FIXME: this test fails, if it happens not in the same second.
  #        Disabled, because the mechanism is not used anyway atm and needs to generalized for non-ichain usage as well
  #  def test_reject
  #    @expected.subject = 'Buildservice account request rejected'
  #    @expected.body    = read_fixture('reject')
  #    @expected.date    = Time.now
  #
  #    assert_equal @expected.encoded, IchainNotifier.create_reject(@user).encoded
  #  end
  #
  #  def test_approval
  #    @expected.subject = 'Your openSUSE buildservice account is active'
  #    @expected.body    = read_fixture('approval')
  #    @expected.date    = Time.now
  #
  #    assert_equal @expected.encoded, IchainNotifier.create_approval(@user).encoded
  #  end

  private

  def read_fixture(action)
    IO.readlines("#{ActionController::TestCase.fixture_path}/ichain_notifier/#{action}")
  end

  def encode(subject)
    quoted_printable(subject, CHARSET)
  end
end
