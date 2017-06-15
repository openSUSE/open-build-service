class CleanupDigestEmails < ApplicationJob
  def perform
    DigestEmail.where(email_sent: true).lock(true).delete_all
  end
end
