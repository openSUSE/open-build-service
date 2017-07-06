require_relative '../test_helper'

class EventMailerTest < ActionMailer::TestCase
  fixtures :all

  teardown do
    Timecop.return
  end

  test "commit event" do
    mail = EventMailer.event([users(:adrian)], events(:pack1_commit))
    assert_equal "BaseDistro/pack1 r1 commited", mail.subject
    assert_equal ["adrian@example.com"], mail.to
  end

  test 'maintainer mails for build failure' do
    # for this test we don't want fixtures to interfere
    EventSubscription.delete_all

    # just one subsciption
    EventSubscription.create eventtype: 'Event::BuildFail', receiver_role: :maintainer, user: users(:Iggy)
    Backend::Connection.wait_for_scheduler_start

    email = EventMailer.event([users(:Iggy)], events(:build_failure_for_iggy))
    assert_equal %w(Iggy@pop.org), email.to
    assert_equal 'Build failure of home:Iggy/TestPack in 10.2/i586', email.subject
  end

  test 'reader mails for build failure' do
    # for this test we don't want fixtures to interfere
    EventSubscription.delete_all

    # just one subsciption
    EventSubscription.create eventtype: 'Event::BuildFail', receiver_role: :reader, user: users(:fred)
    Backend::Connection.wait_for_scheduler_start

    email = EventMailer.event([users(:fred)], events(:build_failure_for_reader))
    assert_equal 'Build failure of home:Iggy/TestPack in 10.2/i586', email.subject
    assert_equal %w(fred@feuerstein.de), email.to
  end

  test 'group emails' do
    User.current = users(:Iggy)

    # the default is reviewer groups get email, so check that adrian gets an email
    req = bs_requests(:submit_from_home_project)
    Timecop.travel(2013, 8, 20, 12, 0, 0)
    myid = req.number
    SendEventEmails.new.perform # empty queue
    assert_difference 'ActionMailer::Base.deliveries.size', +1 do
      req.addreview(by_group: 'test_group', comment: 'does it look ok?')
      # trigger the send job
      SendEventEmails.new.perform
    end

    email = ActionMailer::Base.deliveries.last

    assert_equal "Request #{myid} requires review (submit Apache/BranchPack)", email.subject
    assert_equal %w(test_group@testsuite.org), email.to
  end

  # now check that disabling it for users in groups works too
  test 'group emails to users disabled' do
    User.current = users(:Iggy)

    req = bs_requests(:submit_from_home_project)

    GroupsUser.where(user: users(:maintenance_assi), group: groups(:maint_coord)).first.update({ email: false })
    GroupsUser.where(user: users(:maintenance_coord), group: groups(:maint_coord)).first.update({ email: false })
    assert_difference 'ActionMailer::Base.deliveries.size', 0 do
      req.addreview(by_group: 'maint_coord', comment: 'does it still look ok?')
    end
  end
end
