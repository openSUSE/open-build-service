require 'rails_helper'
require 'webmock/rspec'

RSpec.describe Webui::Projects::StatusController do
  let(:admin_user) { create(:admin_user, login: 'admin') }

  describe 'GET #show' do
    let(:params) { { project_name: project.name } }

    before do
      get :show, params: params
    end

    context 'no params set' do
      # NOTE: These project names need to be different for each context because otherwise the
      # test backend will fail to cleanup the backend packages which causes failures in this spec
      let!(:project) do
        create(:project, name: 'Apache22', title: 'Apache WebServer', description: 'The best webserver ever.')
      end
      let!(:package) do
        create(:package, project: project, name: 'mod_rewrite3', title: 'mod_rewrite', description: 'url rewrite module')
      end

      it_behaves_like 'a project status controller'
    end

    context 'param format=json set' do
      let!(:project) do
        create(:project, name: 'Apache3', title: 'Apache WebServer', description: 'The best webserver ever.')
      end
      let!(:package) do
        create(:package, project: project, name: 'mod_rewrite3', title: 'mod_rewrite', description: 'url rewrite module')
      end
      let(:params) { { project_name: project.name, format: 'json' } }

      it_behaves_like 'a project status controller'
    end

    context 'param filter_devel is set' do
      let!(:project) do
        create(:project, name: 'Apache4', title: 'Apache WebServer', description: 'The best webserver ever.')
      end
      let!(:package) do
        create(:package, project: project, name: 'mod_rewrite4', title: 'mod_rewrite', description: 'url rewrite module')
      end
      let(:params) { { project_name: project.name, filter_devel: 'No Project' } }

      it { expect(assigns[:filter]).to eq('_none_') }
    end

    context 'param ignore_pending is set' do
      let!(:project) do
        create(:project, name: 'Apache5', title: 'Apache WebServer', description: 'The best webserver ever.')
      end
      let!(:package) do
        create(:package, project: project, name: 'mod_rewrite5', title: 'mod_rewrite', description: 'url rewrite module')
      end
      let(:params) { { project_name: project.name, ignore_pending: true } }

      it { expect(assigns[:ignore_pending]).to be_truthy }
    end

    context 'param limit_to_fails is set' do
      let!(:project) do
        create(:project, name: 'Apache6', title: 'Apache WebServer', description: 'The best webserver ever.')
      end
      let!(:package) do
        create(:package, project: project, name: 'mod_rewrite6', title: 'mod_rewrite', description: 'url rewrite module')
      end
      let(:params) { { project_name: project.name, limit_to_fails: 'false' } }

      it { expect(assigns[:limit_to_fails]).to be_falsey }
    end

    context 'param limit_to_old is set' do
      let!(:project) do
        create(:project, name: 'Apache7', title: 'Apache WebServer', description: 'The best webserver ever.')
      end
      let!(:package) do
        create(:package, project: project, name: 'mod_rewrite7', title: 'mod_rewrite', description: 'url rewrite module')
      end
      let(:params) { { project_name: project.name, limit_to_old: 'true' } }

      it { expect(assigns[:limit_to_old]).to be_truthy }
    end

    context 'param include_versions is set' do
      let!(:project) do
        create(:project, name: 'Apache8', title: 'Apache WebServer', description: 'The best webserver ever.')
      end
      let!(:package) do
        create(:package, project: project, name: 'mod_rewrite8', title: 'mod_rewrite', description: 'url rewrite module')
      end
      let(:params) { { project_name: project.name, include_versions: 'true' } }

      it { expect(assigns[:include_versions]).to be_truthy }
    end

    context 'param filter_for_user is set' do
      let!(:project) do
        create(:project, name: 'Apache9', title: 'Apache WebServer', description: 'The best webserver ever.')
      end
      let!(:package) do
        create(:package, project: project, name: 'mod_rewrite9', title: 'mod_rewrite', description: 'url rewrite module')
      end
      let(:params) { { project_name: project.name, filter_for_user: admin_user.login } }

      it { expect(assigns[:filter_for_user]).to eq(admin_user.login) }
    end
  end
end
