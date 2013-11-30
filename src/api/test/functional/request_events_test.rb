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
    should = load_fixture('event_mailer/request_event').gsub('REQUESTID', myid).chomp
    assert_equal should, email.encoded.lines.map(&:chomp).select { |l| l !~ %r{^Date:} }.join("\n")
  end

end
