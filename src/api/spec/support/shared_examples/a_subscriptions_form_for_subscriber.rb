# frozen_string_literal: true

RSpec.shared_examples 'a subscriptions form for subscriber' do
  it 'updates the source_maintainer subscription to channel = disabled' do
    subscription = EventSubscription.for_eventtype('Event::RequestStatechange').for_subscriber(user).find_by(receiver_role: 'source_maintainer')
    expect(subscription.channel).to eq('disabled')
  end

  it 'updates the target_maintainer subscription to channel = disabled' do
    subscription = EventSubscription.for_eventtype('Event::RequestStatechange').for_subscriber(user).find_by(receiver_role: 'target_maintainer')
    expect(subscription.channel).to eq('disabled')
  end

  it 'creates the creator subscription with channel = instant_email' do
    subscription = EventSubscription.for_eventtype('Event::RequestStatechange').for_subscriber(user).find_by(receiver_role: 'creator')
    expect(subscription.channel).to eq('instant_email')
  end

  it 'creates the reviewer subscription with channel = instant_email' do
    subscription = EventSubscription.for_eventtype('Event::RequestStatechange').for_subscriber(user).find_by(receiver_role: 'reviewer')
    expect(subscription.channel).to eq('instant_email')
  end
end

RSpec.shared_examples 'a subscriptions form for default' do
  it 'updates the source_maintainer subscription to channel = disabled' do
    subscription = EventSubscription.for_eventtype('Event::RequestStatechange').for_subscriber(nil).find_by(receiver_role: 'source_maintainer')
    expect(subscription.channel).to eq('disabled')
  end

  it 'updates the target_maintainer subscription to channel = disabled' do
    subscription = EventSubscription.for_eventtype('Event::RequestStatechange').for_subscriber(nil).find_by(receiver_role: 'target_maintainer')
    expect(subscription.channel).to eq('disabled')
  end

  it 'creates the creator subscription with channel = instant_email' do
    subscription = EventSubscription.for_eventtype('Event::RequestStatechange').for_subscriber(nil).find_by(receiver_role: 'creator')
    expect(subscription.channel).to eq('instant_email')
  end

  it 'creates the reviewer subscription with channel = instant_email' do
    subscription = EventSubscription.for_eventtype('Event::RequestStatechange').for_subscriber(nil).find_by(receiver_role: 'reviewer')
    expect(subscription.channel).to eq('instant_email')
  end
end
