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
    let(:event_subscription_user) do
      create(:event_subscription_comment_for_request,
             receiver_role: 'target_maintainer',
             user: owner,
             channel: :web)
    end

    context 'for a user not belonging to any group' do
      context 'when having no subscription' do
        subject do
          described_class.new(nil, event).call
        end

        let(:latest_comment) do
          create(:comment_request, commentable: new_bs_request, user: requester, updated_at: 1.hour.ago, body: 'Latest comment')
        end

        before do
          event_subscription_user
          latest_comment
        end

        it 'does not create a new notification' do
          expect(subject).to be_nil
        end

        it 'does not change the number of notifications' do
          expect { subject }.not_to change(Notification, :count)
        end
      end

      context 'when having no event' do
        subject do
          described_class.new(event_subscription_user, nil).call
        end

        let(:latest_comment) do
          create(:comment_request, commentable: new_bs_request, user: requester, updated_at: 1.hour.ago, body: 'Latest comment')
        end

        before do
          event_subscription_user
          latest_comment
        end

        it 'does not create a new notification' do
          expect(subject).to be_nil
        end

        it 'does not change the number of notifications' do
          expect { subject }.not_to change(Notification, :count)
        end
      end

      context 'when having no previous notifications' do
        subject do
          described_class.new(event_subscription_user, event).call
        end

        before do
          event_subscription_user
          create(:comment_request, commentable: new_bs_request, user: requester, updated_at: 1.hour.ago)
        end

        it 'creates a notification' do
          expect(subject).to be_present
        end

        it 'sets no last_seen_at date for the new notification' do
          expect(subject.first.last_seen_at).to be_nil
        end
      end

      context 'when having a previous unread notification' do
        subject do
          described_class.new(event_subscription_user, event).call
        end

        let(:first_comment) do
          create(:comment_request, commentable: new_bs_request, user: requester, updated_at: 2.hours.ago, body: 'Previous comment')
        end
        let(:second_comment) do
          create(:comment_request, commentable: new_bs_request, user: requester, updated_at: 1.hour.ago, body: 'Latest comment')
        end
        let(:previous_notification) do
          create(:notification_for_comment, :web_notification, :comment_for_request, subscription_receiver_role: 'target_maintainer', notifiable: first_comment, subscriber: owner, delivered: false)
        end

        before do
          event_subscription_user
          first_comment
          previous_notification
          second_comment
        end

        it 'creates a notification' do
          expect(subject).to be_present
        end

        it 'does not change the number of notifications' do
          expect { subject }.not_to change(Notification, :count)
        end

        it 'sets the last_seen_at date to the oldest notification' do
          expect(subject.first.unread_date).to eql(previous_notification.created_at)
        end
      end

      context 'when having a previous notification read already' do
        subject do
          described_class.new(event_subscription_user, event).call
        end

        let(:first_comment) do
          create(:comment_request, commentable: new_bs_request, user: requester, updated_at: 2.hours.ago, body: 'Previous comment')
        end
        let(:second_comment) do
          create(:comment_request, commentable: new_bs_request, user: requester, updated_at: 1.hour.ago, body: 'Latest comment')
        end
        let(:previous_notification) do
          create(:notification_for_comment, :web_notification, :comment_for_request, subscription_receiver_role: 'target_maintainer', notifiable: first_comment, subscriber: owner, delivered: true)
        end

        before do
          event_subscription_user
          first_comment
          previous_notification
          second_comment
        end

        it 'creates a notification' do
          expect(subject).to be_present
        end

        it 'does not change the number of notifications' do
          expect { subject }.not_to change(Notification, :count)
        end

        it 'sets no last_seen_at date for the new notification' do
          expect(subject.first.last_seen_at).to be_nil
        end
      end
    end

    context 'a user who belongs to a group' do
      let(:group_maintainers) { create(:group, title: 'maintainers') }
      let(:group_heroes) { create(:group, title: 'heroes') }
      let(:owner) { create(:confirmed_user, login: 'bob', groups: [group_maintainers, group_heroes]) }
      let(:project) { create(:project, name: 'bob_project', maintainer: [owner, group_maintainers]) }

      let(:event_subscription_group) do
        create(:event_subscription_comment_for_request,
               receiver_role: 'target_maintainer',
               user: nil,
               group: group_maintainers,
               channel: :web)
      end

      context 'when having no previous notifications' do
        subject do
          described_class.new(event_subscription_group, event).call
        end

        before do
          event_subscription_group
          event_subscription_user
          create(:comment_request, commentable: new_bs_request, user: requester, updated_at: 1.hour.ago)
        end

        it 'only creates one notification' do
          expect(subject.count).to eq(1)
        end

        it 'creates a new notification for the group members' do
          expect(subject.first.groups.pluck(:title)).to match_array([group_maintainers].pluck(:title))
        end

        it 'sets no last_seen_at date for the new notification' do
          expect(subject.first.last_seen_at).to be_nil
        end
      end

      context 'when having no user subscription' do
        subject do
          described_class.new(event_subscription_group, event).call
        end

        before do
          event_subscription_group
          create(:comment_request, commentable: new_bs_request, user: requester, updated_at: 1.hour.ago)
        end

        it 'creates no notifications' do
          expect(subject.compact).to be_empty
        end
      end

      context 'when having a previous unread notification' do
        subject do
          described_class.new(event_subscription_group, event).call
        end

        let(:first_comment) do
          create(:comment_request, commentable: new_bs_request, user: requester, updated_at: 2.hours.ago, body: 'Previous comment')
        end
        let(:second_comment) do
          create(:comment_request, commentable: new_bs_request, user: requester, updated_at: 1.hour.ago, body: 'Latest comment')
        end
        let(:previous_notification) do
          create(:notification_for_comment, :web_notification, :comment_for_request,
                 subscription_receiver_role: 'target_maintainer', notifiable: first_comment, subscriber: owner, delivered: false,
                 groups: [group_maintainers])
        end

        before do
          event_subscription_group
          event_subscription_user
          first_comment
          previous_notification
          second_comment
        end

        it 'creates a new notification for the group members' do
          expect(subject.first.groups.pluck(:title)).to match_array([group_maintainers].pluck(:title))
        end

        it 'the number of notifications stays the same' do
          expect { subject }.not_to change(Notification, :count)
        end

        it 'sets the last_seen_at date to the oldest notification' do
          expect(subject.first.unread_date).to eql(previous_notification.created_at)
        end
      end

      context 'when having a previous notification read already' do
        subject do
          described_class.new(event_subscription_group, event).call
        end

        let(:first_comment) do
          create(:comment_request, commentable: new_bs_request, user: requester, updated_at: 2.hours.ago, body: 'Previous comment')
        end
        let(:second_comment) do
          create(:comment_request, commentable: new_bs_request, user: requester, updated_at: 1.hour.ago, body: 'Latest comment')
        end
        let(:previous_notification) do
          create(:notification_for_comment, :web_notification, :comment_for_request,
                 subscription_receiver_role: 'target_maintainer', notifiable: first_comment, subscriber: owner, delivered: true,
                 groups: [group_maintainers])
        end

        before do
          event_subscription_group
          event_subscription_user
          first_comment
          previous_notification
          second_comment
        end

        it 'creates a new notification for the group members' do
          expect(subject.first.groups.pluck(:title)).to match_array([group_maintainers].pluck(:title))
        end

        it 'the number of notifications stays the same' do
          expect { subject }.not_to change(Notification, :count)
        end

        it 'sets no last_seen_at date for the new notification' do
          expect(subject.first.last_seen_at).to be_nil
        end
      end
    end

    context 'a user who belongs to a group, but is not a maintainer of the project' do
      let(:group_maintainers) { create(:group, title: 'maintainers') }
      let(:group_heroes) { create(:group, title: 'heroes') }
      let(:owner) { create(:confirmed_user, login: 'bob', groups: [group_maintainers, group_heroes]) }
      let(:project) { create(:project, name: 'bob_project', maintainer: [group_maintainers]) }

      let(:event_subscription_group) do
        create(:event_subscription_comment_for_request,
               receiver_role: 'target_maintainer',
               user: nil,
               group: group_maintainers,
               channel: :web)
      end

      context 'when having no previous notifications' do
        subject do
          described_class.new(event_subscription_group, event).call
        end

        before do
          event_subscription_group
          event_subscription_user
          create(:comment_request, commentable: new_bs_request, user: requester, updated_at: 1.hour.ago)
        end

        it 'only creates one notification' do
          expect(subject.count).to eq(1)
        end

        it 'creates a new notification for the group members' do
          expect(subject.first.groups.pluck(:title)).to match_array([group_maintainers].pluck(:title))
        end

        it 'sets no last_seen_at date for the new notification' do
          expect(subject.first.last_seen_at).to be_nil
        end
      end
    end
  end
end
