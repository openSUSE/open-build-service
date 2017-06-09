require 'rails_helper'

RSpec.describe SendEventEmails, type: :job do
  include ActiveJob::TestHelper

  describe '#perform' do
    before do
      ActionMailer::Base.deliveries = []
      # Needed for X-OBS-URL
      allow_any_instance_of(Configuration).to receive(:obs_url).and_return('https://build.example.com')
    end

    let!(:user) { create(:confirmed_user) }
    let!(:digest_user) { create(:confirmed_user, digest_email_enabled: true) }
    let!(:comment_author) { create(:confirmed_user) }
    let!(:group) { create(:group) }
    let!(:digest_group) { create(:group, digest_email_enabled: true) }

    let!(:subscription1) { create(:event_subscription_comment_for_project, receiver_role: 'all', user: user) }
    let!(:subscription2) { create(:event_subscription_comment_for_project, receiver_role: 'all', user: nil, group: group) }
    let!(:subscription3) { create(:event_subscription_comment_for_project, receiver_role: 'all', user: comment_author) }
    let!(:subscription4) { create(:event_subscription_comment_for_project, receiver_role: 'all', user: digest_user) }
    let!(:subscription5) { create(:event_subscription_comment_for_project, receiver_role: 'all', user: nil, group: digest_group) }

    let!(:comment1) { create(:comment_project, body: "Hey @#{user.login} how are things?", user: comment_author) }
    let!(:comment2) { create(:comment_project, body: "Hello @#{comment_author.login} I'm good thanks! How are you?", user: user) }

    subject! { SendEventEmails.new.perform }

    it 'sends an email to the subscribers which have digest_email_enabled = false' do
      email = ActionMailer::Base.deliveries.first

      expect(email.to).to match_array([user.email, group.email])
      expect(email.subject).to include('New comment')
    end

    it 'creates digest emails with this event for the subscribers which have digest_email_enabled = true' do
      expect(DigestEmail.all.count).to eq(2)

      digest_email_for_user = DigestEmail.find_by(event_subscription: subscription4)

      expect(digest_email_for_user.body_html).to include('how are things?', 'good thanks!')
      expect(digest_email_for_user.body_text).to include('how are things?', 'good thanks!')

      digest_email_for_group = DigestEmail.find_by(event_subscription: subscription5)

      expect(digest_email_for_group.body_html).to include('how are things?', 'good thanks!')
      expect(digest_email_for_group.body_text).to include('how are things?', 'good thanks!')
    end
  end
end
