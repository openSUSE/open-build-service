require 'rails_helper'

# WARNING: If you change tests make sure you uncomment this line
# and start a test backend. Some of the actions
# require real backend answers for projects/packages.
# CONFIG['global_write_through'] = true

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
