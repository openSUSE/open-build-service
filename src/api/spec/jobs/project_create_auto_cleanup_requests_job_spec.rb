require 'rails_helper'
require 'webmock/rspec'

RSpec.describe ProjectCreateAutoCleanupRequests, type: :job, vcr: true do
  include ActiveJob::TestHelper

  describe '#perform' do
    let(:admin) { create(:admin_user, login: 'Admin') }
    let(:project) { create(:project, name: 'ProjectA') }
    let(:attribute) { create(:auto_cleanup_attrib, project: project) }

    subject { ProjectCreateAutoCleanupRequests.new.perform }

    before do
      allow(::Configuration).to receive(:cleanup_after_days).and_return(3)
      login(admin)
      attribute
    end

    context 'with project without dependencies' do
      it 'sets a deletion request on the project' do
        subject
        expect(project.target_of_bs_request_actions.where(type: 'delete').count).to eq(1)
      end
    end

    context 'with devel_package inside the project' do
      let(:another_project) { create(:project, name: 'ProjectB') }
      let!(:develpackage) { create(:package, project: project, name: 'DevelPackage') }
      let!(:another_package) { create(:package, project: another_project, name: 'AnotherPackage', develpackage: develpackage) }

      it 'does not create a deletion request' do
        subject
        expect(project.target_of_bs_request_actions.where(type: 'delete').count).to eq(0)
      end
    end
  end
end
