require 'rails_helper'
require Rails.root.join('lib', 'influxdb_obs', 'obs', 'normalizer', 'location_normalizer').to_s

RSpec.describe InfluxDB::OBS::Normalizer::LocationNormalizer do
  let(:controller_backtrace) { instance_double('Thread::Backtrace::Location', label: 'show', absolute_path: 'src/api/app/controllers/projects_controller.rb') }
  let(:backend_backtrace) { instance_double('Thread::Backtrace::Location', label: 'upload', absolute_path: 'src/api/lib/backend/api/cloud.rb') }
  let(:full_backtrace) { [controller_backtrace, backend_backtrace] }

  describe '#controller_name' do
    it { expect(described_class.new(full_backtrace).controller_name).to eq('ProjectsController#show') }

    context 'with more backtrace takes the last' do
      let(:more_backtrace) { instance_double('Thread::Backtrace::Location', label: 'index', absolute_path: 'src/api/app/controllers/projects_controller.rb') }

      it { expect(described_class.new(full_backtrace.unshift(more_backtrace)).controller_name).to eq('ProjectsController#index') }
    end
  end

  describe '#backend_name' do
    it { expect(described_class.new(full_backtrace).backend_name).to eq('Cloud#upload') }

    context 'with more backtrace takes the first' do
      let(:more_backtrace) { instance_double('Thread::Backtrace::Location', label: 'status', absolute_path: 'src/api/lib/backend/api/cloud.rb') }

      it { expect(described_class.new(full_backtrace.unshift(more_backtrace)).backend_name).to eq('Cloud#status') }
    end
  end
end
