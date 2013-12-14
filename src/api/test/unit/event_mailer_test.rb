require_relative '../test_helper'

class EventMailerTest < ActionMailer::TestCase
  fixtures :all

  test "commit event" do

    mail = EventMailer.event(users(:adrian), events(:pack1_commit))
    assert_equal "BaseDistro/pack1 r1 commited", mail.subject
    assert_equal ["adrian@example.com"], mail.to
    assert_equal read_fixture('commit_event').join, mail.body.to_s
  end

  test 'maintainer mails for build failure' do
    # for this test we don't want fixtures to interfere
    EventSubscription.delete_all

    # just one subsciption
    EventSubscription.create eventtype: 'Event::BuildFail', receiver_role: :maintainer, user: users(:Iggy)
    Suse::Backend.wait_for_scheduler_start

    mail = EventMailer.event(users(:Iggy), events(:build_failure_for_iggy))
    assert_equal "Build failure of home:Iggy/TestPack in 10.2/i586", mail.subject
    assert_equal ["Iggy@pop.org"], mail.to
    assert_equal read_fixture('build_fail').join, mail.body.to_s

  end
end
