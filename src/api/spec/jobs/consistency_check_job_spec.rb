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
      # rubocop:disable-next RSpec/AnyInstance
      allow_any_instance_of(ConsistencyCheckJobService::ProjectMetaChecker).to receive(:diff).and_return({})
    end

    it { expect(consistency_checkjob.check_one_project(project, fix: false)).to be_empty }
  end

  describe '#check_project' do
    let!(:project) { create(:project, name: 'super_project') }
    let(:consistency_checkjob) { described_class.new }
    let(:error_message) { "Project meta is different in backend for super_project\n{foo: \"bar\"}" }

    before do
      create(:admin_user, login: 'Admin')
      # rubocop:disable-next RSpec/AnyInstance
      allow_any_instance_of(ConsistencyCheckJobService::ProjectMetaChecker).to receive(:diff).and_return({ foo: 'bar' })
    end

    context 'fix = false' do
      it { expect(consistency_checkjob.check_project(project.name, fix: false)).to include(error_message) }
    end

    context 'fix = true' do
      before do
        allow(Project).to receive(:get_by_name).with(project.name).and_return(project)
      end

      it 'project should call store' do
        # rubocop:disable-next RSpec/MessageSpies
        expect(project).to receive(:store).with(hash_including(login: 'Admin'))
        consistency_checkjob.check_project(project.name, fix: true)
      end
    end
  end

  describe '#project_existence_consistency_check' do
    let(:consistency_checkjob) { described_class.new }
    let(:checker) { instance_double(ConsistencyCheckJobService::ProjectConsistencyChecker) }

    before do
      allow(ConsistencyCheckJobService::ProjectConsistencyChecker).to receive(:new).and_return(checker)
      allow(checker).to receive(:call).and_return(checker)
      allow(checker).to receive_messages(diff_frontend_backend: ['extra_frontend_project'], diff_backend_frontend: [])
    end

    context 'fix = false' do
      it 'records additional projects error without deleting' do
        # rubocop:disable-next RSpec/MessageSpies
        expect(Project).not_to receive(:find_by_name)
        consistency_checkjob.send(:project_existence_consistency_check, fix: false)
        expect(consistency_checkjob.send(:errors)).to include("Additional projects in frontend:\n [\"extra_frontend_project\"]")
      end
    end

    context 'fix = true' do
      let!(:extra_project) { create(:project, name: 'extra_frontend_project') }

      it 'finds and destroys the extra project in frontend' do
        expect { consistency_checkjob.send(:project_existence_consistency_check, fix: true) }
          .to change { Project.exists?(name: 'extra_frontend_project') }.from(true).to(false)
      end
    end
  end
end
