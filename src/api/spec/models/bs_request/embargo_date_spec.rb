RSpec.describe 'BsRequest', '#embargo_date' do
  describe '#embargo_date' do
    subject { bs_request.embargo_date }

    let(:target_project) { create(:project) }
    let(:source_project) { create(:embargo_date_attrib, project: create(:project)).project }
    let(:source_package) { create(:package, project: source_project) }

    context 'with no embargo attribute' do
      let(:source_project) { create(:project) }

      let(:bs_request) do
        create(:bs_request_with_maintenance_release_actions, source_project_name: source_project.name,
                                                             target_project_names: [target_project.name],
                                                             package_names: [source_package.name])
      end

      it { expect(subject).to be_nil }
    end

    context 'with one embargo attribute' do
      let(:bs_request) do
        create(:bs_request_with_maintenance_release_actions, source_project_name: source_project.name,
                                                             target_project_names: [target_project.name],
                                                             package_names: [source_package.name])
      end

      it 'is the only date' do
        expect(subject).to eql(source_project.embargo_date)
      end
    end

    context 'with multiple embargo attributes' do
      let(:embargo_date) { 1.week.from_now.change({ hour: 18, min: 30, sec: 0 }) }
      let(:embargo_date_value) { build(:attrib_value, value: embargo_date.to_s) }
      let(:other_source_project) { create(:embargo_date_attrib, project: create(:project), values: [embargo_date_value]).project }
      let(:other_source_package) { create(:package, project: other_source_project) }
      let(:bs_request) do
        multiple_action_request = create(:bs_request_with_maintenance_release_actions, source_project_name: source_project.name,
                                                                                       target_project_names: [target_project.name],
                                                                                       package_names: [source_package.name])
        multiple_action_request.bs_request_actions << create(:bs_request_action_maintenance_release, source_project: other_source_project.name,
                                                                                                     source_package: other_source_package.name,
                                                                                                     target_project: target_project.name)
        multiple_action_request
      end

      it 'is the latest date' do
        expect(subject).to eql(embargo_date)
      end
    end
  end
end
