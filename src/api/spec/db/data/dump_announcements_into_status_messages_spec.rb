require 'rails_helper'
require Rails.root.join('db/data/20200528135241_dump_announcements_into_status_messages.rb')

RSpec.describe DumpAnnouncementsIntoStatusMessages, type: :migration do
  describe 'up' do
    let!(:announcement_1) { create(:announcement, created_at: 2.days.ago) }
    let!(:announcement_2) { create(:announcement, created_at: 1.day.ago) }
    let!(:announcement_3) { create(:announcement) }
    let!(:status_message) { create(:status_message) }
    let(:user_a) { create(:confirmed_user) }
    let(:user_b) { create(:confirmed_user) }
    let(:user_c) { create(:confirmed_user) }
    let!(:admin) { create(:admin_user) }

    before do
      announcement_1.users << [user_a, user_b, user_c]
      announcement_2.users << user_b
      DumpAnnouncementsIntoStatusMessages.new.up
    end

    it 'creates 3 status messages with "announcement" severity' do
      expect(StatusMessage.count).to eq(4)
      expect(StatusMessage.announcements.count).to eq(3)
    end

    it 'creates 4 relationships between status messages and users' do
      expect(user_a.acknowledged_status_messages.count).to eq(1)
      expect(user_b.acknowledged_status_messages.count).to eq(2)
      expect(user_c.acknowledged_status_messages.count).to eq(1)
    end
  end
end
