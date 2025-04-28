RSpec.describe Webui::RepositoriesController, :vcr do
  let(:user) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:admin_user) { create(:admin_user, login: 'admin') }
  let(:apache_project) { create(:project, name: 'Apache') }
  let(:another_project) { create(:project, name: 'Another_Project') }
  let(:repo_for_user_home) { create(:repository, name: 'repository_6', project: user.home_project) }

  describe 'GET #index' do
    before do
      get :index, params: { project: apache_project }
    end

    it { expect(assigns(:architectures)).to be_empty }
  end

  describe 'POST #update' do
    before do
      login user
    end

    context 'updating non existent repository' do
      it 'raises a NoMethodError' do
        expect do
          post :update, params: { project: user.home_project, repo: 'standard' }
        end.to raise_error(NoMethodError)
      end
    end

    context 'updating the repository without architectures' do
      before do
        post :update, params: { project: user.home_project, repo: repo_for_user_home.name }
      end

      it { expect(repo_for_user_home.architectures.pluck(:name)).to be_empty }
      it { expect(assigns(:repository_arch_hash).to_a).to contain_exactly(['armv7l', false], ['i586', false], ['x86_64', false]) }
      it { is_expected.to redirect_to(action: :index) }
      it { expect(flash[:success]).to eq('Successfully updated repository') }
    end

    context 'updating the repository with architectures' do
      before do
        post :update, params: { project: user.home_project, repo: repo_for_user_home.name, arch: { 'i586' => true, 'x86_64' => true } }
      end

      it 'each repository has a different position' do
        id = user.home_project.repositories.pluck(:id)
        foo = RepositoryArchitecture.where(repository_id: id)
        expect(foo.count).to eq(foo.distinct.count)
      end

      it { expect(repo_for_user_home.architectures.pluck(:name)).to contain_exactly('i586', 'x86_64') }
      it { expect(Architecture.available.pluck(:name)).to contain_exactly('armv7l', 'i586', 'x86_64') }
      it { expect(assigns(:repository_arch_hash).to_a).to contain_exactly(['armv7l', false], ['i586', true], ['x86_64', true]) }
      it { is_expected.to redirect_to(action: :index) }
      it { expect(flash[:success]).to eq('Successfully updated repository') }
    end
  end

  describe 'POST #create' do
    before do
      login user
      request.env['HTTP_REFERER'] = root_url # Needed for the redirect_to :back
    end

    context 'with a non valid repository name' do
      let(:action) { post :create, params: { project: user.home_project, repository: '_not/valid/name' } }

      it 'displays an error message' do
        action
        expect(flash[:error]).to eq("Can not add repository: Name must not start with '_' or contain any of these characters ':/'")
      end

      it { expect(action).to redirect_to(root_url) }
      it { expect { action }.not_to change(Repository, :count) }
    end

    context 'with a non valid target repository' do
      before do
        post :create, params: { project: user.home_project, repository: 'valid_name',
                                add_repo_from_project_target_project: another_project, target_repo: 'non_valid_repo' }
      end

      it { expect(flash[:error]).to eq('Can not add repository: Path elements is invalid and Path Element: Link must exist') }
      it { is_expected.to redirect_to(root_url) }
    end

    context 'with a valid repository but with a non valid architecture' do
      before do
        create(:repository, project: another_project)
        post :create, params: { project: user.home_project, repository: 'valid_name', architectures: ['non_existent_arch'] }
      end

      it { expect(flash[:error]).to start_with('Can not add repository: Repository ') }
      it { is_expected.to redirect_to(root_url) }
    end

    context 'with a valid repository' do
      before do
        target_repo = create(:repository, project: another_project)
        post :create, params: {
          project: user.home_project, repository: 'valid_name',
          add_repo_from_project_target_project: another_project, target_repo: target_repo.name, architectures: ['i586']
        }
      end

      it { expect(flash[:success]).to eq("Successfully added repository 'valid_name'") }
      it { is_expected.to redirect_to(action: :index, project: user.home_project) }
      it { expect(user.home_project.repositories.find_by(name: 'valid_name').repository_architectures.count).to eq(1) }
    end

    context 'without any repository passed' do
      before do
        post :create, params: { project: user.home_project }
      end

      it {
        expect(flash[:error]).to eq('Can not add repository: ' \
                                    'Name is too short (minimum is 1 character) and ' \
                                    "Name must not start with '_' or contain any of these characters ':/'")
      }

      it { is_expected.to redirect_to(root_url) }
      it { expect(assigns(:project).repositories.count).to eq(0) }
    end
  end

  describe 'POST #create_dod_repository' do
    context 'as regular user' do
      before do
        login user
      end

      context 'with valid repository data' do
        before do
          post :create_dod_repository, xhr: true,
                                       params: {
                                         project: user.home_project, name: 'NewRepo', arch: Architecture.first.name, url: 'http://whatever.com', repotype: 'rpmmd'
                                       }
        end

        it { expect(response).to have_http_status(:forbidden) }
      end
    end

    context 'as admin' do
      before do
        login admin_user
      end

      context 'with an existing repository' do
        let(:existing_repository) { create(:repository) }

        before do
          post :create_dod_repository, xhr: true,
                                       params: {
                                         project: user.home_project, name: existing_repository.name, arch: Architecture.first.name, url: 'http://whatever.com', repotype: 'rpmmd'
                                       }
        end

        it { expect(assigns(:error)).to start_with('Repository with name') }
        it { expect(response).to have_http_status(:redirect) }
      end

      context 'with no valid repository type' do
        before do
          post :create_dod_repository, xhr: true,
                                       params: {
                                         project: user.home_project, name: 'NewRepo', arch: Architecture.first.name, url: 'http://whatever.com', repotype: 'invalid_repo_type'
                                       }
        end

        it { expect(assigns(:error)).to start_with("Couldn't add repository:") }
        it { expect(response).to have_http_status(:redirect) }
      end

      context 'with no valid repository Architecture' do
        before do
          post :create_dod_repository, xhr: true,
                                       params: {
                                         project: user.home_project, name: 'NewRepo', arch: 'non_existent_arch', url: 'http://whatever.com', repotype: 'rpmmd'
                                       }
        end

        it { expect(assigns(:error)).to start_with("Couldn't add repository:") }
        it { expect(response).to have_http_status(:redirect) }
      end

      context 'with valid repository data' do
        before do
          post :create_dod_repository, xhr: true,
                                       params: {
                                         project: user.home_project, name: 'NewRepo', arch: Architecture.first.name, url: 'http://whatever.com', repotype: 'rpmmd'
                                       }
        end

        it { expect(assigns(:error)).to be_nil }
        it { expect(response).to have_http_status(:redirect) }
      end
    end
  end

  describe 'POST #create_image_repository' do
    context 'with a distribution called images' do
      before do
        login user
        allow_any_instance_of(Project).to receive(:prepend_kiwi_config).and_return(true)
        post :create_image_repository, params: { project: user.home_project }
      end

      it { expect(flash[:success]).to eq('Successfully added image repository') }
      it { is_expected.to redirect_to(action: :index, project: user.home_project) }
      it { expect(assigns(:project).repositories.count).to eq(1) }
      it { expect(assigns(:project).repositories.first.name).to eq('images') }
      it { expect(assigns(:project).repositories.first.repository_architectures.count).to eq(Architecture.available.count) }
    end
  end
end
