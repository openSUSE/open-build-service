require Rails.root.join('db/data/20200326221616_regenerate_notifications.rb')

RSpec.describe RegenerateNotifications, type: :migration do
  describe 'up' do
    subject { RegenerateNotifications.new.up }

    let(:owner) { create(:confirmed_user, login: 'bob') }
    let(:requester) { create(:confirmed_user, login: 'ann') }
    let(:project) { create(:project, name: 'bob_project', maintainer: [owner]) }
    let(:package) { create(:package, name: 'bob_package', project: project) }
    let(:another_package) { create(:package) }

    let!(:new_bs_request) do
      create(:bs_request_with_submit_action,
             state: :new,
             creator: requester,
             target_project: project,
             target_package: package,
             source_package: another_package)
    end
    let!(:declined_bs_request) do
      bs_request_to_decline =
        create(:bs_request_with_submit_action,
               state: :new,
               creator: requester,
               target_project: project,
               target_package: package,
               source_package: another_package,
               created_at: 3.days.ago,
               updated_at: 2.days.ago)
      bs_request_to_decline.update(state: 'declined')
      bs_request_to_decline
    end
    let!(:old_declined_bs_request) do
      bs_request_to_decline =
        create(:bs_request_with_submit_action,
               state: :new,
               creator: requester,
               target_project: project,
               target_package: package,
               source_package: another_package,
               created_at: 101.days.ago)
      bs_request_to_decline.update(state: 'declined')
      bs_request_to_decline
    end
    let!(:revoked_bs_request) { create(:bs_request, type: 'maintenance_release', state: :revoked) } # This shouldn't regenerate notification

    before do
      owner.regenerate_rss_secret
    end

    context 'for RequestCreate Notifications' do
      let!(:rss_subscription) { create(:event_subscription_request_created, receiver_role: 'target_maintainer', user: owner, channel: :rss) }
      let!(:web_subscription) { create(:event_subscription_request_created, receiver_role: 'target_maintainer', user: owner, channel: :web) }

      before do
        subject
      end

      it 'creates a RequestCreate Notification' do
        expect(Notification.where(event_type: 'Event::RequestCreate').count).to eq(1)
        notification = Notification.find_by(event_type: 'Event::RequestCreate')

        # Checks the Notification's attributes have correct values:
        expect(notification.event_payload['number']).to eq(new_bs_request.number)
        expect(notification.notifiable).to eq(new_bs_request)
        # Timestamps compared with .to_s because they have different precision and the values differ slightly.
        expect(notification.created_at.to_s).to eq(new_bs_request.updated_when.to_s)
        expect(notification.title).to eq("Request #{new_bs_request.number} created by #{requester} (submit #{project}/#{package})")
        expect(notification).to be_web
        expect(notification).to be_rss
      end
    end

    context 'for RequestStatechange Notifications' do
      let!(:subscription) { create(:event_subscription_request_statechange, receiver_role: 'target_maintainer', user: owner, channel: :rss) }

      before do
        subject
      end

      it 'creates a RequestStatechange Notification' do
        expect(Notification.where(event_type: 'Event::RequestStatechange').count).to eq(1)
        notification = Notification.find_by(event_type: 'Event::RequestStatechange')

        # Checks the Notification's attributes have correct values:
        expect(notification.event_payload['number']).to eq(declined_bs_request.number)
        expect(notification.notifiable).to eq(declined_bs_request)
        expect(notification.title).to eq("Request #{declined_bs_request.number} changed from new to declined (submit #{project}/#{package})")
        expect(notification.created_at.to_s).to eq(declined_bs_request.updated_when.to_s)
        expect(notification.bs_request_oldstate).to eq('new')
      end
    end

    context 'for ReviewWanted Notifications' do
      let!(:review_request) do # The type, submit, shouldn't matter
        create(:bs_request_with_submit_action,
               state: :review,
               creator: requester,
               target_project: project,
               target_package: package,
               source_package: another_package,
               updated_at: 15.days.ago)
      end
      let!(:accepted_review) { create(:review, bs_request: review_request, by_user: owner, state: :accepted) }

      context 'with review by user' do
        let!(:subscription) { create(:event_subscription_review_wanted, receiver_role: 'reviewer', user: owner, channel: :rss) }
        let!(:review) { create(:review, bs_request: review_request, by_user: owner, state: :new, updated_at: 10.days.ago) }

        before do
          subject
        end

        it 'creates a ReviewWanted Notification of type Request' do
          expect(Notification.where(event_type: 'Event::ReviewWanted').count).to eq(1)
          notification = Notification.find_by(event_type: 'Event::ReviewWanted')

          # Checks the Notification's attributes have correct values:
          expect(notification.event_payload['number']).to eq(review_request.number)
          expect(notification.notifiable).to eq(review_request)
          expect(notification.created_at.to_s).to eq(review.updated_at.to_s)
          expect(notification.title).to eq("Request #{review_request.number} requires review (submit #{project}/#{package})")
        end
      end

      context 'with review by project and by package' do
        let(:reviewer1) { create(:confirmed_user, login: 'reviewer_1') }
        let(:package2) { create(:package, name: 'package_2') }
        let!(:relationship) { create(:relationship_package_user, user: reviewer1, package: package2) }
        let!(:web_subscription) { create(:event_subscription_review_wanted, receiver_role: 'reviewer', user: reviewer1, channel: :web) }
        let!(:rss_subscription) { create(:event_subscription_review_wanted, receiver_role: 'reviewer', user: reviewer1, channel: :rss) }
        let!(:review_by_package) { create(:review, bs_request: review_request, by_project: package2.project, by_package: package2, state: :new) }

        before do
          subject
        end

        it 'creates a ReviewWanted Notification of type Request' do
          expect(Notification.where(event_type: 'Event::ReviewWanted').count).to eq(1)
          notification = Notification.find_by(event_type: 'Event::ReviewWanted')

          # Checks the Notification's attributes have correct values:
          expect(notification.event_payload['number']).to eq(review_request.number)
          expect(notification.notifiable).to eq(review_request)
          expect(notification.title).to eq("Request #{review_request.number} requires review (submit #{project}/#{package})")
          expect(notification).to be_web
          expect(notification).not_to be_rss
        end
      end
    end

    context 'for CommentForRequest Notifications' do
      let!(:subscription) { create(:event_subscription_comment_for_request, receiver_role: 'target_maintainer', user: owner, channel: :rss) }
      let!(:old_comment_for_request) { create(:comment_request, commentable: new_bs_request, user: requester, created_at: 4.weeks.ago) }
      let!(:comment_for_request) { create(:comment_request, commentable: new_bs_request, user: requester, updated_at: 1.week.ago) }
      let!(:comment_for_project) { create(:comment_project, commentable: project, user: requester) } # Shouldn't regenerate notification
      let!(:comment_for_package) { create(:comment_package, commentable: package, user: requester) } # Shouldn't regenerate notification

      before do
        subject
      end

      it 'creates a CommentForRequest Notification' do
        expect(Notification.where(notifiable_type: 'Comment').count).to eq(1)
        notification = Notification.find_by(notifiable_type: 'Comment')

        # Checks the Notification's attributes have correct values:
        expect(notification.event_type).to eq('Event::CommentForRequest')
        expect(notification.event_payload['number']).to eq(new_bs_request.number)
        expect(notification.notifiable).to eq(comment_for_request)
        expect(notification.created_at.to_s).to eq(comment_for_request.updated_at.to_s)
        expect(notification.title).to eq("Request #{new_bs_request.number} commented by #{requester} (submit #{project}/#{package})")
      end
    end

    context 'when running the job after running the data migration' do
      let!(:subscription) { create(:event_subscription_comment_for_request, receiver_role: 'target_maintainer', user: owner, channel: :rss) }
      let!(:comment_for_request) { create(:comment_request, commentable: new_bs_request, user: requester, body: 'bla') }
      let(:events) { Event::Base.where(eventtype: 'Event::CommentForRequest') }
      let(:comment_notifications) { Notification.where(notifiable_type: 'Comment') }

      before do
        subject
      end

      it 'creates only one CommentForRequest Notification' do
        expect(comment_notifications.count).to eq(1)
        expect(events.count).to eq(1)
        expect(events.last.mails_sent).to be_falsey

        # we run this to ensure the job doesn't duplicate notifications
        SendEventEmailsJob.new.perform
        expect(events.last.mails_sent).to be_truthy
        expect(comment_notifications.count).to eq(1)
        expect(events.last.payload['id']).to eq(comment_notifications.last.notifiable_id)
      end
    end
  end
end
