RSpec.describe SendEventEmailsJob do
  include ActiveJob::TestHelper

  describe '#perform' do
    let(:group1) { create(:group) }
    let(:group2) { create(:group) }
    let(:user) { create(:confirmed_user, groups: [group1, group2]) }
    let(:project) { create(:project, name: 'comment_project', maintainer: [user, group1, group2]) }
    let(:comment_author) { create(:confirmed_user) }
    let!(:comment) { create(:comment_project, commentable: project, body: "Hey @#{user.login} how are things?", user: comment_author) }

    before do
      ActionMailer::Base.deliveries = []
      # Needed for X-OBS-URL
      allow_any_instance_of(Configuration).to receive(:obs_url).and_return('https://build.example.com')
    end

    context 'with no errors being raised' do
      let!(:subscription1) { create(:event_subscription_comment_for_project, receiver_role: 'maintainer', user: user) }
      let!(:subscription2) { create(:event_subscription_comment_for_project, receiver_role: 'maintainer', user: user, channel: :web) }
      let!(:subscription3) { create(:event_subscription_comment_for_project, receiver_role: 'maintainer', user: user, channel: :rss) }
      let!(:subscription4) { create(:event_subscription_comment_for_project, receiver_role: 'maintainer', user: nil, group: group1) }
      let!(:subscription5) { create(:event_subscription_comment_for_project, receiver_role: 'maintainer', user: nil, group: group1, channel: :web) }
      let!(:subscription6) { create(:event_subscription_comment_for_project, receiver_role: 'maintainer', user: nil, group: group2, channel: :web) }

      before { described_class.new.perform }

      it 'sends an email to the subscribers' do
        email = ActionMailer::Base.deliveries.first

        expect(email.to).to contain_exactly(user.email, group1.email)
        expect(email.subject).to include('New comment')
      end

      it "does not create a rss notification if the user doesn't have a rss secret" do
        expect(Notification.find_by(subscriber: user, rss: true)).to be_nil
      end

      # rubocop:disable RSpec/ExampleLength
      it 'creates a user web notification for a user with a web subscription' do
        notification = Notification.find_by(subscriber: user, web: true)

        expect(notification.event_type).to eq('Event::CommentForProject')
        expect(notification.event_payload['comment_body']).to include('how are things?')
        expect(notification.subscription_receiver_role).to eq('maintainer')
        expect(notification.delivered).to be_falsey
        expect(notification.groups.pluck(:title)).to match_array([group1, group2].pluck(:title))
      end
      # rubocop:enable RSpec/ExampleLength

      it "creates a web notification with the same raw value of the corresponding event's payload" do
        notification = Notification.find_by(subscriber: user, web: true)
        raw_event_payload = Event::Base.first.attributes_before_type_cast['payload']
        raw_notification_payload = notification.attributes_before_type_cast['event_payload']

        expect(raw_event_payload).to eq(raw_notification_payload)
      end

      it 'creates only one notification' do
        expect(Notification.count).to eq(1)
      end
    end

    context 'when the user has a rss secret' do
      let!(:subscription) { create(:event_subscription_comment_for_project, receiver_role: 'maintainer', user: user, channel: :rss) }

      before do
        user.regenerate_rss_secret

        SendEventEmailsJob.new.perform
      end

      it 'creates a rss notification' do
        notification = Notification.find_by(subscriber: user, rss: true)

        expect(notification.event_type).to eq('Event::CommentForProject')
        expect(notification.event_payload['comment_body']).to include('how are things?')
        expect(notification.subscription_receiver_role).to eq('maintainer')
        expect(notification.delivered).to be_falsey
      end
    end

    context 'without any subscriptions to the event' do
      before { SendEventEmailsJob.new.perform }

      it 'updates the event mails_sent = true' do
        event = Event::CommentForProject.first
        expect(event.mails_sent).to be_truthy
      end

      it 'does not send any email' do
        expect(ActionMailer::Base.deliveries.count).to eq(0)
      end
    end

    context 'skips sending emails about hidden projects' do
      let(:project) { create(:forbidden_project, name: 'comment_project', maintainer: user) }
      let!(:subscription) { create(:event_subscription_comment_for_project, receiver_role: 'maintainer', user: user) }

      before { SendEventEmailsJob.new.perform }

      it 'does not queue a mail' do
        expect(ActionMailer::Base.deliveries).to be_empty
      end
    end
  end
end
