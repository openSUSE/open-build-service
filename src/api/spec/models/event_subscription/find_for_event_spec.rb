# frozen_string_literal: true
require 'rails_helper'

RSpec::Matchers.define :be_like_subscription do |expected_subscription|
  match do |actual_subscription|
    actual_subscription.eventtype == expected_subscription.eventtype &&
      actual_subscription.receiver_role == expected_subscription.receiver_role &&
      actual_subscription.channel == expected_subscription.channel
  end
end

RSpec.shared_context 'it returns subscriptions for an event' do
  let(:maintainer_subscription_result) { subject.find { |subscription| subscription.subscriber == maintainer } }

  context 'with a maintainer user/group who has a maintainer subscription' do
    let!(:project) { create(:project, maintainer: [maintainer]) }
    let!(:comment) { create(:comment_project, commentable: project) }

    context 'which is enabled' do
      let!(:subscription) { create(:event_subscription_comment_for_project_without_subscriber, receiver_role: 'maintainer', subscriber: maintainer) }

      it 'returns the subscription for that user/group' do
        expect(maintainer_subscription_result).to eq(subscription)
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
        expect(maintainer_subscription_result).to be_like_subscription(default_subscription)
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

  context 'with a maintainer user/group who has a maintainer subscription and default subscription' do
    let!(:project) { create(:project, maintainer: [maintainer]) }
    let!(:comment) { create(:comment_project, commentable: project) }

    let!(:default_subscription) do
      create(:event_subscription_comment_for_project, receiver_role: 'maintainer', user: nil, group: nil)
    end

    context 'and the maintainer subscription is enabled' do
      let!(:subscription) { create(:event_subscription_comment_for_project_without_subscriber, receiver_role: 'maintainer', subscriber: maintainer) }

      it 'returns the subscription for that user/group' do
        expect(maintainer_subscription_result).to eq(subscription)
      end
    end

    context 'and the maintainer subscription is disabled' do
      let!(:subscription) do
        create(:event_subscription_comment_for_project_without_subscriber, receiver_role: 'maintainer', subscriber: maintainer, channel: 'disabled')
      end

      it 'does not include that user/group' do
        expect(subject.map(&:subscriber)).not_to include(maintainer)
      end
    end
  end
end

RSpec.describe EventSubscription::FindForEvent do
  describe '#subscribers' do
    context 'with a request' do
      let!(:watcher) { create(:confirmed_user) }
      let!(:watcher2) { create(:confirmed_user) }
      let!(:source_project) { create(:project, name: 'TheSource') }
      let!(:target_project) { create(:project, name: 'TheTarget') }
      let!(:source_package) { create(:package) }
      let!(:target_package) { create(:package) }
      let(:request) do
        create(
          :bs_request_with_submit_action,
          source_project: source_project.name,
          target_project: target_project.name,
          source_package: source_package.name,
          target_package: target_package.name
        )
      end
      let!(:default_subscription) do
        create(
          :event_subscription,
          eventtype: 'Event::RequestCreate',
          receiver_role: 'source_watcher',
          user: nil,
          group: nil,
          channel: :instant_email
        )
      end

      before do
        watcher.add_watched_project(source_project.name)
        request
      end

      subject do
        event = Event::RequestCreate.first
        EventSubscription::FindForEvent.new(event).subscriptions
      end

      it 'returns a new subscription for the watcher based on the default subscription' do
        result_subscription = subject.find { |subscription| subscription.subscriber == watcher }

        expect(result_subscription).to be_like_subscription(default_subscription)
      end
    end

    context 'with a comment for a project' do
      subject do
        event = Event::CommentForProject.first
        EventSubscription::FindForEvent.new(event).subscriptions
      end

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

      context 'with a user who watching the project' do
        let!(:watcher) { create(:confirmed_user) }
        let!(:project) { create(:project) }
        let!(:comment) { create(:comment_project, commentable: project) }

        let!(:default_subscription) do
          create(:event_subscription_comment_for_project, receiver_role: 'watcher', user: nil, group: nil)
        end

        before do
          watcher.add_watched_project(project.name)
        end

        it 'returns a new subscription for the watcher based on the default subscription' do
          result_subscription = subject.find { |subscription| subscription.subscriber == watcher }

          expect(result_subscription).to be_like_subscription(default_subscription)
        end
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

        let(:user_subscription_result) { subject.find { |subscription| subscription.subscriber == user } }

        before do
          group.users << user
        end

        context 'and the user has a maintainer subscription' do
          context 'which is enabled' do
            let!(:subscription) { create(:event_subscription_comment_for_project_without_subscriber, receiver_role: 'maintainer', subscriber: user) }

            context 'and the user has emails enabled for the group' do
              it 'returns the subscription for that user/group' do
                subscriber_result = subject.find { |subscription| subscription.subscriber == user }

                expect(subscriber_result).to eq(subscription)
              end
            end

            context 'and the user has emails disabled for the group' do
              before do
                groups_user = GroupsUser.find_by(user: user, group: group)
                groups_user.email = false
                groups_user.save
              end

              it 'does not include that user' do
                expect(subject.map(&:subscriber)).not_to include(user)
              end
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

            it 'returns a new subscription for that user/group based on the default subscription' do
              expect(user_subscription_result).to be_like_subscription(default_subscription)
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
