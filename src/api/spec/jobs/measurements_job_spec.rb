RSpec.describe MeasurementsJob do
  describe 'token workflows' do
    before do
      allow(RabbitmqBus).to receive(:send_to_bus)
      stub_const('CONFIG', { 'amqp_options' => { host: 'rabbit.example.com' } })
    end

    it 'gathers some intelligence about our token workflow runs' do
      MeasurementsJob.new.perform

      expect(RabbitmqBus).to have_received(:send_to_bus)
        .with('metrics', 'token_workflow total_count=0,enabled=0,disabled=0,custom_configuration_path=0,custom_configuration_url=0,user_with_tokens=0,groups_sharing_tokens=0')
        .at_least(1).times
    end
  end
end
