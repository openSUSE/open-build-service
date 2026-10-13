RSpec.describe BsRequestAction do
  let(:user) { create(:confirmed_user, :with_home, login: 'request_user') }
  let(:project) { user.home_project }
  let(:package) { create(:package, project: project, scmsync: 'https://example.com/package.git') }
  let(:action) { build(:bs_request_action_delete, target_project: project.name, target_package: package.name) }

  before do
    allow(User).to receive(:current).and_return(user)
  end

  it 'allows deleting an SCM-managed package from a regular project' do
    expect { action.check_action_permission! }.not_to raise_error
  end

  context 'when the project is SCM-managed' do
    before do
      project.update!(scmsync: 'https://example.com/project.git')
    end

    it 'rejects the delete request' do
      expect { action.check_action_permission! }.to raise_error(BsRequestAction::Errors::RequestRejected, /The target project .* is managed in an external SCM/)
    end
  end

  context 'with a submit request' do
    let(:action) do
      build(:bs_request_action_submit, source_project: project.name, source_package: package.name,
                                       target_project: project.name, target_package: package.name)
    end

    it 'rejects changes to SCM-managed package sources' do
      expect { action.check_action_permission! }.to raise_error(BsRequestAction::Errors::RequestRejected, /The target package .* is managed in an external SCM/)
    end
  end
end
