require 'rails_helper'
require 'webmock/rspec'

RSpec.describe Webui::Projects::RebuildTimesController do
  let(:user) { create(:confirmed_user, login: 'tom') }
  let(:repo_for_user_home) { create(:repository, project: user.home_project) }

  describe 'GET #show' do
    before do
      # To not ask backend for build status
      allow_any_instance_of(Project).to receive(:number_of_build_problems).and_return(0)
    end

    context 'with bdep and jobs' do
      let(:bdep_url) do
        # FIXME: Hardcoding urls in test doesn't sound like a good idea
        "http://backend:5352/build/#{user.home_project.name}/#{repo_for_user_home.name}/x86_64/_builddepinfo"
      end
      let(:bdep_xml) do
        <<-XML
          "<builddepinfo>" +
            "<package name=\"gcc6\">" +
              "<pkgdep>gcc</pkgdep>" +
            "</package>" +
          "</builddepinfo>"
        XML
      end

      let(:jobs_url) do
        # FIXME: Hardcoding urls in test doesn't sound like a good idea
        "http://backend:5352/build/#{user.home_project.name}/#{repo_for_user_home.name}/x86_64/_jobhistory?code=succeeded&code=unchanged&limit=0"
      end
      let(:jobs_xml) do
        <<-XML
          "<jobhistory>" +
            "<package name=\"gcc6\">" +
              "<pkgdep>gcc</pkgdep>" +
            "</package>" +
          "</jobhistory>"
        XML
      end

      before do
        stub_request(:get, bdep_url).to_return(status: 200, body: bdep_xml)
        stub_request(:get, jobs_url).to_return(status: 200, body: jobs_xml)

        get :show, params: {
          project:    user.home_project.name,
          repository: repo_for_user_home.name,
          arch:       'x86_64'
        }
      end

      it { expect(response).to have_http_status(:success) }
    end

    context 'with an invalid scheduler' do
      before do
        get :show, params: { project: user.home_project, repository: repo_for_user_home.name, arch: 'x86_64', scheduler: 'invalid_scheduler' }
      end

      it { expect(flash[:error]).to eq('Invalid scheduler type, check mkdiststats docu - aehm, source') }
      it { is_expected.to redirect_to(project_show_path(user.home_project)) }
    end

    context 'without build dependency info or jobs history' do
      before do
        allow(BuilddepInfo).to receive(:find)
        allow(Jobhistory).to receive(:find)
        get :show, params: { project: user.home_project, repository: repo_for_user_home.name, arch: 'x86_64' }
      end

      it { expect(flash[:error]).to start_with('Could not collect infos about repository') }
      it { is_expected.to redirect_to(project_show_path(user.home_project)) }
    end

    context 'normal flow' do
      before do
        allow(BuilddepInfo).to receive(:find).and_return([])
        allow(Jobhistory).to receive(:find).and_return([])
      end

      context 'with diststats generated' do
        before do
          path = Xmlhash::XMLHash.new('package' => 'package_name')
          longestpaths_xml = Xmlhash::XMLHash.new('longestpath' => Xmlhash::XMLHash.new('path' => path))
          allow_any_instance_of(Webui::Projects::RebuildTimesController).to receive(:call_diststats).and_return(longestpaths_xml)
          get :show, params: { project: user.home_project, repository: repo_for_user_home.name, arch: 'x86_64' }
        end

        it { expect(assigns(:longestpaths)).to match_array([[], [], [], [], ['package_name']]) }
      end

      context 'with diststats not generated' do
        before do
          allow_any_instance_of(Webui::Projects::RebuildTimesController).to receive(:call_diststats)
          get :show, params: { project: user.home_project, repository: repo_for_user_home.name, arch: 'x86_64' }
        end

        it { expect(assigns(:longestpaths)).to match_array([[], [], [], []]) }
      end
    end
  end

  describe 'GET #rebuild_time_png' do
    context 'with an invalid key' do
      before do
        get :rebuild_time_png, params: { project: user.home_project, key: 'invalid_key' }
      end

      it { expect(response.body).to be_empty }
      it { expect(response.header['Content-Type']).to eq('image/png') }
      it { expect(response.header['Content-Disposition']).to eq('inline') }
    end

    context 'with a valid key' do
      before do
        Rails.cache.write('rebuild-valid_key.png', 'PNG Content')
        get :rebuild_time_png, params: { project: user.home_project, key: 'valid_key' }
      end

      it { expect(response.body).to eq('PNG Content') }
      it { expect(response.header['Content-Type']).to eq('image/png') }
      it { expect(response.header['Content-Disposition']).to eq('inline') }
    end
  end
end
