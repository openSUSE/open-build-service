require 'rails_helper'

RSpec.describe Staging::ProjectCategory, type: :model do
  let(:project) { create(:project_with_package, name: 'MyProject') }
  let(:staging_workflow) { create(:staging_workflow, project: project) }
  let(:staging_project_category) { create(:staging_project_category, staging_workflow: staging_workflow, name_pattern: '.*:Staging:(?<nick>\w)') }

  describe '#title' do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.not_to(allow_value('').for(:title)) }
  end

  describe '#name_pattern' do
    it { is_expected.to validate_presence_of(:name_pattern) }

    it { is_expected.not_to allow_value('Just:So').for(:name_pattern) }
    it { is_expected.not_to allow_value('*Hallo').for(:name_pattern) }
    it { is_expected.not_to allow_value('Hallo:(?<nick>').for(:name_pattern) }
    it { is_expected.to allow_value('Just:(?<nick>So)').for(:name_pattern) }
  end

  describe '#nick' do
    it { expect(staging_project_category.nick(project.name)).to be_nil }
    it { expect(staging_project_category.nick('MyProject:Staging:A')).to eq('A') }
  end
end
