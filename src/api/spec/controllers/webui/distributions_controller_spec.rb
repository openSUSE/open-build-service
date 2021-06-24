require 'rails_helper'

RSpec.describe Webui::DistributionsController do
  let(:user) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:admin_user) { create(:admin_user, login: 'admin') }
  let(:apache_project) { create(:project_with_repository, name: 'Apache') }

  describe 'GET #new' do
    context 'with some distributions' do
      before do
        create_list(:distribution, 4, vendor: 'vendor1')
        create_list(:distribution, 2, vendor: 'vendor2')
      end

      it 'shows repositories from default list' do
        login user
        get :new, params: { project_name: user.home_project_name }
        expect(assigns(:distributions).length).to eq(2)
      end
    end

    context 'without any distribution and being normal user' do
      before do
        login user
        get :new, params: { project_name: user.home_project_name }
      end

      it { is_expected.to redirect_to(project_repositories_path(project: user.home_project_name)) }
    end

    context 'without any distribution and being admin user' do
      before do
        login admin_user
        get :new, params: { project_name: apache_project }
      end

      it { is_expected.to redirect_to(new_interconnect_path) }
      it { expect(flash[:alert]).to include('no distributions configured') }
    end
  end

  describe 'PATCH #toggle' do
    let(:distribution) { create(:distribution, project: apache_project, repository: apache_project.repositories.first.name) }

    context 'with an existing distribution repository' do
      before do
        repository = Repository.new_from_distribution(distribution)
        repository.project = user.home_project
        repository.save!
        login user
        get :toggle, params: { project_name: user.home_project_name, distribution: distribution }, xhr: true
      end

      it 'removes the repository' do
        expect(user.home_project.reload.repositories.where(name: distribution.reponame)).not_to be_any
      end
    end

    context 'without a repository' do
      before do
        login user
        get :toggle, params: { project_name: user.home_project_name, distribution: distribution }, xhr: true
      end

      it 'adds the repository' do
        expect(user.home_project.reload.repositories.where(name: distribution.reponame)).to be_any
      end
    end
  end
end
