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
end
