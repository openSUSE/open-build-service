require 'rails_helper'

RSpec.describe BsRequestAction do
  context 'uniqueness validation of type' do
    let(:bs_request) { create(:bs_request) }
    let(:action_attributes) do
      {
        bs_request:     bs_request,
        type:           'submit',
        target_project: 'target_prj',
        target_package: 'target_pkg'
      }
    end
    let!(:bs_request_action) { create(:bs_request_action, action_attributes) }

    it { expect(bs_request_action).to be_valid }

    it 'validates uniqueness of type among bs requests, target_project and target_package' do
      duplicated_bs_request_action = build(:bs_request_action, action_attributes)
      expect(duplicated_bs_request_action).to_not be_valid
      expect(duplicated_bs_request_action.errors.full_messages.to_sentence).to eq('Type has already been taken')
    end

    RSpec.shared_examples 'it skips validation for type' do |type|
      context "type '#{type}'" do
        it 'allows multiple bs request actions' do
          expect(build(:bs_request_action, action_attributes.merge(type: 'add_role'))).to be_valid
        end
      end
    end

    it_should_behave_like 'it skips validation for type', 'add_role'
    it_should_behave_like 'it skips validation for type', 'maintenance_incident'
  end

  it { should belong_to(:bs_request).touch(true) }

  describe '.set_source_and_target_associations' do
    let(:project) { create(:project_with_package, name: 'Apache', package_name: 'apache2') }
    let(:package) { project.packages.first }

    it 'sets target_package_object to package if target_package and target_project parameters provided' do
      action = BsRequestAction.create(target_project: project.name, target_package: package.name)
      expect(action.target_package_object).to eq(package)
    end

    it 'sets target_project_object to project if target_project parameters provided' do
      action = BsRequestAction.create(target_project: project.name)
      expect(action.target_project_object).to eq(project)
    end
  end
end
