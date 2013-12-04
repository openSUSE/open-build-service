# encoding: UTF-8
require_relative '../test_helper'

class RequestEventsTest < ActionDispatch::IntegrationTest

  fixtures :all

  teardown do
    Timecop.return
  end

  setup do
    ActionMailer::Base.deliveries.clear
  end

  def verify_email(fixture_name, myid, email)
    should = load_fixture("event_mailer/#{fixture_name}").gsub('REQUESTID', myid).chomp
    assert_equal should, email.encoded.lines.map(&:chomp).select { |l| l !~ %r{^Date:} }.join("\n")
  end

  test 'request event' do
    login_Iggy

    Timecop.travel(2013, 8, 20, 12, 0, 0)
    myid = 0
    assert_difference 'ActionMailer::Base.deliveries.size', +1 do
      raw_post '/request?cmd=create', "<request><action type='add_role'><target project='home:tom'/><person name='Iggy' role='reviewer'/></action></request>"
      assert_response :success
      myid = Xmlhash.parse(@response.body)['id']
    end

    email = ActionMailer::Base.deliveries.last

    assert_equal "Request #{myid} created by Iggy: add_role home:tom", email.subject
    assert_equal %w(user1@example.com), email.to
    verify_email('request_event', myid, email)
  end

  test 'set_bugowner event' do
    login_Iggy

    Timecop.travel(2013, 8, 20, 12, 0, 0)
    myid = 0
    assert_difference 'ActionMailer::Base.deliveries.size', +1 do
      raw_post '/request?cmd=create', "<request><action type='set_bugowner'><target project='home:tom'/><person name='Iggy'/></action></request>"
      assert_response :success
      myid = Xmlhash.parse(@response.body)['id']
    end

    email = ActionMailer::Base.deliveries.last

    assert_equal "Request #{myid} created by Iggy: set_bugowner home:tom", email.subject
    assert_equal %w(user1@example.com), email.to
    verify_email('set_bugowner_event', myid, email)
  end

end
