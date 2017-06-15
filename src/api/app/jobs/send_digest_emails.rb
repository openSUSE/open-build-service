class SendDigestEmails
  def perform
    digest_emails = DigestEmail.where(email_sent: false).order(:created_at).limit(1000).lock(true)

    digest_emails.each do |digest_email|
      digest_email.email_sent = true
      begin
        digest_email.save!
      rescue ActiveRecord::StaleObjectError
        # Do not continue if this object is stale because that means the email has probably already been sent
        return false
      end

      DigestMailer.email(digest_email).deliver_now
    end
  end
end
