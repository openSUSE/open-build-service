require 'rails_helper'

RSpec.describe BsRequestAction do
  context 'uniqueness validation of type' do
    let(:bs_request) { create(:bs_request) }
    let(:action_attributes) {
      {
        bs_request:     bs_request,
        type:           'submit',
        target_project: 'target_prj',
        target_package: 'target_pkg'
      }
    }
    let!(:bs_request_action) { create(:bs_request_action, action_attributes) }

    it { expect(bs_request_action).to be_valid }

    it 'validates uniqueness of type among bs requests, target_project and target_package' do
      duplicated_bs_request_action = build(:bs_request_action, action_attributes)
      expect(duplicated_bs_request_action).not_to be_valid
      expect(duplicated_bs_request_action.errors.full_messages.to_sentence).to eq('Type has already been taken')
    end

    describe '.set_associations' do
      let(:project) { create(:project_with_package, name: 'Apache', package_name: 'apache2') }
      let(:package) { project.packages.first }

      it 'sets target to package if target_package and target_project parameters provided' do
        action = BsRequestAction.create(target_project: project.name, target_package: package.name)
        expect(action.target = package)
      end

      it 'sets target to project if target_project parameters provided' do
        action = BsRequestAction.create(target_project: project.name)
        expect(action.target = project)
      end

      it 'sets source to package if source_package and source_project parameters provided' do
        action = BsRequestAction.create(source_project: project.name, source_package: package.name)
        expect(action.source = package)
      end

      it 'sets source to project if target_project parameter provided' do
        action = BsRequestAction.create(source_project: project.name)
        expect(action.source = project)
      end
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
end
