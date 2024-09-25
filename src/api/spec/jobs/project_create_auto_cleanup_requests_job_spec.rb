require 'webmock/rspec'

RSpec.describe ProjectCreateAutoCleanupRequestsJob, :vcr do
  include ActiveJob::TestHelper

  describe 'CleanupRequestTemplate' do
    describe '#render' do
      let(:clean_up_template) { described_class::CleanupRequestTemplate.new(project: 'foo', description: 'bar', cleanup_time: 3) }
      let(:bs_delete_request) do
        <<~XML
          <request>
            <action type="delete"><target project="foo"/></action>
            <description>bar</description>
            <state name="new" />
            <accept_at>3</accept_at>
          </request>
        XML
      end

      it { expect(clean_up_template.render).to eq(bs_delete_request) }
    end
  end

  describe '#perform' do
    subject { described_class.perform_now }

    let(:admin) { create(:admin_user, login: 'Admin') }
    let(:project) { create(:project, name: 'ProjectA') }
    let(:attribute) { create(:auto_cleanup_attrib, project: project) }

    before do
      allow(Configuration).to receive(:cleanup_after_days).and_return(3)
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

    context 'with empty cleanup time' do
      before do
        attribute.values.first.value = ''
        attribute.save
      end

      it { expect { subject }.not_to raise_error }
    end

    context 'with invalid cleanup time' do
      before do
        attribute.values.first.value = '200000'
        attribute.save
      end

      it { expect { subject }.not_to raise_error }
    end
  end
end
