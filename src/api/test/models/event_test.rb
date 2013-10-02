require 'test_helper'
require 'event'

class EventTest < ActiveSupport::TestCase
  fixtures :all
  set_fixture_class events: Event::Base

  test "find nothing" do
    assert_nil Event::Factory.new_from_type('NOT_EXISTANT', {})
  end

  test "find event" do
    e = Event::Factory.new_from_type('SRCSRV_CREATE_PACKAGE',
                                   {'project' => 'kde4',
                                    'package' => 'kdelibs',
                                    'sender' => 'tom'})
    assert_equal 'Event::CreatePackage', e.class.name
    assert_equal 'kdelibs', e.payload['package']
  end

  test "create request" do
    User.current = users(:Iggy)
    req = bs_requests(:submit_from_home_project)
    req.addreview by_user: 'Iggy'
    assert Event::Base.last.is_a? Event::RequestReviewerAdded
  end

  test "notifications are sent" do
    e = Event::RequestReviewerGroupAdded.first
    assert e.notify_backend
  end

  test "sent all" do
    Event::NotifyBackends.trigger_delayed_sent
  end

  test "get last" do
    firstcount = Event::Base.count
    UpdateNotificationEvents.new.perform
    oldcount = Event::Base.count
    # the first call fetches around 100
    assert oldcount - firstcount > 100
  end

end
