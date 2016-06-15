require 'rails_helper'

RSpec.describe Package, vcr: true do
  let(:user) { create(:confirmed_user, login: 'tom') }
  let(:home_project) { Project.find_by(name: user.home_project_name) }
  let(:package) { create(:package, name: 'test_package', project: home_project) }
  let(:services) { package.services }

  context '#save_file' do
    before do
      User.current = user
    end

    it 'calls #addKiwiImport if filename ends with kiwi.txz' do
      Service.any_instance.expects(:addKiwiImport).once
      package.save_file({ filename: 'foo.kiwi.txz' })
    end

    it 'does not call #addKiwiImport if filename ends not with kiwi.txz' do
      Service.any_instance.expects(:addKiwiImport).never
      package.save_file({ filename: 'foo.spec' })
    end
  end
end
