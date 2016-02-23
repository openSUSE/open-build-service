require 'rails_helper'

RSpec.describe Webui::DownloadOnDemandController do
  let(:admin_user) { create(:admin_user) }
  let(:repository) { create(:repository) }
  let(:project)    { create(:project) }

  let(:dod_parameters) {
    {
      project:             project.name,
      download_repository: {
        arch:                 "x86_64",
        repotype:             "rpmmd",
        url:                  "http://mola.org",
        archfilter:           "i586",
        masterurl:            "http://opensuse.org",
        mastersslfingerprint: "asdfasd",
        pubkey:               "3jnlkdsjfoisdjf0932juro2ikjfdslñkfj",
        repository_id:        repository.id
      }
    }
  }

  before do
    project.repositories << repository
  end

  it { is_expected.to use_before_action(:set_project) }

  it "uses strong parameters" do
    login(admin_user)
    should permit(:arch, :repotype, :url, :repository_id, :archfilter, :masterurl, :mastersslfingerprint, :pubkey).
              for(:create, params: dod_parameters).on(:download_repository)
  end

  describe "POST create" do
    context "permission check" do
      skip("Ensure that users can't add dod repositories to repos / projects they have no write access to!")
    end

    context "for non-admin users" do
      before do
        login(create(:confirmed_user))
        post :create, dod_parameters
      end

      it { is_expected.to redirect_to(root_path) }
      it { expect(flash[:error]).to eq("Sorry, you are not authorized to create this DownloadRepository.") }
      it { expect(DownloadRepository.where(dod_parameters[:download_repository])).not_to exist }
    end

    context "valid requests" do
      before do
        login(admin_user)
        post :create, dod_parameters
      end

      it { is_expected.to redirect_to(project_repositories_path(project)) }
      it { expect(flash[:notice]).to eq("Successfully created Download on Demand") }
      it { expect(assigns(:download_on_demand)).to be_kind_of(DownloadRepository) }
      it { expect(DownloadRepository.where(dod_parameters[:download_repository])).to exist }
    end

    context "invalid architecture parameter" do
      before do
        dod_parameters[:download_repository][:arch] = ""
        login(admin_user)
        post :create, dod_parameters
      end

      it { is_expected.to redirect_to(root_path) }
      it { expect(flash[:error]).to eq("Download on Demand can't be created: Arch can't be blank") }
      it { expect(assigns(:download_on_demand)).to be_kind_of(DownloadRepository) }
      it { expect(DownloadRepository.where(dod_parameters[:download_repository])).not_to exist }
    end
  end

  describe 'DELETE destroy' do
    let(:dod_repository) { create(:download_repository) }

    before do
      repository.download_repositories << dod_repository
    end

    context "for non-admin users" do
      before do
        login(create(:confirmed_user))
        delete :destroy, id: dod_repository.id, project: project.name
      end

      it { is_expected.to redirect_to(root_path) }
      it { expect(flash[:error]).to eq("Sorry, you are not authorized to delete this DownloadRepository.") }
      it { expect(DownloadRepository.where(id: dod_repository.id)).to exist }
    end

    context "valid requests" do
      before do
        login(admin_user)
        delete :destroy, id: dod_repository.id, project: project.name
      end

      it { is_expected.to redirect_to(project_repositories_path(project)) }
      it { expect(flash[:notice]).to eq("Successfully removed Download on Demand") }
      it { expect(DownloadRepository.where(id: dod_repository.id)).not_to exist }
    end

    context "invalid requests" do
      skip("Please add some tests:-)")
    end
  end

  describe "POST update" do
    let(:dod_repository) { create(:download_repository) }

    before do
      repository.download_repositories << dod_repository
    end

    context "for non-admin users" do
      before do
        login(create(:confirmed_user))
        dod_parameters[:id] = dod_repository.id
        dod_parameters[:download_repository][:arch] = "s390x"

        post :update, dod_parameters
      end

      it { is_expected.to redirect_to(root_path) }
      it { expect(flash[:error]).to eq("Sorry, you are not authorized to update this DownloadRepository.") }

      it "updates the DownloadRepository" do
        expect(dod_repository.arch).to eq("x86_64")
      end
    end

    context "valid requests" do
      before do
        login(admin_user)
        dod_parameters[:id] = dod_repository.id
        dod_parameters[:download_repository][:arch] = "s390x"

        post :update, dod_parameters
      end

      it { is_expected.to redirect_to(project_repositories_path(project)) }
      it { expect(flash[:notice]).to eq("Successfully updated Download on Demand") }

      it "updates the DownloadRepository" do
        expect(dod_repository.reload.arch).to eq("s390x")
      end
    end

    context "invalid requests" do
      skip("Please add some tests:-)")
    end

    context "repository id" do
      skip("Ensure that users can't change repository_id of an existing dod repository!")
    end
  end
end
