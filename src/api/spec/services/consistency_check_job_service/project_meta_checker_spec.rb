RSpec.describe ConsistencyCheckJobService::ProjectMetaChecker, :vcr do
  let!(:project) { create(:project, name: 'super_bacana') }

  let(:project_meta_checker) { described_class.new(project) }

  describe '#call' do
    context 'different meta in frontend and backend' do
      let(:frontend_meta) { { 'name' => 'Test', 'title' => 'test project', 'description' => {}, 'person' => { 'userid' => 'Admin', 'role' => 'maintainer' } } }
      let(:backend_meta) { { 'name' => 'Test', 'title' => 'test project foo', 'description' => {}, 'person' => { 'userid' => 'Admin', 'role' => 'maintainer' } } }

      before do
        allow(project_meta_checker).to receive_messages(frontend_meta: frontend_meta, backend_meta: backend_meta)
        project_meta_checker.call
      end

      it { expect(project_meta_checker.errors).not_to be_empty }
    end
  end
end
