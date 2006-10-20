require File.dirname(__FILE__) + '/../test_helper'
require 'ichain_notifier'

class IchainNotifierTest < Test::Unit::TestCase
  FIXTURES_PATH = File.dirname(__FILE__) + '/../fixtures'
  CHARSET = "utf-8"

  include ActionMailer::Quoting

  def setup
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []

    @expected = TMail::Mail.new
    @expected.set_content_type "text", "plain", { "charset" => CHARSET }
  end

  def test_reject
    @expected.subject = 'IchainNotifier#reject'
    @expected.body    = read_fixture('reject')
    @expected.date    = Time.now

    assert_equal @expected.encoded, IchainNotifier.create_reject(@expected.date).encoded
  end

  def test_approve
    @expected.subject = 'IchainNotifier#approve'
    @expected.body    = read_fixture('approve')
    @expected.date    = Time.now

    assert_equal @expected.encoded, IchainNotifier.create_approve(@expected.date).encoded
  end

  private
    def read_fixture(action)
      IO.readlines("#{FIXTURES_PATH}/ichain_notifier/#{action}")
    end

    def encode(subject)
      quoted_printable(subject, CHARSET)
    end
end
