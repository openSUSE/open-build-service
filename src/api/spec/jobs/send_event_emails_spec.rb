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
    let!(:comment_author) { create(:confirmed_user) }
    let!(:group) { create(:group) }

    let!(:subscription1) { create(:event_subscription_comment_for_project, receiver_role: 'all', user: user) }
    let!(:subscription2) { create(:event_subscription_comment_for_project, receiver_role: 'all', user: nil, group: group) }
    let!(:subscription3) { create(:event_subscription_comment_for_project, receiver_role: 'all', user: comment_author) }

    let!(:comment) { create(:comment_project, body: "Hey @#{user.login} how are things?", user: comment_author) }

    subject! { SendEventEmails.new.perform }

    it 'sends an email to the subscribers' do
      email = ActionMailer::Base.deliveries.first

      expect(email.to).to match_array([user.email, group.email])
      expect(email.subject).to include('New comment')
    end
  end
end
