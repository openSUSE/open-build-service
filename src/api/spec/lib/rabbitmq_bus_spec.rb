RSpec.describe RabbitmqBus, rabbitmq: '#' do
  it 'publishes messages' do
    RabbitmqBus.send_to_bus('metrics', 'hallo')
    expect_message('opensuse.obs.metrics', 'hallo')
  end
end
