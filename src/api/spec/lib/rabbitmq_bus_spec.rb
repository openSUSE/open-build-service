require 'rails_helper'

RSpec.describe RabbitmqBus, rabbitmq: '#' do
  it 'publishes messages' do
    RabbitmqBus.send_to_bus('metrics', 'hallo')
    expect_message('opensuse.obs.metrics', 'hallo')
  end

  context 'with exceptions' do
    before do
      allow_any_instance_of(BunnyMock::Queue).to receive(:publish).and_raise(Net::ReadTimeout)
    end

    it 'disconnects on errors' do
      RabbitmqBus.send_to_bus('metrics', 'hallo')
      expect_no_message
    end
  end
end
