require_relative '../test_helper'

class SendEventEmailsTest < ActionMailer::TestCase

  def test_perform
    SendEventEmails.new.perform

    3.times do |i|
      event = Event::BuildSuccess.create(
        eventtype: "Event::BuildSuccess",
        project:   "NotLongerThere",
        package:   "package_#{i}",
        arch:      "x86_64"
      )

      event.update_attributes!(mails_sent: false)
    end

    assert_difference 'ActionMailer::Base.deliveries.size', +3 do
      SendEventEmails.new.perform
    end

    sent_emails = ActionMailer::Base.deliveries[-3, 3]
    3.times do |i|
      sent_email = sent_emails[i]

      assert_equal ["fred@feuerstein.de"], sent_email.to
      assert_equal ["obs-email@opensuse.org"], sent_email.from
      assert_nil sent_email.reply_to
      assert_equal "Build Service Notification", sent_email.subject
      assert_match(/Build success of NotLongerThere\/package_#{i} \/x86_64/, sent_email.encoded)
    end
  end
end
