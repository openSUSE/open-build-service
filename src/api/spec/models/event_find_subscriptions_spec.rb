require 'rails_helper'

RSpec.shared_context 'it returns subscriptions for an event' do
  context 'with a maintainer user/group who has a maintainer subscription' do
    let!(:project) { create(:project, maintainer: [maintainer]) }
    let!(:comment) { create(:comment_project, commentable: project) }

    context 'which is enabled' do
      let!(:subscription) { create(:event_subscription_comment_for_project_without_subscriber, receiver_role: 'maintainer', subscriber: maintainer) }

      it 'returns the subscription for that user/group' do
        subscriber_result = subject.find { |subscription| subscription.subscriber == maintainer }

        expect(subscriber_result).to eq(subscription)
      end
    end

    context 'which is disabled' do
      let!(:subscription) do
        create(:event_subscription_comment_for_project_without_subscriber, receiver_role: 'maintainer', subscriber: maintainer, channel: 'disabled')
      end

      it 'does not include that user/group' do
        expect(subject.map(&:subscriber)).not_to include(maintainer)
      end
    end
  end

  context 'with a maintainer user/group who has no subscriptions' do
    let!(:project) { create(:project, maintainer: [maintainer]) }
    let!(:comment) { create(:comment_project, commentable: project) }

    context 'and a default maintainer subscription is enabled' do
      let!(:default_subscription) do
        create(:event_subscription_comment_for_project, receiver_role: 'maintainer', user: nil, group: nil)
      end

      it 'returns a new subscription for that user/group based on the default subscription' do
        result = subject.find { |subscription| subscription.subscriber == maintainer }

        expect(result.id).to be_nil
        expect(result.eventtype).to eq(default_subscription.eventtype)
        expect(result.receiver_role).to eq(default_subscription.receiver_role)
        expect(result.channel).to eq(default_subscription.channel)
      end
    end

    context 'and a default maintainer subscription is disabled' do
      let!(:default_subscription) do
        create(:event_subscription_comment_for_project, receiver_role: 'maintainer', user: nil, group: nil, channel: 'disabled')
      end

      it 'does not include that user/group' do
        expect(subject.map(&:subscriber)).not_to include(maintainer)
      end
    end
  end
end

RSpec.describe EventFindSubscriptions do
  describe '#subscribers' do
    subject do
      event = Event::CommentForProject.first
      EventFindSubscriptions.new(event).subscriptions
    end

    context 'with a comment for a project' do
      context 'with no maintainers' do
        let!(:project) { create(:project) }
        let!(:comment) { create(:comment_project, commentable: project) }

        it 'does not include the author of the comment' do
          expect(subject.map(&:subscriber)).not_to include(comment.user)
        end
      end

      it_behaves_like 'it returns subscriptions for an event' do
        let!(:maintainer) { create(:confirmed_user) }
      end

      it_behaves_like 'it returns subscriptions for an event' do
        let!(:maintainer) { create(:group) }
      end

      context 'with a user who is a maintainer and a commenter' do
        context 'and the user has a maintainer and commenter subscriptions, which are both enabled' do
          let!(:maintainer) { create(:confirmed_user) }
          let!(:project) { create(:project, maintainer: [maintainer]) }
          let!(:comment) { create(:comment_project, commentable: project, body: "Hey @#{maintainer.login} hows it going?") }

          let!(:subscription_maintainer) do
            create(:event_subscription_comment_for_project_without_subscriber, receiver_role: 'maintainer', subscriber: maintainer)
          end
          let!(:subscription_commenter) do
            create(:event_subscription_comment_for_project_without_subscriber, receiver_role: 'commenter', subscriber: maintainer)
          end

          it 'returns a subscription for that user/group' do
            result_subscription = subject.find { |subscription| subscription.subscriber == maintainer }

            # It doesn't matter if the maintainer or commenter subscription is returned
            expect(result_subscription.id).not_to be_nil
            expect(result_subscription.eventtype).to eq(subscription_maintainer.eventtype)
            expect(result_subscription.channel).to eq(subscription_maintainer.channel)
          end

          it 'only returns one subscription' do
            result_subscriptions = subject.select { |subscription| subscription.subscriber == maintainer }

            expect(result_subscriptions.length).to eq(1)
          end
        end
      end

      context 'with a maintainer group who has no email set and has a user as a member' do
        let!(:group) { create(:group, email: nil) }
        let!(:user) { create(:confirmed_user) }

        let!(:project) { create(:project, maintainer: [group]) }
        let!(:comment) { create(:comment_project, commentable: project) }

        before do
          group.users << user
        end

        context 'and the user has a maintainer subscription' do
          context 'which is enabled' do
            let!(:subscription) { create(:event_subscription_comment_for_project_without_subscriber, receiver_role: 'maintainer', subscriber: user) }

            it 'returns the subscription for that user/group' do
              subscriber_result = subject.find { |subscription| subscription.subscriber == user }

              expect(subscriber_result).to eq(subscription)
            end
          end

          context 'which is disabled' do
            let!(:subscription) do
              create(:event_subscription_comment_for_project_without_subscriber, receiver_role: 'maintainer', subscriber: user, channel: 'disabled')
            end

            it 'does not include that user/group' do
              expect(subject.map(&:subscriber)).not_to include(user)
            end
          end
        end

        context 'and the user has no subscriptions' do
          context 'and a default maintainer subscription is enabled' do
            let!(:default_subscription) do
              create(:event_subscription_comment_for_project, receiver_role: 'maintainer', user: nil, group: nil)
            end

            # TODO: This does not seem like the correct logic for this class.
            it 'does not include that user/group' do
              expect(subject.map(&:subscriber)).not_to include(user)
            end
          end

          context 'and a default maintainer subscription is disabled' do
            let!(:default_subscription) do
              create(:event_subscription_comment_for_project, receiver_role: 'maintainer', user: nil, group: nil, channel: 'disabled')
            end

            it 'does not include that user/group' do
              expect(subject.map(&:subscriber)).not_to include(user)
            end
          end
        end
      end
    end
  end
end
