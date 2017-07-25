require 'rails_helper'

RSpec.describe BackendPackage, vcr: true do
  describe '.refresh_dirty' do
    let!(:project) { create(:project) }
    let!(:package) { create(:package_with_file, project: project) }

    subject { BackendPackage.refresh_dirty }

    it do
      expect { subject }.to have_enqueued_job(UpdatePackagesIfDirtyJob).with(project.id)
    end
  end
end
