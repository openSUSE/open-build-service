require 'test_helper'
require 'event'
require 'event_subscription'

class EventTest < ActiveSupport::TestCase
  fixtures :all

  teardown do
    WebMock.reset!
  end

  test "find nothing" do
    assert_nil EventFactory.new_from_type('NOT_EXISTANT', {})
  end

  test "find event" do
    e = EventFactory.new_from_type('SRCSRV_CREATE_PACKAGE',
                                   {'project' => 'kde4',
                                    'package' => 'kdelibs',
                                    'sender' => 'tom'})
    assert_equal 'CreatePackageEvent', e.class.name
    assert_equal 'kdelibs', e.payload['package']
  end

  def users_for_event(e)
    users = EventFindSubscribers.new(e).subscribers
    User.where(id: users).pluck(:login).sort
  end

  test "find subscribers" do
    all_get_events = EventSubscription.create eventtype: 'CreatePackageEvent', receive: 'maintainer'

    e = EventFactory.new_from_type('SRCSRV_CREATE_PACKAGE',
                                   {'project' => 'kde4',
                                    'package' => 'kdelibs',
                                    'sender' => 'tom'})

    # fred, fredlibs and king are maintainer, adrian is in test_group
    assert_equal ["adrian", "fred", "fredlibs", "king"], users_for_event(e)

    # now fred configures off for the project
    EventSubscription.create eventtype: 'CreatePackageEvent',
                             project: Project.find_by_name('kde4'),
                             user: User.find_by_login("fred"), receive: 'none'

    # fred, fredlibs and king are maintainer, adrian is in test_group - fred disabled it
    assert_equal ["adrian", "fredlibs", "king"], users_for_event(e)

    # now the global default is turned off again
    all_get_events.delete
    assert_equal [], users_for_event(e)

    # now fredlibs configures on for the project
    EventSubscription.create eventtype: 'CreatePackageEvent',
                             project: Project.find_by_name('kde4'),
                             user: User.find_by_login("fredlibs"), receive: 'all'

    assert_equal ["fredlibs"], users_for_event(e)

  end

  test "notifications are sent" do
    e = events(:reviewer_group_added)
    CONFIG['hermes_server'] = 'http://hermes.example.com'
    stub_request(:get, "http://hermes.example.com/index.cgi?rm=notify&_type=OBS_SRCSRV_REQUEST_REVIEWER_GROUP_ADDED&author=king&description=&id=1029&newreviewer_group=test_group&sender=king&sourcepackage=TestPack&sourceproject=home:Iggy&sourcerevision=1&state=review&targetpackage=Testing&targetproject=kde4&type=submit&when=2010-07-12T00:00:00&who=king").
        with(:headers => {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Host'=>'hermes.example.com', 'User-Agent'=>'Ruby'}).
        to_return(:status => 200, :body => "42", :headers => {})
    assert_equal "42", e.send_notification

  end

end
