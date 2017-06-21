RSpec.shared_context 'a user and subscriptions with defaults' do
  let!(:user) { create(:confirmed_user) }

  let!(:user_subscription1) do
    create(
      :event_subscription,
      eventtype: 'Event::RequestStatechange',
      receiver_role: :source_maintainer,
      user: user,
      receive: true
    )
  end
  let!(:user_subscription2) do
    create(
      :event_subscription,
      eventtype: 'Event::RequestStatechange',
      receiver_role: :target_maintainer,
      user: user,
      receive: true
    )
  end
  let!(:default_subscription1) do
    create(
      :event_subscription,
      eventtype: 'Event::RequestStatechange',
      receiver_role: :source_maintainer,
      user: nil,
      group: nil,
      receive: true
    )
  end
  let!(:default_subscription2) do
    create(
      :event_subscription,
      eventtype: 'Event::RequestStatechange',
      receiver_role: :target_maintainer,
      user: nil,
      group: nil,
      receive: true
    )
  end

  let(:subscription_params) do
    {
      '0' => { receive: "0", eventtype: "Event::RequestStatechange", receiver_role: "source_maintainer"},
      '1' => { receive: "0", eventtype: "Event::RequestStatechange", receiver_role: "target_maintainer"},
      '2' => { receive: "1", eventtype: "Event::RequestStatechange", receiver_role: "creator"},
      '3' => { receive: "1", eventtype: "Event::RequestStatechange", receiver_role: "reviewer"}
    }
  end
end
