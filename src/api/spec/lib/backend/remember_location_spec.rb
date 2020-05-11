require 'rails_helper'

RSpec.describe Backend::RememberLocation do
  let(:with_remember_location_class) do
    Class.new do
      extend Backend::RememberLocation

      def self.run
        raise 'Backend module missing' unless Thread.current[:_influxdb_obs_backend_api_module] == 'WithRememberLocation'
        raise 'Backend method missing' unless Thread.current[:_influxdb_obs_backend_api_method] == 'run'
      end
    end
  end

  before do
    stub_const('WithRememberLocation', with_remember_location_class)
  end

  describe 'remembers the location while executing' do
    it { expect { WithRememberLocation.run }.not_to raise_exception }
  end

  describe 'resets the cache after executing' do
    before do
      WithRememberLocation.run
    end

    it { expect(Thread.current[:_influxdb_obs_backend_api_module]).to be_nil }
    it { expect(Thread.current[:_influxdb_obs_backend_api_method]).to be_nil }
  end
end
