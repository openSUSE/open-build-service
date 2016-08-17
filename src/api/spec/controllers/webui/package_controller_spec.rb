require 'rails_helper'

RSpec.describe Webui::PackageController, vcr: true do
  let(:admin) { create(:admin_user, login: "admin") }
  let(:user) { create(:confirmed_user, login: 'tom') }
  let(:source_project) { user.home_project }
  let(:source_package) { create(:package, name: 'my_package', project: source_project) }
  let(:target_project) { create(:project) }
  let(:package) { create(:package_with_file, name: "package_with_file", project: source_project) }

  describe 'submit_request' do
    context "sending a valid submit request" do
      before do
        login(user)
        post :submit_request, { project: source_project, package: package, targetproject: target_project }
      end

      it { expect(flash[:notice]).to match("Created .+submit request \\d.+to .+#{target_project}") }
      it { expect(response).to redirect_to(package_show_path(project: source_project, package: package)) }

      it "creates a submit request" do
        expect(BsRequestActionSubmit.where(target_project: target_project.name, target_package: package.name)).to exist
      end
    end

    context 'not successful' do
      before do
        login(user)
        post :submit_request, { project: source_project, package: source_package, targetproject: target_project.name }
      end

      it { expect(flash[:error]).to eq('Unable to submit: The source of package home:tom/my_package is broken') }
      it { expect(BsRequestActionSubmit.where(target_project: target_project, target_package: source_package)).not_to exist }
    end

    context "a submit request that fails due to validation errors" do
      let(:unconfirmed_user) { create(:user) }

      before do
        login(unconfirmed_user)
        post :submit_request, { project: source_project, package: package, targetproject: target_project }
      end

      it { expect(flash[:error]).to eq("Unable to submit: Validation failed: Creator Login #{unconfirmed_user.login} is not an active user") }
      it { expect(response).to redirect_to(package_show_path(project: source_project, package: package)) }

      it "does not create a submit request and shows an error message" do
        expect(BsRequestActionSubmit.where(target_project: target_project.name, target_package: package.name)).not_to exist
      end
    end

    context "unchanged sources" do
      before do
        login(user)
        post :submit_request, { project: source_project, package: package, targetproject: source_project }
      end

      it { expect(flash[:error]).to eq("Unable to submit, sources are unchanged") }
      it { expect(response).to redirect_to(package_show_path(project: source_project, package: package)) }

      it "doesn't create a submit request" do
        expect(BsRequestActionSubmit.where(target_project: source_project.name, target_package: package.name)).not_to exist
      end
    end

    context "invalid request (missing parameters)" do
      before do
        login(user)
        post :submit_request, { project: source_project, package: "", targetproject: source_project }
      end

      it { expect(flash[:error]).to eq("Unable to submit: #{source_project}/") }
      it { expect(response).to redirect_to(project_show_path(project: source_project)) }
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

  describe "POST #remove" do
    before do
      login(user)
    end

    describe "authentification" do
      let(:target_package) { create(:package, name: "forbidden_package", project: target_project) }

      it "does not allow other users than the owner to delete a package" do
        post :remove, project: target_project, package: target_package

        expect(flash[:error]).to eq("Sorry, you are not authorized to delete this Package.")
        expect(target_project.packages).not_to be_empty
      end

      it "allows admins to delete other user's packages" do
        login(admin)
        post :remove, project: target_project, package: target_package

        expect(flash[:notice]).to eq("Package was successfully removed.")
        expect(target_project.packages).to be_empty
      end
    end

    context "a package" do
      before do
        post :remove, project: user.home_project, package: source_package
      end

      it { expect(response).to have_http_status(:found) }
      it { expect(flash[:notice]).to eq("Package was successfully removed.") }
      it "deletes the package" do
        expect(user.home_project.packages).to be_empty
      end
    end

    context "a package with dependencies" do
      let(:devel_project) { create(:package, project: target_project) }

      before do
        source_package.develpackages << devel_project
      end

      it "does not delete the package and shows an error message" do
        post :remove, project: user.home_project, package: source_package

        expect(flash[:notice]).to eq "Package can't be removed: used as devel package by #{target_project}/#{devel_project}"
        expect(user.home_project.packages).not_to be_empty
      end

      context "forcing the deletion" do
        before do
          post :remove, project: user.home_project, package: source_package, force: true
        end

        it "deletes the package" do
          expect(flash[:notice]).to eq "Package was successfully removed."
          expect(user.home_project.packages).to be_empty
        end
      end
    end
  end
end
