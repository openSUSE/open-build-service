require 'rails_helper'

RSpec.describe SendDigestEmails, type: :job do
  include ActiveJob::TestHelper

  describe '#perform' do
    before do
      ActionMailer::Base.deliveries = []
      # Needed for X-OBS-URL
      allow_any_instance_of(Configuration).to receive(:obs_url).and_return('https://build.example.com')
    end

    let!(:digest_user) { create(:confirmed_user, digest_email_enabled: true) }
    let!(:digest_group) { create(:group, digest_email_enabled: true) }

    let!(:subscription1) { create(:event_subscription_comment_for_project, receiver_role: 'all', user: digest_user) }
    let!(:subscription2) { create(:event_subscription_comment_for_project, receiver_role: 'all', user: nil, group: digest_group) }

    let!(:digest_email1) do
      create(
        :digest_email,
        event_subscription: subscription1,
        body_html: Faker::Lorem.sentence,
        body_text: Faker::Lorem.sentence
      )
    end
    let!(:digest_email2) do
      create(
        :digest_email,
        event_subscription: subscription2,
        body_html: Faker::Lorem.sentence,
        body_text: Faker::Lorem.sentence
      )
    end

    subject! { SendDigestEmails.new.perform }

    it 'sends a digest email to the user' do
      digest_email = ActionMailer::Base.deliveries.find { |email| email.to.first == digest_user.email }

      expect(digest_email.text_part.body.raw_source).to eq(digest_email1.body_text)
      expect(digest_email.html_part.body.raw_source).to eq(digest_email1.body_html)
    end

    it 'sends a digest email to the group' do
      digest_email = ActionMailer::Base.deliveries.find { |email| email.to.first == digest_group.email }

      expect(digest_email.text_part.body.raw_source).to eq(digest_email2.body_text)
      expect(digest_email.html_part.body.raw_source).to eq(digest_email2.body_html)
    end
  end
end
