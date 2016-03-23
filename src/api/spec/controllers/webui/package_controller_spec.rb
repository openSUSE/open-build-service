require 'rails_helper'

RSpec.describe Webui::PackageController, vcr: true do
  let(:user) { create(:user, login: 'tom') }
  let(:source_project) { Project.find_by(name: user.home_project_name) }
  let(:source_package) { create(:package, name: 'my_package', project: source_project) }
  let(:target_project) { create(:project) }

  describe 'submit_request' do
    context 'not successful' do
      before do
        login(user)
        post :submit_request, { project: source_project, package: source_package, targetproject: target_project.name }
      end

      it { expect(flash[:error]).to eq('Unable to submit: The source of package home:tom/my_package is broken') }
      it { expect(BsRequestActionSubmit.where(target_project: target_project, target_package: source_package).count).to eq(0) }
    end
  end

  describe 'POST #save' do
    before do
      login(user)
      post :save, { project: source_project, package: source_package, title: 'New title for package', description: 'New description for package' }
    end

    it { expect(flash[:notice]).to eq("Package data for '#{source_package.name}' was saved successfully") }
    it { expect(source_package.reload.title).to eq('New title for package') }
    it { expect(source_package.reload.description).to eq('New description for package') }
    it { expect(response).to redirect_to(package_show_path(project: source_project, package: source_package)) }
  end
end
