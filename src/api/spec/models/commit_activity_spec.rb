require 'rails_helper'

RSpec.describe CommitActivity do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:package) }
    it { is_expected.to belong_to(:user) }
    it { is_expected.to validate_presence_of(:date) }
  end
end
