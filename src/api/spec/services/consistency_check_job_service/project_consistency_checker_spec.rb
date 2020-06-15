require 'rails_helper'

RSpec.describe ::ConsistencyCheckJobService::ProjectConsistencyChecker, vcr: true do
  let(:project) { create(:project, name: 'super_bacana') }
  let(:project_consistency_checker) { described_class.new }

  describe '#call' do
    context 'everything goes well' do
      it { expect { project_consistency_checker.call }.not_to raise_error }
    end
  end
end
