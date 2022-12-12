require 'rails_helper'

RSpec.describe ConsistencyCheckJobService::BackendProjectImporter, vcr: true do
  let(:project) { create(:project, name: 'super_project') }
  let(:backend_project_importer) { described_class.new(project.name) }

  describe '#call' do
    subject { backend_project_importer.call }

    before do
      allow(backend_project_importer).to receive(:create_project_frontend).and_raise(custom_exception)
      subject
    end

    context 'it raises APIError' do
      let(:custom_exception) { APIError }
      let(:error_message) { "Invalid project meta data hosted in src server for project #{project}: APIError" }

      it { expect(backend_project_importer.errors).to include(error_message) }
    end

    context 'it raises ActiveRecord::RecordInvalid' do
      let(:custom_exception) { ActiveRecord::RecordInvalid }
      let(:error_message) { "DELETED #{project} on backend due to invalid data" }

      it { expect(backend_project_importer.errors).to include(error_message) }
    end

    context 'it raises Backend::NotFoundError' do
      let(:custom_exception) { Backend::NotFoundError }
      let(:error_message) { "specified #{project} does not exist on backend" }

      it { expect(backend_project_importer.errors).to include(error_message) }
    end
  end
end
