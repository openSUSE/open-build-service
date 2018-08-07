require 'rails_helper'

RSpec.describe Status::RepositoryPublish, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:build_id) }
    it { is_expected.to validate_presence_of(:repository) }
  end
end
