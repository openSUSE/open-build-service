require 'rails_helper'

RSpec.describe Backend::RememberLocation do
  let(:mod) { WithRememberLocation }

  class WithRememberLocation
    extend Backend::RememberLocation

    def self.run_after; end
  end

  describe 'it remembers the location' do
    before do
      mod.run_after
    end

    it { expect(Thread.current[:_influxdb_obs_backend_api_module]).to eq(mod.to_s) }
    it { expect(Thread.current[:_influxdb_obs_backend_api_method]).to eq('run_after') }
  end
end
