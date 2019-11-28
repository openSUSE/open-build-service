require 'rails_helper'

RSpec.describe Staging::ProjectCategory, type: :model do
  let(:staging_workflow) { create(:staging_workflow) }

  before do
    staging_workflow.project_categories.create(title: 'Letter', name_pattern: "#{staging_workflow.project.name}:Staging:{(?<nick>\w}")
  end

  describe '#title' do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.not_to(allow_value('').for(:title)) }
  end

  describe '#name_pattern' do
    it { is_expected.to validate_presence_of(:name_pattern) }
    it { is_expected.not_to(allow_value('Just:So').for(:name_pattern)) }
    it { is_expected.to allow_value('Just:(?<nick>So)').for(:name_pattern) }
  end
end
