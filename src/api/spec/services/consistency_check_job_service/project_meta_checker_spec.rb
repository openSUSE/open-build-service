require 'rails_helper'

RSpec.describe ::ConsistencyCheckJobService::ProjectMetaChecker, vcr: true do
  let(:project) { create(:project, name: 'super_bacana') }
  let(:project_meta_checker) { described_class.new(project) }
  describe '#call' do
    context 'everything goes well' do
      it { expect { project_meta_checker.call }.not_to raise_error }
    end
  end
end
