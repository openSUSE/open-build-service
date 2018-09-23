require 'rails_helper'

RSpec.describe Status::Report, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:checkable) }
    it { is_expected.to validate_presence_of(:uuid) }
  end
end
