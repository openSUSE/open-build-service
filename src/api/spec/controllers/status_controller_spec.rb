# frozen_string_literal: true

require 'rails_helper'
# WARNING: If you change tests make sure you uncomment this line
# and start a test backend. Some of the actions
# require real backend answers for projects/packages.
# CONFIG['global_write_through'] = true

RSpec.describe StatusController, vcr: true do
  render_views

  describe 'GET #project' do
    let(:admin_user) { create(:admin_user) }
    let(:project) { create(:project, name: 'Apache') }
    let!(:package) { create(:package_with_file, name: 'apache2', project: project) }

    context 'with default attributes' do
      before do
        login(admin_user)
        get :project, params: { project: project.name, format: :xml }
      end

      it { is_expected.to respond_with(:success) }
      it { expect(response.body).to include("project=\"#{project.name}\"") }
      it { expect(response.body).to include("name=\"#{package.name}\"") }
      it { expect(response.body).to include('srcmd5=') }
      it { expect(response.body).to include('changesmd5=') }
      it { expect(response.body).to include('maxmtime=') }
      it { expect(response.body).to include('release=') }
      it { expect(response.body).not_to include('verifymd5=') }
    end

    context 'with verifymd5 attribute' do
      before do
        allow_any_instance_of(ProjectStatus::PackInfo).to receive(:verifymd5).and_return('42')
        login(admin_user)
        get :project, params: { project: project.name, format: :xml }
      end

      it { expect(response.body).to include('verifymd5="42"') }
    end

    context 'with failures' do
      before do
        allow_any_instance_of(ProjectStatus::PackInfo).to receive(:fails).and_return([['repo', 'arch', 'time', 'md5']])
        login(admin_user)
        get :project, params: { project: project.name, format: :xml }
      end

      it { expect(response.body).to include('<failure repo="repo" time="time" srcmd5="md5"/>') }
    end

    context 'with a develpackage' do
      let(:devel_project) { create(:project, name: 'DevelProject') }
      let(:devel_package) { create(:package_with_file, name: 'developmentPackage', project: devel_project) }

      before do
        package.develpackage = devel_package
        package.save
        login(admin_user)
        get :project, params: { project: project.name, format: :xml }
      end

      it { expect(response.body).to include("project=\"#{devel_project.name}\"") }
      it { expect(response.body).to include("name=\"#{devel_package.name}\"") }
    end

    context 'with persons' do
      let!(:relationships) { create(:relationship_package_user, package: package, user: admin_user) }
      let(:role) { relationships.role }

      before do
        login(admin_user)
        get :project, params: { project: project.name, format: :xml }
      end

      it { expect(response.body).to include("userid=\"#{admin_user.login}\"") }
      it { expect(response.body).to include("role=\"#{role.title}\"") }
    end

    context 'with groups' do
      let!(:relationships) { create(:relationship_package_group, package: package) }
      let(:group) { relationships.group }
      let(:role)  { relationships.role }

      before do
        login(admin_user)
        get :project, params: { project: project.name, format: :xml }
      end

      it { expect(response.body).to include("groupid=\"#{group.title}\"") }
      it { expect(response.body).to include("role=\"#{role.title}\"") }
    end

    context 'with errors' do
      before do
        allow_any_instance_of(ProjectStatus::PackInfo).to receive(:error).and_return('the error message')
        login(admin_user)
        get :project, params: { project: project.name, format: :xml }
      end

      it { expect(response.body).to include('<error>the error message</error>') }
    end

    context 'with a link' do
      let(:backend_package) { package.backend_package }

      context 'to a package in the same project' do
        let(:package_link) { create(:package_with_file, name: 'kiwi', project: project) }

        before do
          backend_package.links_to = package_link
          backend_package.save
          login(admin_user)
          get :project, params: { project: project.name, format: :xml }
        end

        it { expect(response.body).to include("<link project=\"#{project.name}\" package=\"#{package_link.name}\"/>\n") }
      end

      context 'to a package in a different project' do
        let(:project_link) { create(:project, name: 'home:tom') }
        let(:package_link) { create(:package_with_file, name: 'kiwi', project: project_link) }

        before do
          backend_package.links_to = package_link
          backend_package.save
          login(admin_user)
          get :project, params: { project: project.name, format: :xml }
        end

        it { expect(response.body).not_to include("<link project=\"#{package_link.project.name}\" package=\"#{package_link.name}\"/>\n") }
      end
    end
  end
end
