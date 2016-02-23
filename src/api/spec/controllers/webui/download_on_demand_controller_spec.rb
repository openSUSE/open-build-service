require 'rails_helper'

RSpec.describe Webui::DownloadOnDemandController do
  let(:user) { create(:confirmed_user) }
  let(:dod_parameters) {
    {
      download_repository: {
        arch:                 "x86_64",
        repotype:             "rpmmd",
        url:                  "http://mola.org",
        archfilter:           "i586",
        masterurl:            "http://opensuse.org",
        mastersslfingerprint: "asdfasd",
        pubkey:               "3jnlkdsjfoisdjf0932juro2ikjfdslñkfj",
        repository_id:        "???"
      },
      project: user.home_project_name
    }
  }

  it { should permit(:arch, :repotype, :url, :repository_id, :archfilter, :masterurl, :mastersslfingerprint, :pubkey).
              for(:create, params: dod_parameters).on(:download_repository) }
end
