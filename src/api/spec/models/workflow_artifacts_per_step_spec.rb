require 'rails_helper'

RSpec.describe WorkflowArtifactsPerStep do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:step) }
    it { is_expected.to validate_presence_of(:artifacts) }
  end
end
