require_relative '../test_helper'

class EventMailerTest < ActionMailer::TestCase
  fixtures :all

  test "commit event" do

    mail = EventMailer.event(users(:adrian), Event::Commit.first)
    assert_equal "BaseDistro/pack1 r1 commited", mail.subject
    assert_equal ["adrian@suse.de"], mail.to
    assert_equal read_fixture('commit_event').join, mail.body.to_s
  end

end
