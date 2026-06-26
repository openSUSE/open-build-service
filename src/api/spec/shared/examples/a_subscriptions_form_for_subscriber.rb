RSpec.shared_examples 'a subscriptions form for subscriber' do
  it 'disable the source_maintainer subscription to channel = instant_email' do
    subscription = EventSubscription.for_eventtype('Event::RequestStatechange')
                                    .for_subscriber(user)
                                    .find_by(receiver_role: 'source_maintainer', channel: :instant_email)
    expect(subscription).to be_instant_email
    expect(subscription).not_to be_enabled
  end

  it 'disable the target_maintainer subscription to channel = instant_email' do
    subscription = EventSubscription.for_eventtype('Event::RequestStatechange')
                                    .for_subscriber(user)
                                    .find_by(receiver_role: 'target_maintainer', channel: :instant_email)
    expect(subscription).to be_instant_email
    expect(subscription).not_to be_enabled
  end

  it 'creates the creator subscription with channel = instant_email' do
    subscription = EventSubscription.for_eventtype('Event::RequestStatechange')
                                    .for_subscriber(user)
                                    .find_by(receiver_role: 'creator', channel: :instant_email)
    expect(subscription).to be_instant_email
    expect(subscription).to be_enabled
  end

  it 'creates the reviewer subscription with channel = instant_email' do
    subscription = EventSubscription.for_eventtype('Event::RequestStatechange')
                                    .for_subscriber(user)
                                    .find_by(receiver_role: 'reviewer', channel: :instant_email)
    expect(subscription).to be_instant_email
    expect(subscription).to be_enabled
  end

  it 'creates the reviewer subscription with channel = web' do
    subscription = EventSubscription.for_eventtype('Event::RequestStatechange')
                                    .for_subscriber(user)
                                    .find_by(receiver_role: 'reviewer', channel: :web)
    expect(subscription).to be_web
    expect(subscription).to be_enabled
  end

  it 'creates the creator subscription with channel = rss' do
    subscription = EventSubscription.for_eventtype('Event::RequestStatechange')
                                    .for_subscriber(user)
                                    .find_by(receiver_role: 'creator', channel: :rss)
    expect(subscription).to be_rss
    expect(subscription).to be_enabled
  end
end

RSpec.shared_examples 'a subscriptions form for default' do
  it 'disable the source_maintainer subscription to channel = instant_email' do
    subscription = EventSubscription.for_eventtype('Event::RequestStatechange')
                                    .for_subscriber(nil)
                                    .find_by(receiver_role: 'source_maintainer', channel: :instant_email)
    expect(subscription).to be_instant_email
    expect(subscription).not_to be_enabled
  end

  it 'disable the target_maintainer subscription to channel = instant_email' do
    subscription = EventSubscription.for_eventtype('Event::RequestStatechange')
                                    .for_subscriber(nil)
                                    .find_by(receiver_role: 'target_maintainer', channel: :instant_email)
    expect(subscription).to be_instant_email
    expect(subscription).not_to be_enabled
  end

  it 'creates the creator subscription with channel = instant_email' do
    subscription = EventSubscription.for_eventtype('Event::RequestStatechange')
                                    .for_subscriber(nil)
                                    .find_by(receiver_role: 'creator', channel: :instant_email)
    expect(subscription).to be_instant_email
    expect(subscription).to be_enabled
  end

  it 'creates the reviewer subscription with channel = instant_email' do
    subscription = EventSubscription.for_eventtype('Event::RequestStatechange')
                                    .for_subscriber(nil)
                                    .find_by(receiver_role: 'reviewer', channel: :instant_email)
    expect(subscription).to be_instant_email
    expect(subscription).to be_enabled
  end

  it 'creates the creator subscription with channel = web' do
    subscription = EventSubscription.for_eventtype('Event::RequestStatechange')
                                    .for_subscriber(nil)
                                    .find_by(receiver_role: 'reviewer', channel: :web)
    expect(subscription).to be_web
    expect(subscription).to be_enabled
  end

  it 'creates the reviewer subscription with channel = rss' do
    subscription = EventSubscription.for_eventtype('Event::RequestStatechange')
                                    .for_subscriber(nil)
                                    .find_by(receiver_role: 'creator', channel: :rss)
    expect(subscription).to be_rss
    expect(subscription).to be_enabled
  end
end
