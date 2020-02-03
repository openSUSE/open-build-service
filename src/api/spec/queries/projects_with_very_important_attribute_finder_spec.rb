require 'rails_helper'

RSpec.describe ProjectsWithVeryImportantAttributeFinder do
  let(:project) { create(:project, name: 'project_with_image') }
  let!(:very_important_project_attrib) { create(:very_important_project_attrib, project: project) }

  describe '.call' do
    subject { ProjectsWithVeryImportantAttributeFinder.new.call }

    it { expect(subject).not_to be_empty }
    it { expect(subject).to include(project) }
  end
end
