require_relative '../test_helper'
require 'event'
require 'event_subscription'

class EventTest < ActionDispatch::IntegrationTest
  fixtures :all
  set_fixture_class events: Event::Base

  def setup
    # ensure that the backend got started or we read, process and forget the indexed data.
    # of course only if our timing is bad :/
    super
    Backend::Connection.start_test_backend
  end

  test 'find nothing' do
    assert_nil Event::Factory.new_from_type('NOT_EXISTANT', {})
  end

  test 'find event' do
    e = Event::Factory.new_from_type('SRCSRV_CREATE_PACKAGE',
                                     {'project' => 'kde4',
                                      'package' => 'kdelibs',
                                      'sender'  => 'tom'})
    assert_equal 'Event::CreatePackage', e.class.name
    assert_equal 'kdelibs', e.payload['package']
    assert_equal [], e.receiver_roles
  end

  test 'receive roles for build failure' do
    assert_equal [:maintainer, :bugowner, :reader], events(:build_fails_with_deleted_user_and_request).receiver_roles
  end

  def users_for_event(e)
    users = EventFindSubscribers.new(e).subscribers
    User.where(id: users).pluck(:login).sort
  end

  def groups_for_event(e)
    groups = EventFindSubscribers.new(e).subscribers
    Group.where(id: groups).pluck(:title).sort
  end

  test 'find subscribers' do
    # for this test we don't want fixtures to interfere
    EventSubscription.delete_all

    all_get_events = EventSubscription.create eventtype: 'Event::CreatePackage', receiver_role: :maintainer

    e = Event::Factory.new_from_type('SRCSRV_CREATE_PACKAGE',
                                     {'project' => 'kde4',
                                      'package' => 'kdebase',
                                      'sender'  => 'tom'})

    # fred, fredlibs and king are maintainer, adrian is in test_group
    assert_equal %w(fred fredlibs king), users_for_event(e)
    assert_equal %w(test_group), groups_for_event(e)

    # now fred configures it off
    EventSubscription.create eventtype: 'Event::CreatePackage',
                             user: users(:fred), receiver_role: :all, receive: false

    # fred, fredlibs and king are maintainer, adrian is in test_group - fred disabled it
    assert_equal %w(fredlibs king), users_for_event(e)
    assert_equal %w(test_group), groups_for_event(e)

    # now the global default is turned off again
    all_get_events.delete
    assert_equal [], users_for_event(e)

    # now fredlibs configures on
    EventSubscription.create eventtype: 'Event::CreatePackage',
                             user: users(:fredlibs),
                             receiver_role: :all, receive: true

    assert_equal %w(fredlibs), users_for_event(e)
  end

  test 'create request' do
    User.current = users(:Iggy)
    req = bs_requests(:submit_from_home_project)
    myid = req.number
    SendEventEmails.new.perform # empty queue
    assert_difference 'ActionMailer::Base.deliveries.size', +1 do
      req.addreview by_user: 'tom', comment: 'Can you check that?'
      SendEventEmails.new.perform
    end
    email = ActionMailer::Base.deliveries.last

    assert_equal "Request #{myid} requires review (submit Apache/BranchPack)", email.subject
    assert_equal %w(tschmidt@example.com), email.to
    should = load_fixture('event_mailer/review_wanted').gsub('REQUESTID', myid.to_s).chomp
    if ENV['TRAVIS']
      # travis is not using libxdiff and I am too lazy to package it for ubuntu
      should.gsub!(/\n@@ -0,0 \+1,1 @@\n/, "\n@@ -0,0 +1 @@\n")
    end
    assert_equal should, email.encoded.lines.map(&:chomp).select { |l| l !~ %r{^Date:} }.join("\n")
  end

  test 'notifications are sent' do
    e = Event::VersionChange.first
    # TODO assert e.send_to_bus
  end

  test 'sent all' do
    Event::SendToBus.trigger_delayed_sent
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

  test 'maintainer mails for build failure' do
    # for this test we don't want fixtures to interfere
    EventSubscription.delete_all

    # just one subsciption
    EventSubscription.create eventtype: 'Event::BuildFail', receiver_role: :maintainer, user: users(:Iggy)

    assert_equal %w(Iggy), users_for_event(events(:build_failure_for_iggy))
  end

  test 'reader mails for build failure' do
    # for this test we don't want fixtures to interfere
    EventSubscription.delete_all

    # just one subsciption
    EventSubscription.create eventtype: 'Event::BuildFail', receiver_role: :reader, user: users(:fred)

    assert_equal %w(fred), users_for_event(events(:build_failure_for_reader))
  end

  test 'maintainer mails for source service fail' do
    # for this test we don't want fixtures to interfere
    EventSubscription.delete_all

    # just one subsciption
    EventSubscription.create eventtype: 'Event::ServiceFail', receiver_role: :maintainer, user: users(:Iggy)

    assert_equal %w(Iggy), users_for_event(events(:service_failure_for_iggy))
  end

  test 'package maintainer mail' do
    ActionMailer::Base.deliveries.clear
    User.current = users(:Iggy)
    req = bs_requests(:submit_from_home_project)
    myid = req.number
    SendEventEmails.new.perform # empty queue
    assert_difference 'ActionMailer::Base.deliveries.size', +1 do
      req.addreview by_project: 'home:Iggy', by_package: 'TestPack', comment: 'Can you check that?'
      SendEventEmails.new.perform
    end
    email = ActionMailer::Base.deliveries.last

    assert_equal "Request #{myid} requires review (submit Apache/BranchPack)", email.subject
    # fred is maintainer of the package, hidden_homer of the project, Iggy triggers the event, so doesn't get email
    assert_equal %w(fred@feuerstein.de homer@nospam.net), email.to.sort

    # now verify another review sends other emails
    ActionMailer::Base.deliveries.clear
    assert_difference 'ActionMailer::Base.deliveries.size', +1 do
      req.addreview by_project: 'Apache', by_package: 'apache2', comment: 'Can you check that?'
      SendEventEmails.new.perform
    end
    email = ActionMailer::Base.deliveries.last

    assert_equal "Request #{myid} requires review (submit Apache/BranchPack)", email.subject
    # fred and fredlibs are project maintainers, apache2 has no package maintainer - and they share the email address (DUDE!)
    assert_equal %w(fred@feuerstein.de fred@feuerstein.de), email.to
  end
end
