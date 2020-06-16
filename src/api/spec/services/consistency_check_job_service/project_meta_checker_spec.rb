require 'rails_helper'

RSpec.describe ::ConsistencyCheckJobService::ProjectMetaChecker, vcr: true do
  let!(:project) { create(:project, name: 'super_bacana') }

  let(:project_meta_checker) { described_class.new(project) }

  describe '#call' do
    context 'different meta in frontend and backend' do
      let(:frontend_meta) { { 'name' => 'Test', 'title' => 'test project', 'description' => {}, 'person' => { 'userid' => 'Admin', 'role' => 'maintainer' } } }
      let(:backend_meta) { { 'name' => 'Test', 'title' => 'test project foo', 'description' => {}, 'person' => { 'userid' => 'Admin', 'role' => 'maintainer' } } }

      before do
        allow(project_meta_checker).to receive(:frontend_meta).and_return(frontend_meta)
        allow(project_meta_checker).to receive(:backend_meta).and_return(backend_meta)
        project_meta_checker.call
      end

      it { expect(project_meta_checker.errors).not_to be_empty }
    end
  end
end
