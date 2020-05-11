require 'rails_helper'

RSpec.describe ProjectsWithImageTemplatesFinder do
  let(:project) { create(:project, name: 'project_with_image') }
  let!(:template_attrib) { create(:template_attrib, project: project) }

  describe '.call' do
    subject { ProjectsWithImageTemplatesFinder.new.call }

    it { expect(subject).not_to be_empty }
    it { expect(subject).to include(project) }
  end
end
