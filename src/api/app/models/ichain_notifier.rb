class IchainNotifier < ActionMailer::Base
  def reject(recipient)
    subject('Buildservice account request rejected')
    recipients(recipient.email)
    from ::Configuration.admin_email
    sent_on(Time.now)
    content_type 'text/plain'
    body('user' => recipient)
    headers 'Precedence' => 'bulk'
  end

  def approval(recipient)
    subject('Your openSUSE buildservice account is active')
    recipients(recipient.email)
    from ::Configuration.admin_email
    sent_on(Time.now)
    content_type 'text/plain'
    body('user' => recipient)
    headers 'Precedence' => 'bulk'
  end
end
