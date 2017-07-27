require 'rails_helper'

# WARNING: If you change tests make sure you uncomment this line
# and start a test backend. Some of the actions
# require real backend answers for projects/packages.
# CONFIG['global_write_through'] = true

RSpec.describe BsRequestAutoAcceptJob, type: :job, vcr: true do
  include ActiveJob::TestHelper

  describe '#perform' do
    let!(:project) { create(:project) }
    let!(:admin) { create(:admin_user) }

    let(:target_package) { create(:package) }
    let(:target_project) { target_package.project }
    let(:source_package) { create(:package) }
    let(:source_project) { source_package.project }

    let!(:request) do
      create(:bs_request_with_submit_action,
             target_project: target_project.name,
             target_package: target_package.name,
             source_project: source_project.name,
             source_package: source_package.name,
             creator: admin.login)
    end

    before do
      allow(BsRequest).to receive(:find).and_return(request)
      allow(request).to receive(:auto_accept)
    end

    subject! { BsRequestAutoAcceptJob.new.perform(request.id) }

    it 'calls auto_accept on the request' do
      expect(request).to have_received(:auto_accept)
    end
  end
end
