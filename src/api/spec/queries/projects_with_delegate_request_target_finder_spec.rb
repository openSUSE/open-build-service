require 'rails_helper'

RSpec.describe ProjectsWithDelegateRequestTargetFinder do
  let(:project) { create(:project, name: 'project_that_delegates') }
  let!(:delegate_attrib) { create(:delegate_requests_attrib, project: project) }

  describe '.call' do
    subject { ProjectsWithDelegateRequestTargetFinder.new.call }

    it { expect(subject).not_to be_empty }
    it { expect(subject).to include(project) }
  end
end
