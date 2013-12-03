require_relative '../test_helper'
require 'event'
require 'event_subscription'

class EventTest < ActiveSupport::TestCase

  fixtures :all
  set_fixture_class events: Event::Base

  test 'find nothing' do
    assert_nil Event::Factory.new_from_type('NOT_EXISTANT', {})
  end

  test 'find event' do
    e = Event::Factory.new_from_type('SRCSRV_CREATE_PACKAGE',
                                     {'project' => 'kde4',
                                      'package' => 'kdelibs',
                                      'sender' => 'tom'})
    assert_equal 'Event::CreatePackage', e.class.name
    assert_equal 'kdelibs', e.payload['package']
  end

  def users_for_event(e)
    users = EventFindSubscribers.new(e).subscribers
    User.where(id: users).pluck(:login).sort
  end

  test 'find subscribers' do
    # for this test we don't want fixtures to interfere
    EventSubscription.delete_all

    all_get_events = EventSubscription.create eventtype: 'Event::CreatePackage', receive: 'maintainer'

    e = Event::Factory.new_from_type('SRCSRV_CREATE_PACKAGE',
                                     {'project' => 'kde4',
                                      'package' => 'kdebase',
                                      'sender' => 'tom'})

    # fred, fredlibs and king are maintainer, adrian is in test_group
    assert_equal %w(adrian fred fredlibs king), users_for_event(e)

    # now fred configures off for the project
    EventSubscription.create eventtype: 'Event::CreatePackage',
                             project: projects(:kde4),
                             user: users(:fred), receive: 'none'

    # fred, fredlibs and king are maintainer, adrian is in test_group - fred disabled it
    assert_equal %w(adrian fredlibs king), users_for_event(e)

    # now the global default is turned off again
    all_get_events.delete
    assert_equal [], users_for_event(e)

    # now fredlibs configures on for the project
    EventSubscription.create eventtype: 'Event::CreatePackage',
                             project: projects(:kde4),
                             user: users(:fredlibs), receive: 'all'

    assert_equal %w(fredlibs), users_for_event(e)

  end

  test 'create request' do
    User.current = users(:Iggy)
    req = bs_requests(:submit_from_home_project)
    myid = req.id
    assert_difference 'ActionMailer::Base.deliveries.size', +1 do
      req.addreview by_user: 'Iggy', comment: 'Can you check that?'
    end
    email = ActionMailer::Base.deliveries.last

    assert_equal "Request #{myid}: Review wanted", email.subject
    assert_equal %w(Iggy@pop.org), email.to
    should = load_fixture('event_mailer/review_wanted').gsub('REQUESTID', myid.to_s).chomp
    email.message_id = '<test@localhost>'
    assert_equal should, email.encoded.lines.map(&:chomp).select { |l| l !~ %r{^Date:} }.join("\n")
  end

  test 'notifications are sent' do
    e = Event::VersionChange.first
    assert e.notify_backend
  end

  test 'sent all' do
    Event::NotifyBackends.trigger_delayed_sent
  end

  test 'get last' do
    firstcount = Event::Base.count
    UpdateNotificationEvents.new.perform
    oldcount = Event::Base.count
    # the first call fetches around 100
    assert oldcount - firstcount > 100
  end

  test 'cleanup job' do
    firstcount = Event::Base.count
    CleanupEvents.new.perform
    assert Event::Base.count == firstcount, 'all our fixtures are fresh'
    f = Event::Base.first
    f.queued = true
    f.save
    CleanupEvents.new.perform
    assert Event::Base.count == firstcount, 'queuing is not enough'
    f.project_logged = true
    f.save
    CleanupEvents.new.perform
    assert Event::Base.count != firstcount, 'now its gone'
  end
end
