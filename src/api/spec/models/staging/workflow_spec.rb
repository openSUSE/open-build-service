RSpec.describe Staging::Workflow do
  let(:admin_user) { create(:admin_user, login: 'admin') }
  let(:project) { create(:project_with_package, name: 'MyProject') }
  let(:staging_workflow) { create(:staging_workflow_with_staging_projects, project: project) }
  let(:group) { staging_workflow.managers_group }
  let(:staging_project) { staging_workflow.staging_projects.first }
  let(:source_project) { create(:project, name: 'source_project') }
  let(:target_package) { create(:package, name: 'target_package', project: project) }
  let(:source_package) { create(:package, :as_submission_source, name: 'source_package', project: source_project) }
  let(:bs_request) do
    create(:bs_request_with_submit_action,
           target_package: target_package,
           source_package: source_package)
  end

  before do
    login(admin_user)
    staging_workflow
  end

  describe 'validations' do
    it { is_expected.to belong_to(:managers_group) }
    it { is_expected.to belong_to(:project) }
  end

  context 'when created' do
    let(:role) { Role.find_by_title('reviewer') }

    it { expect(project.relationships.where(group: group, role: role)).to exist }
  end

  describe '#unassigned_requests' do
    subject { staging_workflow.unassigned_requests }

    context 'without requests in the main project' do
      it { expect(subject).to be_empty }
    end

    context 'with requests with reviews by the staging managers group' do
      it { expect(subject).to contain_exactly(bs_request) }
    end

    context 'with requests but all of them are already assigned' do
      before do
        bs_request.staging_project = staging_project
        bs_request.save
      end

      it { expect(subject).to be_empty }
    end

    context 'with requests and some are in staging projects and some not' do
      let!(:bs_request2) do
        create(:bs_request_with_submit_action,
               target_package: target_package,
               source_package: source_package)
      end

      before do
        bs_request.staging_project = staging_project
        bs_request.save
      end

      it { expect(subject).to contain_exactly(bs_request2) }
    end
  end

  describe '#ready_requests' do
    subject { staging_workflow.ready_requests }

    context 'without requests in the main project' do
      it { expect(subject).to be_empty }
    end

    context 'with requests but not in state new' do
      before { bs_request }

      it { expect(subject).to be_empty }
    end

    context 'with request in state review whether they are in staging projects or not' do
      let(:bs_request2) do
        create(:bs_request_with_submit_action,
               target_package: target_package,
               source_package: source_package)
      end

      before do
        bs_request
        bs_request2.change_review_state(:accepted, by_group: group.title)
        bs_request2.update!(staging_project: staging_project)
      end

      it { expect(subject).to contain_exactly(bs_request2) }
    end
  end

  describe '#autocomplete' do
    let!(:bs_request2) do
      create(:bs_request_with_submit_action,
             target_package: target_package,
             source_package: source_package)
    end

    it { expect(staging_workflow.autocomplete(bs_request2.number)).to include(bs_request2) }
    it { expect(staging_workflow.autocomplete(bs_request.number)).not_to include(bs_request2) }
    it { expect(staging_workflow.autocomplete(-1)).to be_empty }
  end
end
