require 'rails_helper'

RSpec.describe BackendPackage, vcr: true do
  describe '.refresh_dirty' do
    let!(:project) { create(:project, name: 'apache') }
    let!(:package) { create(:package_with_file, project: project, name: 'mod_ssl') }

    subject { BackendPackage.refresh_dirty }

    it do
      expect { subject }.to change(BackendPackage, :count).by(1)
    end
  end
end
