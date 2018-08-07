require 'rails_helper'

RSpec.describe Status::Check, type: :model do
  describe 'validations' do
    validates :state, :name, :checkable, presence: true
    it { should validate_presence_of(:state) }
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:checkable) }

    should validate_inclusion_of(:state).in_array(%w(pending error failure success))
  end
end
