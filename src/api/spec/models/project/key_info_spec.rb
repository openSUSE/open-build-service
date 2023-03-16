require 'rails_helper'

RSpec.describe Project::KeyInfo do
  describe '#find_by_project' do
    context 'when the backend throws an error' do
      let(:project) { create(:project, name: 'foo') }

      before do
        allow(Backend::Api::Sources::Project).to receive(:key_info).and_raise(Backend::Error)
      end

      it 'rescues from the error and returns nil' do
        expect(described_class.find_by_project(project)).to be_nil
      end
    end
  end
end
