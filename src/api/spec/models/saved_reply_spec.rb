require 'rails_helper'

RSpec.describe SavedReply do
  describe 'validations' do
    let(:saved_reply) { build(:saved_reply) }

    it 'requires title' do
      saved_reply.title = nil
      expect(saved_reply).not_to be_valid
    end

    it 'requires body' do
      saved_reply.body = nil
      expect(saved_reply).not_to be_valid
    end
  end

  describe 'relationship with users' do
    let(:user) { create(:admin_user, login: 'king') }
    let(:saved_reply) { create(:saved_reply, user: user) }

    it { expect(user.saved_replies).to include(saved_reply) }
  end
end
