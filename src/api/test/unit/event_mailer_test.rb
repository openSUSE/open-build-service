require_relative '../test_helper'

class EventMailerTest < ActionMailer::TestCase
  fixtures :all

  def verify_email(fixture_name, email)
    email.message_id = '<test@localhost>'
    should = load_fixture("event_mailer/#{fixture_name}").chomp
    assert_equal should, email.encoded.lines.map(&:chomp).select { |l| l !~ %r{^Date:} }.join("\n")
  end

  test "commit event" do

    mail = EventMailer.event([users(:adrian)], events(:pack1_commit))
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

    mail = EventMailer.event([users(:Iggy)], events(:build_failure_for_iggy))
    verify_email('build_fail', mail)
  end
end
