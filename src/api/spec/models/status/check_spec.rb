require 'rails_helper'

RSpec.describe Status::Check, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:state) }
    it { is_expected.to validate_presence_of(:name) }

    it { is_expected.to validate_inclusion_of(:state).in_array(%w[pending error failure success]) }
  end
end
