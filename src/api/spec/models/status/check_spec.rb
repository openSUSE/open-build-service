require 'rails_helper'

RSpec.describe Status::Check, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:state) }
    it { is_expected.to validate_presence_of(:name) }

    it do
      expect(subject).to validate_inclusion_of(:state).in_array(%w[pending error failure success])
                                                      .with_message(/is not a valid. Valid states are: pending, error, failure, success/)
    end
  end
end
