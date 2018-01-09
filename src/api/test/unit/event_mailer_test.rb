require_relative '../test_helper'

class EventMailerTest < ActionMailer::TestCase
  fixtures :all

  teardown do
    Timecop.return
  end

  test 'commit event' do
    mail = EventMailer.event([users(:adrian)], events(:pack1_commit))
    assert_equal 'BaseDistro/pack1 r1 commited', mail.subject
    assert_equal ['adrian@example.com'], mail.to
    assert_equal read_fixture('commit_event').join, mail.body.to_s
  end

  test 'maintainer mails for build failure' do
    # for this test we don't want fixtures to interfere
    EventSubscription.delete_all

    # just one subscription
    EventSubscription.create eventtype: 'Event::BuildFail', receiver_role: :maintainer, user: users(:Iggy)
    Backend::Test.start(wait_for_scheduler: true)

    mail = EventMailer.event([users(:Iggy)], events(:build_failure_for_iggy)).encoded.lines.map(&:chomp).join("\n")

    assert_match(/To: Iggy Pop <Iggy@pop.org>/, mail)
    pattern = Regexp.new('Visit http://localhost/package/live_build_log/home:Iggy/TestPack/10.2/i586')
    assert_match(pattern, mail.gsub(/=\n/, ''))
    pattern = Regexp.new('Package home:Iggy/TestPack failed to build in 10.2/i586')
    assert_match(pattern, mail)
    assert_match(/osc checkout home:Iggy TestPack/, mail)
  end

  test 'reader mails for build failure' do
    # for this test we don't want fixtures to interfere
    EventSubscription.delete_all

    # just one subscription
    EventSubscription.create eventtype: 'Event::BuildFail', receiver_role: :reader, user: users(:fred)
    Backend::Test.start(wait_for_scheduler: true)

    mail = EventMailer.event([users(:fred)], events(:build_failure_for_reader)).encoded.lines.map(&:chomp).join("\n")

    assert_match(/To: Frederic Feuerstone <fred@feuerstein.de>/, mail)
    pattern = Regexp.new('Visit http://localhost/package/live_build_log/home:Iggy/TestPack/10.2/i586')
    assert_match(pattern, mail.gsub(/=\n/, ''))
    pattern = Regexp.new('Package home:Iggy/TestPack failed to build in 10.2/i586')
    assert_match(pattern, mail)
    assert_match(/osc checkout home:Iggy TestPack/, mail)
  end

  test 'group emails' do
    User.current = users(:Iggy)

    # the default is reviewer groups get email, so check that adrian gets an email
    req = bs_requests(:submit_from_home_project)
    Timecop.travel(2013, 8, 20, 12, 0, 0)
    myid = req.number
    SendEventEmailsJob.new.perform # empty queue
    assert_difference 'ActionMailer::Base.deliveries.size', +1 do
      req.addreview(by_group: 'test_group', comment: 'does it look ok?')
      # trigger the send job
      SendEventEmailsJob.new.perform
    end

    email = ActionMailer::Base.deliveries.last

    assert_equal "Request #{myid} requires review (submit Apache/BranchPack)", email.subject
    assert_equal %w(test_group@testsuite.org), email.to
  end

  # now check that disabling it for users in groups works too
  test 'group emails to users disabled' do
    User.current = users(:Iggy)

    req = bs_requests(:submit_from_home_project)

    GroupsUser.where(user: users(:maintenance_assi), group: groups(:maint_coord)).first.update(email: false)
    GroupsUser.where(user: users(:maintenance_coord), group: groups(:maint_coord)).first.update(email: false)
    assert_difference 'ActionMailer::Base.deliveries.size', 0 do
      req.addreview(by_group: 'maint_coord', comment: 'does it still look ok?')
    end
  end
end
