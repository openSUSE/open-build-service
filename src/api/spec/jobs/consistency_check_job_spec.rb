RSpec.describe ConsistencyCheckJob, :vcr do
  include ActiveJob::TestHelper

  describe '#perform' do
    let!(:admin_user) { create(:admin_user, login: 'Admin') }

    it { expect { ConsistencyCheckJob.new.perform }.not_to raise_error }
  end

  describe '#check_one_project' do
    let!(:project) { create(:project, name: 'super_project', title: 'super', description: 'awesome stuff') }
    let(:consistency_checkjob) { described_class.new }

    before do
      # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(ConsistencyCheckJobService::ProjectMetaChecker).to receive(:diff).and_return({})
      # rubocop:enable RSpec/AnyInstance
    end

    it { expect(consistency_checkjob.check_one_project(project, fix: false)).to be_empty }
  end

  describe '#check_project' do
    let!(:project) { create(:project, name: 'super_project') }
    let(:consistency_checkjob) { described_class.new }
    let(:error_message) { "Project meta is different in backend for super_project\n{foo: \"bar\"}" }

    before do
      create(:admin_user, login: 'Admin')
      # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(ConsistencyCheckJobService::ProjectMetaChecker).to receive(:diff).and_return({ foo: 'bar' })
      # rubocop:enable RSpec/AnyInstance
    end

    context 'fix = false' do
      it { expect(consistency_checkjob.check_project(project.name, fix: false)).to include(error_message) }
    end

    context 'fix = true' do
      before do
        allow(Project).to receive(:get_by_name).with(project.name).and_return(project)
      end

      it 'project should call store' do
        # rubocop:disable RSpec/MessageSpies
        expect(project).to receive(:store).with(hash_including(login: 'Admin'))
        # rubocop:enable RSpec/MessageSpies
        consistency_checkjob.check_project(project.name, fix: true)
      end
    end
  end
end
