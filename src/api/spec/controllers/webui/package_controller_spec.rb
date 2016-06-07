require 'rails_helper'

RSpec.describe Webui::PackageController, vcr: true do
  let(:user) { create(:user, login: 'tom') }
  let(:source_project) { user.home_project }
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

  describe "POST #save_new_link" do
    before do
      login(user)
    end

    it "shows an error if source package doesn't exist" do
      post :save_new_link, project: user.home_project, linked_project: source_project
      expect(flash[:error]).to eq("Failed to branch: Package does not exist.")
      expect(response).to redirect_to(root_path)
    end

    it "shows an error if source project doesn't exist" do
      post :save_new_link, project: user.home_project
      expect(flash[:error]).to eq("Failed to branch: Package does not exist.")
      expect(response).to redirect_to(root_path)
    end
  end
end
