require_relative '../test_helper'
require 'event_subscription'

class EventTest < ActionDispatch::IntegrationTest
  fixtures :all
  set_fixture_class events: Event::Base

  def setup
    # ensure that the backend got started or we read, process and forget the indexed data.
    # of course only if our timing is bad :/
    super
    Backend::Test.start
  end

  test 'cleanup job' do
    firstcount = Event::Base.count
    CleanupEvents.new.perform
    assert Event::Base.count == firstcount, 'all our fixtures are fresh, mail must be sent first'
    f = Event::Base.first
    f.mails_sent = true
    f.save
    CleanupEvents.new.perform
    assert Event::Base.count != firstcount, 'now its gone'
  end
end
