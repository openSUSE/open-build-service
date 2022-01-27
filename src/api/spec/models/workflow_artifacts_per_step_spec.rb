require 'rails_helper'

RSpec.describe WorkflowArtifactsPerStep, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:step) }
    it { is_expected.to validate_presence_of(:artifacts) }
  end
end
