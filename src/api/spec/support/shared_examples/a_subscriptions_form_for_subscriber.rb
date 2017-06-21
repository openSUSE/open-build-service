RSpec.shared_examples 'a subscriptions form for subscriber' do
  it 'updates the source_maintainer subscription to receive = true' do
    subscription = EventSubscription.for_eventtype('Event::RequestStatechange').for_subscriber(user).find_by(receiver_role: 'source_maintainer')
    expect(subscription.receive).to be_falsey
  end

  it 'updates the target_maintainer subscription to receive = true' do
    subscription = EventSubscription.for_eventtype('Event::RequestStatechange').for_subscriber(user).find_by(receiver_role: 'target_maintainer')
    expect(subscription.receive).to be_falsey
  end

  it 'creates the creator subscription with receive = false' do
    subscription = EventSubscription.for_eventtype('Event::RequestStatechange').for_subscriber(user).find_by(receiver_role: 'creator')
    expect(subscription.receive).to be_truthy
  end

  it 'creates the reviewer subscription with receive = false' do
    subscription = EventSubscription.for_eventtype('Event::RequestStatechange').for_subscriber(user).find_by(receiver_role: 'reviewer')
    expect(subscription.receive).to be_truthy
  end
end

RSpec.shared_examples 'a subscriptions form for default' do
  it 'updates the source_maintainer subscription to receive = true' do
    subscription = EventSubscription.for_eventtype('Event::RequestStatechange').for_subscriber(nil).find_by(receiver_role: 'source_maintainer')
    expect(subscription.receive).to be_falsey
  end

  it 'updates the target_maintainer subscription to receive = true' do
    subscription = EventSubscription.for_eventtype('Event::RequestStatechange').for_subscriber(nil).find_by(receiver_role: 'target_maintainer')
    expect(subscription.receive).to be_falsey
  end

  it 'creates the creator subscription with receive = false' do
    subscription = EventSubscription.for_eventtype('Event::RequestStatechange').for_subscriber(nil).find_by(receiver_role: 'creator')
    expect(subscription.receive).to be_truthy
  end

  it 'creates the reviewer subscription with receive = false' do
    subscription = EventSubscription.for_eventtype('Event::RequestStatechange').for_subscriber(nil).find_by(receiver_role: 'reviewer')
    expect(subscription.receive).to be_truthy
  end
end
