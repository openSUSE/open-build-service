require 'rails_helper'

RSpec.describe EventMailer do
  # Needed for X-OBS-URL
  before do
    allow_any_instance_of(Configuration).to receive(:obs_url).and_return('https://build.example.com')
  end

  context 'comment mail' do
    let!(:receiver) { create(:confirmed_user) }
    let!(:subscription) { create(:event_subscription_comment_for_project, user: receiver) }
    let!(:comment) { create(:comment_project, body: "Hey @#{receiver.login} how are things?") }
    let(:mail) { EventMailer.event(Event::CommentForProject.last.subscribers, Event::CommentForProject.last).deliver_now }

    it 'gets delivered' do
      expect(ActionMailer::Base.deliveries).to include(mail)
    end
    it 'has subscribers' do
      expect(mail.to).to eq Event::CommentForProject.last.subscribers.map(&:email)
    end
    it 'has a subject' do
      expect(mail.subject).to eq "New comment in project #{comment.commentable.name} by #{comment.user.login}"
    end
  end
end
