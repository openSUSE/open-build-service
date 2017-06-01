class DigestMailer < EventMailer
  def email(digest_email)
    set_headers

    mail(
      to:            digest_email.event_subscription.subscriber.display_name,
      subject:       "Notification daily report – #{Date.today}",
      from:          'noreply@opensuse.org',
      date:          Time.now
    ) do |format|
      format.text { digest_email.body_text }
      format.html { digest_email.body_html }
    end
  end
end
