RSpec.describe BsRequestAction do
  let(:user) { create(:confirmed_user, :with_home, login: 'request_user') }
  let(:project) { user.home_project }
  let(:package) { create(:package, project: project, scmsync: 'https://example.com/package.git') }
  let(:action) { build(:bs_request_action_delete, target_project: project.name, target_package: package.name) }

  before do
    allow(User).to receive(:current).and_return(user)
  end

  shared_examples 'an OBS-managed action' do
    it 'allows the action on an SCM-managed package in a regular project' do
      expect { action.check_action_permission! }.not_to raise_error
    end

    context 'when the project is SCM-managed' do
      before do
        project.update!(scmsync: 'https://example.com/project.git')
      end

      it 'rejects the request' do
        expect { action.check_action_permission! }.to raise_error(BsRequestAction::Errors::RequestRejected, /The target project .* is managed in an external SCM/)
      end
    end
  end

  it_behaves_like 'an OBS-managed action'

  context 'with an add_role request' do
    let(:action) do
      BsRequestActionAddRole.new(target_project: project.name, target_package: package.name,
                                 person_name: user.login, role: 'maintainer')
    end

    it_behaves_like 'an OBS-managed action'
  end

  context 'with a set_bugowner request' do
    let(:action) do
      build(:bs_request_action_set_bugowner, target_project: project.name, target_package: package.name, person_name: user.login)
    end

    it_behaves_like 'an OBS-managed action'
  end

  context 'with a change_devel request' do
    let(:source_package) { create(:package, project: project) }
    let(:action) do
      build(:bs_request_action_change_devel, source_project: project.name, source_package: source_package.name,
                                             target_project: project.name, target_package: package.name)
    end

    it_behaves_like 'an OBS-managed action'
  end

  %i[submit release maintenance_release].each do |action_type|
    context "with a #{action_type} request" do
      let(:action) do
        build("bs_request_action_#{action_type}", source_project: project.name, source_package: package.name,
                                                  target_project: project.name, target_package: package.name)
      end

      it 'rejects changes to SCM-managed package sources' do
        expect { action.check_action_permission! }.to raise_error(BsRequestAction::Errors::RequestRejected, /The target package .* is managed in an external SCM/)
      end
    end
  end
end
