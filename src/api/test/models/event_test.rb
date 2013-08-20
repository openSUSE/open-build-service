require 'test_helper'
require 'event'
require 'event_subscription'

class EventTest < ActiveSupport::TestCase
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
    all_get_events = EventSubscriptionMaintainer.create eventtype: 'CreatePackageEvent'

    e = EventFactory.new_from_type('SRCSRV_CREATE_PACKAGE',
                                   {'project' => 'kde4',
                                    'package' => 'kdelibs',
                                    'sender' => 'tom'})

    # fred, fredlibs and king are maintainer, adrian is in test_group
    assert_equal ["adrian", "fred", "fredlibs", "king"], users_for_event(e)

    # now fred configures off for the project
    EventSubscriptionNone.create eventtype: 'CreatePackageEvent',
                                 project: Project.find_by_name('kde4'),
                                 user: User.find_by_login("fred")

    # fred, fredlibs and king are maintainer, adrian is in test_group - fred disabled it
    assert_equal ["adrian", "fredlibs", "king"], users_for_event(e)

    # now the global default is turned off again
    all_get_events.delete
    assert_equal [], users_for_event(e)

    # now fredlibs configures on for the project
    EventSubscriptionAll.create eventtype: 'CreatePackageEvent',
                                project: Project.find_by_name('kde4'),
                                user: User.find_by_login("fredlibs")

    assert_equal ["fredlibs"], users_for_event(e)

  end

end
