require 'rails_helper'

RSpec.describe NotificationService::WebChannel do
  describe '#call' do
    let(:owner) { create(:confirmed_user, login: 'bob') }
    let(:requester) { create(:confirmed_user, login: 'ann') }
    let(:project) { create(:project, name: 'bob_project', maintainer: [owner]) }
    let(:package) { create(:package, name: 'bob_package', project: project) }
    let(:another_package) { create(:package) }
    let(:new_bs_request) do
      create(:bs_request_with_submit_action,
             state: :new,
             creator: requester,
             target_project: project,
             target_package: package,
             source_package: another_package)
    end
    let(:event) { Event::Base.last }
    let(:event_subscription) do
      create(:event_subscription_comment_for_request,
             receiver_role: 'target_maintainer',
             user: owner,
             channel: :web)
    end

    RSpec.shared_examples 'creating a new notification' do
      it { expect(subject).to be_present }
    end

    RSpec.shared_examples 'ensuring the number of notifications is the same' do
      it { expect { subject }.not_to change(Notification, :count) }
    end

    context 'when having no subscription' do
      let(:latest_comment) do
        create(:comment_request, commentable: new_bs_request, user: requester, updated_at: 1.hour.ago, body: 'Latest comment')
      end

      before do
        event_subscription
        latest_comment
      end

      subject do
        described_class.new(nil, event).call
      end

      it 'does not create a new notification' do
        expect(subject).to be_nil
      end

      it_behaves_like 'ensuring the number of notifications is the same'
    end

    context 'when having no event' do
      let(:latest_comment) do
        create(:comment_request, commentable: new_bs_request, user: requester, updated_at: 1.hour.ago, body: 'Latest comment')
      end

      before do
        event_subscription
        latest_comment
      end

      subject do
        described_class.new(event_subscription, nil).call
      end

      it 'does not create a new notification' do
        expect(subject).to be_nil
      end

      it_behaves_like 'ensuring the number of notifications is the same'
    end

    context 'when having no previous notifications' do
      before do
        event_subscription
        create(:comment_request, commentable: new_bs_request, user: requester, updated_at: 1.hour.ago)
      end

      subject do
        described_class.new(event_subscription, event).call
      end

      it_behaves_like 'creating a new notification'

      it 'sets no last_seen_at date for the new notification' do
        expect(subject.last_seen_at).to be_nil
      end
    end

    context 'when having a previous unread notification' do
      let(:first_comment) do
        create(:comment_request, commentable: new_bs_request, user: requester, updated_at: 2.hours.ago, body: 'Previous comment')
      end
      let(:second_comment) do
        create(:comment_request, commentable: new_bs_request, user: requester, updated_at: 1.hour.ago, body: 'Latest comment')
      end
      let(:previous_notification) do
        create(:web_notification, :comment_for_request, subscription_receiver_role: 'target_maintainer', notifiable: first_comment, subscriber: owner, delivered: false)
      end

      before do
        event_subscription
        first_comment
        previous_notification
        second_comment
      end

      subject do
        described_class.new(event_subscription, event).call
      end

      it_behaves_like 'creating a new notification'
      it_behaves_like 'ensuring the number of notifications is the same'

      it 'sets the last_seen_at date' do
        expect(subject.unread_date).to be_present
      end

      it 'sets the last_seen_at date to the oldest notification' do
        expect(subject.unread_date).to eql(previous_notification.created_at)
      end

      it 'does not set the last_seen_at date to the oldest notifications last_seen_at date' do
        expect(subject.unread_date).not_to eql(previous_notification.last_seen_at)
      end
    end

    context 'when having a previous notification read already' do
      let(:first_comment) do
        create(:comment_request, commentable: new_bs_request, user: requester, updated_at: 2.hours.ago, body: 'Previous comment')
      end
      let(:second_comment) do
        create(:comment_request, commentable: new_bs_request, user: requester, updated_at: 1.hour.ago, body: 'Latest comment')
      end
      let(:previous_notification) do
        create(:web_notification, :comment_for_request, subscription_receiver_role: 'target_maintainer', notifiable: first_comment, subscriber: owner, delivered: true)
      end

      before do
        event_subscription
        first_comment
        previous_notification
        second_comment
      end

      subject do
        described_class.new(event_subscription, event).call
      end

      it_behaves_like 'creating a new notification'
      it_behaves_like 'ensuring the number of notifications is the same'

      it 'sets no last_seen_at date for the new notification' do
        expect(subject.last_seen_at).to be_nil
      end
    end
  end
end
