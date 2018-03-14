require 'rails_helper'
# WARNING: Some tests require real backend answers, so make sure you uncomment
# this line and start a test backend.
# CONFIG['global_write_through'] = true

RSpec.describe UpdateBackendInfosJob, vcr: true do
  let(:project) { create(:project, name: 'apache') }
  let(:package) { create(:package, name: 'mod_ssl', project: project) }
  let(:user) { create(:admin_user, login: 'myself') }
  let(:event) do
    Event::UndeletePackage.create('project' => project.name, 'package' => package.name,
                               'sender' => user.login, 'comment' => 'fake_payload_comment')
  end

  context 'for an event with a package' do
    before do
      allow(Package).to receive(:find_by_project_and_name).and_return(package)
      allow(package).to receive(:update_backendinfo)
    end

    subject! { event } # UpdateBackendInfosJob gets called when the event is created

    it { expect(package).to have_received(:update_backendinfo) }
  end

  context 'for an event with a package and a linked package' do
    let!(:package2) { create(:package, name: 'mod_rewrite', project: project) }
    let!(:linking_backend_package) { BackendPackage.create(package: package2, links_to: package) }

    before do
      allow(Package).to receive(:find_by_project_and_name).and_return(package)
      allow(package).to receive(:update_backendinfo)
      allow(Package).to receive(:find_by_id).and_return(package2)
      allow(package2).to receive(:update_backendinfo)
    end

    subject! { event } # UpdateBackendInfosJob gets called when the event is created

    it { expect(package).to have_received(:update_backendinfo) }
    it { expect(package2).to have_received(:update_backendinfo) }
  end

  context 'for an event without a package' do
    let(:event_without_package) do
      Event::UndeletePackage.new('project' => project.name, 'package' => nil,
                                 'sender' => user.login, 'comment' => 'fake_payload_comment')
    end

    before do
      allow(Package).to receive(:find_by_project_and_name).and_return(package)
      allow(package).to receive(:update_backendinfo)
    end

    subject! { event_without_package } # UpdateBackendInfosJob gets called when the event is created

    it { expect(package).to_not have_received(:update_backendinfo) }
  end
end
