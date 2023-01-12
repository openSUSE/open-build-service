require 'rails_helper'

RSpec.describe ConsistencyCheckJobService::BackendPackageImporter, vcr: true do
  let(:project) { create(:project_with_package, name: 'super_project', package_name: 'foo') }
  let(:error_message) { "DELETED in backend due to invalid data #{project.name}/foo" }
  let(:backend_package_importer) { described_class.new(project, 'foo') }

  describe '#call' do
    subject { backend_package_importer.call }

    before do
      allow(backend_package_importer).to receive(:create_package_frontend).and_raise(custom_exception)
      subject
    end

    context 'it raises ActiveRecord::RecordInvalid' do
      let(:custom_exception) { ActiveRecord::RecordInvalid }

      it { expect(backend_package_importer.errors).to include(error_message) }
    end

    context 'it raises Backend::NotFoundError' do
      let(:custom_exception) { Backend::NotFoundError }

      it { expect(backend_package_importer.errors).to include(error_message) }
    end
  end
end
