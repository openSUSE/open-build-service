require 'rails_helper'

RSpec.describe WatchItem do
  let(:user) { create(:confirmed_user) }
  let(:project) { create(:project) }
  let(:package) { create(:package) }
  let(:bs_request) { create(:bs_request_with_submit_action) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:user).with_message('must be given') }
    it { is_expected.to validate_presence_of(:item).with_message('must be given') }
  end

  describe 'adding items' do
    it 'add items correctly' do
      expect(create(:watch_item, user: user, item: project)).not_to be(false)
      expect(user.watch_items.count).to be(1)

      expect(create(:watch_item, user: user, item: package)).not_to be(false)
      expect(user.watch_items.count).to be(2)

      expect(create(:watch_item, user: user, item: bs_request)).not_to be(false)
      expect(user.watch_items.count).to be(3)
    end

    it 'returns false if the item is already in the list' do
      create(:watch_item, user: user, item: project)
      watch_item = build(:watch_item, user: user, item: project)
      expect(watch_item.save).to be(false)
      expect(user.watch_items.count).to be(1)
    end
  end
end
