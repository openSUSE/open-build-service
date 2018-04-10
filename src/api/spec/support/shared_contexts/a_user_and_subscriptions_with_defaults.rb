# frozen_string_literal: true
RSpec.shared_context 'a user and subscriptions with defaults' do
  let!(:user) { create(:confirmed_user) }

  let!(:user_subscription1) do
    create(
      :event_subscription,
      eventtype: 'Event::RequestStatechange',
      receiver_role: :source_maintainer,
      user: user,
      channel: 'instant_email'
    )
  end
  let!(:user_subscription2) do
    create(
      :event_subscription,
      eventtype: 'Event::RequestStatechange',
      receiver_role: :target_maintainer,
      user: user,
      channel: 'instant_email'
    )
  end
  let!(:default_subscription1) do
    create(
      :event_subscription,
      eventtype: 'Event::RequestStatechange',
      receiver_role: :source_maintainer,
      user: nil,
      group: nil,
      channel: 'instant_email'
    )
  end
  let!(:default_subscription2) do
    create(
      :event_subscription,
      eventtype: 'Event::RequestStatechange',
      receiver_role: :target_maintainer,
      user: nil,
      group: nil,
      channel: 'instant_email'
    )
  end

  let(:subscription_params) do
    {
      '0' => { channel: 'disabled', eventtype: 'Event::RequestStatechange', receiver_role: 'source_maintainer' },
      '1' => { channel: 'disabled', eventtype: 'Event::RequestStatechange', receiver_role: 'target_maintainer' },
      '2' => { channel: 'instant_email', eventtype: 'Event::RequestStatechange', receiver_role: 'creator' },
      '3' => { channel: 'instant_email', eventtype: 'Event::RequestStatechange', receiver_role: 'reviewer' }
    }
  end
end
