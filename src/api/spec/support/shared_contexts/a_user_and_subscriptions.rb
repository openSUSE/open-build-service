# frozen_string_literal: true
RSpec.shared_context 'a user and subscriptions' do
  let!(:user) { create(:confirmed_user) }

  let!(:user_subscription1) do
    create(:event_subscription, eventtype: 'Event::CommentForProject', receiver_role: :commenter, user: user)
  end
  let!(:user_subscription2) do
    create(:event_subscription, eventtype: 'Event::CommentForProject', receiver_role: :maintainer, user: user)
  end

  let!(:default_subscription1) do
    create(:event_subscription, eventtype: 'Event::CommentForProject', receiver_role: :commenter, user: nil)
  end
  let!(:default_subscription2) do
    create(:event_subscription, eventtype: 'Event::CommentForProject', receiver_role: :maintainer, user: nil)
  end
  let!(:default_subscription3) do
    create(:event_subscription, eventtype: 'Event::CommentForRequest', receiver_role: :source_maintainer, user: nil)
  end
  let!(:default_subscription4) do
    create(:event_subscription, eventtype: 'Event::CommentForRequest', receiver_role: :target_maintainer, user: nil)
  end
end
