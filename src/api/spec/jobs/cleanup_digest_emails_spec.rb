require 'rails_helper'

RSpec.describe CleanupDigestEmails, type: :job do
  include ActiveJob::TestHelper

  describe '#perform' do
    let!(:digest_user) { create(:confirmed_user, digest_email_enabled: true) }
    let!(:digest_group) { create(:group, digest_email_enabled: true) }

    let!(:subscription1) { create(:event_subscription_comment_for_project, receiver_role: 'all', user: digest_user) }
    let!(:subscription2) { create(:event_subscription_comment_for_project, receiver_role: 'all', user: nil, group: digest_group) }

    let!(:digest_email1) { create(:digest_email, event_subscription: subscription1) }
    let!(:digest_email2) { create(:digest_email, event_subscription: subscription2, email_sent: true) }

    subject! { CleanupDigestEmails.new.perform }

    it 'deletes the digest_email with email_sent == true' do
      digest_email = DigestEmail.exists?(id: digest_email2.id)
      expect(digest_email).to be_falsey
    end

    it 'keeps the digest_email with email_sent == false' do
      digest_email = DigestEmail.exists?(id: digest_email1.id)
      expect(digest_email).to be_truthy
    end
  end
end
