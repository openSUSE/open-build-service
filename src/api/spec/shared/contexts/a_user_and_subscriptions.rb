RSpec.shared_context 'a user and subscriptions' do
  let!(:user) { create(:confirmed_user) }

  let!(:user_subscription1) do
    create(:event_subscription_comment_for_project, receiver_role: :commenter, user: user)
  end
  let!(:user_subscription2) do
    create(:event_subscription_comment_for_project, receiver_role: :maintainer, user: user)
  end
  let!(:user_subscription3) do
    create(:event_subscription_comment_for_project, receiver_role: :maintainer, user: user, channel: :web)
  end

  let!(:default_subscription1) do
    create(:event_subscription_comment_for_project_without_subscriber, receiver_role: :commenter)
  end
  let!(:default_subscription2) do
    create(:event_subscription_comment_for_project_without_subscriber, receiver_role: :maintainer)
  end
  let!(:default_subscription3) do
    create(:event_subscription_comment_for_request_without_subscriber, receiver_role: :source_maintainer)
  end
  let!(:default_subscription4) do
    create(:event_subscription_comment_for_request_without_subscriber, receiver_role: :target_maintainer)
  end
end
