require 'rails_helper'

RSpec.describe Status::RepositoryPublish, type: :model do
  describe 'validations' do
    validates :state, :name, :checkable, presence: true
    it { should validate_presence_of(:build_id) }
    it { should validate_presence_of(:repository) }
  end
end
