require 'rails_helper'

RSpec.describe Status::Report do
  describe 'validations' do
    it { is_expected.to belong_to(:checkable) }
    it { is_expected.to validate_presence_of(:uuid) }
  end
end
